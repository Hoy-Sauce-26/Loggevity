# Loggevity

A local-first weekly health tracker. You log seven kinds of activity; it scores
your week against mortality-risk curves derived from epidemiological hazard
ratios and shows how you are tracking.

No account, no backend, no network calls, no analytics or ad SDKs. Everything
lives in an encrypted SQLite database on the device, and the only way data
leaves is a JSON or CSV export that you initiate.

- **Flutter** 3.44.9 / **Dart** 3.12.2 (stable)
- **Targets**: iOS, Android (macOS builds but is not a supported target)
- **State**: Riverpod 3 · **Storage**: Drift + SQLCipher · **Charts**: fl_chart

---

## Quick start

```bash
flutter pub get
flutter test          # 158 tests, ~5s
flutter analyze       # must be clean
flutter run           # pick a device, or -d <id>
```

After changing anything in [`lib/data/database.dart`](lib/data/database.dart)
you must regenerate the Drift code, or the build will fail on missing symbols:

```bash
dart run build_runner build
```

`lib/data/database.g.dart` is generated and checked in. Never edit it by hand.

### Build flavours

Debug and profile builds install **alongside** release builds rather than
replacing them, so a dev build cannot clobber real data:

| Build | Application ID | Display name |
| --- | --- | --- |
| debug / profile | `com.nttech.loggevity.dev` | Loggevity Dev |
| release | `com.nttech.loggevity` | Loggevity |

Android via `applicationIdSuffix` in
[`android/app/build.gradle.kts`](android/app/build.gradle.kts), iOS via
per-configuration `PRODUCT_BUNDLE_IDENTIFIER`. Separate containers and separate
keys, so **the dev build cannot read the release build's database.**

---

## Repository map

```
lib/
  main.dart                  App entry, theme (single seed colour)
  providers.dart             Riverpod graph — the wiring diagram for the app
  scoring/                   Pure Dart. No Flutter, no I/O, no clock.
    curves.dart              Categories, weights, lookup grids
    interpolation.dart       Piecewise linear interpolation (clamped)
    calculator.dart          HealthScoreCalculator
    models.dart              WeeklyTotals, CategoryScore, ScoreResult
  data/                      Storage and domain services
    database.dart            Drift schema + DAOs  (edit → run build_runner)
    connection.dart          SQLCipher connection; the encryption seam
    database_key.dart        Key generation + keychain storage
    week.dart                WeekRange, local-date bucketing
    metrics_repository.dart  Reactive bridge: rows → scores
    week_sealer.dart         Week-boundary engine
    portability.dart         JSON/CSV serialisation (pure)
    backup_service.dart      File I/O + share/pick for import/export
  screens/                   DashboardPage, AnalyticsPage
  widgets/                   Presentation
test/
  scoring/  data/  ui/       Mirrors lib/
```

The dependency direction is one-way: `scoring/` knows nothing about `data/`,
and `data/` knows nothing about `widgets/`.

---

## The scoring model

The part you cannot infer from the code alone, and the part most likely to be
"fixed" incorrectly. [`lib/scoring/`](lib/scoring/) and the tests that pin it
are the definitive statement of the model.

### Curves are scores, not hazard ratios

Each category's curve is a **score** curve, derived from hazard ratios. The two
are easy to confuse and are not interchangeable:

```
score = (1 - HR) / k * 10
```

where `k` is the maximum achievable risk reduction for that category. An HR of
1.00 means "no benefit" and maps to a score of **0**, not 10.

| Category | k | Curve (weekly minutes → score) |
| --- | --- | --- |
| Moderate PA | 0.40 | (0,**0**) (75,2) (160,4.5) (250,5.5) (900,10) (10080,10) |
| Vigorous PA | 0.15 | (0,0) (100,8.667) (215,**10**) (900,6.667) |
| Resistance | 0.20 | (0,0) (15,4) (22,6.5) (45,**10**) (60,**10**) (80,8) (100,6.5) (140,0) (160,−2.5) (200,**−9**) |

