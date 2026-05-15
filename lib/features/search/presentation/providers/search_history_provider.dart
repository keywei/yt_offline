import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/search_history_store.dart';

final searchHistoryStoreProvider =
    Provider<SearchHistoryStore>((_) => SearchHistoryStore());

class SearchHistoryController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() =>
      ref.read(searchHistoryStoreProvider).load();

  Future<void> add(String query) async {
    await ref.read(searchHistoryStoreProvider).add(query);
    ref.invalidateSelf();
  }

  Future<void> delete(String query) async {
    await ref.read(searchHistoryStoreProvider).delete(query);
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    await ref.read(searchHistoryStoreProvider).clear();
    ref.invalidateSelf();
  }
}

final searchHistoryProvider =
    AsyncNotifierProvider<SearchHistoryController, List<String>>(
  SearchHistoryController.new,
);
