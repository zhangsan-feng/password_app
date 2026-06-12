# LAN Sync Multicast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace LAN peer discovery in `LanSyncService` with UDP multicast while keeping the existing HTTPS sync endpoints and emulator fallback.

**Architecture:** Keep the secure sync server bound on `0.0.0.0`, add a UDP multicast listener bound on `0.0.0.0` for discovery probes, and answer probes with unicast UDP payloads advertising reachable IPv4 hosts plus sync metadata. Discovery sends a probe, collects UDP responses, deduplicates them, filters self entries, and then reuses the existing HTTPS probe for trust validation.

**Tech Stack:** Flutter, Dart `dart:io` sockets, `flutter_test`

---

### Task 1: Lock down discovery protocol helpers with tests

**Files:**
- Create: `test/services/lan_sync_service_test.dart`
- Modify: `lib/services/lan_sync_service.dart`

- [ ] **Step 1: Write the failing test**

Add tests that verify multicast payload encode/decode, export-path normalization, response de-duplication keys, and self-host filtering from a response payload.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/lan_sync_service_test.dart`
Expected: FAIL because multicast helper APIs do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add small static/internal helper methods and payload model code in `lib/services/lan_sync_service.dart` so the tests can compile and pass without socket behavior yet.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/lan_sync_service_test.dart`
Expected: PASS

### Task 2: Replace mDNS runtime with multicast runtime

**Files:**
- Modify: `lib/services/lan_sync_service.dart`

- [ ] **Step 1: Write the failing test**

Extend tests to cover candidate peer extraction from UDP response payloads and rejection of invalid fingerprint, invalid port, and non-private IPv4 addresses.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/lan_sync_service_test.dart`
Expected: FAIL because multicast response parsing is incomplete.

- [ ] **Step 3: Write minimal implementation**

Remove `Bonsoir`-based discovery and broadcast code, add UDP multicast listener lifecycle, probe sending, response handling, and candidate extraction that feeds existing `_probePeer`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/lan_sync_service_test.dart`
Expected: PASS

### Task 3: Verify the integrated service behavior

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/services/lan_sync_service.dart`

- [ ] **Step 1: Run focused tests**

Run: `flutter test test/services/lan_sync_service_test.dart`
Expected: PASS

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Remove obsolete dependency if no code references remain**

Delete the `bonsoir` dependency from `pubspec.yaml` only after code and analysis confirm no remaining imports/usages.

- [ ] **Step 4: Re-run verification**

Run: `flutter test test/services/lan_sync_service_test.dart`
Run: `flutter analyze`
Expected: PASS and no analyzer issues
