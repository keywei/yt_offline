import 'package:flutter/widgets.dart';

import '../storage/video_metadata.dart';

/// Supported app languages. The order here drives the Settings picker.
const supportedLocales = <Locale>[
  Locale('en'),
  Locale('zh', 'TW'),
];

/// Translates a small, hand-curated set of UI strings. Codegen-free: one
/// method per string, every string declared in both English and Traditional
/// Chinese inline. Keeps the project consistent with the rest of the
/// "no build_runner" stance — to add a string, edit one file.
class S {
  final Locale locale;
  const S(this.locale);

  static S of(BuildContext context) => S(Localizations.localeOf(context));

  bool get _zh => locale.languageCode == 'zh';

  String _pick(String en, String zh) => _zh ? zh : en;

  // ---- Tabs ----
  String get tabSearch => _pick('Search', '搜尋');
  String get tabLibrary => _pick('Library', '媒體庫');
  String get tabSettings => _pick('Settings', '設定');

  // ---- Search screen ----
  String get searchYouTube => _pick('Search YouTube', '搜尋 YouTube');
  String get searchInitialHint =>
      _pick('Tap the search box to start', '點搜尋框開始搜尋');
  String get searchNoResults => _pick('No results', '沒有結果');
  String recentHeader(int visible, int? total) {
    final base = _pick('Recent', '最近搜尋');
    return total == null ? '$base ($visible)' : '$base ($visible/$total)';
  }

  String get clearAll => _pick('Clear all', '全部清除');
  String noHistoryMatch(String filter) =>
      _pick('No history matches "$filter"', '搜尋紀錄找不到「$filter」');
  String get selectedCount {
    // Replaced inline via {n} selected; helper not used directly.
    return '';
  }

  String selectedN(int n) => _pick('$n selected', '已選 $n');
  String get download => _pick('Download', '下載');
  String get preparing => _pick('Preparing', '準備中');
  String preparingItem(String what, String category) =>
      _pick('Preparing "$what" → $category', '準備中：「$what」→ $category');
  String alreadyInLibrary(String title) =>
      _pick('"$title" is already in your library', '「$title」已在媒體庫中');
  String failed(String reason) => _pick('Failed: $reason', '失敗：$reason');
  String allAlreadyInLibrary(int n) =>
      _pick('All $n already in library', '全部 $n 部已在媒體庫');
  String batchSummary(int queued, int duplicates) =>
      _pick(
        '$queued queued • $duplicates already in library',
        '已加入 $queued 部 • $duplicates 部已存在',
      );

  // ---- Category picker ----
  String get downloadIntoCategory =>
      _pick('Download into category', '下載到分類');
  String get newCategoryHint => _pick('New category name', '新分類名稱');
  String get defaultCategory => _pick('Uncategorized', '未分類');

  /// Wraps display of an arbitrary category name so the special
  /// [VideoMetadata.defaultCategory] sentinel renders in the current
  /// locale instead of leaking the raw English storage key.
  String displayCategory(String raw) =>
      raw == VideoMetadata.defaultCategory ? defaultCategory : raw;

  // ---- Library ----
  String get libraryEmpty => _pick(
        'Nothing downloaded yet.\nTap a video on Search to download.',
        '尚未下載任何影片。\n到搜尋頁點影片下載。',
      );
  String inProgressHeader(int n) =>
      _pick('In progress ($n)', '進行中（$n）');
  String resumeFrom(String time) => _pick('Resume $time', '從 $time 繼續');
  String get missingFile => _pick('missing file', '檔案遺失');
  String get newCategory => _pick('New category', '新增分類');
  String get collapseExpandAll =>
      _pick('Collapse / expand all', '全部收摺/展開');
  String get refresh => _pick('Refresh', '重新整理');
  String get moveToCategory => _pick('Move to category', '移動到分類');
  String moveNVideosTo(int n) =>
      _pick('Move $n videos to…', '移動 $n 部影片到…');
  String get renameCategory => _pick('Rename category', '重新命名分類');
  String get deleteCategory => _pick('Delete category', '刪除分類');
  String get videosMoveToUncategorised =>
      _pick('Videos move to Uncategorized', '影片會移到「未分類」');
  String renameOf(String name) =>
      _pick('Rename "$name"', '重新命名「$name」');
  String deleteCategoryConfirm(String name) =>
      _pick('Delete category "$name"?', '刪除分類「$name」？');
  String get deleteCategoryBody => _pick(
        'All videos in this category will move to Uncategorized.',
        '此分類下的所有影片將移到「未分類」。',
      );
  String get name => _pick('Name', '名稱');
  String get cancel => _pick('Cancel', '取消');
  String get delete => _pick('Delete', '刪除');
  String get pause => _pick('Pause', '暫停');
  String get resume => _pick('Resume', '繼續');
  String get retry => _pick('Retry', '重試');
  String get dismiss => _pick('Dismiss', '關閉');

