/// The persisted state of the built-in review gate.
///
/// Timestamps are milliseconds since the Unix epoch; `0` means "not set".
/// The state is stored by the platform implementations (SharedPreferences on
/// Android, UserDefaults on iOS & macOS, a small file on Windows) so apps
/// don't need any storage package of their own.
class ReviewGateState {
  /// Creates a gate state. All fields default to "not set".
  const ReviewGateState({
    this.launches = 0,
    this.firstLaunchAt = 0,
    this.lastPromptAt = 0,
  });

  /// How many app launches were counted by `configure`.
  final int launches;

  /// When the first counted launch happened.
  final int firstLaunchAt;

  /// When the user was last prompted for a review.
  final int lastPromptAt;

  /// An empty state, as if nothing was ever persisted.
  static const ReviewGateState empty = ReviewGateState();

  /// Encodes the state for the method channel.
  Map<String, int> toMap() => <String, int>{
        'launches': launches,
        'firstLaunchAt': firstLaunchAt,
        'lastPromptAt': lastPromptAt,
      };

  /// Decodes a method channel reply; tolerates null, malformed maps and
  /// non-numeric values.
  static ReviewGateState fromMap(Object? map) {
    if (map is Map) {
      int read(String key) {
        final Object? value = map[key];
        return value is num ? value.toInt() : 0;
      }

      return ReviewGateState(
        launches: read('launches'),
        firstLaunchAt: read('firstLaunchAt'),
        lastPromptAt: read('lastPromptAt'),
      );
    }
    return ReviewGateState.empty;
  }

  ReviewGateState copyWith({
    int? launches,
    int? firstLaunchAt,
    int? lastPromptAt,
  }) =>
      ReviewGateState(
        launches: launches ?? this.launches,
        firstLaunchAt: firstLaunchAt ?? this.firstLaunchAt,
        lastPromptAt: lastPromptAt ?? this.lastPromptAt,
      );

  @override
  bool operator ==(Object other) =>
      other is ReviewGateState &&
      other.launches == launches &&
      other.firstLaunchAt == firstLaunchAt &&
      other.lastPromptAt == lastPromptAt;

  @override
  int get hashCode => Object.hash(launches, firstLaunchAt, lastPromptAt);

  @override
  String toString() =>
      'ReviewGateState(launches: $launches, firstLaunchAt: $firstLaunchAt, '
      'lastPromptAt: $lastPromptAt)';
}
