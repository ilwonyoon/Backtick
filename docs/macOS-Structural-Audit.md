# macOS Structural Audit

> Generated: 2026-03-09
> Last re-audit: 2026-03-09
> Scope: Full codebase structural analysis from macOS platform perspective

---

## Overview

Prompt Cue is a macOS menu-bar utility (LSUIElement) for capturing and organizing prompt snippets. Built with SwiftUI views hosted in AppKit NSPanels.

Architecture: `AppDelegate` → `AppCoordinator` → `AppModel` (@MainActor ObservableObject). Pure business logic isolated in `PromptCueCore` Swift Package.

---

## Audit Status Summary

| Item | Severity | Status | Notes |
|------|----------|--------|-------|
| C-1 | CRITICAL | RESOLVED | fd closed via DispatchSource cancel handler + deinit |
| C-2 | CRITICAL | RESOLVED | Security-scoped access guarded with state tracking |
| C-3 | CRITICAL | RESOLVED | GRDB `write {}` provides transaction semantics |
| C-4 | CRITICAL | OPEN | removeDismissMonitors() exists but no defensive deinit |
| C-5 | CRITICAL | OPEN | No deinit in CapturePanelRuntimeViewController |
| C-6 | CRITICAL | OPEN | `panel` still strongly captured in completion handler |
| H-1 | HIGH | OPEN | Timer fire handler doesn't check isStarted |
| H-2 | HIGH | RESOLVED | Timer invalidated in stop(); stop() called from coordinator |
| H-3 | HIGH | RESOLVED | Immutable patterns used throughout AppModel |
| H-4 | HIGH | RESOLVED | Configurable 0.25s interval with guard |
| H-5 | HIGH | OPEN | Accessibility nearly absent across UI layer |
| M-1 | MEDIUM | OPEN | Shadow modifiers hardcode values instead of tokens |
| M-2 | MEDIUM | OPEN | SearchFieldSurface 6+ overlays in light mode |
| M-3 | MEDIUM | OPEN | 21 color conditionals per frame in CaptureCardView |
| M-4 | MEDIUM | OPEN | windowDidChangeScreen not implemented |
| M-5 | MEDIUM | OPEN | constrainFrameRect bypass (intentional for animation) |
| M-6 | MEDIUM | OPEN | Stale bookmark not refreshed to UserDefaults |
| M-7 | MEDIUM | RESOLVED | ExportSuffix normalization + edge case tests added |
| M-8 | MEDIUM | RESOLVED | Ordering semantics clarified with clear sort hierarchy |
| L-1 | LOW | OPEN | statusItem not set to nil in stop() |
| L-2 | LOW | OPEN | Event monitor type Any? instead of NSObjectProtocol? |
| L-3 | LOW | OPEN | UserDefaults keys not namespaced |
| L-4 | LOW | OPEN | DispatchQueue.main.asyncAfter in @MainActor |
| L-5 | LOW | OPEN | CaptureCard JSON codec round-trip test missing |

**Resolved: 8 / 24 — Remaining: 16 (3 Critical, 2 High, 6 Medium, 5 Low)**

---

## CRITICAL — Immediate Fix Required

### ~~C-1. File Descriptor Leak in RecentScreenshotFileWatcher~~ RESOLVED

fd is now properly closed via `DispatchSource.setCancelHandler` with `deinit { source?.cancel() }` ensuring cleanup on deallocation.

---

### ~~C-2. Security-Scoped Resource Guard Missing~~ RESOLVED

`startAccessingSecurityScopedResource()` return value tracked in `isAccessingAuthorizedDirectory`. Access properly released in `stop()` and before re-acquisition.

---

### ~~C-3. Database Save Not Atomic~~ RESOLVED

Save now uses GRDB's `dbQueue.write { }` which wraps `deleteAll` + insert loop in an implicit transaction with rollback on failure.

---

### C-4. Missing deinit — NSEvent Global Monitor Leak

**Location:** `CapturePanelController` and `StackPanelController`

`removeDismissMonitors()` exists and is called in `close()`, but neither controller implements `deinit`. If deallocated without `close()` being called, global event monitors persist indefinitely.

**Fix:** Add `deinit { removeDismissMonitors() }` to both controllers.

---

### C-5. Combine Subscriptions Not Cleaned on Dealloc

**Location:** `CapturePanelRuntimeViewController` — `cancellables: Set<AnyCancellable>`

Three Combine subscriptions stored in `cancellables` with no `deinit` cleanup. Also `imageLoadTask` not cancelled on dealloc.

**Fix:** Add `deinit { cancellables.removeAll(); imageLoadTask?.cancel() }`.

---

### C-6. Unsafe Panel Reference in Animation Completion

**Location:** `StackPanelController.swift:67-76`

Completion handler captures `[weak self]` but accesses `panel` as a strong local variable. If controller deallocates mid-animation, `panel` could be a dangling reference.

**Fix:** Capture `[weak self, weak panel]` in completion handler.

---

## HIGH — Priority Improvement

### H-1. Timer Race Condition After stop()

**Location:** `RecentScreenshotCoordinator.swift`

Timer fire handler validates `self` via `[weak self]` but doesn't explicitly check `isStarted`. After `stop()`, pending timer firings can still call `refreshState()`.

**Fix:** Add `guard isStarted else { timer.invalidate(); return }` inside timer callback.

---

### ~~H-2. AppModel Timer Not Invalidated in deinit~~ RESOLVED

