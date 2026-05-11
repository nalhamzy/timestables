# Times Tables Trainer — SPEC

> Filled in by `app-architect` on 2026-05-11. `mobile-developer` builds against this.
> Do not add features not listed here without returning to the architect.

---

## 1. Product

- **One-line description**: Times Tables Trainer helps kids in grades 2-5 master multiplication tables 1–12 through calm, non-timed flash drills, typed-answer practice, and scored tests — with no inappropriate content and a parent dashboard parents can check without standing over the child.
- **PMF metric**: Day-14 retention >= 30% among users who attempt at least one Practice or Test session in the first 3 days. Below 20% after 500 activated users = the non-timed framing or table-unlock paywall needs iteration.
- **Source idea**: Internal brief 2026-05-11. Exploits documented trust gap vs. Genioworks (4+ rated app showed violent imagery, 6K reviews, 4.5★); free alternative (3MB Solutions, 4.8★) has zero monetization. Studio's existing SpellBee + Sight Words gives free cross-promotion to the same K-5 parent.

---

## 2. Identity

| Field | Value |
|---|---|
| Display name | Times Tables Trainer |
| Slug | `timestables` |
| Bundle ID | `com.idealai.timestables` |
| Package name (Android) | `com.idealai.timestables` |
| Firebase project | None — local-first, no Firebase |
| AdMob publisher prefix | `ca-app-pub-2199673102027930` (reserved; NOT used in v1 — trust differentiator) |
| GitHub app repo | `nalhamzy/timestables` (private) |
| Target platform | iOS 14.0+ and Android (min SDK 23), iPhone + Android phone |
| iOS minimum | 14.0 |
| Android minimum SDK | 23 (Android 6.0 Marshmallow) |

**iOS 14.0 minimum rationale**: `flutter_tts ^4.x` requires iOS 14. `in_app_purchase ^3.x` supports iOS 14+. `shared_preferences ^2.x` supports iOS 9+ so is not the constraint. Setting 14 gives access to StoreKit 1 (which `in_app_purchase` uses on iOS 14; StoreKit 2 path is transparent to the client SDK). Testing two iOS major versions (14 vs. 16) is manageable because no iOS-16-specific APIs are used.

**Android 23 (API 23) minimum rationale**: `in_app_purchase` Play Billing requires API 19+; `flutter_tts` requires API 21+; 23 is a safe floor that also enables runtime permissions API without backport complexity. API 23 covers ~99% of active Android devices as of 2026.

**No Firebase rationale**: This app is explicitly local-first. No user data leaves the device. The trust/safety differentiator ("no tracking, no accounts, works offline") is architectural, not cosmetic. Firebase would add cold-start latency, require a privacy policy update for data leaving the device, and introduce a cost axis for a low-ARPU kids app.

---

## 3. Architecture decisions

### Framework
Flutter (stable channel) + Dart. No deviation. iOS-only APIs are not load-bearing. Cross-platform is the correct call: the existing SpellBee and Sight Words siblings are Flutter, enabling shared toolchain, CI template, and design tokens.

### State management
`flutter_riverpod ^2.6.x`. Specific provider types:

- `NotifierProvider<MasteryNotifier, MasteryState>` — per-table correct/total counts, accuracy %, streak. Persists to SharedPreferences. Loaded on cold start.
- `NotifierProvider<EntitlementsNotifier, Entitlements>` — cached IAP state (unlockTables, premiumAnnual). Refreshed on launch via `restorePurchases()` and after any purchase.
- `NotifierProvider<SettingsNotifier, AppSettings>` — timer enabled, TTS enabled, voice speed. Persists to SharedPreferences.
- `NotifierProvider<StreakNotifier, StreakState>` — daily streak (date of last practice + current count). Same pattern as SpellBee; port directly.
- `Provider<IapService>` — singleton IAP service. Same pattern as Sight Words; port and rename.
- `Provider<FlutterTts>` — singleton TTS instance.

### Data layer
SharedPreferences only. No network, no database, no accounts. All data is keyed per-table with a consistent namespace (see §4 for key registry). No migration framework needed for v1 because we never had a prior schema.

### Auth strategy
None. No sign-in, no anonymous auth, no accounts. Parent Dashboard is gated by IAP entitlement only, not identity. If a parent reinstalls, the mastery data is gone (documented limitation, acceptable for v1).

### Payments
`in_app_purchase ^3.2.x` directly — same pattern as Sight Words. No RevenueCat. Two products (see §7). Entitlement state is cached in SharedPreferences for UX; verified against the StoreKit/Play Billing receipt stream on every app launch via `restorePurchases()`.

