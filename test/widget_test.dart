import 'package:flutter_test/flutter_test.dart';
import 'package:covoiturage_etudiant/main.dart';

void main() {
  testWidgets('App loads login page smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CovoiturageApp());

    // Verify that login screen text is present.
    expect(find.text('Covoiturage Étudiant'), findsWidgets);
  });
}