Timer properly invalidated in `stop()`, which is called from `AppCoordinator.stop()`. Lifecycle management is sound.

---

### ~~H-3. Session Struct Mutation Violates Immutability~~ RESOLVED

AppModel now uses immutable patterns throughout — `markCopied()` returns new instances, mutations create new objects via constructors.

---

### ~~H-4. Clipboard Polling Performance~~ RESOLVED

Polling interval is configurable (default 0.25s) with guard against invalid intervals. Acceptable for current use case.

---

### H-5. Accessibility Nearly Absent

**Location:** Entire UI layer

Only 2 `.accessibilityLabel()` calls in the entire codebase. No Dynamic Type support, no VoiceOver semantic grouping, no `.accessibilityHint()`, no keyboard navigation hints.

**Scope:** All interactive elements in `CaptureComposerView`, `CardStackView`, `CaptureCardView` need labels and traits.

---

## MEDIUM — Planned Improvement

### M-1. Shadow Modifiers Ignore Token Values

**Location:** `PromptCueShadowModifiers.swift:19-62`

`promptCueGlassShadow()` and `promptCuePanelShadow()` hardcode radius/y values instead of using `PrimitiveTokens.Shadow.*`. Token changes won't propagate.

---

### M-2. SearchFieldSurface Render Complexity

**Location:** `SearchFieldSurface.swift:33-140`

Light mode quiet style uses 6 overlays (material + fill + gradient + 3 masked strokes). Each overlay creates a layout pass. Problematic if used in scrolling contexts.

---

### M-3. CaptureCardView — 21 Color Conditionals Per Frame

**Location:** `CaptureCardView.swift:89-183`

Five computed properties with 21 total conditional branches for color selection, recomputed every frame. Should extract to a state-based style enum.

---

### M-4. No windowDidChangeScreen Handling

**Location:** `CapturePanelController`, `StackPanelController`

Neither controller implements `windowDidChangeScreen(_:)`. Panels don't reposition when external monitors connect/disconnect or when switching Spaces.

---

### M-5. StackPanel constrainFrameRect Bypass

**Location:** `StackPanelController.swift` (StackPanel subclass)

`constrainFrameRect(_:to:)` returns `frameRect` unchanged, disabling macOS screen boundary enforcement. Intentional for off-screen animation, but panel can end up off-screen permanently.

---

### M-6. Stale Bookmark Not Refreshed

**Location:** `ScreenshotDirectoryResolver.swift`

When security-scoped bookmark is detected as stale, the resolved URL is returned but fresh bookmark data is never written back to UserDefaults. Staleness accumulates over time.

---

### ~~M-7. ExportFormatter Edge Cases Unhandled~~ RESOLVED

`ExportSuffix` now normalizes newlines (`\r\n` → `\n`), trims whitespace, and handles empty/blank suffix. Tests cover blank suffix, normalization, and multi-card formatting.

---

### ~~M-8. CardStackOrdering Semantic Ambiguity~~ RESOLVED

Sort hierarchy is now clear: copied cards go to bottom section, sorted by `lastCopiedAt` descending. Active cards sorted by `sortOrder` → `createdAt` → `id`. Tests verify both sections.

---

## LOW — Backlog

### L-1. NSStatusItem Not Cleaned in stop()

**Location:** `AppCoordinator.swift`

`statusItem` should be set to `nil` in `stop()` for explicit cleanup. Currently persists after stop.

### L-2. Event Monitor Type Erasure

**Location:** `CapturePanelController`, `StackPanelController`

`localMouseMonitor: Any?` → should be `NSObjectProtocol?` for type safety and auditability.

### L-3. UserDefaults Keys Not Namespaced

**Location:** `ScreenshotDirectoryResolver.swift`

Key `"preferredScreenshotDirectoryBookmarkData"` lacks `com.promptcue.` prefix. Low collision risk but violates naming convention.

### L-4. DispatchQueue.main.asyncAfter in @MainActor

**Location:** `AppCoordinator.swift`

Redundant — already on main thread. Could use `Task.sleep` for consistency with structured concurrency.

### L-5. CaptureCard JSON Codec Round-Trip Test Missing

**Location:** `Tests/PromptCueCoreTests/`

Custom `encode(to:)`/`init(from:)` on `CaptureCard` has no isolated codec test. Only tested indirectly through `CardStore` database round-trip.

---

## Strengths

- **@MainActor consistency** across entire app target for thread safety
- **Explicit lifecycle management** via `start()`/`stop()` pattern on all major components
- **Pure logic separation** — `PromptCueCore` package has zero platform dependencies
- **Immutable domain models** — `CaptureCard.markCopied()` etc. return new instances
- **Protocol-driven testability** — `RecentScreenshotCoordinating`, `AttachmentStoring`, etc.
- **Two-layer design token system** — Primitive → Semantic, adaptive light/dark
- **Test quality** — state machine coverage, boundary value testing, proper @MainActor test isolation
- **Consistent weak self captures** across all closure-heavy code
- **Lazy window controller initialization** — correct for app-lifetime objects
- **Configurable settings architecture** — new CardRetention and ExportTail models follow @MainActor + ObservableObject pattern consistently

---

## Recommended Priority Order

1. **Stability** (C-4, C-5, C-6): deinit cleanup, Combine subscriptions, animation safety
2. **Quality** (H-1, H-5): Timer race guard, accessibility
3. **Maintainability** (M-1 through M-6): Token consistency, render performance, screen handling
4. **Cleanup** (L-1 through L-5): Conventions, type safety, minor improvements
