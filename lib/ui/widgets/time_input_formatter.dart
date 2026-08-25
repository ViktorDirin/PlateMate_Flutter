import 'package:flutter/services.dart';

class TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Allow only digits and colon
    final cleaned = text.replaceAll(RegExp(r'[^0-9:]'), '');
    
    // If they are deleting, just let them delete
    if (newValue.text.length < oldValue.text.length) {
      return TextEditingValue(
        text: cleaned,
        selection: newValue.selection,
      );
    }

    // Parse digits
    final digits = cleaned.replaceAll(':', '');
    if (digits.length > 4) {
      return oldValue; // Limit to 4 digits (HHMM)
    }

    String formatted = cleaned;
    if (digits.length == 3) {
      // e.g. "930" -> "9:30" or "09:30"
      formatted = '${digits.substring(0, 1)}:${digits.substring(1)}';
    } else if (digits.length == 4) {
      // e.g. "1915" -> "19:15"
      formatted = '${digits.substring(0, 2)}:${digits.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Normalizes a raw string input to 'HH:MM' when submitted.
  static String normalizeTime(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '00:00';

    if (digits.length == 1) {
      return '0$digits:00';
    } else if (digits.length == 2) {
      int hours = int.tryParse(digits) ?? 0;
      if (hours >= 24) hours = 23;
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:00';
    } else if (digits.length == 3) {
      int hours = int.tryParse(digits.substring(0, 1)) ?? 0;
      int minutes = int.tryParse(digits.substring(1)) ?? 0;
      if (minutes >= 60) minutes = 59;
      final hh = hours.toString().padLeft(2, '0');
      final mm = minutes.toString().padLeft(2, '0');
      return '$hh:$mm';
    } else {
      int hours = int.tryParse(digits.substring(0, 2)) ?? 0;
      int minutes = int.tryParse(digits.substring(2, 4)) ?? 0;
      if (hours >= 24) hours = 23;
      if (minutes >= 60) minutes = 59;
      final hh = hours.toString().padLeft(2, '0');
      final mm = minutes.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
  }
}
