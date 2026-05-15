import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/video_metadata.dart';
import '../../../library/presentation/providers/library_providers.dart';

/// Shows existing categories (derived from current library) + lets the user
/// type a new one. Returns the chosen category via `Navigator.pop`.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const CategoryPickerSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CategoryPickerSheet(),
    );
  }

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitNew() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryListProvider);
    final categories = library.maybeWhen(
      data: (videos) => videos
          .map((v) => v.category)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
      orElse: () => <String>[],
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Download into category',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitNew(),
                decoration: InputDecoration(
                  hintText: 'New category name',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _submitNew,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.inbox_outlined),
                    title: const Text(VideoMetadata.defaultCategory),
                    onTap: () => Navigator.of(context)
                        .pop(VideoMetadata.defaultCategory),
                  ),
                  ...categories
                      .where((c) => c != VideoMetadata.defaultCategory)
                      .map(
                        (c) => ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(c),
                          onTap: () => Navigator.of(context).pop(c),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