- **Vigorous PA is a horseshoe** — benefit peaks at 215 min/week, then declines.
- **Resistance training goes negative.** Past 140 min/week it is a net harm,
  bottoming at −9 at 200 min; sleep can reach −10. **Negative sub-scores are
  intentional and never clamped to zero.** A composite can legitimately be
  negative, and the UI renders that rather than hiding it.

The remaining four categories are linear to a weekly target, capped at 10:
flexibility 45 min, nature 120 min, socializing 21 h, sleep (see below).

Out-of-range inputs **clamp** to the terminal value; the curves are undefined
beyond their last anchor. Extrapolating the final segment instead would give
unbounded penalties — 300 min of resistance would score −25.25.

### Sleep

Raw hours are converted per night to "adjusted hours", penalising both tails at
2× the deviation:

```
A(h) = 2h − 7.5        if h < 7.5
     = 7.5             if 7.5 ≤ h ≤ 9.0
     = 7.5 − 2(h − 9)   if h > 9.0

S_sleep = Σ A(hᵢ) / 52.5 × 10
```

**Store raw hours, never adjusted.** The reference week's seven nights total
58.25 raw hours, which compress to 52.0 adjusted. Storing 52 would be wrong.

### Composite

```
composite % = Σ(subScore × weight) / 1690 × 100
```

| Category | Weight | Max points |
| --- | --- | --- |
| Moderate PA | 40 | 400 |
| Vigorous PA | 15 | 150 |
| Resistance | 8 | 80 |
| Flexibility | 7 | 70 |
| Nature | 15 | 150 |
| Socializing | 50 | 500 |
| Sleep | 34 | 340 |
| **Total** | **169** | **1690** |

> **Vigorous PA counts toward the denominator by design.** Including its weight
> makes vigorous activity a required category rather than bonus credit, and
> gives the composite a hard 100% ceiling. Dropping it from the divisor would
> turn vigorous into overflow credit and let a strong week exceed 100%. That is
> a product decision, not an oversight — don't "simplify" it.

### Pace vs. progress

Every formula is a weekly total, but the dashboard is live mid-week, so
`ScoreBasis` offers two readings of the same data:

- **`pace`** — targets scaled to days elapsed. An on-track Wednesday reads
  ~100%. This drives the ring by default.
- **`fullWeek`** — raw progress toward the whole week. That same Wednesday
  reads ~43%. This drives the category bars.

The ring is tappable to switch between them; the choice persists in settings.

### The golden test

[`test/scoring/calculator_test.dart`](test/scoring/calculator_test.dart) pins a
canonical reference week (Mon 2026-07-06 – Sun 2026-07-12):

```
524 min moderate · 0 vigorous · 50 resistance · 50 flexibility
136 min nature · 22 h social · nights [9, 9, 8.5, 8.75, 8, 7.75, 7.25]
→ 84.77%      (+200 min vigorous → 93.49%)
```

Every sub-score is asserted to 9 decimal places — **this is the test that tells
you whether you broke the model.** A separate test re-derives all three curves
from their hazard ratios, keeping the HR→score relationship provable.

---

## Data and storage

### Schema (Drift, `schemaVersion = 2`)

- **`daily_entries`** — one row per logged activity. `occurred_at` (UTC
  instant, for ordering) plus `local_date` (`YYYY-MM-DD`, for bucketing).
- **`weekly_snapshots`** — one sealed row per completed week, unique on
  `week_start_date`, storing the composite and all seven sub-scores.
- **`app_settings`** — single row, id 0. Week start day, ring preference.

**Why two timestamp columns.** `local_date` decides which day — and therefore
which week — an entry belongs to. A log at 11pm stays on the day you
experienced it regardless of timezone travel or DST. The key sorts
lexicographically, so week range queries are plain string comparisons.

### Weeks

`WeekRange` is a half-open range of seven local days. **The start day is
user-configurable** (`DateTime.monday`…`sunday`) — nothing may assume Monday.
Snapshots record the start day in force when sealed, so changing the setting
later cannot retroactively reinterpret history.

