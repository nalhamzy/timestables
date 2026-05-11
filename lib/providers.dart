// Central barrel for all top-level Riverpod providers.
// Import this file in screens — do not import individual provider files directly
// unless the file is only used in one location.

export 'core/services/mastery_service.dart';
export 'purchases/entitlements_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchases/iap_constants.dart';

// ---------------------------------------------------------------------------
// Settings notifier
// ---------------------------------------------------------------------------

class AppSettings {
  final bool timerEnabled;
  final bool ttsEnabled;
  final double voiceSpeed;

  const AppSettings({
    required this.timerEnabled,
    required this.ttsEnabled,
    required this.voiceSpeed,
  });

  static const defaults = AppSettings(
    timerEnabled: false,  // Non-timed by default — SPEC §A Refusal 2
    ttsEnabled: true,
    voiceSpeed: 0.5,
  );

  AppSettings copyWith({
    bool? timerEnabled,
    bool? ttsEnabled,
    double? voiceSpeed,
  }) {
    return AppSettings(
      timerEnabled: timerEnabled ?? this.timerEnabled,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      voiceSpeed: voiceSpeed ?? this.voiceSpeed,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return AppSettings.defaults;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      timerEnabled: prefs.getBool(TimesTablesPrefsKeys.settingsTimerEnabled) ??
          AppSettings.defaults.timerEnabled,
      ttsEnabled: prefs.getBool(TimesTablesPrefsKeys.settingsTtsEnabled) ??
          AppSettings.defaults.ttsEnabled,
      voiceSpeed: prefs.getDouble(TimesTablesPrefsKeys.settingsVoiceSpeed) ??
          AppSettings.defaults.voiceSpeed,
    );
  }

  Future<void> setTimerEnabled(bool value) async {
    state = state.copyWith(timerEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TimesTablesPrefsKeys.settingsTimerEnabled, value);
  }

  Future<void> setTtsEnabled(bool value) async {
    state = state.copyWith(ttsEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TimesTablesPrefsKeys.settingsTtsEnabled, value);
  }

  Future<void> setVoiceSpeed(double speed) async {
    final clamped = speed.clamp(0.1, 1.0);
    state = state.copyWith(voiceSpeed: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(TimesTablesPrefsKeys.settingsVoiceSpeed, clamped);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---------------------------------------------------------------------------
// Streak notifier (port of SpellBee pattern)
// ---------------------------------------------------------------------------

class StreakState {
  final int count;
  final String? lastDateIso; // 'yyyy-MM-dd' or null if never practised

  const StreakState({required this.count, required this.lastDateIso});

  static const zero = StreakState(count: 0, lastDateIso: null);
}

class StreakNotifier extends Notifier<StreakState> {
  @override
  StreakState build() {
    _load();
    return StreakState.zero;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(TimesTablesPrefsKeys.streakCount) ?? 0;
    final lastDate = prefs.getString(TimesTablesPrefsKeys.streakLastDate);
    state = StreakState(count: count, lastDateIso: lastDate);
  }

  /// Call at the start of every FlashScreen, PracticeScreen, or TestScreen session.
  /// Increments streak if this is the first session of the calendar day.
  Future<void> recordSessionToday() async {
    final today = _todayIso();
    if (state.lastDateIso == today) return; // Already recorded today

    final prefs = await SharedPreferences.getInstance();
    final yesterday = _yesterdayIso();
    final newCount =
        state.lastDateIso == yesterday ? state.count + 1 : 1; // reset if missed

    state = StreakState(count: newCount, lastDateIso: today);
    await prefs.setInt(TimesTablesPrefsKeys.streakCount, newCount);
    await prefs.setString(TimesTablesPrefsKeys.streakLastDate, today);
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayIso() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}

final streakProvider =
    NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);

// ---------------------------------------------------------------------------
// TTS service (singleton FlutterTts instance)
// ---------------------------------------------------------------------------

final ttsProvider = Provider<FlutterTts>((ref) {
  final tts = FlutterTts();
  tts.setLanguage('en-US');
  // Default speed pulled from settings on first use; updated by SettingsScreen.
  tts.setSpeechRate(0.5);
  ref.onDispose(() {
    tts.stop();
  });
  return tts;
});

/// Speaks [text] if TTS is enabled in settings.
/// Call site: FlashScreen on card flip, PracticeScreen on question display.
Future<void> speakEquation(
  String text, {
  required bool ttsEnabled,
  required FlutterTts tts,
  required double voiceSpeed,
}) async {
  if (!ttsEnabled) return;
  try {
    await tts.setSpeechRate(voiceSpeed);
    await tts.speak(text);
  } catch (e) {
    debugPrint('TTS error: $e');
  }
}