### Storage
SharedPreferences only. See §4 for the full key registry.

### Backend
None.

---

## 4. Local storage schema (SharedPreferences key registry)

No Firestore. This section replaces §4 "Firestore schema" with the equivalent SharedPreferences contract.

### Mastery keys (per table, tables 1–12 plus "mixed")

| Key pattern | Type | Notes |
|---|---|---|
| `tt_mastery_<N>_correct` | `int` | Number of correct answers recorded for table N (1–12). |
| `tt_mastery_<N>_total` | `int` | Total attempts for table N. Accuracy = correct / total. |
| `tt_mastery_mixed_correct` | `int` | Correct answers recorded in mixed-table test sessions. |
| `tt_mastery_mixed_total` | `int` | Total attempts in mixed-table test sessions. |

`N` is the integer 1–12. These keys are written by `MasteryService` only — never directly by UI code.

### Test history keys

| Key pattern | Type | Notes |
|---|---|---|
| `tt_history_json` | `String` | JSON-encoded `List<TestResult>`. Max 50 entries, evicted FIFO. Each entry: `{table, score, totalQ, accuracy, durationSeconds, timestamp}`. |

### Streak keys (port of SpellBee pattern)

| Key | Type | Notes |
|---|---|---|
| `tt_streak_count` | `int` | Current consecutive-day streak. |
| `tt_streak_last_date` | `String` | ISO-8601 date string of the last day a practice/test was completed (`yyyy-MM-dd`). |

### Settings keys

| Key | Type | Default | Notes |
|---|---|---|---|
| `tt_settings_timer_enabled` | `bool` | `false` | Timer shown in PracticeScreen. Default off — non-timed is the differentiator. |
| `tt_settings_tts_enabled` | `bool` | `true` | TTS reads equation aloud on Flash reveal. |
| `tt_settings_voice_speed` | `double` | `0.5` | Clamped 0.1–1.0 passed to FlutterTts. |

### IAP cache keys (UX convenience only — never sole source of truth)

| Key | Type | Notes |
|---|---|---|
| `tt_iap_tables_unlock` | `bool` | Cached result of `tables_unlock` non-consumable purchase. |
| `tt_iap_premium_annual` | `bool` | Cached result of `premium_annual` subscription active status. |

### Security constraints
All keys are client-only. There is no server validation. The IAP cache is a UX convenience to avoid a loading spinner on every launch. The actual entitlement check occurs in the `purchaseStream` listener and on `restorePurchases()`. UI gates on `Entitlements.hasTablesUnlock` (which is `iapTablesUnlock || iapPremiumAnnual`).

---

## 5. Screen inventory

| Screen | Route / type | Prototype status | Notes for ui-ux-designer |
|---|---|---|---|
| HomeScreen | `/` — full screen, root | Wireframe needed | Grid of 13 cards (1×–12× + Mixed). Each card: table label, mastery % ring, lock icon for tables 7–12 (free users). Header: daily streak badge. |
| FlashScreen | `/flash/:table` — full screen | Wireframe needed | Card-flip animation. Front: equation with "?". Back: full equation with answer. TTS on flip. Swipe right = Got it, swipe left = Not yet. Progress bar. |
| PracticeScreen | `/practice/:table` — full screen | Wireframe needed | Equation displayed, number pad (0-9 + backspace + submit), correct/incorrect feedback overlay, optional countdown timer toggle, auto-advance after 1.5s on correct. |
| TestScreen | `/test/:table` — full screen | Wireframe needed | 20 questions, timed (120s default). Number pad input. Results screen inline: score/20, accuracy %, time taken. Save to history. |
| ParentDashboard | `/parent` — full screen | Wireframe needed | Premium gate (`premium_annual`). Per-table accuracy bars, top-5 missed facts list, weekly correct count chart (SimpleBarChart built from SharedPreferences data). "Email report" share button. |
| StoryMnemonicsSheet | Bottom sheet — modal | Wireframe needed | Premium gate (`premium_annual`). Triggered from FlashScreen or PracticeScreen by tapping a "Story" button on a qualifying fact (6×6 through 9×9 + other hard facts). 40 mnemonics. |
| PaywallSheet | Bottom sheet — modal | Wireframe needed | Two offers: "Unlock Tables 7-12 — $2.99" (primary, non-consumable) + "Premium Annual — $4.99/yr" (secondary). Restore purchases link. |
| SettingsScreen | `/settings` — full screen | Wireframe needed | Timer on/off, TTS on/off, voice speed slider, restore purchases, privacy policy link, version string. |

