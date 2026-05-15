import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the now-playing overlay is in its expanded (full-screen) state.
/// Mini player taps → set true; collapse button / Android back → set false.
final nowPlayingExpandedProvider = StateProvider<bool>((_) => false);
