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

  setUpAll(() {
    originalPlatform = MultiStoreReviewPlatform.instance;
  });

  setUp(() {
    platform = MockMultiStoreReviewPlatform();
    MultiStoreReviewPlatform.instance = platform;
  });

  tearDown(() {
    verifyNoMoreInteractions(platform);
    MultiStoreReviewPlatform.instance = originalPlatform;
  });

  test('instance is a singleton', () {
    expect(MultiStoreReview.instance, same(multiStoreReview));
  });

  group('detectStore', () {
    test('delegates to MultiStoreReviewPlatform.detectStore()', () async {
      when(platform.detectStore()).thenAnswer(
        (_) async => ReviewStore.googlePlay,
      );

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
      when(platform.requestReview()).thenAnswer(
        (_) async => ReviewStore.googlePlay,
      );

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

class MockMultiStoreReviewPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements MultiStoreReviewPlatform {
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
  Future<void> openStoreListing(StoreListing listing) => (super.noSuchMethod(
        Invocation.method(#openStoreListing, [listing]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);
}
