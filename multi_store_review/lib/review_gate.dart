/// Policy controlling when the built-in review gate prompts the user.
///
/// Pass it to `MultiStoreReview.instance.configure`; the defaults are
/// deliberately conservative so most apps need no configuration at all.
class ReviewPolicy {
  /// Creates a review policy.
  const ReviewPolicy({
    this.minLaunches = 3,
    this.minDaysBetweenPrompts = 60,
    this.maxDaysSinceInstall,
  });

  /// Minimum counted app launches before the first prompt is allowed.
  final int minLaunches;

  /// Minimum days between two prompt attempts.
  final int minDaysBetweenPrompts;

  /// When set, the gate stops asking entirely after this many days since
  /// the first recorded launch (users who abandoned the app long ago).
  final int? maxDaysSinceInstall;
}

/// Key names used by the built-in review gate when a custom [ReviewStorage]
/// is provided via `MultiStoreReview.instance.configure`.
///
/// The values are integers; timestamps are milliseconds since the epoch and
/// `0` means "not set".
abstract final class ReviewStorageKeys {
  /// The counted app launches.
  static const String launches = 'multi_store_review.launches';

  /// The first counted launch timestamp.
  static const String firstLaunchAt = 'multi_store_review.firstLaunchAt';

  /// The last prompt attempt timestamp.
  static const String lastPromptAt = 'multi_store_review.lastPromptAt';
}

/// An optional storage the review gate can use instead of the built-in
/// platform storage, for apps that prefer keeping the state inside their
/// own store (get_storage, Hive, SharedPreferences, ...).
///
/// ```dart
/// class GetStorageReviewStorage implements ReviewStorage {
///   GetStorageReviewStorage(this._box);
///   final GetStorage _box;
///
///   @override
///   Future<int?> readInt(String key) async => _box.read<int>(key);
///
///   @override
///   Future<void> writeInt(String key, int value) async =>
///       _box.write(key, value);
/// }
/// ```
abstract class ReviewStorage {
  /// Reads the integer stored under [key], or null when absent.
  Future<int?> readInt(String key);

  /// Stores [value] under [key].
  Future<void> writeInt(String key, int value);
}
