# Site Soft Delete Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add site soft-delete sync support and preserve recycle-bin site metadata so deleted-site account restores can recreate the site when needed.

**Architecture:** Extend the database schema with `sites.is_delete` and `account_recycle_bin.site_name`, then thread those fields through repository fetch/delete/restore/export/import flows. Keep normal UI reads filtered to active sites while allowing sync and recycle-bin flows to work with deleted site records.

**Tech Stack:** Flutter, Dart, sqflite/sqflite_common_ffi, flutter_test

---

### Task 1: Add failing tests for site soft delete and recycle metadata

**Files:**
- Modify: `C:\Users\10463\Desktop\project\password_app\test\repositories\password_repository_test.dart`

- [ ] **Step 1: Write the failing tests**
- [ ] **Step 2: Run targeted tests to verify they fail for the expected reasons**
- [ ] **Step 3: Implement the minimal production changes needed to satisfy each failing test**
- [ ] **Step 4: Re-run targeted tests to verify they pass**

### Task 2: Migrate schema and repository logic

**Files:**
- Modify: `C:\Users\10463\Desktop\project\password_app\lib\services\database_service.dart`
- Modify: `C:\Users\10463\Desktop\project\password_app\lib\repositories\password_repository.dart`
- Modify: `C:\Users\10463\Desktop\project\password_app\lib\models\app_models.dart`

- [ ] **Step 1: Add schema version bump and migrations for `sites.is_delete` and `account_recycle_bin.site_name`**
- [ ] **Step 2: Update repository delete/fetch/export/import/restore flows to use the new fields**
- [ ] **Step 3: Keep public read paths filtered to active sites while restoring from recycle metadata when the site is missing**
- [ ] **Step 4: Re-run repository tests and fix any regressions**

### Task 3: Verify behavior end to end at the repository layer

**Files:**
- Test: `C:\Users\10463\Desktop\project\password_app\test\repositories\password_repository_test.dart`

- [ ] **Step 1: Run the focused repository test file**
- [ ] **Step 2: Run broader Flutter verification that is feasible in this workspace**
- [ ] **Step 3: Summarize exact verification results before claiming completion**
