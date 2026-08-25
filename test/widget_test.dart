import 'package:flutter_test/flutter_test.dart';
import 'package:platemate/ui/widgets/time_input_formatter.dart';
import 'package:platemate/models/diet_plan.dart';

void main() {
  group('TimeInputFormatter Normalization Tests', () {
    test('Should normalize single digits to hours', () {
      expect(TimeInputFormatter.normalizeTime('9'), '09:00');
    });

    test('Should normalize two digits to hours', () {
      expect(TimeInputFormatter.normalizeTime('12'), '12:00');
      expect(TimeInputFormatter.normalizeTime('25'), '23:00'); // Clamped
    });

    test('Should normalize three digits (HHMM)', () {
      expect(TimeInputFormatter.normalizeTime('930'), '09:30');
      expect(TimeInputFormatter.normalizeTime('815'), '08:15');
    });

    test('Should normalize four digits (HHMM)', () {
      expect(TimeInputFormatter.normalizeTime('1915'), '19:15');
      expect(TimeInputFormatter.normalizeTime('2359'), '23:59');
      expect(TimeInputFormatter.normalizeTime('2570'), '23:59'); // Clamped
    });
  });

  group('Ingredient Model Tests', () {
    test('Should serialize and deserialize correctly', () {
      final ing = Ingredient(name: 'Tomato', quantity: 2, unit: 'pcs');
      final json = ing.toJson();
      
      expect(json['name'], 'Tomato');
      expect(json['quantity'], 2.0);
      expect(json['unit'], 'pcs');

      final fromJson = Ingredient.fromJson(json);
      expect(fromJson.name, 'Tomato');
      expect(fromJson.quantity, 2.0);
      expect(fromJson.unit, 'pcs');
    });
  });
}
