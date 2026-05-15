import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MethodChannel shared with `MainActivity.kt` (Android-backed) and
/// `AppDelegate.swift` (iOS stub that reports unsupported).
const _channelName = 'yt_offline/pip';

/// Asks the OS to enter Picture-in-Picture. Resolves with whether the
/// request was issued. The Dart side caches the platform's
/// `isSupported` answer once at first call so we don't repeatedly hit
/// the channel for the UI guard.
class PipController {
  static const _channel = MethodChannel(_channelName);
  bool? _supported;

  /// True if the underlying platform can put us into PiP. Lazy-loaded.
  Future<bool> isSupported() async {
    final cached = _supported;
    if (cached != null) return cached;
    try {
      final v = await _channel.invokeMethod<bool>('isSupported');
      _supported = v ?? false;
    } catch (_) {
      _supported = false;
    }
    return _supported!;
  }

  Future<bool> enter() async {
    try {
      final v = await _channel.invokeMethod<bool>('enter');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }
}

final pipControllerProvider = Provider<PipController>((_) => PipController());

/// One-shot resolution of `isSupported`. UI watches this to decide
/// whether to render the PiP button at all.
final pipSupportedProvider = FutureProvider<bool>((ref) {
  return ref.watch(pipControllerProvider).isSupported();
});
