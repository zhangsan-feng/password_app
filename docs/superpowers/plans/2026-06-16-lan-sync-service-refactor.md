# LAN Sync Service Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the oversized LAN sync service into focused files while preserving the existing `LanSyncService` API and behavior.

**Architecture:** Keep `lib/services/lan_sync_service.dart` as the public library entry that owns the models, class fields, constants, and shared state. Move server flow, discovery flow, platform helpers, and pure helper logic into `part` files implemented as non-private extensions or top-level library-private helpers so existing call sites continue to use `LanSyncService` the same way.

**Tech Stack:** Flutter, Dart IO, crypto, sqflite-backed repository integration

---
