import 'package:multi_store_review_platform_interface/multi_store_review_platform_interface.dart';

export 'package:multi_store_review_platform_interface/error_codes.dart';
export 'package:multi_store_review_platform_interface/review_store.dart';
export 'package:multi_store_review_platform_interface/store_listing.dart';

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
///
/// Linux and web are not supported: [canRequestReview] returns `false` there
/// and the other methods throw a [UnsupportedError] synchronously.
class MultiStoreReview {
  MultiStoreReview._();

  static final MultiStoreReview instance = MultiStoreReview._();

  /// Detects which supported store is present on this device.
  ///
  /// Returns `null` when no supported store is detected. On Android both
  /// the store the app was installed from, Google Play and Huawei AppGallery
  /// are considered. Use this to decide whether to call [requestReview] or
  /// [openStoreListing].
  ///
  /// Throws a [UnsupportedError] synchronously on unsupported platforms and
  /// a [PlatformException] when the platform call itself fails.
  Future<ReviewStore?> detectStore() =>
      MultiStoreReviewPlatform.instance.detectStore();

  /// Checks if the device is able to show a review dialog.
  ///
  /// Equivalent to `(await detectStore()) != null`.
  ///
  /// It's recommended to check this before calling [requestReview] and to
  /// fall back to [openStoreListing] when it returns false.
  Future<bool> canRequestReview() =>
      MultiStoreReviewPlatform.instance.canRequestReview();

  /// Attempts to show the in-app review dialog and completes with the
  /// [ReviewStore] that showed it.
  ///
  /// When [store] is null the store detected by [detectStore] is used. On
  /// Android you can explicitly target [ReviewStore.googlePlay] or
  /// [ReviewStore.huaweiAppGallery]; requesting a store that is not
  /// installed on the device throws a [PlatformException] with the
  /// `MultiStoreReviewErrorCode.unavailableStore` error code.
  ///
  /// Concurrent calls are deduplicated: while a request is in flight,
  /// subsequent calls share (and await) the same future instead of launching
  /// a second review dialog.
  ///
  /// A user dismissing the dialog resolves the future normally — only
  /// genuine failures throw.
  ///
  /// To improve the user's experience, stores enforce limitations that
  /// might prevent the dialog from being shown after a few tries, so don't
  /// tie this call to a button — prefer natural pauses in your flow.
  ///
  /// Throws a [UnsupportedError] synchronously on unsupported platforms and
  /// a [PlatformException] when the platform call itself fails.
  ///
  /// More info and guidance:
  /// https://developer.android.com/guide/playcore/in-app-review#when-to-request
  /// https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
  Future<ReviewStore> requestReview({ReviewStore? store}) =>
      MultiStoreReviewPlatform.instance.requestReview(store: store);

  /// Opens the store listing of the app on the detected store, with a
  /// review screen when the store supports deep-linking one.
  ///
  /// [StoreListing.appStoreId] is required on iOS & macOS and
  /// [StoreListing.microsoftStoreId] is required on Windows; blank ids are
  /// rejected with an [ArgumentError].
  ///
  /// Throws a [UnsupportedError] synchronously on unsupported platforms and
  /// a [PlatformException] when the platform call itself fails.
  Future<void> openStoreListing(StoreListing listing) =>
      MultiStoreReviewPlatform.instance.openStoreListing(listing);
}
