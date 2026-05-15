import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/strings.dart';
import '../../domain/entities/search_filters.dart';
import '../providers/search_providers.dart';

class SearchFiltersSheet extends ConsumerStatefulWidget {
  const SearchFiltersSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SearchFiltersSheet(),
    );
  }

  @override
  ConsumerState<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends ConsumerState<SearchFiltersSheet> {
  late SearchFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(searchFiltersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      s.searchFiltersTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (_draft.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            setState(() => _draft = SearchFilters.none),
                        child: Text(s.filtersReset),
                      ),
                  ],
                ),
              ),
              _sectionHeader(context, s.filterSort),
              ..._sortOptions(context, s),
              const Divider(height: 1),
              _sectionHeader(context, s.filterDuration),
              ..._durationOptions(context, s),
              const Divider(height: 1),
              _sectionHeader(context, s.filterUploadDate),
              ..._uploadDateOptions(context, s),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ref
                          .read(searchFiltersProvider.notifier)
                          .update(_draft);
                      Navigator.of(context).pop();
                    },
                    child: Text(s.filtersApply),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );

  Widget _radioRow<T>({
    required T value,
    required T groupValue,
    required String label,
    required ValueChanged<T> onPick,
  }) =>
      ListTile(
        dense: true,
        leading: Icon(
          value == groupValue
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: value == groupValue ? Colors.amber : null,
        ),
        title: Text(label),
        onTap: () => onPick(value),
      );

  List<Widget> _sortOptions(BuildContext context, S s) {
    String label(SortBy v) => switch (v) {
          SortBy.relevance => s.sortRelevance,
          SortBy.uploadDate => s.sortUploadDate,
          SortBy.viewCount => s.sortViewCount,
          SortBy.rating => s.sortRating,
        };
    return [
      for (final v in SortBy.values)
        _radioRow<SortBy>(
          value: v,
          groupValue: _draft.sort,
          label: label(v),
          onPick: (picked) =>
              setState(() => _draft = _draft.copyWith(sort: picked)),
        ),
    ];
  }

  List<Widget> _durationOptions(BuildContext context, S s) {
    String label(DurationFilter v) => switch (v) {
          DurationFilter.any => s.filterAny,
          DurationFilter.short => s.durationShort,
          DurationFilter.long => s.durationLong,
        };
    return [
      for (final v in DurationFilter.values)
        _radioRow<DurationFilter>(
          value: v,
          groupValue: _draft.duration,
          label: label(v),
          onPick: (picked) =>
              setState(() => _draft = _draft.copyWith(duration: picked)),
        ),
    ];
  }

  List<Widget> _uploadDateOptions(BuildContext context, S s) {
    String label(UploadDate v) => switch (v) {
          UploadDate.any => s.filterAny,
          UploadDate.lastHour => s.uploadLastHour,
          UploadDate.today => s.uploadToday,
          UploadDate.lastWeek => s.uploadLastWeek,
          UploadDate.lastMonth => s.uploadLastMonth,
          UploadDate.lastYear => s.uploadLastYear,
        };
    return [
      for (final v in UploadDate.values)
        _radioRow<UploadDate>(
          value: v,
          groupValue: _draft.uploadDate,
          label: label(v),
          onPick: (picked) =>
              setState(() => _draft = _draft.copyWith(uploadDate: picked)),
        ),
    ];
  }
}
