import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:multi_store_review/multi_store_review.dart';
import 'package:multi_store_review_platform_interface/multi_store_review_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final multiStoreReview = MultiStoreReview.instance;
  late MockMultiStoreReviewPlatform platform;
  late MultiStoreReviewPlatform originalPlatform;
  late ReviewGateState gateState;

  setUpAll(() {
    originalPlatform = MultiStoreReviewPlatform.instance;
  });

  setUp(() async {
    platform = MockMultiStoreReviewPlatform();
    MultiStoreReviewPlatform.instance = platform;
    gateState = ReviewGateState.empty;
    when(platform.readReviewGateState()).thenAnswer((_) async => gateState);
    when(platform.writeReviewGateState(any)).thenAnswer((invocation) async {
      gateState = invocation.positionalArguments.single as ReviewGateState;
    });

    // Reset the singleton's session state between tests.
    await multiStoreReview.resetReviewGate();
    clearInteractions(platform);
  });

  tearDown(() {
    MultiStoreReviewPlatform.instance = originalPlatform;
  });

  test('instance is a singleton', () {
    expect(MultiStoreReview.instance, same(multiStoreReview));
  });

  group('gateAllows', () {
    final now = DateTime(2026, 8, 27);
    int daysAgo(int days) =>
        now.millisecondsSinceEpoch - Duration(days: days).inMilliseconds;

    test('stays closed below the minimum launch count', () {
      expect(
        MultiStoreReview.gateAllows(
          ReviewGateState(launches: 2, firstLaunchAt: daysAgo(30)),
          const ReviewPolicy(),
          now,
        ),
        isFalse,
      );
    });

    test('stays closed when configure never ran', () {
      expect(
        MultiStoreReview.gateAllows(
          const ReviewGateState(launches: 10),
          const ReviewPolicy(),
          now,
        ),
        isFalse,
      );
    });

    test('opens with the default policy when eligible', () {
      expect(
        MultiStoreReview.gateAllows(
          ReviewGateState(launches: 3, firstLaunchAt: daysAgo(100)),
          const ReviewPolicy(),
          now,
        ),
        isTrue,
      );
    });

    test('honours the cooldown window around its boundary', () {
      const policy = ReviewPolicy(minLaunches: 1, minDaysBetweenPrompts: 60);
      final recentlyPrompted = ReviewGateState(
        launches: 5,
        firstLaunchAt: daysAgo(200),
        lastPromptAt: daysAgo(30),
      );
      expect(
        MultiStoreReview.gateAllows(recentlyPrompted, policy, now),
        isFalse,
      );

      final cooldownExpired = ReviewGateState(
        launches: 5,
        firstLaunchAt: daysAgo(200),
        lastPromptAt: daysAgo(60),
      );
      expect(
        MultiStoreReview.gateAllows(cooldownExpired, policy, now),
        isTrue,
      );
    });

    test('closes permanently after maxDaysSinceInstall', () {
      const policy = ReviewPolicy(minLaunches: 1, maxDaysSinceInstall: 180);
      expect(
        MultiStoreReview.gateAllows(
          ReviewGateState(launches: 5, firstLaunchAt: daysAgo(179)),
          policy,
          now,
        ),
        isTrue,
      );
      expect(
        MultiStoreReview.gateAllows(
          ReviewGateState(launches: 5, firstLaunchAt: daysAgo(181)),
          policy,
          now,
        ),
        isFalse,
      );
    });
  });

  group('configure', () {
    test('counts a launch once per session and stamps the first launch',
        () async {
      await multiStoreReview.configure();
      await multiStoreReview.configure();

      verify(platform.readReviewGateState()).called(1);
      final writes = verify(platform.writeReviewGateState(captureAny)).captured;
      expect(writes, hasLength(1));
      final written = writes.single as ReviewGateState;
      expect(written.launches, 1);
      expect(written.firstLaunchAt, greaterThan(0));
    });

    test('keeps counting across sessions on top of persisted state', () async {
      gateState = ReviewGateState(
        launches: 4,
        firstLaunchAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      );

      await multiStoreReview.configure();

      final writes = verify(platform.writeReviewGateState(captureAny)).captured;
      final written = writes.single as ReviewGateState;
      expect(written.launches, 5);
      // The original first-launch stamp must survive.
      expect(
        written.firstLaunchAt,
        DateTime(2026, 1, 1).millisecondsSinceEpoch,
      );
    });
  });

  group('maybeRequestReview', () {
    test('stays closed before the minimum launch count', () async {
      await multiStoreReview.configure();

      final shown = await multiStoreReview.maybeRequestReview();

      expect(shown, isFalse);
      verify(platform.readReviewGateState()).called(2);
      verify(platform.writeReviewGateState(any)).called(1);
      verifyNever(platform.requestReview());
      verifyNever(platform.openStoreListing(any));
    });

    test('prompts through requestReview when eligible and records it',
        () async {
      when(platform.canRequestReview()).thenAnswer((_) async => true);
      when(platform.requestReview())
          .thenAnswer((_) async => ReviewStore.googlePlay);

      await multiStoreReview.configure(
          policy: const ReviewPolicy(minLaunches: 1));
      final shown = await multiStoreReview.maybeRequestReview();

      expect(shown, isTrue);
      verify(platform.canRequestReview()).called(1);
      verify(platform.requestReview()).called(1);
      verify(platform.writeReviewGateState(captureAny)).captured;
      expect(gateState.lastPromptAt, greaterThan(0));
      expect(gateState.launches, 1);
    });

    test('falls back to the store listing when no store can review', () async {
      when(platform.canRequestReview()).thenAnswer((_) async => false);
      when(platform.openStoreListing(any)).thenAnswer((_) async {});
      const listing = StoreListing(appStoreId: '1493928622');

      await multiStoreReview.configure(
          policy: const ReviewPolicy(minLaunches: 1));
      final shown = await multiStoreReview.maybeRequestReview(listing: listing);

      expect(shown, isTrue);
      verifyInOrder([
        platform.canRequestReview(),
        platform.openStoreListing(listing),
      ]);
      expect(gateState.lastPromptAt, greaterThan(0));
    });

    test('returns false without a store and without a listing', () async {
      when(platform.canRequestReview()).thenAnswer((_) async => false);

      await multiStoreReview.configure(
          policy: const ReviewPolicy(minLaunches: 1));
      final shown = await multiStoreReview.maybeRequestReview();

      expect(shown, isFalse);
      verifyNever(platform.requestReview());
      verifyNever(platform.openStoreListing(any));
      expect(gateState.lastPromptAt, 0);
    });

    test('swallows platform exceptions from the store flow', () async {
      when(platform.canRequestReview()).thenAnswer((_) async => true);
      when(platform.requestReview()).thenAnswer(
        (_) async => throw PlatformException(code: 'unavailable_store'),
      );

      await multiStoreReview.configure(
          policy: const ReviewPolicy(minLaunches: 1));
      final shown = await multiStoreReview.maybeRequestReview();

      expect(shown, isFalse);
      expect(gateState.lastPromptAt, 0);
    });

    test('deduplicates concurrent calls into one flow', () async {
      when(platform.canRequestReview()).thenAnswer((_) async => true);
      final completer = Completer<ReviewStore>();
      when(platform.requestReview()).thenAnswer((_) => completer.future);

      await multiStoreReview.configure(
          policy: const ReviewPolicy(minLaunches: 1));
      final first = multiStoreReview.maybeRequestReview();
      final second = multiStoreReview.maybeRequestReview();

      completer.complete(ReviewStore.googlePlay);
      expect(await first, isTrue);
      expect(await second, isTrue);
      // Both callers shared a single review flow.
      verify(platform.requestReview()).called(1);
    });

    test('uses a custom storage instead of the channel when provided',
        () async {
      final storage = _FakeStorage();
      when(platform.canRequestReview()).thenAnswer((_) async => true);
      when(platform.requestReview())
          .thenAnswer((_) async => ReviewStore.googlePlay);

      await multiStoreReview.configure(
        policy: const ReviewPolicy(minLaunches: 1),
        storage: storage,
      );
      final shown = await multiStoreReview.maybeRequestReview();

      expect(shown, isTrue);
      expect(storage.data[ReviewStorageKeys.launches], 1);
      expect(storage.data[ReviewStorageKeys.lastPromptAt], greaterThan(0));
      // The gate state must come from the custom storage, not the channel.
      verifyNever(platform.readReviewGateState());
      verifyNever(platform.writeReviewGateState(any));
    });
  });

  group('resetReviewGate', () {
    test('clears the persisted state', () async {
      await multiStoreReview.configure(
          policy: const ReviewPolicy(minLaunches: 1));

      await multiStoreReview.resetReviewGate();

      expect(gateState, ReviewGateState.empty);
      // The next configure starts counting from scratch again.
      await multiStoreReview.configure();
      expect(gateState.launches, 1);
    });
  });

  group('detectStore', () {
    test('delegates to MultiStoreReviewPlatform.detectStore()', () async {
      when(platform.detectStore())
          .thenAnswer((_) async => ReviewStore.googlePlay);

      final result = await multiStoreReview.detectStore();

      verify(platform.detectStore());
      expect(result, ReviewStore.googlePlay);
    });

    test('forwards a null (no store detected) result', () async {
      when(platform.detectStore()).thenAnswer((_) async => null);

      expect(await multiStoreReview.detectStore(), isNull);

      verify(platform.detectStore());
    });

    test('surfaces platform exceptions to the caller', () async {
      when(platform.detectStore()).thenAnswer(
        (_) async => throw PlatformException(
          code: MultiStoreReviewErrorCode.unavailableStore,
        ),
      );

      await expectLater(
        multiStoreReview.detectStore(),
        throwsA(isA<PlatformException>()),
      );

      verify(platform.detectStore());
    });
  });

  group('canRequestReview', () {
    test('delegates to MultiStoreReviewPlatform.canRequestReview()', () async {
      when(platform.canRequestReview()).thenAnswer((_) async => true);

      final result = await multiStoreReview.canRequestReview();

      verify(platform.canRequestReview());
      expect(result, isTrue);
    });
  });

  group('requestReview', () {
    test('delegates without a store by default and returns the used store',
        () async {
      when(platform.requestReview())
          .thenAnswer((_) async => ReviewStore.googlePlay);

      final usedStore = await multiStoreReview.requestReview();

      verify(platform.requestReview());
      expect(usedStore, ReviewStore.googlePlay);
    });

    test('forwards the explicit store', () async {
      when(platform.requestReview(store: ReviewStore.huaweiAppGallery))
          .thenAnswer((_) async => ReviewStore.huaweiAppGallery);

      final usedStore = await multiStoreReview.requestReview(
        store: ReviewStore.huaweiAppGallery,
      );

      verify(platform.requestReview(store: ReviewStore.huaweiAppGallery));
      expect(usedStore, ReviewStore.huaweiAppGallery);
    });

    test('surfaces platform exceptions to the caller', () async {
      when(platform.requestReview()).thenAnswer(
        (_) async => throw PlatformException(
          code: MultiStoreReviewErrorCode.unavailableStore,
        ),
      );

      await expectLater(
        multiStoreReview.requestReview(),
        throwsA(isA<PlatformException>()),
      );

      verify(platform.requestReview());
    });
  });

  group('openStoreListing', () {
    test('delegates to MultiStoreReviewPlatform.openStoreListing()', () async {
      const listing = StoreListing(
        appStoreId: 'app_store_id',
        microsoftStoreId: 'microsoft_store_id',
      );
      when(platform.openStoreListing(listing)).thenAnswer((_) async {});

      await multiStoreReview.openStoreListing(listing);

      verify(platform.openStoreListing(listing));
    });

    test('surfaces platform exceptions to the caller', () async {
      const listing = StoreListing(appStoreId: 'app_store_id');
      when(platform.openStoreListing(listing)).thenAnswer(
        (_) async => throw PlatformException(
          code: MultiStoreReviewErrorCode.noStoreId,
        ),
      );

      await expectLater(
        multiStoreReview.openStoreListing(listing),
        throwsA(isA<PlatformException>()),
      );

      verify(platform.openStoreListing(listing));
    });
  });
}

