import 'dart:io';

import 'package:flutter/services.dart';

/// One-shot read of the iOS provisioning profile expiry, exposed by
/// `AppDelegate.swift`. Returns `null` on Android or when the bundle
/// doesn't ship an embedded profile (release App-Store builds).
class ProfileInfo {
  /// When the embedded signing profile stops being valid. Local time on the
  /// device; iOS parses the raw ExpirationDate as a `Date` and we just round-
  /// trip it as ISO-8601 across the channel.
  final DateTime expiresAt;
  const ProfileInfo({required this.expiresAt});

  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());
  bool get isExpired => timeUntilExpiry.isNegative;
}

class ProfileInfoChannel {
  static const _channel = MethodChannel('yt_offline/profile');

  static Future<ProfileInfo?> fetch() async {
    if (!Platform.isIOS) return null;
    try {
      final iso = await _channel.invokeMethod<String>('expiry');
      if (iso == null) return null;
      return ProfileInfo(expiresAt: DateTime.parse(iso).toLocal());
    } catch (_) {
      return null;
    }
  }
}
