import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../domain/entities/video_summary.dart';
import '../providers/search_history_provider.dart';
import '../providers/search_providers.dart';
import '../state/search_state.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/video_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _selectionMode = false;
  final _selected = <String>{}; // videoIds

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Rebuild on text or focus change so the body picks the right view.
    _textController.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(searchControllerProvider.notifier).loadMore();
    }
  }

  void _submit([String? query]) {
    final q = (query ?? _textController.text).trim();
    if (q.isEmpty) return;
    if (q != _textController.text) _textController.text = q;
    FocusScope.of(context).unfocus();
    ref.read(searchHistoryProvider.notifier).add(q);
    ref.read(searchControllerProvider.notifier).search(q);
  }

  void _enterSelection(VideoSummary v) {
    setState(() {
      _selectionMode = true;
      _selected.add(v.id);
    });
  }

  void _toggleSelection(VideoSummary v) {
    setState(() {
      if (_selected.contains(v.id)) {
        _selected.remove(v.id);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(v.id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  Future<void> _onVideoTap(VideoSummary v) async {
    if (_selectionMode) {
      _toggleSelection(v);
      return;
    }
    final category = await CategoryPickerSheet.show(context);
    if (category == null || !mounted) return;
    _showPreparing(v.title, category);
    final result = await ref.read(downloadVideoUseCaseProvider)(
      videoId: v.id,
      title: v.title,
      thumbnailUrl: v.thumbnailUrl,
      category: category,
    );
    if (!mounted) return;
    result.when(
      ok: (_) {},
      err: (f) {
        final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
        if (f is AlreadyDownloadedFailure) {
          messenger.showSnackBar(SnackBar(
            content: Text('"${v.title}" is already in your library'),
          ));
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text('Failed: ${f.message}')),
          );
        }
      },
    );
  }

  Future<void> _enqueueSelected(List<VideoSummary> all) async {
    final selected = all.where((v) => _selected.contains(v.id)).toList();
    if (selected.isEmpty) return;
    final category = await CategoryPickerSheet.show(context);
    if (category == null || !mounted) return;
    _showPreparing('${selected.length} videos', category);
    final useCase = ref.read(downloadVideoUseCaseProvider);

    // Fire all enqueues in parallel. Tally duplicates / new so we can
    // surface a single summary at the end.
    final futures = selected.map(
      (v) => useCase(
        videoId: v.id,
        title: v.title,
        thumbnailUrl: v.thumbnailUrl,
        category: category,
      ),
    );
    final results = await Future.wait(futures);
    if (!mounted) return;

    var duplicates = 0;
    var queued = 0;
    for (final r in results) {
      r.when(
        ok: (_) => queued++,
        err: (f) {
          if (f is AlreadyDownloadedFailure) duplicates++;
        },
      );
    }
    if (duplicates > 0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(
            duplicates == selected.length
                ? 'All $duplicates already in library'
                : '$queued queued • $duplicates already in library',
          ),
        ));
    }
    _exitSelection();
  }

  void _showPreparing(String what, String category) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Preparing "$what" → $category',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final loadedVideos = state is SearchLoaded ? state.videos : const <VideoSummary>[];

    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              title: Text('${_selected.length} selected'),
              actions: [
                TextButton.icon(
                  onPressed: () => _enqueueSelected(loadedVideos),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
              ],
            )
          : AppBar(
              title: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  hintText: 'Search YouTube',
                  border: InputBorder.none,
                  suffixIcon: _textController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _textController.clear(),
                        ),
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () => _submit(),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
      body: _focusNode.hasFocus
          ? _HistoryView(
              filter: _textController.text,
              onPick: (q) {
                _textController.text = q;
                _submit(q);
              },
            )
          : switch (state) {
              SearchInitial() => const Center(
                  child: Text(
                    'Tap the search box to start',
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                ),
              SearchLoading() =>
                const Center(child: CircularProgressIndicator()),
              SearchError(:final message) => Center(
                  child: Text(message, style: const TextStyle(fontSize: 16)),
                ),
              SearchLoaded(videos: final v) when v.isEmpty =>
                const Center(child: Text('No results')),
              SearchLoaded() => _ResultList(
                  state: state,
                  scrollController: _scrollController,
                  selectionMode: _selectionMode,
                  selected: _selected,
                  onTap: _onVideoTap,
                  onLongPress: _enterSelection,
                ),
            },
    );
  }
}

class _ResultList extends StatelessWidget {
  final SearchLoaded state;
  final ScrollController scrollController;
  final bool selectionMode;
  final Set<String> selected;
  final ValueChanged<VideoSummary> onTap;
  final ValueChanged<VideoSummary> onLongPress;

  const _ResultList({
    required this.state,
    required this.scrollController,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final videos = state.videos;
    final itemCount = videos.length + (state.hasMore ? 1 : 0);
    return ListView.separated(
      controller: scrollController,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i >= videos.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final v = videos[i];
        return VideoCard(
          video: v,
          selected: selectionMode ? selected.contains(v.id) : null,
          onTap: () => onTap(v),
          onLongPress: () => onLongPress(v),
        );
      },
    );
  }
}

class _HistoryView extends ConsumerWidget {
  final String filter;
  final ValueChanged<String> onPick;

  const _HistoryView({required this.filter, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(searchHistoryProvider);

    return asyncHistory.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (all) {
        final f = filter.trim().toLowerCase();
        final visible = f.isEmpty
            ? all
            : all.where((q) => q.toLowerCase().contains(f)).toList();

        if (all.isEmpty) {
          return const Center(
            child: Text(
              'Type and press search',
              style: TextStyle(color: Colors.black87, fontSize: 16),
            ),
          );
        }
        if (visible.isEmpty) {
          return Center(
            child: Text(
              'No history matches "$filter"',
              style: const TextStyle(color: Colors.black54),
            ),
          );
        }
        return ListView.builder(
          itemCount: visible.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    Text(
                      'Recent (${visible.length}${f.isEmpty ? '' : '/${all.length}'})',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(searchHistoryProvider.notifier).clear(),
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text('Clear all'),
                    ),
                  ],
                ),
              );
            }
            final q = visible[i - 1];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.history, size: 20),
              title: Text(q),
              trailing: IconButton(
                iconSize: 18,
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(searchHistoryProvider.notifier).delete(q),
              ),
              onTap: () => onPick(q),
            );
          },
        );
      },
    );
  }
}
