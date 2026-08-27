import 'package:flutter_test/flutter_test.dart';
import 'package:multi_store_review_example/main.dart';

void main() {
  testWidgets('example app renders the detected store placeholder',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MultiStoreReviewExampleApp());
    // Let the post-frame detectStore future settle (it falls back to
    // 'unavailable' in the test environment).
    await tester.pump();
    await tester.pump();

    expect(find.text('Multi Store Review Example'), findsOneWidget);
    expect(find.text('Detected store: unavailable'), findsOneWidget);
    expect(find.text('Request Review (auto)'), findsOneWidget);
    expect(find.text('Open Store Listing'), findsOneWidget);
  });
}
