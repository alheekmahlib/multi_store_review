import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_store_review_platform_interface/method_channel_multi_store_review.dart';
import 'package:multi_store_review_platform_interface/multi_store_review_platform_interface.dart';
import 'package:platform/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel(
    'dev.alheekmahlib.multi_store_review',
  );

  late MethodChannelMultiStoreReview plugin;
  late List<MethodCall> log;
  late Map<String, Future<Object?> Function(MethodCall call)> handlers;

  Future<Object?> defaultHandler(MethodCall call) {
    log.add(call);
    return handlers[call.method]!(call);
  }

  setUp(() {
    log = <MethodCall>[];
    handlers = <String, Future<Object?> Function(MethodCall call)>{
      'detectStore': (_) async => 'huaweiAppGallery',
      'requestReview': (_) async => 'huaweiAppGallery',
      'openStoreListing': (_) async => null,
    };
    plugin = MethodChannelMultiStoreReview(
      channel: channel,
      platform: FakePlatform(operatingSystem: 'android'),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, defaultHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('detectStore', () {
    test('parses every store wire name', () async {
      const wireNames = <String, ReviewStore>{
        'googlePlay': ReviewStore.googlePlay,
        'huaweiAppGallery': ReviewStore.huaweiAppGallery,
        'appleAppStore': ReviewStore.appleAppStore,
        'microsoftStore': ReviewStore.microsoftStore,
      };
      for (final entry in wireNames.entries) {
        handlers['detectStore'] = (_) async => entry.key;

        final result = await plugin.detectStore();

        expect(result, entry.value, reason: entry.key);
      }
    });

    test('maps the unavailable wire name to null', () async {
      handlers['detectStore'] = (_) async => 'unavailable';

      expect(await plugin.detectStore(), isNull);
    });

    test('maps an unknown store name to null', () async {
      handlers['detectStore'] = (_) async => 'mars';

      expect(await plugin.detectStore(), isNull);
    });

    test('maps a null and a non-string reply to null', () async {
      handlers['detectStore'] = (_) async => null;
      expect(await plugin.detectStore(), isNull);

      handlers['detectStore'] = (_) async => 42;
      expect(await plugin.detectStore(), isNull);
    });

    test('propagates platform exceptions', () async {
      handlers['detectStore'] =
          (_) async => throw PlatformException(code: 'unavailable_store');

      await expectLater(
          plugin.detectStore(), throwsA(isA<PlatformException>()));
    });
  });

  group('canRequestReview', () {
    test('is true when a store is detected', () async {
      handlers['detectStore'] = (_) async => 'googlePlay';

      expect(await plugin.canRequestReview(), isTrue);
    });

    test('is false when no store is detected', () async {
      handlers['detectStore'] = (_) async => 'unavailable';

      expect(await plugin.canRequestReview(), isFalse);
    });

    test('is false on unsupported platforms without a channel call', () async {
      plugin = MethodChannelMultiStoreReview(
        channel: channel,
        platform: FakePlatform(operatingSystem: 'linux'),
      );

      expect(await plugin.canRequestReview(), isFalse);
      expect(log, isEmpty);
    });

    test('propagates platform exceptions', () async {
      handlers['detectStore'] =
          (_) async => throw PlatformException(code: 'unavailable_store');

      await expectLater(
        plugin.canRequestReview(),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('requestReview', () {
    test('invokes requestReview without arguments by default', () async {
      final usedStore = await plugin.requestReview();

      expect(log, <Matcher>[isMethodCall('requestReview', arguments: null)]);
      expect(usedStore, ReviewStore.huaweiAppGallery);
    });

    test('passes the explicit store and parses the used store', () async {
      handlers['requestReview'] = (_) async => 'googlePlay';

      final usedStore =
          await plugin.requestReview(store: ReviewStore.googlePlay);

      expect(log, <Matcher>[
        isMethodCall('requestReview', arguments: 'googlePlay'),
      ]);
      expect(usedStore, ReviewStore.googlePlay);
    });

    test('throws a StateError for an unknown used-store reply', () async {
      handlers['requestReview'] = (_) async => 'mars';

      await expectLater(plugin.requestReview(), throwsA(isA<StateError>()));
    });

    test('deduplicates concurrent calls into one channel invocation', () async {
      final completer = Completer<String>();
      handlers['requestReview'] = (_) => completer.future;

      final first = plugin.requestReview();
      final second = plugin.requestReview();

      expect(log.length, 1);

      completer.complete('googlePlay');
      expect(await first, ReviewStore.googlePlay);
      expect(await second, ReviewStore.googlePlay);

      // Once the request completes, a new call invokes the channel again.
      handlers['requestReview'] = (_) async => 'googlePlay';
      expect(await plugin.requestReview(), ReviewStore.googlePlay);
      expect(log.length, 2);
    });

    test('propagates platform exceptions', () async {
      handlers['requestReview'] =
          (_) async => throw PlatformException(code: 'unavailable_store');

      await expectLater(
        plugin.requestReview(store: ReviewStore.huaweiAppGallery),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('openStoreListing', () {
    test('sends the store ids as a map of arguments', () async {
      await plugin.openStoreListing(
        const StoreListing(
          appStoreId: 'app_store_id',
          microsoftStoreId: 'microsoft_store_id',
        ),
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

    test('requires a non-blank appStoreId on iOS', () async {
      plugin = MethodChannelMultiStoreReview(
        channel: channel,
        platform: FakePlatform(operatingSystem: 'ios'),
      );

      await expectLater(
        plugin.openStoreListing(const StoreListing()),
        throwsArgumentError,
      );
      await expectLater(
        plugin.openStoreListing(const StoreListing(appStoreId: '')),
        throwsArgumentError,
      );
      await expectLater(
        plugin.openStoreListing(const StoreListing(appStoreId: '  ')),
        throwsArgumentError,
      );
    });

    test('requires a non-blank appStoreId on macOS', () async {
      plugin = MethodChannelMultiStoreReview(
        channel: channel,
        platform: FakePlatform(operatingSystem: 'macos'),
      );

      await expectLater(
        plugin.openStoreListing(const StoreListing()),
        throwsArgumentError,
      );
    });

    test('succeeds on iOS when an appStoreId is given', () async {
      plugin = MethodChannelMultiStoreReview(
        channel: channel,
        platform: FakePlatform(operatingSystem: 'ios'),
      );

      await plugin.openStoreListing(
        const StoreListing(appStoreId: '1493928622'),
      );

      expect(log, isNotEmpty);
    });

    test('requires a non-blank microsoftStoreId on Windows', () async {
      plugin = MethodChannelMultiStoreReview(
        channel: channel,
        platform: FakePlatform(operatingSystem: 'windows'),
      );

      await expectLater(
        plugin.openStoreListing(const StoreListing()),
        throwsArgumentError,
      );
      await expectLater(
        plugin.openStoreListing(
          const StoreListing(microsoftStoreId: ' '),
        ),
        throwsArgumentError,
      );
    });

    test('propagates platform exceptions', () async {
      handlers['openStoreListing'] =
          (_) async => throw PlatformException(code: 'no_store_id');

      await expectLater(
        plugin.openStoreListing(const StoreListing()),
        throwsA(isA<PlatformException>()),
      );
    });

    test('throws UnsupportedError on unsupported platforms', () async {
      plugin = MethodChannelMultiStoreReview(
        channel: channel,
        platform: FakePlatform(operatingSystem: 'linux'),
      );

      await expectLater(plugin.detectStore(), throwsUnsupportedError);
      // requestReview throws synchronously, so it must be wrapped in a
      // closure for the matcher to observe the throw.
      expect(() => plugin.requestReview(), throwsUnsupportedError);
      await expectLater(
        plugin.openStoreListing(const StoreListing()),
        throwsUnsupportedError,
      );
    });
  });

  group('ReviewStore.fromName', () {
    test('round-trips every enum value', () {
      for (final store in ReviewStore.values) {
        expect(ReviewStore.fromName(store.name), store);
      }
    });

    test('maps null, unknown and unavailable names to null', () {
      expect(ReviewStore.fromName(null), isNull);
      expect(ReviewStore.fromName('mars'), isNull);
      expect(ReviewStore.fromName('unavailable'), isNull);
      expect(ReviewStore.fromName(''), isNull);
    });
  });

  group('MultiStoreReviewPlatform base class', () {
    test('unimplemented methods throw UnimplementedError', () {
      final platform = _UnimplementedTestPlatform();

      expect(
        () => platform.detectStore(),
        throwsUnimplementedError,
      );
      expect(
        () => platform.requestReview(),
        throwsUnimplementedError,
      );
      expect(
        () => platform.openStoreListing(const StoreListing()),
        throwsUnimplementedError,
      );
    });

    test('canRequestReview derives from detectStore by default', () async {
      expect(
        await _DetectingTestPlatform(ReviewStore.googlePlay).canRequestReview(),
        isTrue,
      );
      expect(await _DetectingTestPlatform(null).canRequestReview(), isFalse);
    });

    test('rejects implementations that bypass the platform interface token',
        () {
      expect(
        () => MultiStoreReviewPlatform.instance = _BareTestPlatform(),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

class _UnimplementedTestPlatform extends MultiStoreReviewPlatform {}

class _DetectingTestPlatform extends MultiStoreReviewPlatform {
  _DetectingTestPlatform(this.detected);

  final ReviewStore? detected;

  @override
  Future<ReviewStore?> detectStore() async => detected;
}

class _BareTestPlatform implements MultiStoreReviewPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