---

## 6. MVP build order

Tasks are sized at ≤ 1 day each. `mobile-developer` works top-to-bottom in strict order.

| # | Task | Dependency | Output |
|---|---|---|---|
| 1 | Scaffold: init Flutter project, `pubspec.yaml`, `main.dart`, `tokens.dart`, `iap_constants.dart`, all screen stub files, `flutter analyze` clean | None | Compilable skeleton, `flutter build appbundle --release` succeeds (no logic) |
| 2 | `MasteryService` + `MasteryNotifier`: SharedPreferences read/write for all 13 tables, accuracy calculation, unit test for `recordAnswer()` | Task 1 | Mastery data persists across hot restarts |
| 3 | `HomeScreen`: 13-card grid, mastery ring (CircularProgressIndicator), streak badge, lock icons for tables 7-12 (free), navigation to FlashScreen/PracticeScreen/TestScreen | Task 2 | Home renders with placeholder mastery data |
| 4 | `FlashScreen`: card-flip animation (`AnimatedFlipCard`), equation display, TTS on flip (`flutter_tts`), Got it / Not yet swipe or tap, progress bar, records to `MasteryNotifier` | Task 3 | Full flash card experience for table 1 |
| 5 | `PracticeScreen`: equation display, custom number pad widget, submit logic, correct/incorrect overlay, auto-advance 1.5s, optional countdown timer (toggle reads from `SettingsNotifier`), records to `MasteryNotifier` | Task 4 | Full practice experience |
| 6 | `TestScreen`: 20-question set generation (shuffled from selected table or mixed 1-12), timed countdown (120s), number pad, results screen (score/20, accuracy %, time), save `TestResult` to history JSON in SharedPreferences | Task 5 | Full test experience, results persist |
| 7 | `StreakNotifier` (port from SpellBee): reads/writes `tt_streak_*` keys, increments on first practice/test per calendar day, resets if day missed, displays on HomeScreen header | Task 6 | Daily streak visible and correct |
| 8 | IAP wiring: `IapService` (port from Sight Words, rename product IDs), `EntitlementsNotifier`, `PaywallSheet` UI, gate HomeScreen lock icons, gate table 7-12 navigation, gate ParentDashboard and StoryMnemonicsSheet | Task 7 | PaywallSheet opens, sandbox purchase unlocks tables 7-12 |
| 9 | `ParentDashboard`: per-table accuracy bar list, top-5 missed facts (computed from mastery data), weekly correct count (sum of `correct` deltas stored in history), "Email report" share (generates plain-text via `Share.shareXFiles` / built-in `share_plus`), premium gate redirect to PaywallSheet | Task 8 | Parent Dashboard fully functional behind paywall |
| 10 | `StoryMnemonicsSheet`: 40 hardcoded mnemonics (6×6–9×9 + select others), bottom sheet, premium gate, "Story" button wired in FlashScreen and PracticeScreen | Task 9 | Mnemonics visible in sandbox for premium users |
| 11 | `SettingsScreen`: timer toggle, TTS toggle, voice speed slider, restore purchases, privacy policy `url_launcher`, `package_info_plus` version, all wired to `SettingsNotifier` | Task 10 | All settings persist, restore purchases works |
| 12 | Codemagic YAML, `flutter analyze` clean pass, release build validation (`flutter build ipa --release`, `flutter build appbundle --release`), store asset placeholders, cross-promotion banner for SpellBee/Sight Words in SettingsScreen | Task 11 | Clean release build ready for console-operator upload |

---

## 7. Monetization spec

**Primary lever**: IAP only. No ads, no RevenueCat, no third-party ad SDKs. The absence of ads is a named differentiator vs. the free competitor and a trust signal for parents.

### Products

| Product ID | Type | Price | Entitlement | Notes |
|---|---|---|---|---|
| `com.idealai.timestables.tables_unlock` | Non-consumable | $2.99 | `hasTablesUnlock` | Unlocks tables 7–12 and Mixed mode in all 3 learning modes. One-time, permanent. |
| `com.idealai.timestables.premium_annual` | Auto-renewable subscription | $4.99/year | `hasPremium` (implies `hasTablesUnlock`) | All of tables_unlock + Parent Dashboard + Story Mnemonics. Annual only in v1. |

`hasPremium` implies `hasTablesUnlock` — the `Entitlements` model must reflect this: `bool get hasTablesUnlock => _tablesUnlock || _premiumAnnual;`

### Paywall trigger points

