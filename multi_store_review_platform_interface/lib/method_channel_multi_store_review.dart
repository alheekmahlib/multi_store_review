import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:platform/platform.dart';

import 'multi_store_review_platform_interface.dart';

/// An implementation of [MultiStoreReviewPlatform] that uses method channels.
class MethodChannelMultiStoreReview extends MultiStoreReviewPlatform {
  MethodChannel _channel = const MethodChannel('devdox.multi_store_review');
  Platform _platform = const LocalPlatform();

  @visibleForTesting
  set channel(MethodChannel channel) => _channel = channel;

  @visibleForTesting
  set platform(Platform platform) => _platform = platform;

  bool get _isSupportedPlatform =>
      _platform.isAndroid ||
      _platform.isIOS ||
      _platform.isMacOS ||
      _platform.isWindows;

  @override
  Future<ReviewStore> detectStore() async {
    _ensureSupportedPlatform();
    final store = await _channel.invokeMethod<String>('detectStore');
    return ReviewStore.values.firstWhere(
      (candidate) => candidate.name == store,
      orElse: () => ReviewStore.unavailable,
    );
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || !_isSupportedPlatform) return false;
    return _channel
        .invokeMethod<bool>('isAvailable')
        .then((available) => available ?? false, onError: (_) => false);
  }

  @override
  Future<void> requestReview({ReviewStore? store}) async {
    _ensureSupportedPlatform();
    await _channel.invokeMethod<void>('requestReview', store?.name);
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    _ensureSupportedPlatform();

    final bool isApple = _platform.isIOS || _platform.isMacOS;
    if (isApple && appStoreId == null) {
      throw ArgumentError('appStoreId is required on iOS & macOS');
    }
    if (_platform.isWindows && microsoftStoreId == null) {
      throw ArgumentError('microsoftStoreId is required on Windows');
    }

    await _channel.invokeMethod<void>('openStoreListing', {
      'appStoreId': appStoreId,
      'microsoftStoreId': microsoftStoreId,
    });
  }

  void _ensureSupportedPlatform() {
    if (kIsWeb) {
      throw UnsupportedError('Web is not supported');
    }
    if (!_isSupportedPlatform) {
      throw UnsupportedError(
        'Platform(${_platform.operatingSystem}) not supported',
      );
    }
  }
}
