# Password Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a top-level password generator page with configurable rules, batch generation, and per-item copy actions, then update `project.md` to document the new structure.

**Architecture:** Keep dashboard routing and navigation changes minimal, add a focused generator page for UI state, and isolate password generation logic in a dedicated service so rule allocation remains testable and independent from Flutter widgets.

**Tech Stack:** Flutter, Dart, flutter_test

---

### Task 1: Add generator service tests and implementation

**Files:**
- Create: `test/services/password_generator_service_test.dart`
- Create: `lib/services/password_generator_service.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:password_app/services/password_generator_service.dart';

void main() {
  group('PasswordGeneratorService', () {
    final service = PasswordGeneratorService();

    test('generates the requested number of passwords with the requested length', () {
      final result = service.generateBatch(
        const PasswordGeneratorOptions(length: 16, count: 10),
      );

      expect(result, hasLength(10));
      expect(result.every((password) => password.length == 16), isTrue);
    });

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
```

- [ ] **Step 2: Verify the tests are red**

Run: `flutter test test/services/password_generator_service_test.dart`
Expected: FAIL because `PasswordGeneratorService` does not exist yet

- [ ] **Step 3: Write the minimal implementation**

```dart
class PasswordGeneratorOptions {
  const PasswordGeneratorOptions({
    this.includeUppercase = true,
    this.includeLowercase = true,
    this.includeDigits = true,
    this.includeSymbols = true,
    this.length = 16,
    this.count = 10,
  });
}

class PasswordGeneratorService {
  List<String> generateBatch(PasswordGeneratorOptions options) {
    return <String>[];
  }
}
```

- [ ] **Step 4: Complete the service behavior**

```dart
class PasswordGeneratorService {
  List<String> generateBatch(PasswordGeneratorOptions options) {
    // validate enabled groups
    // compute 20% symbol share when enabled
    // distribute remaining characters across enabled non-symbol groups
    // shuffle final character order
  }
}
```

- [ ] **Step 5: Verify the tests are green**

Run: `flutter test test/services/password_generator_service_test.dart`
Expected: PASS

### Task 2: Add the password generator page and wire it into navigation

**Files:**
- Modify: `lib/models/app_models.dart`
- Create: `lib/pages/password_generator_page.dart`
- Modify: `lib/pages/dashboard_screen.dart`
- Modify: `lib/widgets/side_navigation.dart`

- [ ] **Step 1: Add the new app section**

```dart
enum AppSection { passwords, generator, sync, settings }
```

- [ ] **Step 2: Build the page widget**

```dart
class PasswordGeneratorPage extends StatefulWidget {
  const PasswordGeneratorPage({super.key});
}
```

- [ ] **Step 3: Add controls and generation flow**

```dart
Future<void> _generatePasswords() async {
  final passwords = _service.generateBatch(_buildOptions());
  setState(() {
    _generatedPasswords = passwords;
  });
}
```

- [ ] **Step 4: Add copy actions**

```dart
Future<void> _copyPassword(String password) async {
  await Clipboard.setData(ClipboardData(text: password));
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('密码已复制')),
  );
}
```

- [ ] **Step 5: Route the page from the dashboard and navigation**

```dart
case AppSection.generator:
  return const PasswordGeneratorPage();
```

### Task 3: Verify syntax and update project documentation

**Files:**
- Modify: `project.md`

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: PASS with no errors in the new generator files

- [ ] **Step 2: Update the project structure document**

```text
pages/
    password_generator_page.dart/
        PasswordGeneratorPage
            build()
                负责创建密码生成页面状态组件
```

- [ ] **Step 3: Confirm the document reflects the new navigation and service**

```text
services/
    password_generator_service.dart/
        PasswordGeneratorOptions
        PasswordGeneratorService
```
