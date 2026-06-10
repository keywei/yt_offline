import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/i18n/settings_providers.dart';
import '../../../../core/i18n/strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/preferences_store.dart';
import '../providers/profile_info_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;
    return Scaffold(
      appBar: AppBar(title: Text(s.tabSettings)),
      body: ListView(
        children: [
          _section(context, s.theme),
          _ThemeTile(s: s, current: prefs.themeMode),
          const Divider(height: 1),
          _section(context, s.language),
          _LanguageTile(s: s, current: prefs.locale),
          const Divider(height: 1),
          _section(context, s.subtitlesSectionTitle),
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: Text(s.subtitleSettingsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(
              '${Routes.settings}/${Routes.subtitleSettings}',
            ),
          ),
          const Divider(height: 1),
          _section(context, s.storageSectionTitle),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: Text(s.storageTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.go('${Routes.settings}/${Routes.storage}'),
          ),
          const Divider(height: 1),
          _section(context, s.historySectionTitle),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(s.historyTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.go('${Routes.settings}/${Routes.history}'),
          ),
          const Divider(height: 1),
          _section(context, 'About'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final subtitle = info == null
                  ? s.loading
                  : '${info.version} (build ${info.buildNumber})';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(s.version),
                subtitle: Text(subtitle),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(s.source),
            subtitle: const Text('github.com/keywei/yt_offline'),
          ),
          _ProfileExpiryTile(s: s),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );
}

/// iOS-only signing-profile expiry indicator. Hidden on Android (the
/// provider returns null). Goes amber under 2 days and red once expired.
class _ProfileExpiryTile extends ConsumerWidget {
  final S s;
  const _ProfileExpiryTile({required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileInfoProvider);
    final info = async.valueOrNull;
    if (info == null) return const SizedBox.shrink();

    final remaining = info.timeUntilExpiry;
    final expired = info.isExpired;
    final color = expired
        ? Colors.red
        : (remaining < const Duration(days: 2)
            ? Colors.amber
            : null);

    final String subtitle;
    if (expired) {
      subtitle = '${_fmtDateTime(info.expiresAt)} · ${s.signingProfileExpired}';
    } else {
      final hours = remaining.inHours.remainder(24);
      subtitle =
          '${_fmtDateTime(info.expiresAt)} · ${s.signingProfileExpiresIn(remaining.inDays, hours)}';
    }

    return ListTile(
      leading: Icon(
        expired ? Icons.error_outline : Icons.verified_user_outlined,
        color: color,
      ),
      title: Text(s.signingProfile),
      subtitle: Text(
        subtitle,
        style: color == null ? null : TextStyle(color: color),
      ),
    );
  }

  String _fmtDateTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}

class _ThemeTile extends ConsumerWidget {
  final S s;
  final ThemeMode current;
  const _ThemeTile({required this.s, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String label(ThemeMode m) => switch (m) {
          ThemeMode.light => s.themeLight,
          ThemeMode.dark => s.themeDark,
          ThemeMode.system => s.themeSystem,
        };
    IconData icon(ThemeMode m) => switch (m) {
          ThemeMode.light => Icons.light_mode,
          ThemeMode.dark => Icons.dark_mode,
          ThemeMode.system => Icons.brightness_auto,
        };

    return ListTile(
      leading: Icon(icon(current)),
      title: Text(s.theme),
      subtitle: Text(label(current)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<ThemeMode>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in ThemeMode.values)
                  ListTile(
                    leading: Icon(icon(m)),
                    title: Text(label(m)),
                    trailing: m == current
                        ? const Icon(Icons.check, color: Colors.amber)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(m),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) {
          await ref
              .read(appPreferencesProvider.notifier)
              .setThemeMode(picked);
        }
      },
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  final S s;
  final Locale current;
  const _LanguageTile({required this.s, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String label(Locale l) {
      if (l.languageCode == 'zh') return s.languageZhTw;
      return s.languageEnglish;
    }

    return ListTile(
      leading: const Icon(Icons.translate),
      title: Text(s.language),
      subtitle: Text(label(current)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<Locale>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final loc in supportedLocales)
                  ListTile(
                    title: Text(label(loc)),
                    trailing: loc.languageCode == current.languageCode
                        ? const Icon(Icons.check, color: Colors.amber)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(loc),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) {
          await ref
              .read(appPreferencesProvider.notifier)
              .setLocale(picked);
        }
      },
    );
  }
}