| Trigger point | What the user tried to do | Sheet shown | Primary CTA |
|---|---|---|---|
| Tap any table card 7–12 on HomeScreen (free user) | Start flash/practice/test on a locked table | PaywallSheet | "Unlock Tables 7-12 — $2.99" |
| Tap "Mixed" test mode (free user) | Start mixed test | PaywallSheet | "Unlock Tables 7-12 — $2.99" |
| Tap "Parent Dashboard" in navigation (free or tables_unlock user) | Open parent dashboard | PaywallSheet | "Go Premium — $4.99/yr" |
| Tap "Story" button on any hard fact (free or tables_unlock user) | Open mnemonic sheet | PaywallSheet | "Go Premium — $4.99/yr" |

### Trial mechanics
No free trial in v1 (avoids subscription receipt complexity without RevenueCat). Revisit at v1.1 if conversion is below 1%.

### Restore purchases
Restore button appears in PaywallSheet and SettingsScreen. Triggers `IapService.restorePurchases()` which calls `InAppPurchase.instance.restorePurchases()`. Restored purchases flow through `purchaseStream` and update `EntitlementsNotifier` identically to a fresh purchase.

---

## 8. Notification spec

| Notification | Channel | Trigger | Message | Suppression | Implementation notes |
|---|---|---|---|---|---|
| Daily practice reminder | Local (flutter_local_notifications) | User completes first practice on day N, schedules reminder for 24h later if no practice on day N+1 by a user-set time (default 17:00) | "Time for times tables! Keep your streak going — {streakCount} days strong." | No notification if user has already practiced today. Cancel scheduled notification on next practice. Suppress if streak is 0 (no habit yet). | NOT in v1 MVP. Listed here so `mobile-developer` does not wire it without a scope change. See §10. |

**v1 has zero notifications.** The reminder spec above is captured for v1.1. The `flutter_local_notifications` package is NOT in `pubspec.yaml` for v1.

---

## 9. Analytics events

**No analytics SDK in v1.** The trust differentiator ("no tracking") is credible only if there is genuinely no telemetry leaving the device. Firebase Analytics and Crashlytics are explicitly excluded.

All instrumentation that would normally be analytics events is instead surfaced to the Parent Dashboard as local aggregates (per-table accuracy, weekly count, missed facts). The parent sees the data; no third party does.

If retention data is needed post-launch, add PostHog (self-hosted or cloud) behind a parent opt-in consent flow in v1.1. This is a scope change that must go back to the architect.

### Local event log (for Parent Dashboard only — never transmitted)

| Event | When recorded | Stored where |
|---|---|---|
| `answer_recorded` | Every time child submits an answer in Practice or Test | Increments `tt_mastery_<N>_correct` / `tt_mastery_<N>_total` |
| `test_completed` | When TestScreen shows results | Appended to `tt_history_json` (FIFO, max 50) |
| `flash_swipe` | Got it or Not yet swipe in FlashScreen | Increments mastery counters same as answer_recorded |
| `streak_updated` | First session of each calendar day | Writes `tt_streak_count` + `tt_streak_last_date` |

---

## 10. Non-MVP scope (explicit exclusion list)

`mobile-developer` may not implement any of the following without an architect sign-off:

1. **Push notifications / local reminders** — the infrastructure (flutter_local_notifications, notification permissions) is NOT in the v1 pubspec. Add in v1.1.
2. **Dark mode** — light mode only. Same deliberate call as Sight Words. Kids content is brighter in light mode; the QA matrix does not test dark mode.
3. **iPad layout** — portrait phone only in v1. The grid and number pad are not optimized for iPad split-screen. iPad layout is a v1.1 task.
4. **Multiple child profiles** — a single mastery store, no per-child switching. Parents who want multi-child support must reinstall or use separate devices. v1.2.
5. **Multiplayer / head-to-head mode** — requires a backend; out of scope for local-first v1.
6. **Custom table ranges beyond 12** — tables 1–12 are the UK/US curriculum standard. 13× and beyond are out of scope.
7. **Leaderboards / Game Center / Google Play Games** — social features add complexity and a backend; out of scope.
8. **Handwriting recognition input** — number pad is the only input method in v1.
9. **Landscape orientation** — portrait lock enforced via `SystemChrome.setPreferredOrientations`. Do not remove this lock.
10. **Spanish / multilingual TTS or UI** — English only in v1. Localization strings are not extracted to ARB files in v1 (add at v1.1).
11. **Story Mnemonics for all 144 facts** — only the 40 hardest facts (6×6–9×9 core + a curated set). Expanding to all 144 is v1.2.
12. **Audio sound effects / music** — TTS only; no background music, no "ding" on correct. Avoids audio session conflicts with system media.
13. **Firebase Analytics, Crashlytics, or any remote telemetry** — explicitly excluded. See §9.

