import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platemate/ui/screens/auth_screen.dart';

void main() {
  testWidgets('AuthScreen renders email form and Continue with Google button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app logo and titles are present
    expect(find.text('PlateMate'), findsOneWidget);
    expect(find.text('Your Meal Planning & Shopping Assistant'), findsOneWidget);

    // Verify email and password text fields are present
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify "OR" divider text is present
    expect(find.text('OR'), findsOneWidget);

    // Verify "Continue with Google" button is present
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
