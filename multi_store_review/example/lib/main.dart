import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:multi_store_review/multi_store_review.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Counts the launch and arms the automatic review gate with the default
  // policy (3+ launches, 60 days between prompts).
  unawaited(MultiStoreReview.instance.configure());

  runApp(const MultiStoreReviewExampleApp());
}

class MultiStoreReviewExampleApp extends StatefulWidget {
  const MultiStoreReviewExampleApp({super.key});

  @override
  MultiStoreReviewExampleAppState createState() =>
      MultiStoreReviewExampleAppState();
}

class MultiStoreReviewExampleAppState
    extends State<MultiStoreReviewExampleApp> {
  final MultiStoreReview _multiStoreReview = MultiStoreReview.instance;

  String _appStoreId = '';
  String _microsoftStoreId = '';
  ReviewStore? _store;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // This plugin cannot be fully tested on Android by installing your
        // app locally. See the README testing section for more information.
        final ReviewStore? store = await _multiStoreReview.detectStore();
        setState(() => _store = store);
      } catch (_) {
        setState(() => _store = null);
      }
    });
  }

  void _setAppStoreId(String id) => _appStoreId = id;

  void _setMicrosoftStoreId(String id) => _microsoftStoreId = id;

  Future<void> _requestReview() async {
    try {
      final ReviewStore used = await _multiStoreReview.requestReview();
      _showSnack('requestReview shown by: ${used.name}');
    } catch (e) {
      _showSnack('requestReview failed: $e');
    }
  }

  Future<void> _requestHuaweiReview() async {
    try {
      final ReviewStore used = await _multiStoreReview.requestReview(
        store: ReviewStore.huaweiAppGallery,
      );
      _showSnack('AppGallery review shown by: ${used.name}');
    } catch (e) {
      _showSnack('AppGallery review failed: $e');
    }
  }

  Future<void> _openStoreListing() async {
    try {
      await _multiStoreReview.openStoreListing(
        StoreListing(
          appStoreId: _appStoreId,
          microsoftStoreId: _microsoftStoreId,
        ),
      );
    } catch (e) {
      _showSnack('openStoreListing failed: $e');
    }
  }

  Future<void> _maybeRequestReview() async {
    final bool shown = await _multiStoreReview.maybeRequestReview(
      listing: const StoreListing(
        appStoreId: '1493928622',
        microsoftStoreId: '9NBLGGH42LBS',
      ),
    );
    _showSnack(
      shown ? 'The review gate prompted the user' : 'The review gate waits',
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Store Review Example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Multi Store Review Example')),
        body: Center(
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              Text('Detected store: ${_store?.name ?? 'unavailable'}'),
              const SizedBox(height: 16),
              if (Platform.isIOS || Platform.isMacOS)
                TextField(
                  onChanged: _setAppStoreId,
                  decoration: const InputDecoration(hintText: 'App Store ID'),
                ),
              if (Platform.isWindows)
                TextField(
                  onChanged: _setMicrosoftStoreId,
                  decoration: const InputDecoration(
                    hintText: 'Microsoft Store ID',
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _requestReview,
                child: const Text('Request Review (auto)'),
              ),
              ElevatedButton(
                onPressed: _maybeRequestReview,
                child: const Text('Maybe Request Review (gated)'),
              ),
              if (Platform.isAndroid) ...[
                ElevatedButton(
                  onPressed: _requestHuaweiReview,
                  child: const Text('Request Review (AppGallery)'),
                ),
              ],
              ElevatedButton(
                onPressed: _openStoreListing,
                child: const Text('Open Store Listing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