---

## 11. Third-party SDKs

| SDK | Package | Purpose | License | Cost | iOS min | Notes |
|---|---|---|---|---|---|---|
| Flutter Riverpod | `flutter_riverpod ^2.6.0` | State management | MIT | Free | 14 | Matches Sight Words version. |
| Shared Preferences | `shared_preferences ^2.3.0` | Local persistence | BSD-3 | Free | 9 | Drives entire local-first data layer. |
| In-App Purchase | `in_app_purchase ^3.2.0` | StoreKit + Play Billing IAP | BSD-3 | Free (platform fees apply) | 14 | No RevenueCat. Same pattern as Sight Words. |
| Flutter TTS | `flutter_tts ^4.2.0` | Text-to-speech — reads equations aloud | BSD-2 | Free | 14 | Device TTS engine only; no network calls. |
| Equatable | `equatable ^2.0.5` | Value equality for state models | MIT | Free | 14 | Used by `TestResult`, `AppSettings`, `Entitlements`. |
| Package Info Plus | `package_info_plus ^8.0.0` | App version display in Settings | BSD-2 | Free | 14 | Small utility. |
| URL Launcher | `url_launcher ^6.3.0` | Privacy policy link in Settings | BSD-3 | Free | 14 | Already in Sight Words. |

**Packages explicitly NOT included in v1**: `firebase_core`, `firebase_analytics`, `firebase_crashlytics`, `google_mobile_ads`, `purchases_flutter` (RevenueCat), `flutter_local_notifications`, `speech_to_text`, `share_plus`.

`share_plus` is a borderline case: the Parent Dashboard "Email report" feature uses it. Decision: include `share_plus ^10.x` in the pubspec and add to this table. It is MIT licensed, iOS 14+, and has no network calls.

Updated table row:

| share_plus | `share_plus ^10.0.0` | Native share sheet for Parent Dashboard email report | MIT | Free | 14 | iOS `shareXFiles` / Android `ACTION_SEND`. |

---

## 12. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `flutter_tts` TTS engine unavailable on some Android devices (no Google TTS installed) | Medium | Low — TTS is enhancement, not core | Check `isLanguageAvailable` on init; silently disable TTS if unavailable; show a Settings note "TTS not available on this device." |
| IAP product not found at launch (App Store / Play Console not yet configured) | High on first build | Medium | `IapService.initialize()` logs the error and continues; UI shows products as "unavailable" rather than crashing; PaywallSheet shows "Purchase unavailable — try again later." |
| SharedPreferences data loss on app uninstall (mastery progress lost) | Certain on reinstall | Low (expected behavior, documented) | Document in onboarding and Privacy Policy. Cloud sync is a v1.1 paid feature upsell opportunity. |
| Apple review rejection for Kids-adjacent content | Low (not in Kids Category) | High (delay + rework) | App is NOT in the Kids Category; no COPPA/CIPA compliance required. Age rating 4+ is correct. Confirm in App Store Connect metadata before submission. |
| `in_app_purchase` subscription receipt not refreshed after annual renewal | Medium | High (false paywall) | `restorePurchases()` called on every cold start. Annual renewal is handled by the OS; `purchaseStream` fires automatically. No additional polling needed. |
| Name collision — "Times Tables Trainer" exists on App Store | Medium | Medium (ASO harm) | Run App Store search before submitting. If name taken, add studio qualifier: "Times Tables Trainer: K-5 Math." The bundle ID `com.idealai.timestables` is unique regardless. |
| Cost creep | N/A — no backend | None | Local-first eliminates all Firebase/server cost axes. Only cost is Apple/Google developer fees (fixed, already paid). |
| Mixed-table test algorithm bias | Low | Medium (UX frustration) | Shuffle questions from uniform distribution across all 13 tables; do not weight by mastery (that is a v1.1 adaptive feature). Test the shuffle in a unit test. |

---

## 13. Definition of done for v1

QA tester runs this checklist top-to-bottom on a release build before sign-off.

### Device matrix
- [ ] iPhone SE (375pt wide) — all screens render without overflow, number pad fits screen
- [ ] iPhone Pro Max (430pt wide) — layout is not over-spaced / wasted
- [ ] Android mid-range (e.g. Pixel 4a, 360pt wide) — same overflow checks
- [ ] iOS simulator iOS 14.x (minimum version) — no API usage that crashes on 14

