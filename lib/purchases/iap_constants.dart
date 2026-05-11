/// IAP product IDs for Times Tables Trainer.
/// SPEC §7: two products, namespaced per app.
///
/// Registered in App Store Connect + Google Play Console by console-operator
/// on Day 0 before any IAP code is tested on device.
class TimesTablesProductIds {
  TimesTablesProductIds._();

  /// Non-consumable — $2.99 — permanent unlock of tables 7–12 + Mixed mode.
  static const tablesUnlock = 'com.idealai.timestables.tables_unlock';

  /// Auto-renewable subscription — $4.99/year — all of tablesUnlock
  /// + Parent Dashboard + Story Mnemonics.
  static const premiumAnnual = 'com.idealai.timestables.premium_annual';

  static const Set<String> all = {tablesUnlock, premiumAnnual};
}

/// Local SharedPreferences keys for all Times Tables Trainer data.
/// See SPEC §4 for the full key registry and contract.
class TimesTablesPrefsKeys {
  TimesTablesPrefsKeys._();

  // Mastery — per table 1..12 and 'mixed'
  // Usage: 'tt_mastery_${N}_correct' and 'tt_mastery_${N}_total'
  static String masteryCorrect(int table) => 'tt_mastery_${table}_correct';
  static String masteryTotal(int table) => 'tt_mastery_${table}_total';
  static const masteryMixedCorrect = 'tt_mastery_mixed_correct';
  static const masteryMixedTotal = 'tt_mastery_mixed_total';

  // Test history
  static const historyJson = 'tt_history_json';

  // Streak (port of SpellBee pattern)
  static const streakCount = 'tt_streak_count';
  static const streakLastDate = 'tt_streak_last_date';

  // Settings
  static const settingsTimerEnabled = 'tt_settings_timer_enabled';
  static const settingsTtsEnabled = 'tt_settings_tts_enabled';
  static const settingsVoiceSpeed = 'tt_settings_voice_speed';

  // IAP cache (UX convenience only — never sole source of truth)
  static const iapTablesUnlock = 'tt_iap_tables_unlock';
  static const iapPremiumAnnual = 'tt_iap_premium_annual';
}
