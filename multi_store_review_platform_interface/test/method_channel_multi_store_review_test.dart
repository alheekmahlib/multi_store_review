import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_store_review_platform_interface/method_channel_multi_store_review.dart';
import 'package:platform/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MethodChannelMultiStoreReview methodChannelMultiStoreReview;
  late List<MethodCall> log = [];
  const MethodChannel channel = MethodChannel('devdox.multi_store_review');

  setUp(() {
    methodChannelMultiStoreReview = MethodChannelMultiStoreReview();
    methodChannelMultiStoreReview.channel = channel;
    log = <MethodCall>[];
  });

  tearDown(() {
    log.clear();
  });

  Future<Object?> mockMethodCallHandler(MethodCall call) async {
    log.add(call);

    switch (call.method) {
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

  // Converts a nullable type to its non-nullable equivalent (backwards compatibility)
  (<T>(T? o) => o!)(TestDefaultBinaryMessengerBinding.instance)
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, mockMethodCallHandler);

  group('isAvailable', () {
    test(
      'should invoke the isAvailable method channel',
      () async {
        // ACT
        final result = await methodChannelMultiStoreReview.isAvailable();

        // ASSERT
        expect(log, <Matcher>[isMethodCall('isAvailable', arguments: null)]);
        expect(result, isTrue);
      },
    );
  });

  group('requestReview', () {
    test(
      'should invoke the requestReview method channel',
      () async {
        // ACT
        await methodChannelMultiStoreReview.requestReview();

        // ASSERT
        expect(log, <Matcher>[isMethodCall('requestReview', arguments: null)]);
      },
    );
  });

  group('openStoreListing', () {
    test(
      'should invoke the openStoreListing method channel on Android',
      () async {
        // ARRANGE
        methodChannelMultiStoreReview.platform =
            FakePlatform(operatingSystem: 'android');

        // ACT
        await methodChannelMultiStoreReview.openStoreListing();

        // ASSERT
        expect(
          log,
          <Matcher>[isMethodCall('openStoreListing', arguments: null)],
        );
      },
    );
    test(
      'should invoke the openStoreListing method channel on iOS',
      () async {
        // ARRANGE
        methodChannelMultiStoreReview.platform =
            FakePlatform(operatingSystem: 'ios');
        final appStoreId = "store_id";

        // ACT
        await methodChannelMultiStoreReview.openStoreListing(appStoreId: appStoreId);

        // ASSERT
        expect(log,
            <Matcher>[isMethodCall('openStoreListing', arguments: appStoreId)]);
      },
    );
    test(
      'should invoke the openStoreListing method channel on MacOS',
      () async {
        // ARRANGE
        methodChannelMultiStoreReview.platform =
            FakePlatform(operatingSystem: 'macos');
        final appStoreId = "store_id";

        // ACT
        await methodChannelMultiStoreReview.openStoreListing(appStoreId: appStoreId);

        // ASSERT
        expect(log,
            <Matcher>[isMethodCall('openStoreListing', arguments: appStoreId)]);
      },
    );
    test(
      'should invoke the openStoreListing method channel on Windows',
      () async {
        // ARRANGE
        methodChannelMultiStoreReview.platform =
            FakePlatform(operatingSystem: 'windows');
        final microsoftStoreId = 'store_id';

        // ACT
        await methodChannelMultiStoreReview.openStoreListing(
          microsoftStoreId: microsoftStoreId,
        );

        // ASSERT
        expect(log, <Matcher>[
          isMethodCall('openStoreListing', arguments: microsoftStoreId)
        ]);
      },
      skip:
          'The windows uwp implementation still uses the url_launcher package',
    );
  });
}
