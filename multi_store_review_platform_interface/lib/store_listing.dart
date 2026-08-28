/// The store listing identifiers used to deep-link to the app's review page.
///
/// Construct it as a `const` and pass it to
/// `MultiStoreReview.openStoreListing`. Only the identifiers of the platform
/// in use are required; the others are ignored.
class StoreListing {
  /// Creates a store listing description.
  const StoreListing(
      {this.appStoreId, this.macAppStoreId, this.microsoftStoreId});

  /// The numeric Apple App Store identifier of the iOS app
  /// (e.g. `'558029783'`). Required on iOS.
  final String? appStoreId;

  /// The numeric Apple App Store identifier of the macOS app, for apps whose
  /// macOS listing differs from the iOS one (separate app records instead of
  /// a universal purchase). Required on macOS unless [appStoreId] already
  /// carries the shared identifier — it is used as the fallback.
  final String? macAppStoreId;

  /// The Microsoft Store product identifier (ProductId from Partner Center).
  /// Required on Windows.
  final String? microsoftStoreId;
}
