import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:platform/platform.dart';

import 'multi_store_review_platform_interface.dart';

/// An implementation of [MultiStoreReviewPlatform] that uses method channels.
class MethodChannelMultiStoreReview extends MultiStoreReviewPlatform {
  /// Creates a method-channel implementation talking over [channel] and
  /// reading platform details from [platform].
  MethodChannelMultiStoreReview({
    MethodChannel channel = const MethodChannel(
      'dev.alheekmahlib.multi_store_review',
    ),
    Platform platform = const LocalPlatform(),
  })  : _channel = channel,
        _platform = platform;

  final MethodChannel _channel;
  final Platform _platform;

  /// The review request currently in flight, if any.
  Future<ReviewStore>? _requestReviewInFlight;

  bool get _isSupportedPlatform =>
      _platform.isAndroid ||
      _platform.isIOS ||
      _platform.isMacOS ||
      _platform.isWindows;

  @override
  Future<ReviewStore?> detectStore() async {
    _ensureSupportedPlatform();
    final Object? store = await _channel.invokeMethod('detectStore');
    // Unknown and `unavailable` wire names map to null through fromName.
    return ReviewStore.fromName(store is String ? store : null);
  }

  @override
  Future<bool> canRequestReview() async {
    if (kIsWeb || !_isSupportedPlatform) return false;
    return await detectStore() != null;
  }

  @override
  Future<ReviewStore> requestReview({ReviewStore? store}) {
    _ensureSupportedPlatform();
    // Concurrent calls share the in-flight request instead of launching a
    // second review flow (e.g. Play's launchReviewFlow) on top of the first.
    final Future<ReviewStore>? inFlight = _requestReviewInFlight;
    if (inFlight != null) return inFlight;

    final Future<ReviewStore> future = _invokeRequestReview(store);
    _requestReviewInFlight = future;
    return future;
  }

  Future<ReviewStore> _invokeRequestReview(ReviewStore? store) async {
    try {
      final Object? usedStore = await _channel.invokeMethod(
        'requestReview',
        store?.name,
      );
      final ReviewStore? resolved =
          ReviewStore.fromName(usedStore is String ? usedStore : null);
      if (resolved == null) {
        throw StateError(
          'The platform reported the unknown store "$usedStore" for '
          'requestReview',
        );
      }
      return resolved;
    } finally {
      _requestReviewInFlight = null;
    }
  }

  @override
  Future<void> openStoreListing(StoreListing listing) async {
    _ensureSupportedPlatform();

    final bool isApple = _platform.isIOS || _platform.isMacOS;
    if (isApple && _isBlank(listing.appStoreId)) {
      throw ArgumentError.value(
        listing.appStoreId,
        'appStoreId',
        'a non-empty id is required on iOS & macOS',
      );
    }
    if (_platform.isWindows && _isBlank(listing.microsoftStoreId)) {
      throw ArgumentError.value(
        listing.microsoftStoreId,
        'microsoftStoreId',
        'a non-empty id is required on Windows',
      );
    }

    await _channel.invokeMethod<void>('openStoreListing', <String, String?>{
      'appStoreId': listing.appStoreId,
      'microsoftStoreId': listing.microsoftStoreId,
    });
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

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
