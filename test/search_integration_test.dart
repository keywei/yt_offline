// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:yt_offline/core/result/result.dart';
import 'package:yt_offline/features/search/data/datasources/youtube_search_remote_datasource.dart';
import 'package:yt_offline/features/search/data/repositories/search_repository_impl.dart';

void main() {
  test('end-to-end: YouTube search returns videos through Clean Arch layers',
      () async {
    final yt = YoutubeExplode();
    addTearDown(yt.close);

    final repo = SearchRepositoryImpl(YoutubeSearchRemoteDataSource(yt));
    final result = await repo.search('flutter tutorial');

    switch (result) {
      case Ok(:final value):
        expect(value.items, isNotEmpty);
        final first = value.items.first;
        print('Got ${value.items.length} results, hasMore=${value.hasMore}');
        print('First: "${first.title}" by ${first.author} '
            '(${first.duration.inMinutes}m, ${first.viewCount} views)');
        expect(first.id, isNotEmpty);
        expect(first.thumbnailUrl, startsWith('http'));
      case Err(:final failure):
        fail('Expected Ok, got Err: $failure');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
