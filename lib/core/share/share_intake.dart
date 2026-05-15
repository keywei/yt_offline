import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Channel name shared with `MainActivity.kt` and `AppDelegate.swift`.
const _channelName = 'yt_offline/share';

/// Holds the latest pending share text (a URL or plain text from
/// another app's share sheet). Set when the OS hands us a fresh share
/// either via cold-launch intent or `onShare` push; cleared by the
/// consumer (typically [SearchScreen]) after it routes the value.
final pendingShareProvider = StateProvider<String?>((_) => null);

/// Owns the platform channel that surfaces incoming shares. Initialised
/// once at app start; survives for the app's lifetime.
class ShareIntake {
  ShareIntake(this._ref) {
    _channel.setMethodCallHandler(_onCall);
    _drainInitial();
  }

  final Ref _ref;
  final MethodChannel _channel = const MethodChannel(_channelName);

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method != 'onShare') return null;
    final v = call.arguments;
    if (v is String && v.isNotEmpty) {
      _ref.read(pendingShareProvider.notifier).state = v;
    }
    return null;
  }

  Future<void> _drainInitial() async {
    try {
      final v = await _channel.invokeMethod<String?>('getInitial');
      if (v != null && v.isNotEmpty) {
        _ref.read(pendingShareProvider.notifier).state = v;
      }
    } catch (_) {
      // Channel unavailable (e.g. tests). Ignore.
    }
  }
}

/// Eagerly-built provider so the channel handler is up before the first
/// share intent can reach the engine.
final shareIntakeProvider = Provider<ShareIntake>(ShareIntake.new);