  // ---- Download status labels ----
  String get statusPreparing => _pick('Resolving stream…', '解析串流中…');
  String get statusQueued => _pick('Queued', '排隊中');
  String get statusRunning => _pick('Downloading', '下載中');
  String get statusPaused => _pick('Paused', '已暫停');
  String get statusComplete => _pick('Complete', '已完成');
  String get statusFailed => _pick('Failed', '失敗');
  String get statusCanceled => _pick('Canceled', '已取消');

  // ---- Player controls ----
  String get play => _pick('Play', '播放');
  String get next => _pick('Next', '下一首');
  String get previous => _pick('Previous', '上一首');
  String get shuffle => _pick('Shuffle', '隨機');
  String loopMode(String mode) {
    final translatedMode = switch (mode) {
      'off' => _pick('off', '關閉'),
      'one' => _pick('one', '單曲'),
      'all' => _pick('all', '全部'),
      _ => mode,
    };
    return _pick('Loop: $mode', '循環：$translatedMode');
  }

  String get speed => _pick('Playback speed', '播放速度');
  String get sleep => _pick('Sleep', '睡眠');
  String get sleepTimer => _pick('Sleep timer', '睡眠計時');
  String get sleepOff => _pick('Off', '關閉');
  String get sleepEndOfTrack =>
      _pick('End of current track', '當前播放結束');
  String get sleepMinutes5 => _pick('5 minutes', '5 分鐘');
  String get sleepMinutes15 => _pick('15 minutes', '15 分鐘');
  String get sleepMinutes30 => _pick('30 minutes', '30 分鐘');
  String get sleepHour1 => _pick('1 hour', '1 小時');
  String get endOfTrack => _pick('End of track', '結束本首');
  String get fullscreen => _pick('Fullscreen', '全螢幕');
  String get exitFullscreen => _pick('Exit fullscreen', '退出全螢幕');
  String get stop => _pick('Stop', '停止');
  String get collapse => _pick('Collapse', '收摺');
  String get nothingToPlay => _pick('Nothing to play.', '沒有可播放的內容');

  // ---- Settings ----
  String get version => _pick('Version', '版本');
  String get source => _pick('Source', '原始碼');
  String get language => _pick('Language', '語言');
  String get theme => _pick('Theme', '主題');
  String get themeLight => _pick('Light', '亮色');
  String get themeDark => _pick('Dark', '暗色');
  String get themeSystem => _pick('Follow system', '跟隨系統');
  String get languageEnglish => _pick('English', 'English');
  String get languageZhTw => _pick('Traditional Chinese', '繁體中文');

  // ---- Search filters ----
  String get searchFiltersTitle => _pick('Search filters', '搜尋篩選');
  String get filtersApply => _pick('Apply', '套用');
  String get filtersReset => _pick('Reset', '重設');
  String get filterAny => _pick('Any', '不限');
  String get filterSort => _pick('Sort by', '排序');
  String get filterDuration => _pick('Duration', '長度');
  String get filterUploadDate => _pick('Upload date', '上傳時間');
  String get sortRelevance => _pick('Relevance', '相關性');
  String get sortUploadDate => _pick('Upload date', '上傳時間');
  String get sortViewCount => _pick('View count', '觀看次數');
  String get sortRating => _pick('Rating', '評分');
  String get durationShort => _pick('Short (< 4 min)', '短片（< 4 分鐘）');
  String get durationLong => _pick('Long (> 20 min)', '長片（> 20 分鐘）');
  String get uploadLastHour => _pick('Last hour', '最近一小時');
  String get uploadToday => _pick('Today', '今天');
  String get uploadLastWeek => _pick('This week', '本週');
  String get uploadLastMonth => _pick('This month', '本月');
  String get uploadLastYear => _pick('This year', '今年');
  String filterActiveBadge(int n) =>
      _pick('$n filter${n == 1 ? '' : 's'}', '已套用 $n 項');

