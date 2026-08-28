import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multi_store_review_platform_interface/multi_store_review_platform_interface.dart';

import 'review_gate.dart';

export 'package:multi_store_review_platform_interface/error_codes.dart';
export 'package:multi_store_review_platform_interface/review_gate_state.dart';
export 'package:multi_store_review_platform_interface/review_store.dart';
export 'package:multi_store_review_platform_interface/store_listing.dart';
export 'review_gate.dart';

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
///
/// For automatic prompting use [configure] once at app start and
/// [maybeRequestReview] at natural pauses; the gate state persists on the
/// platform itself, so no storage package is required.
class MultiStoreReview {
  MultiStoreReview._();

  static final MultiStoreReview instance = MultiStoreReview._();

  ReviewPolicy _policy = const ReviewPolicy();
  ReviewStorage? _storage;
  bool _launchCounted = false;
  Future<bool>? _maybeInFlight;

  /// Arms the automatic review gate and counts this app launch once.
  ///
  /// Call once while the app starts up, e.g. in `main()`. The defaults of
  /// [ReviewPolicy] (3+ launches, 60 days between prompts) suit most apps;
  /// pass a custom [policy] to change them, or a custom [storage] to keep
  /// the gate state inside your own store instead of the built-in
  /// platform storage (see [ReviewStorage]).
  ///
  /// Subsequent calls in the same app session only update the policy; the
  /// launch is counted once. Storage failures are ignored — the gate then
  /// simply starts over.
  Future<void> configure({
    ReviewPolicy policy = const ReviewPolicy(),
    ReviewStorage? storage,
  }) async {
    _policy = policy;
    _storage = storage;
    if (_launchCounted) return;
    _launchCounted = true;

    try {
      final ReviewGateState state = await _readGateState();
      await _writeGateState(
        state.copyWith(
          launches: state.launches + 1,
          firstLaunchAt:
              state.firstLaunchAt == 0 ? _nowMs() : state.firstLaunchAt,
        ),
      );
    } catch (_) {
      // Persisting the launch count is best-effort.
    }
  }

  /// Asks the gate whether it is time to prompt, and shows the review
  /// dialog (or falls back to [listing]) only when the [ReviewPolicy]
  /// allows it.
  ///
  /// Call this at natural pauses — after the user completed a level,
  /// finished a session, or achieved something they liked. Returns whether
  /// a prompt attempt actually happened. Nothing is shown (and `false` is
  /// returned) while the policy says "not yet"; [PlatformException]s from
  /// the underlying store flow are swallowed and reported as `false`.
  ///
  /// Requires [configure] to have been called, otherwise no launches are
  /// ever counted and the gate stays closed.
  Future<bool> maybeRequestReview({StoreListing? listing}) {
    final Future<bool>? inFlight = _maybeInFlight;
    if (inFlight != null) return inFlight;
    final Future<bool> future = _maybeRequestReview(listing);
    _maybeInFlight = future;
    return future;
  }

  Future<bool> _maybeRequestReview(StoreListing? listing) async {
    try {
      final ReviewGateState state = await _readGateState();
      if (!gateAllows(state, _policy, DateTime.now())) return false;

      bool attempted;
      try {
        if (await canRequestReview()) {
          await requestReview();
          attempted = true;
        } else if (listing != null) {
          await openStoreListing(listing);
          attempted = true;
        } else {
          attempted = false;
        }
      } on PlatformException {
        // Store flows are best-effort: quotas, missing stores and race
        // conditions must not crash the host app.
        attempted = false;
      }

      if (attempted) {
        final ReviewGateState fresh = await _readGateState();
        await _writeGateState(
          fresh.copyWith(lastPromptAt: _nowMs()),
        );
      }
      return attempted;
    } finally {
      _maybeInFlight = null;
    }
  }

  /// Clears the persisted review gate state (launch count and timestamps)
  /// and reverts the gate to its default policy and storage.
  ///
  /// Intended for tests and debugging — treat calling this in production
  /// as resetting the user's prompt history.
  Future<void> resetReviewGate() async {
    _policy = const ReviewPolicy();
    _storage = null;
    _launchCounted = false;
    await _writeGateState(ReviewGateState.empty);
  }

  /// Evaluates the gate against [state] and [policy] at [now].
  ///
  /// Pure function, exposed for testing.
  @visibleForTesting
  static bool gateAllows(
    ReviewGateState state,
    ReviewPolicy policy,
    DateTime now,
  ) {
    if (state.launches < policy.minLaunches) return false;
    // Without a recorded first launch, configure() never ran.
    if (state.firstLaunchAt == 0) return false;

    final int nowMs = now.millisecondsSinceEpoch;
    const int dayMs = 24 * 60 * 60 * 1000;

    if (state.lastPromptAt != 0 &&
        nowMs - state.lastPromptAt < policy.minDaysBetweenPrompts * dayMs) {
      return false;
    }
    final int? maxDays = policy.maxDaysSinceInstall;
    if (maxDays != null && nowMs - state.firstLaunchAt > maxDays * dayMs) {
      return false;
    }
    return true;
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<ReviewGateState> _readGateState() async {
    final ReviewStorage? storage = _storage;
    if (storage != null) {
      return ReviewGateState(
        launches: await storage.readInt(ReviewStorageKeys.launches) ?? 0,
        firstLaunchAt:
            await storage.readInt(ReviewStorageKeys.firstLaunchAt) ?? 0,
        lastPromptAt:
            await storage.readInt(ReviewStorageKeys.lastPromptAt) ?? 0,
      );
    }
    return MultiStoreReviewPlatform.instance.readReviewGateState();
  }

  Future<void> _writeGateState(ReviewGateState state) async {
    final ReviewStorage? storage = _storage;
    if (storage != null) {
      await storage.writeInt(ReviewStorageKeys.launches, state.launches);
      await storage.writeInt(
        ReviewStorageKeys.firstLaunchAt,
        state.firstLaunchAt,
      );
      await storage.writeInt(
        ReviewStorageKeys.lastPromptAt,
        state.lastPromptAt,
      );
      return;
    }
    await MultiStoreReviewPlatform.instance.writeReviewGateState(state);
  }

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
