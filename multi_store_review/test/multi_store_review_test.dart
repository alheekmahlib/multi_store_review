import 'package:flutter_test/flutter_test.dart';
import 'package:multi_store_review/multi_store_review.dart';
import 'package:multi_store_review_platform_interface/multi_store_review_platform_interface.dart';
import 'package:mockito/mockito.dart';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inAppReview = MultiStoreReview.instance;
  late MockMultiStoreReviewPlatform platform;

  setUp(() {
    platform = MockMultiStoreReviewPlatform();
    MultiStoreReviewPlatform.instance = platform;
  });

  tearDown(() {
    verifyNoMoreInteractions(platform);
  });

  group('isAvailable', () {
    test(
      'should call MultiStoreReviewPlatform.isAvailable()',
      () async {
        // ARRANGE
        when(platform.isAvailable()).thenAnswer((_) async => true);

        // ACT
        final result = await inAppReview.isAvailable();

        // ASSERT
        verify(platform.isAvailable());
        expect(result, isTrue);
      },
    );
  });
  group('requestReview', () {
    test(
      'should call MultiStoreReviewPlatform.requestReview()',
      () async {
        // ARRANGE
        when(platform.requestReview()).thenAnswer((_) async {});

        // ACT
        await inAppReview.requestReview();

        // ASSERT
        verify(platform.requestReview());
      },
    );
  });
  group('openStoreListing', () {
    test(
      'should call MultiStoreReviewPlatform.openStoreListing()',
      () async {
        // ARRANGE
        const appStoreId = 'app_store_id';
        const microsoftStoreId = 'microsoft_store_id';
        when(platform.openStoreListing(
          appStoreId: appStoreId,
          microsoftStoreId: microsoftStoreId,
        )).thenAnswer((_) async {});

        // ACT
        await inAppReview.openStoreListing(
          appStoreId: appStoreId,
          microsoftStoreId: microsoftStoreId,
        );

        // ASSERT
        verify(platform.openStoreListing(
          appStoreId: appStoreId,
          microsoftStoreId: microsoftStoreId,
        ));
      },
    );
  });
}

class MockMultiStoreReviewPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements MultiStoreReviewPlatform {
  @override
  Future<bool> isAvailable() => super.noSuchMethod(
        Invocation.method(#isAvailable, null),
        returnValue: Future.value(true),
      );

  @override
  Future<void> requestReview() => super.noSuchMethod(
        Invocation.method(#requestReview, null),
        returnValue: Future<void>.value(),
      );

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #openStoreListing,
          null,
          {#appStoreId: appStoreId, #microsoftStoreId: microsoftStoreId},
        ),
        returnValue: Future<void>.value(),
      );
}
