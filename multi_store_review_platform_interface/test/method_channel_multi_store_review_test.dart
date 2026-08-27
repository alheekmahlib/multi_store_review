import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_store_review_platform_interface/method_channel_multi_store_review.dart';
import 'package:multi_store_review_platform_interface/review_store.dart';
import 'package:platform/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MethodChannelMultiStoreReview methodChannelMultiStoreReview;
  late List<MethodCall> log = [];
  const MethodChannel channel = MethodChannel('dev.alheekmahlib.multi_store_review');

  setUp(() {
    methodChannelMultiStoreReview = MethodChannelMultiStoreReview();
    methodChannelMultiStoreReview.channel = channel;
    methodChannelMultiStoreReview.platform = FakePlatform(
      operatingSystem: 'android',
    );
    log = <MethodCall>[];
  });

  tearDown(() {
    log.clear();
  });

  Future<Object?> mockMethodCallHandler(MethodCall call) async {
    log.add(call);

    switch (call.method) {
      case 'detectStore':
        return 'huaweiAppGallery';
      case 'isAvailable':
        return true;
      case 'requestReview':
      case 'openStoreListing':
        return null;
      default:
        assert(false);
        return null;
    }
  }

  (<T>(T? o) => o!)(TestDefaultBinaryMessengerBinding.instance)
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, mockMethodCallHandler);

  group('detectStore', () {
    test(
      'should invoke the detectStore method channel and parse the store',
      () async {
        final result = await methodChannelMultiStoreReview.detectStore();

        expect(log, <Matcher>[isMethodCall('detectStore', arguments: null)]);
        expect(result, ReviewStore.huaweiAppGallery);
      },
    );

    test('should map an unknown store name to unavailable', () async {
      Future<Object?> unknownStoreHandler(MethodCall call) async => 'mars';

      (<T>(T? o) => o!)(TestDefaultBinaryMessengerBinding.instance)
          .defaultBinaryMessenger
          .setMockMethodCallHandler(channel, unknownStoreHandler);

      final result = await methodChannelMultiStoreReview.detectStore();

      expect(result, ReviewStore.unavailable);

      (<T>(T? o) => o!)(TestDefaultBinaryMessengerBinding.instance)
          .defaultBinaryMessenger
          .setMockMethodCallHandler(channel, mockMethodCallHandler);
    });
  });

  group('isAvailable', () {
    test('should invoke the isAvailable method channel', () async {
      final result = await methodChannelMultiStoreReview.isAvailable();

      expect(log, <Matcher>[isMethodCall('isAvailable', arguments: null)]);
      expect(result, isTrue);
    });

    test('should return false when the channel throws', () async {
      Future<Object?> failingHandler(MethodCall call) async =>
          throw PlatformException(code: 'unavailable');

      (<T>(T? o) => o!)(TestDefaultBinaryMessengerBinding.instance)
          .defaultBinaryMessenger
          .setMockMethodCallHandler(channel, failingHandler);

      final result = await methodChannelMultiStoreReview.isAvailable();

      expect(result, isFalse);

      (<T>(T? o) => o!)(TestDefaultBinaryMessengerBinding.instance)
          .defaultBinaryMessenger
          .setMockMethodCallHandler(channel, mockMethodCallHandler);
    });
  });

  group('requestReview', () {
    test('should invoke requestReview without arguments by default', () async {
      await methodChannelMultiStoreReview.requestReview();

      expect(log, <Matcher>[isMethodCall('requestReview', arguments: null)]);
    });

    test('should pass the explicit store as the argument', () async {
      await methodChannelMultiStoreReview.requestReview(
        store: ReviewStore.huaweiAppGallery,
      );

      expect(log, <Matcher>[
        isMethodCall('requestReview', arguments: 'huaweiAppGallery'),
      ]);
    });
  });

  group('openStoreListing', () {
    test('should send the store ids as a map of arguments', () async {
      await methodChannelMultiStoreReview.openStoreListing(
        appStoreId: 'app_store_id',
        microsoftStoreId: 'microsoft_store_id',
      );

      expect(log, <Matcher>[
        isMethodCall(
          'openStoreListing',
          arguments: {
            'appStoreId': 'app_store_id',
            'microsoftStoreId': 'microsoft_store_id',
          },
        ),
      ]);
    });

    test('should require appStoreId on iOS', () async {
      methodChannelMultiStoreReview.platform = FakePlatform(
        operatingSystem: 'ios',
      );

      await expectLater(
        methodChannelMultiStoreReview.openStoreListing(),
        throwsArgumentError,
      );
    });

    test('should require microsoftStoreId on Windows', () async {
      methodChannelMultiStoreReview.platform = FakePlatform(
        operatingSystem: 'windows',
      );

      await expectLater(
        methodChannelMultiStoreReview.openStoreListing(),
        throwsArgumentError,
      );
    });

    test('should throw UnsupportedError on unsupported platforms', () async {
      methodChannelMultiStoreReview.platform = FakePlatform(
        operatingSystem: 'linux',
      );

      await expectLater(
        methodChannelMultiStoreReview.openStoreListing(),
        throwsUnsupportedError,
      );
      await expectLater(
        methodChannelMultiStoreReview.requestReview(),
        throwsUnsupportedError,
      );
      await expectLater(
        methodChannelMultiStoreReview.detectStore(),
        throwsUnsupportedError,
      );
    });
  });
}