  // ---- Subtitle settings ----
  String get subtitlesSectionTitle => _pick('Subtitles', '字幕');
  String get subtitleSettingsTitle =>
      _pick('Subtitle appearance', '字幕外觀');
  String get subtitlePreview => _pick('Preview', '預覽');
  String get subtitlePreviewText =>
      _pick('The quick brown fox jumps over the lazy dog', '字幕外觀預覽範例');
  String get subtitleFontSizeLabel => _pick('Font size', '字體大小');
  String get subtitleColorLabel => _pick('Color', '顏色');
  String get subtitleBackgroundLabel =>
      _pick('Background opacity', '背景透明度');
  String get subtitlePositionLabel => _pick('Vertical position', '垂直位置');
  String get subtitlePosTop => _pick('Top', '上');
  String get subtitlePosMiddle => _pick('Middle', '中');
  String get subtitlePosBottom => _pick('Bottom', '下');

  // ---- A-B segment loop ----
  String get abPointA => _pick('A', 'A');
  String get abPointB => _pick('B', 'B');
  String get abClear => _pick('Clear A-B loop', '清除 A-B 循環');

  // ---- Storage management ----
  String get storageSectionTitle => _pick('Storage', '儲存空間');
  String get storageTitle => _pick('Storage usage', '儲存空間使用');
  String get storagePerCategory => _pick('By category', '依分類');
  String get storageBiggest => _pick('Biggest videos', '最大的影片');
  String get storageCleanup => _pick('Cleanup', '清理');
  String storageUsedSummary(int n) =>
      _pick('Used across $n video${n == 1 ? '' : 's'}',
          '共 $n 部影片佔用');
  String get storageNoWatched =>
      _pick('No fully-watched videos to delete', '沒有看完的影片可刪除');
  String storageDeleteWatched(int n, String size) =>
      _pick('Delete $n watched ($size)', '刪除 $n 部已看完（$size）');
  String get storageDeleteWatchedSubtitle =>
      _pick('Frees space without touching unfinished videos',
          '不影響尚未看完的影片');
  String get storageDeleteWatchedConfirmTitle =>
      _pick('Delete watched videos?', '刪除已看完的影片？');
  String storageDeleteWatchedConfirmBody(int n, String size) => _pick(
        'This will permanently delete $n video${n == 1 ? '' : 's'} '
            'totalling $size from your device.',
        '將會永久刪除 $n 部影片，共 $size。',
      );

  // ---- Watch history ----
  String get historySectionTitle => _pick('History', '紀錄');
  String get historyTitle => _pick('Watch history', '觀看紀錄');
  String get historyEmpty =>
      _pick('No watch history yet', '尚無觀看紀錄');
  String get historyClearTitle =>
      _pick('Clear watch history?', '清除觀看紀錄？');
  String get historyClearBody => _pick(
        'Removes every recorded play. Does not delete videos.',
        '會移除所有紀錄，但不會刪除影片。',
      );
  String historyPlayedUpTo(String pos, String total) =>
      _pick('Played up to $pos of $total', '已播放 $pos / $total');
  String get historyVideoMissing =>
      _pick('Video no longer in library', '影片已不在媒體庫中');
  String get relTimeJustNow => _pick('Just now', '剛剛');
  String relTimeMinutesAgo(int n) =>
      _pick('$n minute${n == 1 ? '' : 's'} ago', '$n 分鐘前');
  String relTimeHoursAgo(int n) =>
      _pick('$n hour${n == 1 ? '' : 's'} ago', '$n 小時前');
  String relTimeDaysAgo(int n) =>
      _pick('$n day${n == 1 ? '' : 's'} ago', '$n 天前');

  // ---- Misc ----
  String get loading => _pick('Loading…', '載入中…');
}
