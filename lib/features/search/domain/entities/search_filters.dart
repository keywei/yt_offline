import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Sort order for YouTube search results.
enum SortBy {
  relevance(0),
  uploadDate(2),
  viewCount(3),
  rating(1);

  final int wireValue;
  const SortBy(this.wireValue);
}

/// Approximate duration buckets YouTube exposes via the `sp=` parameter.
enum DurationFilter {
  any(0),
  short(1), // < 4 min
  long(2);  // > 20 min

  final int wireValue;
  const DurationFilter(this.wireValue);
}

/// Upload-date windows YouTube exposes via the `sp=` parameter.
enum UploadDate {
  any(0),
  lastHour(1),
  today(2),
  lastWeek(3),
  lastMonth(4),
  lastYear(5);

  final int wireValue;
  const UploadDate(this.wireValue);
}

/// Hand-rolled value class — same no-codegen stance as the rest of the
/// project. Encodes itself into YouTube's `sp` query parameter on demand.
@immutable
class SearchFilters {
  final SortBy sort;
  final DurationFilter duration;
  final UploadDate uploadDate;

  const SearchFilters({
    this.sort = SortBy.relevance,
    this.duration = DurationFilter.any,
    this.uploadDate = UploadDate.any,
  });

  static const none = SearchFilters();

  bool get isEmpty =>
      sort == SortBy.relevance &&
      duration == DurationFilter.any &&
      uploadDate == UploadDate.any;

  bool get isNotEmpty => !isEmpty;

  /// Number of non-default groups set; drives the "filter active" badge.
  int get activeCount {
    var n = 0;
    if (sort != SortBy.relevance) n++;
    if (duration != DurationFilter.any) n++;
    if (uploadDate != UploadDate.any) n++;
    return n;
  }

  SearchFilters copyWith({
    SortBy? sort,
    DurationFilter? duration,
    UploadDate? uploadDate,
  }) =>
      SearchFilters(
        sort: sort ?? this.sort,
        duration: duration ?? this.duration,
        uploadDate: uploadDate ?? this.uploadDate,
      );

  /// Encodes this filter combination as the `sp` query parameter YouTube
  /// expects on `https://www.youtube.com/results`. The format is a
  /// base64-encoded protobuf with two top-level fields:
  ///
  /// - field 1 (varint): sort
  /// - field 2 (sub-message): filters
  ///   - sub-field 1 (varint): upload date
  ///   - sub-field 3 (varint): duration
  ///
  /// Returns the empty string when no filter is active so the caller can
  /// skip the URL parameter entirely.
  String toSpValue() {
    if (isEmpty) return '';
    final bytes = <int>[];
    if (sort != SortBy.relevance) {
      bytes.add(0x08); // field 1, varint
      bytes.addAll(_encodeVarint(sort.wireValue));
    }
    final inner = <int>[];
    if (uploadDate != UploadDate.any) {
      inner.add(0x08); // sub-field 1, varint
      inner.addAll(_encodeVarint(uploadDate.wireValue));
    }
    if (duration != DurationFilter.any) {
      inner.add(0x18); // sub-field 3, varint
      inner.addAll(_encodeVarint(duration.wireValue));
    }
    if (inner.isNotEmpty) {
      bytes.add(0x12); // field 2, length-delimited
      bytes.addAll(_encodeVarint(inner.length));
      bytes.addAll(inner);
    }
    return base64Encode(bytes);
  }

  static List<int> _encodeVarint(int v) {
    final out = <int>[];
    var n = v;
    while (n >= 0x80) {
      out.add((n & 0x7F) | 0x80);
      n >>= 7;
    }
    out.add(n);
    return out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchFilters &&
          other.sort == sort &&
          other.duration == duration &&
          other.uploadDate == uploadDate);

  @override
  int get hashCode => Object.hash(sort, duration, uploadDate);
}
