# Memo Page Design

**Goal:** Add a memo page that lets users create, browse, view, edit, and delete memo content inside the existing app shell.

**Scope**
- Add a new app section named `备忘录`.
- Store memos in a dedicated local database table.
- Show memo count and an add button at the top of the page.
- Show memo preview cards in the main list.
- Open a dialog to view full content and edit it.
- Allow deleting memos from the list.

**Architecture**
- Keep the feature inside the existing `PasswordRepository` so the app continues to use one repository object from `main.dart` through `DashboardScreen`.
- Extend the shared model file with memo entities instead of creating a parallel data layer.
- Add one focused page for the memo UI and one focused dialog widget for create/edit interactions.

**Data Model**
- Table: `memos`
- Columns:
  - `id INTEGER PRIMARY KEY AUTOINCREMENT`
  - `content TEXT NOT NULL`
  - `updated_at TEXT NOT NULL`

`updated_at` is added even though the minimum requirement only mentioned `id` and `content`, because it gives stable sorting by latest change and matches the rest of the repository style.

**User Flow**
1. User enters the memo page from the side navigation.
2. The page loads all memos ordered by `updated_at DESC, id DESC`.
3. The top area shows memo count and an add button.
4. The list shows a short content preview for each memo.
5. Clicking `查看` opens a dialog with the full content in a multiline text field.
6. The same dialog supports editing and saving.
7. Clicking `删除` removes the memo and refreshes the list.

**UI Structure**
- Reuse the current rounded container page shell used by other pages.
- Top toolbar:
  - count metric
  - add button
- Main content:
  - empty state when there are no memos
  - card list when memos exist
- Each card:
  - preview text
  - last updated text
  - `查看` button
  - `删除` button

**Error Handling**
- Use the same submit-state pattern as the password page to disable actions while saving/deleting.
- Show a `SnackBar` after create, update, and delete.
- Keep the dialog open only on successful save.

**Testing**
- Prefer repository-level tests for CRUD behavior and ordering.
- Do not run `flutter test` for this task because the user explicitly asked to avoid it.
- Use syntax/static verification before completion.

