import 'dart:async';

import 'package:multi_store_review_platform_interface/multi_store_review_platform_interface.dart';

export 'package:multi_store_review_platform_interface/review_store.dart';

/// Shows the in-app review dialog across multiple stores.
///
/// Supported stores:
///
/// | Store                | Platforms      | requestReview | openStoreListing |
/// |----------------------|----------------|---------------|------------------|
/// | Google Play          | Android        | ✅            | ✅               |
/// | Huawei AppGallery    | Android        | ✅            | ✅               |
/// | Apple App Store      | iOS & macOS    | ✅            | ✅               |
/// | Microsoft Store      | Windows (MSIX) | ✅            | ✅               |
class MultiStoreReview {
  MultiStoreReview._();

  static final MultiStoreReview instance = MultiStoreReview._();

  /// Detects which supported store is present on this device.
  ///
  /// On Android both the Google Play Store and Huawei AppGallery are
  /// detected, preferring the Play Store when both are installed. Use this
  /// to decide whether to call [requestReview] or [openStoreListing].
  Future<ReviewStore> detectStore() =>
      MultiStoreReviewPlatform.instance.detectStore();

  /// Checks if the device is able to show a review dialog.
  ///
  /// Equivalent to `(await detectStore()) != ReviewStore.unavailable`.
  ///
  /// It's recommended to check this before calling [requestReview] and to
  /// fall back to [openStoreListing] when it returns false.
  Future<bool> isAvailable() => MultiStoreReviewPlatform.instance.isAvailable();

  /// Attempts to show the in-app review dialog.
  ///
  /// When [store] is null the store detected by [detectStore] is used. On
  /// Android you can explicitly target [ReviewStore.googlePlay] or
  /// [ReviewStore.huaweiAppGallery]; requesting a store that is not
  /// installed on the device throws a [PlatformException] with the
  /// `unavailable_store` error code.
  ///
  /// To improve the user's experience, stores enforce limitations that
  /// might prevent the dialog from being shown after a few tries, so don't
  /// tie this call to a button — prefer natural pauses in your flow.
  ///
  /// More info and guidance:
  /// https://developer.android.com/guide/playcore/in-app-review#when-to-request
  /// https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
  Future<void> requestReview({ReviewStore? store}) =>
      MultiStoreReviewPlatform.instance.requestReview(store: store);

  /// Opens the store listing of the app on the detected store, with a
  /// review screen when the store supports deep-linking one.
  ///
  /// [appStoreId] is required on iOS & macOS, [microsoftStoreId] is required
  /// on Windows.
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) =>
      MultiStoreReviewPlatform.instance.openStoreListing(
        appStoreId: appStoreId,
        microsoftStoreId: microsoftStoreId,
      );
}
