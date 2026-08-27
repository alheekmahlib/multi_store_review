import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_multi_store_review.dart';
import 'review_store.dart';
import 'store_listing.dart';

export 'error_codes.dart';
export 'review_store.dart';
export 'store_listing.dart';

/// The interface that implementations of multi_store_review must implement.
///
/// Platform implementations should extend this class rather than implement it
/// as `multi_store_review` does not consider newly added methods to be
/// breaking changes. Extending this class (using `extends`) ensures that the
/// subclass will get the default implementation, while platform
/// implementations that `implements` this interface will be broken by newly
/// added [MultiStoreReviewPlatform] methods.
abstract class MultiStoreReviewPlatform extends PlatformInterface {
  MultiStoreReviewPlatform() : super(token: _token);

  static MultiStoreReviewPlatform _instance = MethodChannelMultiStoreReview();

  static final Object _token = Object();

  static MultiStoreReviewPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own
  /// platform-specific class that extends [MultiStoreReviewPlatform] when
  /// they register themselves.
  static set instance(MultiStoreReviewPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Detects which supported store is present on this device.
  ///
  /// Returns `null` when no supported store is detected.
  ///
  /// On Android this prefers the store the app was installed from and falls
  /// back to checking whether the Google Play Store (`com.android.vending`)
  /// or Huawei AppGallery (`com.huawei.appmarket`) is installed.
  ///
  /// On iOS & macOS this returns [ReviewStore.appleAppStore] when the OS
  /// supports in-app reviews.
  ///
  /// On Windows this returns [ReviewStore.microsoftStore] when the app has
  /// package identity (MSIX).
  ///
  /// Throws a [UnsupportedError] synchronously on unsupported platforms, and
  /// may throw a [PlatformException] when the platform call itself fails.
  Future<ReviewStore?> detectStore() {
    throw UnimplementedError('detectStore() has not been implemented.');
  }

  /// Checks if the device is able to show a review dialog.
  ///
  /// Equivalent to `(await detectStore()) != null`, resolved through a
  /// single [detectStore] call. It's recommended to check this before
  /// calling [requestReview] and to fall back to [openStoreListing] when it
  /// returns false.
  Future<bool> canRequestReview() async => await detectStore() != null;

  /// Attempts to show the in-app review dialog.
  ///
  /// Returns the [ReviewStore] that was asked to show the dialog. When
  /// [store] is null the store detected by [detectStore] is used. Passing an
  /// explicit [ReviewStore] makes sense mostly on Android where both Google
  /// Play and Huawei AppGallery can be targeted; requesting a store that is
  /// not present on the device throws a [PlatformException] with the
  /// `MultiStoreReviewErrorCode.unavailableStore` error code.
  ///
  /// A user dismissing the dialog resolves the future normally — only
  /// genuine failures throw.
  ///
  /// To improve the user's experience, iOS and Android enforce limitations
  /// that might prevent the dialog from being shown after a few tries. iOS &
  /// macOS users can also disable this feature entirely in the App Store
  /// settings.
  ///
  /// Throws a [UnsupportedError] synchronously on unsupported platforms, and
  /// may throw a [PlatformException] when the platform call itself fails.
  ///
  /// More info and guidance:
  /// https://developer.android.com/guide/playcore/in-app-review#when-to-request
  /// https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
  Future<ReviewStore> requestReview({ReviewStore? store}) {
    throw UnimplementedError('requestReview() has not been implemented.');
  }

  /// Opens the store listing of the app on the detected store, with a review
  /// screen when the store supports it.
  ///
  /// [StoreListing.appStoreId] is required on iOS & macOS,
  /// [StoreListing.microsoftStoreId] is required on Windows. Blank ids are
  /// rejected with an [ArgumentError].
  ///
  /// Throws a [UnsupportedError] synchronously on unsupported platforms, and
  /// may throw a [PlatformException] when the platform call itself fails.
  Future<void> openStoreListing(StoreListing listing) {
    throw UnimplementedError('openStoreListing() has not been implemented.');
  }
}
