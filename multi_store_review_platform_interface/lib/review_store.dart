/// The app store used to collect a user's review.
enum ReviewStore {
  /// Google Play Store on Android.
  googlePlay,

  /// Huawei AppGallery, typically on Android devices without Google
  /// services.
  huaweiAppGallery,

  /// Apple App Store on iOS & macOS.
  appleAppStore,

  /// Microsoft Store on Windows. Requires the app to be packaged (MSIX)
  /// and distributed through the store.
  microsoftStore,

  /// No supported store was detected on this device.
  unavailable,
}
