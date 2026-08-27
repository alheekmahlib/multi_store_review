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

On Android the store is detected automatically: if the Google Play Store is
installed it is preferred, otherwise Huawei AppGallery is used. You can also
target a store explicitly.

Linux and web are not supported; `isAvailable()` returns `false` there and the
other methods throw an `UnsupportedError`.

# Usage

```dart
import 'package:multi_store_review/multi_store_review.dart';

final MultiStoreReview multiStoreReview = MultiStoreReview.instance;

// Which store is installed on this device?
final ReviewStore store = await multiStoreReview.detectStore();

if (await multiStoreReview.isAvailable()) {
  // Shows the review dialog of the detected store.
  await multiStoreReview.requestReview();
} else {
  await multiStoreReview.openStoreListing(
    appStoreId: '14939 scooter calendar', // required on iOS & macOS
    microsoftStoreId: '9NBLGGH42LBS', // required on Windows
  );
}
```

## Targeting a specific store (Android)

```dart
// Force the Huawei AppGallery review dialog even when Google Play exists,
// for example when you know the build is distributed through AppGallery.
await multiStoreReview.requestReview(store: ReviewStore.huaweiAppGallery);
```

Requesting a store that is not installed on the device throws a
`PlatformException` with the `unavailable_store` error code.

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
through the Microsoft Store**. Unpackaged apps get `isAvailable() == false`
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
you can test the unpackaged fallback: `detectStore()` returns `unavailable`
and `openStoreListing` still opens the `ms-windows-store://` review page.

# Credits

- [britannio/in_app_review](https://github.com/britannio/in_app_review) —
  this project is a fork of it and reuses its Android, iOS & macOS
  implementations. MIT License.
- [ivangr1/in_app_comments](https://github.com/ivangr1/in_app_comments) —
  reference for the AppGallery `guidecomment` intent and its result codes.
  MIT License.
