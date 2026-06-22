import 'package:flutter_test/flutter_test.dart';
import 'package:password_app/services/password_generator_service.dart';

void main() {
  group('PasswordGeneratorService', () {
    final service = PasswordGeneratorService();

    test(
      'generates the requested number of passwords with the requested length',
      () {
        final result = service.generateBatch(
          const PasswordGeneratorOptions(length: 16, count: 10),
        );

        expect(result, hasLength(10));
        expect(result.every((password) => password.length == 16), isTrue);
      },
    );

    test('uses only enabled character categories', () {
      final result = service.generateBatch(
        const PasswordGeneratorOptions(
          length: 12,
          count: 5,
          includeUppercase: false,
          includeDigits: false,
          includeSymbols: false,
        ),
      );

      expect(
        result.every((password) => RegExp(r'^[a-z]+$').hasMatch(password)),
        isTrue,
      );
    });

    test('keeps a fixed symbol share when symbols are enabled', () {
      final result = service.generateBatch(
        const PasswordGeneratorOptions(length: 10, count: 1),
      );

      final symbolCount = result.single
          .split('')
          .where(PasswordGeneratorService.symbolChars.contains)
          .length;

      expect(symbolCount, 2);
    });

    test('throws when every category is disabled', () {
      expect(
        () => service.generateBatch(
          const PasswordGeneratorOptions(
            includeUppercase: false,
            includeLowercase: false,
            includeDigits: false,
            includeSymbols: false,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
