import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/watch_history_store.dart';

final watchHistoryStoreProvider =
    Provider<WatchHistoryStore>((_) => WatchHistoryStore());

class WatchHistoryController extends AsyncNotifier<List<WatchEvent>> {
  @override
  Future<List<WatchEvent>> build() =>
      ref.read(watchHistoryStoreProvider).load();

  Future<void> clear() async {
    await ref.read(watchHistoryStoreProvider).clear();
    state = const AsyncData([]);
  }

  /// Pulled in by the playback controller — re-read from disk after a
  /// write so the UI shows the freshest row.
  void refresh() => ref.invalidateSelf();
}

final watchHistoryProvider =
    AsyncNotifierProvider<WatchHistoryController, List<WatchEvent>>(
  WatchHistoryController.new,
);
