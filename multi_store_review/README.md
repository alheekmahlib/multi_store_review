# multi_store_review

[![pub package](https://img.shields.io/pub/v/multi_store_review.svg)](https://pub.dev/packages/multi_store_review)

A Flutter plugin that shows the in-app review/rating pop-up across multiple
stores, so users can rate your app without leaving it. Alternatively, you can
open your store listing via a deep link.

It is a fork of the wonderful
[in_app_review](https://github.com/britannio/in_app_review) by Britannio
Jarrett, extended with Huawei AppGallery support and a native Microsoft Store
implementation on Windows.

# Stores & platforms

| Store             | Platforms      | `requestReview` | `openStoreListing` |
|-------------------|----------------|-----------------|--------------------|
| Google Play       | Android        | ✅ Play Core In-App Review API | ✅ |
| Huawei AppGallery | Android        | ✅ In-App Comments (no HMS SDK needed) | ✅ |
| Apple App Store   | iOS & macOS    | ✅ StoreKit `requestReview` | ✅ |
| Microsoft Store   | Windows (MSIX) | ✅ `StoreContext.RequestRateAndReviewAppAsync` | ✅ |

On Android the store is detected automatically. The store your app was
**installed from** is preferred, falling back to the Google Play Store and
then Huawei AppGallery when only presence can be determined. You can also
target a store explicitly.

The required `<queries>` package-visibility entries for Google Play and
AppGallery ship in the plugin's own manifest and merge into your app
automatically — no manual manifest changes needed on Android 11+.

Linux and web are not supported; `canRequestReview()` returns `false` there
and the other methods throw an `UnsupportedError`.

# Installation

Until the package is published on pub.dev, depend on it via Git. The
platform interface lives in the same repository, so add a
`dependency_overrides` entry for it too:

```yaml
dependencies:
  multi_store_review:
    git:
      url: https://github.com/alheekmahlib/multi_store_review.git
      path: multi_store_review

dependency_overrides:
  multi_store_review_platform_interface:
    git:
      url: https://github.com/alheekmahlib/multi_store_review.git
      path: multi_store_review_platform_interface
```

No platform setup is required: the `<queries>` package-visibility entries
needed for store detection on Android 11+ ship in the plugin's own
manifest and merge into your app automatically.

# Usage

```dart
import 'package:multi_store_review/multi_store_review.dart';

final MultiStoreReview multiStoreReview = MultiStoreReview.instance;

// Which store is present on this device? null when none was detected.
final ReviewStore? store = await multiStoreReview.detectStore();

if (await multiStoreReview.canRequestReview()) {
  // Shows the review dialog of the detected store and completes with the
  // store that was actually used.
  final ReviewStore used = await multiStoreReview.requestReview();
} else {
  await multiStoreReview.openStoreListing(
    const StoreListing(
      appStoreId: '1493928622', // numeric id, required on iOS & macOS
      microsoftStoreId: '9NBLGGH42LBS', // required on Windows
    ),
  );
}
```

# Automatic review gate (recommended)

Instead of deciding yourself when to prompt, arm the gate once at startup
and ask it at natural pauses. The state (launch count, timestamps)
persists on the platform itself — **no storage package needed** — and the
defaults (3+ launches, 60 days between prompts) suit most apps:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(MultiStoreReview.instance.configure());
  runApp(const MyApp());
}

// After a positive moment — a finished level, a completed session:
final shown = await MultiStoreReview.instance.maybeRequestReview(
  listing: const StoreListing(
    appStoreId: '1493928622',       // fallback when no store can review
    microsoftStoreId: '9NBLGGH42LBS',
  ),
);
```

`maybeRequestReview` never throws and returns `false` when the gate
decides to wait, when no store can review and no `listing` was given, or
when the store flow fails. Call `resetReviewGate()` to clear the state
(tests & debugging).

Custom numbers:

```dart
await MultiStoreReview.instance.configure(
  const ReviewPolicy(
    minLaunches: 5,
    minDaysBetweenPrompts: 90,
    maxDaysSinceInstall: 365, // stop asking long-abandoned users
  ),
);
```

Keeping the state in your own storage instead (optional — the keys are
documented in `ReviewStorageKeys`):

```dart
// get_storage
class GetStorageReviewStorage implements ReviewStorage {
  GetStorageReviewStorage(this._box);
  final GetStorage _box;

  @override
  Future<int?> readInt(String key) async => _box.read<int>(key);

  @override
  Future<void> writeInt(String key, int value) async =>
      _box.write(key, value);
}

// SharedPreferences
class SharedPreferencesReviewStorage implements ReviewStorage {
  SharedPreferencesReviewStorage(this._prefs);
  final SharedPreferences _prefs;

  @override
  Future<int?> readInt(String key) async => _prefs.getInt(key);

  @override
  Future<void> writeInt(String key, int value) async =>
      _prefs.setInt(key, value);
}

await MultiStoreReview.instance.configure(storage: GetStorageReviewStorage(box));
```

Remember that the store quotas still apply on top of the gate: calling
`requestReview` (directly or through the gate) never guarantees that a
dialog is shown.

## Targeting a specific store (Android)

```dart
// Force the Huawei AppGallery review dialog even when Google Play exists,
// for example when you know the build is distributed through AppGallery.
final ReviewStore used = await multiStoreReview.requestReview(
  store: ReviewStore.huaweiAppGallery,
);
```

Requesting a store that is not installed on the device throws a
`PlatformException` with the
`MultiStoreReviewErrorCode.unavailableStore` error code.

## Error codes

Match these via `MultiStoreReviewErrorCode` instead of raw strings:

| Constant | Meaning |
|---|---|
| `unavailableStore` | No supported store on the device, requested store missing, or (Windows) the app is not MSIX-packaged. |
| `notReleased` | The app has not been released on AppGallery. |
| `invalidHuaweiId` | The HUAWEI ID sign-in status is invalid. |
| `conditionsNotMet` | The user does not meet the AppGallery pop-up conditions. |
| `commentsDisabled` | The AppGallery commenting function is disabled. |
| `serviceUnsupported` | The in-app commenting service is not supported. |
| `noStoreId` | The store listing id required on this platform was missing. |
| `urlConstructFail` | The review page URL could not be constructed. |
| `noPresenter` | No window scene (iOS) / view controller (macOS) to present the dialog in. |
| `error` | Generic failure of the review flow or store listing launch. |

A user **dismissing** the dialog never throws — on every platform the
`requestReview` future resolves normally; only genuine failures do.

# Huawei AppGallery requirements

The AppGallery rating dialog is rendered by the AppGallery app itself through
the `com.huawei.appmarket.intent.action.guidecomment` intent, so no HMS SDK or
`agconnect-services.json` is required. Keep in mind that:

- Your app must be **released on AppGallery** (error code `not_released`
  otherwise).
- The user must be signed in with a HUAWEI ID (`invalid_huawei_id`).
- AppGallery **11.3.2.302+** must be installed.
- Huawei throttles how often the dialog is shown (`conditions_not_met`),
  similar to Google Play quotas.

# Microsoft Store (Windows) requirements

`requestReview` uses the WinRT `StoreContext.RequestRateAndReviewAppAsync`
API and therefore requires the app to be **packaged (MSIX) and distributed
through the Microsoft Store**. Unpackaged apps get `detectStore() == null`
and an `unavailable_store` error — fall back to `openStoreListing`, which
needs your `microsoftStoreId` (ProductId from Partner Center).

# When to request a review

### Do

- Use this after a user has experienced your app for long enough to provide
  useful feedback, e.g., after the completion of a game level or after a few
  days.
- Use this sparingly otherwise no pop up will appear.

### Avoid

- Triggering this via a button in your app as it will only work when the
  quota enforced by the underlying API has not been exceeded.
  ([Android](https://developer.android.com/guide/playcore/in-app-review#quotas))
- Interrupting the user if they are mid way through a task.

# Testing (read carefully)

## Android (Google Play)

`requestReview` cannot be tested by installing your app locally. Consult
[Google's official documentation](https://developer.android.com/guide/playcore/in-app-review/test)
on testing the In-App Review API (e.g., via Internal App Sharing). The review
manager also fails on devices without the Play Store — on such devices this
plugin automatically falls back to the Huawei AppGallery dialog when
AppGallery is installed.

## Android (Huawei AppGallery)

The AppGallery dialog only appears for apps that are released on AppGallery.
Test on a Huawei device (or a device with AppGallery installed) signed in
with a HUAWEI ID, using a build whose version is already live on the store.

## iOS

The review dialog works in the simulator but not via TestFlight. Consult
Apple's [testing guide](https://developer.apple.com/documentation/storekit/requesting_app_store_reviews_from_users_in_your_app).

## Windows

The rating dialog requires a Store-published MSIX package. During development
you can test the unpackaged fallback: `detectStore()` returns `null`
and `openStoreListing` still opens the `ms-windows-store://` review page.

# Credits

- [britannio/in_app_review](https://github.com/britannio/in_app_review) —
  this project is a fork of it and reuses its Android, iOS & macOS
  implementations. MIT License.
- [ivangr1/in_app_comments](https://github.com/ivangr1/in_app_comments) —
  reference for the AppGallery `guidecomment` intent and its result codes.
  MIT License.
