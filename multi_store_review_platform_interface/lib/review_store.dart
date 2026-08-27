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
  microsoftStore;

  /// Parses the wire name reported by a platform implementation.
  ///
  /// Returns `null` when [name] is null, unknown, or the `unavailable`
  /// sentinel used by the platform implementations to report that no
  /// supported store was detected on the device.
  static ReviewStore? fromName(String? name) {
    if (name == null) return null;
    for (final ReviewStore store in ReviewStore.values) {
      if (store.name == name) return store;
    }
    return null;
  }
}
