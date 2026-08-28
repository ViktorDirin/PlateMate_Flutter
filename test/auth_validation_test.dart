import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Validation Tests', () {
    // Relaxed validation regex pattern matching auth_screen.dart
    final emailRegex = RegExp(r'^[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    test('Should validate normal email formats successfully', () {
      expect(emailRegex.hasMatch('test@example.com'), isTrue);
      expect(emailRegex.hasMatch('john.doe@domain.co.uk'), isTrue);
      expect(emailRegex.hasMatch('user-name@domain.org'), isTrue);
    });

    test('Should validate email aliases with plus signs successfully', () {
      expect(emailRegex.hasMatch('vdirin+1@gmail.com'), isTrue);
      expect(emailRegex.hasMatch('tester+alias-123@sub.domain.org'), isTrue);
      expect(emailRegex.hasMatch('first.last+testing@company.net'), isTrue);
    });

    test('Should invalidate malformed email formats', () {
      expect(emailRegex.hasMatch('invalid-email'), isFalse);
      expect(emailRegex.hasMatch('test@'), isFalse);
      expect(emailRegex.hasMatch('test@domain'), isFalse);
      expect(emailRegex.hasMatch('@domain.com'), isFalse);
    });
  });
}
