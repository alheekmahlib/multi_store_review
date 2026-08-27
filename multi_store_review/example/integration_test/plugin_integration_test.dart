import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:multi_store_review/multi_store_review.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('detectStore answers without crashing',
      (WidgetTester tester) async {
    final MultiStoreReview plugin = MultiStoreReview.instance;

    // The result depends on the host running the test (device, emulator or
    // desktop); all we assert is that the call completes without throwing.
    final ReviewStore? store = await plugin.detectStore();
    expect(ReviewStore.fromName(store?.name), store);
  });
}
