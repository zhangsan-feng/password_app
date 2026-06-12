# GitHub Actions Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GitHub Actions workflow that runs Flutter tests and builds downloadable Windows and Android APK artifacts for this app.

**Architecture:** Use a single workflow with two jobs. A Linux job will install Flutter, run `flutter pub get`, run tests, build the Android APK, and upload the APK artifact. A Windows job will install Flutter, run `flutter pub get`, build the Windows desktop app, and upload the desktop build directory as an artifact.

**Tech Stack:** GitHub Actions, `subosito/flutter-action`, Flutter SDK, Java 17, Windows and Ubuntu hosted runners

---

### Task 1: Define workflow structure

**Files:**
- Create: `.github/workflows/build.yml`
- Modify: none
- Test: run local inspection on the YAML file contents

- [ ] **Step 1: Create the workflow file with push and pull_request triggers**
- [ ] **Step 2: Add an Ubuntu job for dependency install, tests, APK build, and artifact upload**
- [ ] **Step 3: Add a Windows job for dependency install, Windows build, and artifact upload**

### Task 2: Verify local project assumptions

**Files:**
- Modify: none
- Test: `pubspec.yaml`, `.gitignore`, platform folders

- [ ] **Step 1: Check Flutter project metadata and dependencies for CI prerequisites**
- [ ] **Step 2: Confirm generated local files remain ignored and are not added to the workflow**
- [ ] **Step 3: Run local verification commands that are safe in the current environment**

### Task 3: Prepare git handoff

**Files:**
- Modify: none
- Test: local git state

- [ ] **Step 1: Check whether the directory is already a git repository**
- [ ] **Step 2: If needed, initialize git locally so the workflow file can be committed**
- [ ] **Step 3: Summarize what remains for pushing to GitHub, since remote creation may require authentication and network access**