class _FakeStorage implements ReviewStorage {
  final Map<String, int> data = <String, int>{};

  @override
  Future<int?> readInt(String key) async => data[key];

  @override
  Future<void> writeInt(String key, int value) async => data[key] = value;
}

class MockMultiStoreReviewPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements MultiStoreReviewPlatform {
  // Convenience signatures for stubbing. Object parameters are nullable so
  // that null-typed argument matchers (`any`, `captureAny`) can be passed,
  // the way mockito's code generation widens them.
  @override
  Future<ReviewStore?> detectStore() => (super.noSuchMethod(
        Invocation.method(#detectStore, null),
        returnValue: Future<ReviewStore?>.value(),
        returnValueForMissingStub: Future<ReviewStore?>.value(),
      ) as Future<ReviewStore?>);

  @override
  Future<bool> canRequestReview() => (super.noSuchMethod(
        Invocation.method(#canRequestReview, null),
        returnValue: Future<bool>.value(false),
        returnValueForMissingStub: Future<bool>.value(false),
      ) as Future<bool>);

  @override
  Future<ReviewStore> requestReview({ReviewStore? store}) =>
      (super.noSuchMethod(
        Invocation.method(#requestReview, null, {#store: store}),
        returnValue: Future.value(ReviewStore.googlePlay),
        returnValueForMissingStub: Future.value(ReviewStore.googlePlay),
      ) as Future<ReviewStore>);

  @override
  Future<void> openStoreListing(StoreListing? listing) => (super.noSuchMethod(
        Invocation.method(#openStoreListing, [listing]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);

  @override
  Future<ReviewGateState> readReviewGateState() => (super.noSuchMethod(
        Invocation.method(#readReviewGateState, null),
        returnValue: Future.value(ReviewGateState.empty),
        returnValueForMissingStub: Future.value(ReviewGateState.empty),
      ) as Future<ReviewGateState>);

  @override
  Future<void> writeReviewGateState(ReviewGateState? state) =>
      (super.noSuchMethod(
        Invocation.method(#writeReviewGateState, [state]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);
}
