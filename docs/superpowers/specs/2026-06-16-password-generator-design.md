# Password Generator Design

**Date:** 2026-06-16

**Goal:** Add a dedicated password generator page that lets users configure character rules, password length, and batch size, then copy any generated password directly.

## Context

The app currently exposes three top-level sections in the dashboard: passwords, LAN sync, and settings. The new feature should become a fourth top-level section and follow the same visual style as the existing pages. The project also prefers focused files, so the random generation logic should not live directly inside the page widget.

## User Experience

The new page is named `密码生成` and is reachable from the existing side navigation on both desktop and mobile layouts.

The page contains two main areas:

1. A rule configuration card
   - Toggle switches for uppercase letters, lowercase letters, digits, and special characters
   - Numeric inputs for password length and generation count
   - Defaults: length `16`, generation count `10`
   - Validation that at least one character category is enabled

2. A generated password results card
   - Displays the generated passwords as a scrollable list
   - Each row has a copy action
   - A primary action regenerates the whole batch using the current rules
   - Initial page load can immediately show one default batch to reduce empty-state friction

## Generation Rules

The generator uses the approved fixed-ratio approach:

- Special characters target about `20%` of each password
- The remaining `80%` is shared by the enabled non-special groups
- When uppercase, lowercase, and digits are all enabled, they split the non-special portion as evenly as possible
- When only some non-special groups are enabled, only those enabled groups receive the non-special portion
- Characters are assembled by quota first, then shuffled so the final password does not expose a visible pattern

The supported special character set is:

`!@#$%^&*()_+-=[]{}|;:,.<>?`

## Validation And Edge Cases

- If every toggle is disabled, generation is blocked and the page shows a message prompting the user to enable at least one category
- Length input defaults to `16` if the entered value is empty or invalid
- Count input defaults to `10` if the entered value is empty or invalid
- Very short lengths still try to preserve the fixed-ratio intent, but the final allocation must always sum exactly to the requested length
- If special characters are disabled, the full length is distributed only across the enabled non-special groups
- Copy actions show snackbar feedback consistent with the existing password page

## Architecture

The feature should be split into small units:

- `lib/models/app_models.dart`
  - Extend `AppSection` with the new dashboard section

- `lib/services/password_generator_service.dart`
  - Own the password generation rules, quota allocation, shuffling, and defaults
  - Expose lightweight configuration and result models if needed to keep UI code simple

- `lib/pages/password_generator_page.dart`
  - Own page state, controllers, validation, generation triggers, and copy interactions

- `lib/pages/dashboard_screen.dart`
  - Route the new section to the new page and provide the localized title

- `lib/widgets/side_navigation.dart`
  - Add the new navigation item

- `test/services/password_generator_service_test.dart`
  - Cover defaults, fixed-ratio behavior, disabled-category handling, and deterministic structural expectations

## Testing Strategy

The generation algorithm should be validated first through unit tests because it is pure behavior and should remain independent from Flutter widget state.

Planned test coverage:

- Generates the requested number of passwords with the requested length
- Includes only enabled character categories
- Preserves special-character allocation at roughly 20% when special characters are enabled
- Distributes the non-special share across the enabled letter and digit groups
- Rejects configurations with no enabled character groups

UI work can be verified with static analysis plus manual reasoning against the existing page patterns, because the project explicitly avoids `flutter test` runs in this workflow.
