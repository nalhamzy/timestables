import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/tokens.dart';
import '../../../providers.dart';

/// SettingsScreen — app preferences, restore purchases, legal links.
///
/// Settings (all persisted via SettingsNotifier → SharedPreferences):
///   - Timer on/off (default OFF — SPEC §A Refusal 2)
///   - TTS on/off (default ON)
///   - Voice speed slider (0.1–1.0)
///
/// Actions:
///   - Restore Purchases (wires to IapService.restorePurchases())
///   - Privacy Policy (url_launcher → studio privacy page)
///   - Version string (package_info_plus)
///   - Cross-promotion banner for SpellBee and Sight Words
///
/// SPEC §5 — SettingsScreen | SPEC §6 Task 11
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final iapService = ref.read(iapServiceProvider);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // --- Practice settings ---
          const _SectionHeader(title: 'Practice'),
          SwitchListTile(
            title: const Text('Countdown timer in Practice mode'),
            subtitle: const Text('Off by default — non-timed is less stressful'),
            value: settings.timerEnabled,
            onChanged: settingsNotifier.setTimerEnabled,
            activeTrackColor: kPrimary,
          ),

          // --- TTS settings ---
          const _SectionHeader(title: 'Voice'),
          SwitchListTile(
            title: const Text('Read equations aloud (TTS)'),
            subtitle: const Text('Uses device text-to-speech engine'),
            value: settings.ttsEnabled,
            onChanged: settingsNotifier.setTtsEnabled,
            activeTrackColor: kPrimary,
          ),
          ListTile(
            title: const Text('Voice speed'),
            subtitle: Slider(
              value: settings.voiceSpeed,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: '${(settings.voiceSpeed * 100).round()}%',
              activeColor: kPrimary,
              onChanged: settings.ttsEnabled
                  ? settingsNotifier.setVoiceSpeed
                  : null,
            ),
          ),

          // --- Purchases ---
          const _SectionHeader(title: 'Purchases'),
          ListTile(
            title: const Text('Restore Purchases'),
            leading: const Icon(Icons.restore, color: kPrimary),
            onTap: () async {
              await iapService.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchases restored.')),
                );
              }
            },
          ),

          // --- Legal ---
          const _SectionHeader(title: 'Legal'),
          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.privacy_tip_outlined, color: kPrimary),
            onTap: () async {
              final uri = Uri.parse(
                'https://idealai.app/privacy',  // TODO: update to live URL
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),

          // --- Cross-promotion ---
          const _SectionHeader(title: 'Also from Ideal Intelligence'),
          ListTile(
            leading: const Icon(Icons.apps, color: kAccentGreen),
            title: const Text('Sight Words Flash Cards'),
            subtitle: const Text('K-3 reading — Dolch + Fry words'),
            onTap: () async {
              // TODO: update to live App Store / Play Store URL
              final uri = Uri.parse(
                'https://apps.apple.com/app/id000000000',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.apps, color: kAccentGreen),
            title: const Text('SpellBee: Spelling Practice'),
            subtitle: const Text('K-5 spelling — listen and type'),
            onTap: () async {
              final uri = Uri.parse(
                'https://apps.apple.com/app/id000000001',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),

          // --- About ---
          const _SectionHeader(title: 'About'),
          ListTile(
            title: const Text('Version'),
            trailing: Text(_version, style: const TextStyle(color: kInkSoft)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: kInkSoft,
        ),
      ),
    );
  }
}