### Static analysis
- [ ] `flutter analyze` reports zero issues (warnings count as issues)
- [ ] `dart format --set-exit-if-changed .` exits 0
- [ ] No `// ignore:` directives in production code without a documented reason

### Builds
- [ ] `flutter build ipa --release` succeeds with no Xcode errors
- [ ] `flutter build appbundle --release` succeeds with no Gradle errors
- [ ] IPA size < 30 MB (no large asset bundles)
- [ ] AAB size < 15 MB

### HomeScreen
- [ ] All 13 table cards render with correct labels (1× through 12× + Mixed)
- [ ] Mastery rings show 0% on fresh install
- [ ] Tables 7–12 and Mixed show a lock icon for a free user
- [ ] Tables 1–6 show no lock icon for a free user
- [ ] Streak badge shows 0 on fresh install and increments correctly after a session

### FlashScreen
- [ ] Card flip animation fires on tap
- [ ] TTS reads full equation aloud after flip (e.g. "Seven times eight equals fifty-six")
- [ ] Swipe right increments correct count for the table
- [ ] Swipe left increments total but not correct count
- [ ] Progress bar advances with each card
- [ ] Completing all cards returns to HomeScreen or shows a completion banner

### PracticeScreen
- [ ] Number pad input displays digits correctly; backspace works
- [ ] Correct answer shows green feedback, incorrect shows red with correct answer revealed
- [ ] Auto-advance fires after 1.5s on correct answer
- [ ] Timer toggle OFF by default; when ON, shows countdown and auto-submits on 0
- [ ] Mastery counts increment after each answer

### TestScreen
- [ ] 20 questions generated, no duplicates
- [ ] 120-second timer counts down; test ends if timer reaches 0
- [ ] Results show score/20, accuracy %, time taken
- [ ] Results are appended to history (verify by checking `tt_history_json` in SharedPreferences viewer)

### IAP / PaywallSheet
- [ ] Tapping a locked table card opens PaywallSheet
- [ ] PaywallSheet shows two offers with correct prices (fetched live from StoreKit / Play)
- [ ] Sandbox purchase of `com.idealai.timestables.tables_unlock` unlocks tables 7–12 immediately without restart
- [ ] Sandbox purchase of `com.idealai.timestables.premium_annual` unlocks Parent Dashboard and Story Mnemonics
- [ ] "Restore Purchases" in PaywallSheet restores sandbox purchases on a fresh install (same sandbox account)
- [ ] "Restore Purchases" in SettingsScreen also restores correctly

### ParentDashboard
- [ ] Blocked with PaywallSheet for free and `tables_unlock` users
- [ ] Shows per-table accuracy bars for tables 1–12
- [ ] Top-5 missed facts list computed correctly (lowest accuracy facts)
- [ ] "Email report" share button opens native share sheet with readable text

### StoryMnemonicsSheet
- [ ] "Story" button only appears on qualifying facts (6×6 through hardest facts)
- [ ] Bottom sheet opens and shows the correct mnemonic
- [ ] Blocked with PaywallSheet for free and `tables_unlock` users

### SettingsScreen
- [ ] Timer toggle persists across restarts
- [ ] TTS toggle persists across restarts
- [ ] Voice speed slider persists and changes TTS speed immediately
- [ ] Privacy policy link opens in system browser via `url_launcher`
- [ ] App version matches `pubspec.yaml` version

### No telemetry
- [ ] Confirm with Charles Proxy / Proxyman: zero network requests from the app in normal use (including IAP flows — only Apple/Google endpoints, which are expected)

---

## 14. Build and release plan

### Milestone table

| Milestone | Target date | Owner | Notes |
|---|---|---|---|
| Day 0: Register iOS Bundle ID at Apple Developer, generate upload keystore, register SHA-1+SHA-256 in (no Firebase — just internal record), init GitHub repo `nalhamzy/timestables` | 2026-05-11 | console-operator | Register APNs key even though not used in v1 (required for App Store Connect app record). Bundle ID: `com.idealai.timestables`. |
| Day 1: Scaffold + HomeScreen + FlashScreen + TTS | 2026-05-12 | mobile-developer | Tasks 1–4 above. |
| Day 2: PracticeScreen + mastery persistence | 2026-05-13 | mobile-developer | Task 5–2 (mastery + practice). |
| Day 3: TestScreen + ParentDashboard skeleton | 2026-05-14 | mobile-developer | Tasks 6, 9. |
| Day 4: Mnemonics + IAP wiring + PaywallSheet | 2026-05-15 | mobile-developer | Tasks 8, 10. |
| Day 5: SettingsScreen + streak + analyze clean | 2026-05-16 | mobile-developer | Tasks 7, 11. |
| Day 6: Codemagic YAML + store assets + ASO draft | 2026-05-17 | ci-cd-engineer + aso-specialist | Task 12. Codemagic workflow: `flutter-ios` + `flutter-android`. |
| Day 7: QA pass + buffer | 2026-05-18 | qa-tester | Run §13 checklist. |
| v1.0.0: Manual upload to App Store Connect (TestFlight) + Google Play (internal track) | 2026-05-19 | console-operator | First build MUST be uploaded manually per Apple/Google policy. |
| v1.0.1–v1.0.4: Bug fix builds via Codemagic manual trigger | Rolling | ci-cd-engineer | Fix issues found in TestFlight beta / internal testing. |
| v1.0.5: Enable Codemagic auto-publish (App Store + Play) | After v1.0.4 is live | ci-cd-engineer | Auto-publish kicks in at v1.0.5 per studio runbook. |

