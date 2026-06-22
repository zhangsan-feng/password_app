import 'dart:math';

class PasswordGeneratorOptions {
  const PasswordGeneratorOptions({
    this.includeUppercase = true,
    this.includeLowercase = true,
    this.includeDigits = true,
    this.includeSymbols = true,
    this.length = defaultLength,
    this.count = defaultCount,
  });

  static const int defaultLength = 16;
  static const int defaultCount = 10;
  static const int minLength = 1;
  static const int maxLength = 128;
  static const int minCount = 1;
  static const int maxCount = 50;

  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeDigits;
  final bool includeSymbols;
  final int length;
  final int count;

  PasswordGeneratorOptions normalized() {
    return PasswordGeneratorOptions(
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeDigits: includeDigits,
      includeSymbols: includeSymbols,
      length: length <= 0 ? defaultLength : length.clamp(minLength, maxLength),
      count: count <= 0 ? defaultCount : count.clamp(minCount, maxCount),
    );
  }
}

class PasswordGeneratorService {
  PasswordGeneratorService({Random? random})
    : _random = random ?? Random.secure();

  static const String uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String digitChars = '0123456789';
  static const String symbolChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

  final Random _random;

  List<String> generateBatch(PasswordGeneratorOptions options) {
    final normalized = options.normalized();
    _validateOptions(normalized);

    return List<String>.generate(
      normalized.count,
      (_) => _generateSingle(normalized),
    );
  }

  String _generateSingle(PasswordGeneratorOptions options) {
    final allocations = _buildAllocations(options);
    final characters = <String>[];

    for (final allocation in allocations) {
      for (var i = 0; i < allocation.value; i++) {
        characters.add(_pickCharacter(allocation.key));
      }
    }

    characters.shuffle(_random);
    return characters.join();
  }

  List<MapEntry<_CharacterGroup, int>> _buildAllocations(
    PasswordGeneratorOptions options,
  ) {
    final enabledNonSymbolGroups = <_CharacterGroup>[
      if (options.includeUppercase) _CharacterGroup.uppercase,
      if (options.includeLowercase) _CharacterGroup.lowercase,
      if (options.includeDigits) _CharacterGroup.digits,
    ];

    if (options.includeSymbols && enabledNonSymbolGroups.isEmpty) {
      return [MapEntry(_CharacterGroup.symbols, options.length)];
    }

    var symbolCount = 0;
    if (options.includeSymbols) {
      symbolCount = max(1, (options.length * 0.2).round());
      symbolCount = min(symbolCount, options.length);
    }

    final remaining = options.length - symbolCount;
    final allocations = <MapEntry<_CharacterGroup, int>>[];

    if (remaining > 0 && enabledNonSymbolGroups.isNotEmpty) {
      final baseShare = remaining ~/ enabledNonSymbolGroups.length;
      var remainder = remaining % enabledNonSymbolGroups.length;

      for (final group in enabledNonSymbolGroups) {
        final extra = remainder > 0 ? 1 : 0;
        allocations.add(MapEntry(group, baseShare + extra));
        if (remainder > 0) {
          remainder--;
        }
      }
    }

    if (symbolCount > 0) {
      allocations.add(MapEntry(_CharacterGroup.symbols, symbolCount));
    }

    return allocations;
  }

  String _pickCharacter(_CharacterGroup group) {
    final charset = switch (group) {
      _CharacterGroup.uppercase => uppercaseChars,
      _CharacterGroup.lowercase => lowercaseChars,
      _CharacterGroup.digits => digitChars,
      _CharacterGroup.symbols => symbolChars,
    };
    return charset[_random.nextInt(charset.length)];
  }

  void _validateOptions(PasswordGeneratorOptions options) {
    final hasEnabledGroup =
        options.includeUppercase ||
        options.includeLowercase ||
        options.includeDigits ||
        options.includeSymbols;
    if (!hasEnabledGroup) {
      throw ArgumentError('At least one character group must be enabled.');
    }
  }
}

enum _CharacterGroup { uppercase, lowercase, digits, symbols }