### Encryption

The database file is encrypted with SQLCipher. A 256-bit key is generated on
first launch and stored in the platform keychain
([`database_key.dart`](lib/data/database_key.dart));
[`connection.dart`](lib/data/connection.dart) applies it via `PRAGMA key`.

Two guards, both of which fail closed:

- **`DatabaseNotEncryptedException`** — on plain SQLite, `PRAGMA key` is an
  unrecognised no-op that *reports success*. The app would run perfectly while
  writing plaintext. So `PRAGMA cipher_version` is checked **before** the key is
  applied and before any write can occur.
- **`MissingDatabaseKeyException`** — a database with no key throws rather than
  minting a replacement, which would render the file permanently unreadable and
  silently destroy the user's history.

The key lives only in this device's keychain (`first_unlock_this_device`, so it
is not in an iCloud backup), and it goes missing in two real situations: a
restore onto another device, and a reinstall under different signing that
leaves the app container's `Documents` intact. Neither is recoverable — nothing
can decrypt the file — so `LockedDatabaseView` states that plainly and offers
*Try again* (the keychain reads as absent until the device has been unlocked
once since boot) and a confirmed *Start fresh* that deletes the file. The
dashboard withholds logging, export and Trends while locked. A zero-length file
does not count as an existing database; SQLite leaves one behind if interrupted
before the first page is written, and it would otherwise strand the app on this
error over nothing.

**`flutter test` cannot prove encryption.** Host tests use an in-memory
database and the plugin's native library never loads, so the Dart VM falls back
to system SQLite. Unit tests cover key management only. To verify for real, run
on a device and check the file header:

```bash
C=$(xcrun simctl get_app_container <udid> com.nttech.loggevity.dev data)
xxd -l 16 "$C/Documents/loggevity.sqlite"
```

A plaintext database begins with the ASCII `SQLite format 3`. An encrypted one
begins with random bytes. `sqlite3 <file> .tables` should fail with
`file is not a database (26)`.

**Never add `sqlite3_flutter_libs`.** It conflicts with
`sqlcipher_flutter_libs`; whichever loads first wins, and that is exactly how
plaintext writes sneak in.

### Migrations

`onUpgrade` in [`database.dart`](lib/data/database.dart) is additive and
version-guarded. `test/data/migration_test.dart` opens a real v1 database,
migrates it, and asserts the data survives. Add a step there for every schema
bump.

---

## Weekly sealing

The app has no background execution, so nothing runs at midnight to notice a
week ended. `WeekSealer` runs on launch (`sealOnLaunchProvider`) and walks
**every** completed week since the first entry — the user may have been away
for months, not one week.

It is idempotent and recomputes rather than skipping weeks that already have a
snapshot: a snapshot is derived data, so editing a past entry corrects history
instead of leaving it stale. Weeks with no entries are skipped — a gap in
logging is not a zero-scoring week.

---

## Import / export

Pure serialisation lives in [`portability.dart`](lib/data/portability.dart);
file I/O and the share/pick dialogs live in
[`backup_service.dart`](lib/data/backup_service.dart). Both JSON and CSV carry
the same entries.

- **Categories serialise by name, never by ordinal.** Ordinals are a storage
  detail; exporting them would silently recategorise everything if the enum
  ever moved.
- **Import is additive and de-duplicated** on a fingerprint of
  `localDate|category|value|occurredAt`. Re-importing the same file is a no-op
  rather than a way to double your week. Import never deletes.
- **Bad rows are reported, not fatal.** A malformed entry is skipped with a
  message naming the row and reason; the rest still import. Only a file that
  isn't a Loggevity export at all is rejected outright.

---

## UI layer

`DashboardPage` is the home screen: score ring, seven category rows, and a
floating Log button. Its app bar has Trends (`AnalyticsPage`), week-start, and
a "Your data" menu (export JSON / export CSV / import).

