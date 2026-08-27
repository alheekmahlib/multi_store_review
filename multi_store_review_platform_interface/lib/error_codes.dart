/// Error codes shared by the Dart and platform sides of the plugin.
///
/// Match these against [PlatformException.code] —
/// `catch (e) { if (e is PlatformException && e.code == MultiStoreReviewErrorCode.unavailableStore) ... }` —
/// instead of comparing raw strings.
abstract final class MultiStoreReviewErrorCode {
  /// No supported store is installed on this device, or the requested store
  /// is not available on it. Also reported on Windows when the app is not
  /// packaged (MSIX) or not distributed through the Microsoft Store.
  static const String unavailableStore = 'unavailable_store';

  /// The app has not been released on Huawei AppGallery.
  static const String notReleased = 'not_released';

  /// The HUAWEI ID sign-in status is invalid.
  static const String invalidHuaweiId = 'invalid_huawei_id';

  /// The user does not meet the conditions for the AppGallery review pop-up.
  static const String conditionsNotMet = 'conditions_not_met';

  /// The AppGallery commenting function is disabled.
  static const String commentsDisabled = 'comments_disabled';

  /// The in-app commenting service is not supported.
  static const String serviceUnsupported = 'service_unsupported';

  /// The store listing id required on this platform was missing or blank.
  static const String noStoreId = 'no_store_id';

  /// The review page URL could not be constructed from the store id.
  static const String urlConstructFail = 'url_construct_fail';

  /// No window scene (iOS) or view controller (macOS) was available to
  /// present the review dialog in.
  static const String noPresenter = 'no_presenter';

  /// Generic failure while requesting the review dialog or opening the
  /// store listing.
  static const String error = 'error';
}
