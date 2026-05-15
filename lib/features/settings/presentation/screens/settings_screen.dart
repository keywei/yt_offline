import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/i18n/settings_providers.dart';
import '../../../../core/i18n/strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/preferences_store.dart';

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
