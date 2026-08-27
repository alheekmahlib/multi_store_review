/// The store listing identifiers used to deep-link to the app's review page.
///
/// Construct it as a `const` and pass it to
/// `MultiStoreReview.openStoreListing`. Only the identifier of the platform
/// in use is required; the others are ignored.
class StoreListing {
  /// Creates a store listing description.
  const StoreListing({this.appStoreId, this.microsoftStoreId});

  /// The numeric Apple App Store identifier of the app
  /// (e.g. `'558029783'`). Required on iOS & macOS.
  final String? appStoreId;

  /// The Microsoft Store product identifier (ProductId from Partner Center).
  /// Required on Windows.
  final String? microsoftStoreId;
}