### v1.0.0 bootstrap note
The first AAB and IPA must be uploaded manually (Apple and Google both require the first submission to be manual). Codemagic auto-publishing is configured but will only take effect from v1.0.5 onward, per `ops/ci-cd/playbooks/release-runbook.md`.

---

## 15. Stack summary

| Concern | Choice | Reason |
|---|---|---|
| Framework | Flutter (stable) + Dart | Matches studio standard; siblings SpellBee + Sight Words are Flutter; shared CI/CD template. |
| State management | Riverpod 2.x (NotifierProvider) | Same as Sight Words; proven pattern for local-first notifiers with SharedPreferences. |
| Persistence | SharedPreferences | No backend needed; local-first is the trust/safety differentiator; zero cost. |
| IAP | in_app_purchase 3.x (no RevenueCat) | Same as Sight Words; simpler dependency graph; no RevenueCat SDK cost or Kids-Category policy concern. |
| TTS | flutter_tts 4.x | Device engine only, no API key, no network, works offline. |
| Analytics | None | Trust differentiator; parent complaint: "I don't want my kid's data tracked." Local aggregates surfaced in Parent Dashboard instead. |
| Backend | None | Local-first. Firebase would add cold-start latency, privacy policy complexity, and cost on a low-ARPU kids SKU. |
| CI/CD | Codemagic | Studio standard; flutter-ios + flutter-android workflows; same codemagic.yaml template as Sight Words. |
| Min iOS | 14.0 | Driven by flutter_tts 4.x. |
| Min Android | 23 (API 23) | in_app_purchase + flutter_tts floor; covers ~99% of active devices. |
| Ads | None in v1 | Named trust differentiator vs. free competitor; AdMob publisher prefix reserved for future consideration only. |
| Auth | None | No accounts; no user data leaves device. |
| Dark mode | None in v1 | Light-only, same as Sight Words; QA matrix does not cover dark mode. |
| Orientation | Portrait lock | Kids content; number pad doesn't adapt well to landscape in v1. |

---

## §A. What this app refuses to do

### Refusal 1: No ads of any kind — ever in v1

**What the user gains**: Parents of 7-year-olds do not need to police banner ads, interstitials, or rewarded-video popups that appear mid-drill. The child can use the app unsupervised without stumbling into ad content. This is a recovery from the Genioworks documented incident (violent imagery in a 4+ app).

