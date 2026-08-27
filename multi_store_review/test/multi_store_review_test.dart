import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:multi_store_review/multi_store_review.dart';
import 'package:multi_store_review_platform_interface/multi_store_review_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final multiStoreReview = MultiStoreReview.instance;
  late MockMultiStoreReviewPlatform platform;

  setUp(() {
    platform = MockMultiStoreReviewPlatform();
    MultiStoreReviewPlatform.instance = platform;
  });

  tearDown(() {
    verifyNoMoreInteractions(platform);
  });

  group('detectStore', () {
    test('should call MultiStoreReviewPlatform.detectStore()', () async {
      when(platform.detectStore())
          .thenAnswer((_) async => ReviewStore.googlePlay);

      final result = await multiStoreReview.detectStore();

      verify(platform.detectStore());
      expect(result, ReviewStore.googlePlay);
    });
  });

  group('isAvailable', () {
    test('should call MultiStoreReviewPlatform.isAvailable()', () async {
      when(platform.isAvailable()).thenAnswer((_) async => true);

      final result = await multiStoreReview.isAvailable();

      verify(platform.isAvailable());
      expect(result, isTrue);
    });
  });

  group('requestReview', () {
    test('should call requestReview without a store by default', () async {
      when(platform.requestReview()).thenAnswer((_) async {});

      await multiStoreReview.requestReview();

      verify(platform.requestReview());
    });

    test('should forward the explicit store', () async {
      when(platform.requestReview(store: ReviewStore.huaweiAppGallery))
          .thenAnswer((_) async {});

      await multiStoreReview.requestReview(store: ReviewStore.huaweiAppGallery);

      verify(platform.requestReview(store: ReviewStore.huaweiAppGallery));
    });
  });

  group('openStoreListing', () {
    test('should call MultiStoreReviewPlatform.openStoreListing()', () async {
      const appStoreId = 'app_store_id';
      const microsoftStoreId = 'microsoft_store_id';
      when(platform.openStoreListing(
        appStoreId: appStoreId,
        microsoftStoreId: microsoftStoreId,
      )).thenAnswer((_) async {});

      await multiStoreReview.openStoreListing(
        appStoreId: appStoreId,
        microsoftStoreId: microsoftStoreId,
      );

      verify(platform.openStoreListing(
        appStoreId: appStoreId,
        microsoftStoreId: microsoftStoreId,
      ));
    });
  });
}

class MockMultiStoreReviewPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements MultiStoreReviewPlatform {
  @override
  Future<ReviewStore> detectStore() => super.noSuchMethod(
        Invocation.method(#detectStore, null),
        returnValue: Future.value(ReviewStore.unavailable),
      ) as Future<ReviewStore>;

  @override
  Future<bool> isAvailable() => super.noSuchMethod(
        Invocation.method(#isAvailable, null),
        returnValue: Future.value(true),
      ) as Future<bool>;

  @override
  Future<void> requestReview({ReviewStore? store}) => (super.noSuchMethod(
        Invocation.method(#requestReview, null, {#store: store}),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #openStoreListing,
          null,
          {#appStoreId: appStoreId, #microsoftStoreId: microsoftStoreId},
        ),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);
}
