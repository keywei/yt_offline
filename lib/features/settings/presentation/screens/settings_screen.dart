import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Holds the user-facing settings. Currently just the app version readout;
/// extra knobs (theme, default category, download quality, …) slot in here
/// as new ListTile rows.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final subtitle = info == null
                  ? 'Loading…'
                  : '${info.version} (build ${info.buildNumber})';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                subtitle: Text(subtitle),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Source'),
            subtitle: Text('github.com/keywei/yt_offline'),
          ),
        ],
      ),
    );
  }
}
