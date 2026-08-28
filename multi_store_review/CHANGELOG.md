# 2.1.0

Automatic review gate — prompt users at the right time with two lines and
no storage package of your own.

- `MultiStoreReview.instance.configure()` counts the app launch and arms
  the gate with a sensible default policy (3+ launches, 60 days between
  prompts). Pass a `ReviewPolicy` to change the numbers
  (`minLaunches`, `minDaysBetweenPrompts`, `maxDaysSinceInstall`).
- `maybeRequestReview({listing})` asks the gate whether it is time to
  prompt and, when allowed, shows the review dialog of the detected store
  — or falls back to `openStoreListing(listing)` when no store can review.
  Returns whether a prompt attempt happened; store-flow
  `PlatformException`s are swallowed. Concurrent calls share one flow.
- The gate state persists natively (SharedPreferences on Android,
  UserDefaults on iOS & macOS, a small file under %APPDATA% on Windows) —
  the app needs no storage dependency.
- `resetReviewGate()` clears the state for tests and debugging.
- Advanced: pass a `ReviewStorage` (`readInt`/`writeInt`) to `configure`
  to keep the state in your own store instead (get_storage, Hive,
  SharedPreferences adapters documented in the README).

# 2.0.0

Breaking overhaul based on a full code review of the library. Thanks to the
audit, this release also fixes several critical platform bugs — most notably
Android store detection being broken on Android 11+ and Windows builds
failing outright.

## Breaking changes

- `detectStore()` now returns `Future<ReviewStore?>` — `null` means "no
  supported store detected". The `ReviewStore.unavailable` sentinel value
  was removed.
- `isAvailable()` was replaced by `canRequestReview()`, derived from a
  single `detectStore()` call (one source of truth on the channel).
- `requestReview()` now returns `Future<ReviewStore>` — the store that
  actually showed the dialog — so you no longer need a separate
  `detectStore()` round-trip.
- `openStoreListing({appStoreId, microsoftStoreId})` now takes a
  `StoreListing` value object: `openStoreListing(const StoreListing(
  appStoreId: ..., microsoftStoreId: ...))`. Blank ids are rejected with an
  `ArgumentError` (previously empty strings slipped through and produced
  broken store URLs).
- New `MultiStoreReviewErrorCode` constants replace the magic error-code
  strings documented in prose (`unavailable_store`, `not_released`, ...).

## Fixed

- **Android**: store detection now works on Android 11+ — the plugin
  manifest declares the `<queries>` package visibility entries for Google
  Play and Huawei AppGallery.
- **Android**: the store that *installed* the app is now preferred during
  detection, so devices with both stores route reviews to the store where
  the app is actually listed.
- **Android**: a second `requestReview` while an AppGallery flow is in
  flight no longer leaks the first Dart future forever (it now fails
  explicitly), the activity-result listener is removed on detach, and a
  destroyed activity answers the pending result instead of leaking it.
- **Android**: dismissing the AppGallery dialog (`RESULT_CANCELED`) and the
  user-cancel result code (108) now resolve normally instead of surfacing
  `unknown_error`.
- **iOS/macOS**: the Swift Package product was renamed from `in-app-review`
  to `multi_store_review` — SPM-based builds previously failed to resolve
  it.
- **iOS**: `requestReview` no longer reports success when no foreground
  window scene is available (now a `no_presenter` error) and prefers the
  `foregroundActive` scene.
- **iOS**: `openStoreListing` now reports whether the store URL actually
  opened.
- **macOS**: fixed the double method-channel reply after an error in
  `requestReview`.
- **Windows**: the build is fixed — the missing `c_api` header and export
  expected by `pluginClass: MultiStoreReviewPluginCApi` were added.
- **Windows**: C++/WinRT exceptions are enabled for the plugin target;
  previously every WinRT failure called `std::terminate()` instead of
  returning a `FlutterError`.
- **Windows**: fixed use-after-move of the method result in the error path
  of `requestReview`, and user cancellation now resolves normally like on
  Android & iOS.

## Improved

- Concurrent `requestReview()` calls are deduplicated: while a request is
  in flight, callers share the same future instead of launching a second
  review dialog.
- `MethodChannelMultiStoreReview` takes its channel and platform through
  constructor injection instead of mutable `@visibleForTesting` setters.
- Example app fixed (empty-id `ArgumentError` handling, `StoreListing`,
  `requestReview` result display) and its tests were rewritten — they were
  fully commented out and referenced a removed API.
- Repository hygiene: `/tree/master` links corrected to `main`, podspec
  versions aligned with the pubspec, Makefile `run-macos` path fixed, stale
  CI action replaced (`subosito/flutter-action`), new CI jobs for the
  Windows example build and Android unit tests, lint rules for the
  platform-interface package, and a dead `<queries>`-less manifest is now
  query-complete.

# 1.0.0

Initial release of `multi_store_review`, an independent fork of
`in_app_review` with a new clean API.

- New `ReviewStore` enum and `detectStore()` method: detects Google Play,
  Huawei AppGallery, the Apple App Store or the Microsoft Store.
- `requestReview({ReviewStore? store})`: shows the in-app review dialog of
  the detected store by default, or of an explicitly requested store.
- Huawei AppGallery support on Android through the `guidecomment` intent —
  no HMS SDK or agconnect setup required.
- Windows: native `StoreContext.RequestRateAndReviewAppAsync` implementation
  for MSIX-packaged Microsoft Store apps, plus `openStoreListing` via the
  `ms-windows-store://` review deep link.
- Removed the `url_launcher` dependency — everything goes through the method
  channel now.
