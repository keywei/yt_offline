import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_info_channel.dart';

/// One-shot fetch of the embedded provisioning profile's expiry. Null on
/// Android. Refreshed by `ref.invalidate(profileInfoProvider)` after any
/// reinstall — the new build ships a fresh embedded.mobileprovision.
final profileInfoProvider = FutureProvider<ProfileInfo?>((_) {
  return ProfileInfoChannel.fetch();
});