Tapping a category opens `CategoryDetailSheet` — a day-by-day chart for that
category, its own log input, and the week's entries grouped by day with
edit/delete.

**Logging is not assumed to be same-day.** `DaySelector` sits above the
categories in the quick-log sheet and above the detail sheet's input; the edit
dialog carries one too, so an entry on the wrong date can be moved. Days after
today are disabled. Back-dating matters most for sleep: without it a night
remembered the next afternoon both mis-credits today and scores the night it
actually happened as missing. Back-dated entries keep the current time of day
rather than landing at midnight, so the entry list stays ordered. The pickers
cover the current week only — earlier weeks are sealed into snapshots, and
editing them would mean re-sealing history.

Two layout conventions worth knowing before changing anything:

- **`FitHeight`** wraps screens that must not clip: it measures the laid-out
  height and scales down uniformly on overflow. Estimating content height does
  not work — the same widgets render taller on Android than iOS, and text-scale
  settings move them again. Guessing low pushes the last row off the bottom.
- **Vertical clearance, not narrowing.** The list reserves height beneath it
  for the floating button rather than shrinking the last row.

Theme is a **single seed colour** driving both light and dark schemes with
nothing else overridden, so every surface — including the scaffold background —
is derived. Setting any colour by hand breaks that derivation.

---

## Testing

```bash
flutter test                                   # everything
flutter test test/scoring/                     # pure model, fastest signal
flutter test test/ui/dashboard_test.dart -r compact
```

| Area | Files | Tests |
| --- | --- | --- |
| Scoring | `test/scoring/` | 25 |
| Data | `test/data/` | 86 |
| UI | `test/ui/` | 47 |
| | | **158** |

### Gotchas that will cost you an hour

- **Drift + widget tests deadlock if you await stream cancellation.** Drift
  defers stream cleanup to a zero-duration timer that cannot fire during widget
  disposal; a hand-rolled `switchMap` awaiting `inner.cancel()` hung
  `pumpWidget` forever. Compose streams in Riverpod, not by hand.
- **Unmount inside the test body.** The framework checks for pending timers as
  soon as the body returns — before any `addTearDown` — so the tree must come
  down while pumps are still available. The `withDashboard` helper ends with
  `pumpWidget(SizedBox())` then a single bounded `pump`.
- **Never `pumpAndSettle` after unmounting.** It pumps while frames stay
  scheduled and the drift teardown keeps rescheduling them. One
  `pump(Duration(milliseconds: 10))` is enough and cannot loop.
- **An indeterminate `CircularProgressIndicator` never settles.** If a provider
  doesn't emit, `pumpAndSettle` spins rather than failing fast.
- **Widget tests use a tall viewport** so finders don't miss content a phone
  would push below the fold. `ListView` builds lazily — an off-screen row does
  not exist as far as `find` is concerned.
- **`purity_test.dart` fails the build if anything in `lib/scoring/` imports
  Flutter or `dart:io`.** That is deliberate; keep the model portable.

---

## Invariants

Break these and data corrupts silently — no crash, no test failure unless you
add one.

1. **Never reorder `ActivityCategory`.** Drift persists `intEnum` columns as
   the ordinal, so reordering recategorises every stored row. Pinned by
   `database_test.dart`.
2. **Store raw values, derive everything else.** Sleep especially: raw hours in,
   adjusted hours computed.
3. **Never clamp negative sub-scores to zero.** They are the model's signal for
   overtraining and sleep deprivation.
4. **Never assume the week starts on Monday.**
5. **Keep `lib/scoring/` pure.**
6. **Never ship `sqlite3_flutter_libs` alongside SQLCipher.**
7. **Export categories by name, not ordinal.**

---

## Known gaps

- Encryption is verified manually on-device, not in CI.
- `flutter build ios --simulator` needs a simulator runtime matching the
  installed SDK; targeting a booted device directly (`flutter run -d <udid>`)
  works regardless.
- macOS builds compile but keychain entitlements are not configured, so
  `flutter_secure_storage` will not work there.