**Competitor most threatened**: Genioworks ($5.99/month, the #1 paid app) cannot credibly remove ads without collapsing their revenue model, and their existing 6K reviews contain the documented complaint. The 3MB Solutions free app has no monetization at all, so removing ads is irrelevant to them — they gain nothing by copying this refusal.

**Positioning line**: "No ads. No interruptions. No surprises. Just multiplication."

---

### Refusal 2: No timer by default — drills are non-timed unless the parent or child turns the timer on

**What the user gains**: Parents on Mumsnet specifically cited "timed drills cause anxiety" as a reason they disliked existing apps. A child who freezes under time pressure learns anxiety, not arithmetic. Non-timed practice allows self-paced mastery. The timer exists (for older kids who want the challenge) but is off by default and requires a deliberate toggle.

**Competitor most threatened**: Genioworks and 3MB Solutions both default to timed drills — it is the standard game mechanic in this category. Switching their default would mean re-designing their core loop and alienating users who chose them for the game-feel. They cannot credibly copy this without undermining their own identity.

**Positioning line**: "Drills without the stress. The timer is there if you want it — hidden if you don't."

---

### Refusal 3: No user accounts, no cloud sync, no tracking — ever in v1

**What the user gains**: A parent can hand a phone to a 7-year-old without creating an account, setting a password, or worrying about their child's practice data being stored on a server. Full GDPR/COPPA non-issue because no data leaves the device.

**Competitor most threatened**: Genioworks requires an account. Any app using Firebase Analytics (the default in Flutter tutorials) is implicitly tracking. This refusal is not copiable by any Firebase-backed competitor without a full architecture rewrite — and even then, their existing data would still have been collected.

**Positioning line**: "Nothing leaves this phone. Not your child's name, not their scores, not their mistakes."

---

### Refusal 4: No "designed for kids" App Store Kids Category flag, no COPPA data practices disclosure for child data — because there is no child data

**What the user gains**: Apps in the Kids Category face strict Apple restrictions: no third-party analytics, no social features, no links out of the app. By staying out of the Kids Category (this app targets grade 2-5, parents choose it), the app can include a privacy policy link, a restore purchases flow, and a Parent Dashboard share button — all of which are blocked in the Kids Category. The trade-off is: parents see the app in the general Education category. This is the correct trade-off.

**Competitor most threatened**: Any competitor in the Kids Category cannot legally add the Parent Dashboard share button or a privacy policy link in the app. This is an architectural advantage that cannot be copied without leaving the Kids Category.

**Positioning line**: "Not in the Kids Category — because you, the parent, are our customer. Your child is our student."

---

### Refusal 5: No story or gamification layer beyond the 40 curated mnemonics — no avatar, no coins, no level-up animations

**What the user gains**: The app is a tool, not a game. Parents who want a distraction-free drill environment get exactly that. The one narrative element (Story Mnemonics) is opt-in and premium, serving memory — not engagement manipulation. This avoids variable-reward mechanics that keep kids on the app longer than they need to be.

**Competitor most threatened**: Apps like Prodigy Math and Khan Academy Kids are built on the "gamification = engagement" assumption. Their entire product depends on it. Removing gamification would make them indistinguishable from a worksheet. They cannot copy this refusal without cannibalizing their core product.

**Positioning line**: "It's a trainer, not a game. Ten minutes a day, then put the phone down."

---

## §B. The share moment

**Persona**: Sarah, 34, mum of two in Manchester (Year 3 and Year 5), on her phone at 8:52pm on a Wednesday after the kids are in bed. She's in a WhatsApp group with four other school mums.

**The literal message she sends**:

> "ok this is actually good — downloaded this times tables app tonight, no ads, no login, just lets him do the drills. showed me exactly which ones he keeps getting wrong (7×8, 8×9 — classic). only £2.49 to unlock the harder ones. worth it tbh"

(Note: App Store UK pricing rounds to £2.49 for a $2.99 USD price. The message uses the price she actually saw.)

---

**Hook check — does the message have a hook in the first 7 words?**

"ok this is actually good — downloaded this times tables app tonight"

Yes. "ok this is actually good" is the hook. It signals Sarah's own surprise — she expected another bad app and was wrong. The friend reads this as a signal that skeptical Sarah was converted, which is more powerful than enthusiasm. The friend will read on.

**Does it require explanation?**

No. "Times tables app, no ads, no login, just drills, shows which ones he gets wrong" is self-contained. The friend does not need to ask "wait what is this." She knows: it's for her kid's maths homework, it works, and the parent can see progress.

**What is it sent with?**

The message is sent with a screenshot of the Parent Dashboard showing the per-table accuracy bar chart, with the "7×8" and "8×9" bars visibly low. This screenshot is the artifact. It makes the claim concrete. Without the screenshot, the message is just a recommendation. With the screenshot, the friend sees her own kid's probable weak spots reflected.

The Parent Dashboard "Email report" share button generates this screenshot moment. This is the mechanic in §6 Task 9 that produces the share artifact.

**Would the recipient open the App Store from this message?**

Yes — with conditions. The recipient opens the App Store if:
(a) her child is in a similar year group (likely, given it's a school mums group), and
(b) she is already thinking about times tables (common during Years 3-5).

The honest risk: if the recipient's child is in Reception or Year 6, she does not download. The message has tight but real targeting. For the right recipient, the conversion rate is high because the message is specific (named the exact wrong facts), credible (Sarah is skeptical by nature), and cheap (the free tier de-risks the install).

**Does §6 include the mechanic that produces this share artifact?**

Yes. Task 9 (ParentDashboard with "Email report" share button) is explicitly in the MVP build order. The share button generates plain-text or a shareable image of the per-table accuracy chart. The share_plus package is included in §11. The share moment is a first-class MVP feature, not an afterthought.
