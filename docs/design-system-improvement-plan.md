# Design System Improvement Plan

> **Date**: 2026-03-09
> **Branch**: `design-system-improvement`
> **Goals**: macOS native look & feel / custom identity / zero hardcoded values / reusable components

---

## 1. Current State Assessment

### Architecture (2-layer token system)

```
PrimitiveTokens.swift (132 lines)     SemanticTokens.swift (144 lines)
├── FontSize (5)                      ├── MaterialStyle (3)
├── LineHeight (4)                    ├── Surface (16)
├── Space (8)                         ├── Text (4)
├── Radius (4)                        ├── Border (6)
├── Size (14)                         ├── Accent (2)
├── Stroke (2)                        └── Shadow (6)
├── Icon (4)
├── Opacity (8)                       AppUIConstants.swift (30 lines)
├── Motion (2)                        └── Layout dimensions (20+)
├── Shadow (16)
└── Typography (12)                   PromptCueShadowModifiers.swift (63 lines)
                                      └── 6 shadow view modifiers
```

### Strengths

- **High compliance**: 32/32 UI files pass `validate_ui_tokens.py`
- **Light/dark mode**: `adaptiveColor(light:dark:)` handles NSAppearance correctly
- **Shadow centralization**: All shadows via 6 named modifiers
- **System color usage**: `NSColor.controlAccentColor`, `.labelColor`, `.controlBackgroundColor` as bases
- **Material hierarchy**: thinMaterial → regularMaterial → thickMaterial progression

### Weaknesses Found

| Issue | Location | Severity |
|-------|----------|----------|
| Typography literals `14`, `24` bypass `FontSize` | `PrimitiveTokens.swift:128-130` | Medium |
| No Component Token layer | Views reference SemanticTokens directly | Medium |
| Missing interactive state tokens (hover/pressed) | `SemanticTokens.swift` | Medium |
| Hardcoded shade opacities (0.02, 0.04, 0.05, 0.14, 0.22, 0.26) | `CardStackView.swift` | Low |
| Hardcoded chrome overlay (0.015) | `StackNotificationCardSurface.swift` | Low |
| Hardcoded glassHighlight opacity (0.18) | `CardSurface.swift:74` | Low |
| NSColor/CALayer values outside token system | `CapturePanelRuntimeViewController.swift:333-386` | Low |
| Radius scale lacks small values (4, 6, 8) | `PrimitiveTokens.Radius` starts at 12 | Low |
| No semantic typography layer | Typography only in PrimitiveTokens | Low |
| `AppUIConstants` mixes tokens with layout constants | `AppUIConstants.swift` | Low |

---

## 2. Target Architecture (3-layer)

```
DesignSystem/
├── PrimitiveTokens.swift              ← expand (radius, font sizes)
├── SemanticTokens.swift               ← expand (interactive states, typography)
├── ComponentTokens.swift              ← NEW: per-component token bundles
├── AppKitTokens.swift                 ← NEW: NSColor/CALayer bridge
├── ViewModifiers/
│   ├── PromptCueShadowModifiers.swift ← existing
│   ├── CardStyleModifier.swift        ← NEW
│   └── InteractiveModifier.swift      ← NEW
└── DesignSystemPreviewTokens.swift    ← existing
```

---

## 3. Execution Phases

### Phase 1: Token Foundation (zero visual change)

> Expand primitive + semantic layers. All changes are additive — existing tokens untouched.

**1A. PrimitiveTokens — fill gaps**

```swift
// Radius: add small values for native-feel inline controls
enum Radius {
    static let xs: CGFloat = 4    // NEW — menu item highlights
    static let button: CGFloat = 6 // NEW — buttons, chips inline
    static let field: CGFloat = 8  // NEW — text fields, search
    static let sm: CGFloat = 12   // existing
    static let md: CGFloat = 18   // existing
    static let lg: CGFloat = 26   // existing
    static let xl: CGFloat = 30   // existing
}

// FontSize: add missing sizes used in Typography
enum FontSize {
    static let accessory: CGFloat = 14  // NEW — replaces literal in Typography
    static let emptyIcon: CGFloat = 24  // NEW — replaces literal in Typography
    // ... existing unchanged
}
```

**1B. Fix Typography literals**

```swift
// Before
static let accessoryIcon = Font.system(size: 14, weight: .semibold)
static let emptyStateIcon = Font.system(size: 24, weight: .medium)

// After
static let accessoryIcon = Font.system(size: FontSize.accessory, weight: .semibold)
static let emptyStateIcon = Font.system(size: FontSize.emptyIcon, weight: .medium)
```

**1C. SemanticTokens — add interactive states**

```swift
enum Surface {
    // ... existing

    // NEW: interactive states
    static let cardHover = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.03),
        dark: NSColor.white.withAlphaComponent(0.04)
    )
    static let cardPressed = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.06),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    static let notificationChrome = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.015),
        dark: NSColor.clear
    )
    static let stackedShadeLight = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.02),
        dark: NSColor.white.withAlphaComponent(0.14)
    )
    static let stackedShadeMedium = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.04),
        dark: NSColor.white.withAlphaComponent(0.22)
    )
    static let stackedShadeDeep = adaptiveColor(
        light: NSColor.black.withAlphaComponent(0.05),
        dark: NSColor.white.withAlphaComponent(0.26)
    )
}

enum Border {
    // ... existing

    // NEW
    static let focused = Accent.primary.opacity(PrimitiveTokens.Opacity.soft)
}
```

**1D. SemanticTokens — add semantic typography**

```swift
enum TextStyle {
    static let cardTitle = PrimitiveTokens.Typography.bodyStrong
    static let cardBody = PrimitiveTokens.Typography.body
    static let cardMeta = PrimitiveTokens.Typography.meta
    static let panelHeader = PrimitiveTokens.Typography.panelTitle
    static let chipLabel = PrimitiveTokens.Typography.chip
    static let captureInput = PrimitiveTokens.Typography.captureInput
    static let emptyState = PrimitiveTokens.Typography.iconLabel
}
```

**Files changed**: `PrimitiveTokens.swift`, `SemanticTokens.swift`
**Verification**: `swift test` + `xcodegen generate` + `xcodebuild build`

---

### Phase 2: Component Tokens (zero visual change)

> Introduce per-component token bundles. Views switch from `SemanticTokens.X.y` to `ComponentTokens.Card.background`.

**2A. Create `ComponentTokens.swift`**

```swift
enum ComponentTokens {

    enum Card {
        static let background = SemanticTokens.Surface.cardFill
        static let backgroundSelected = SemanticTokens.Surface.accentFill
        static let border = SemanticTokens.Border.subtle
        static let borderSelected = SemanticTokens.Border.emphasis
        static let cornerRadius = PrimitiveTokens.Radius.md
        static let padding = PrimitiveTokens.Size.cardPadding
        static let strokeDefault = PrimitiveTokens.Stroke.subtle
        static let strokeSelected = PrimitiveTokens.Stroke.emphasis
    }

    enum NotificationCard {
        static let background = SemanticTokens.Surface.notificationCardFill
        static let backgroundHover = SemanticTokens.Surface.notificationCardHoverFill
        static let backdrop = SemanticTokens.Surface.notificationCardBackdrop
        static let border = SemanticTokens.Border.notificationCard
        static let borderHover = SemanticTokens.Border.notificationCardHover
        static let cornerRadius = PrimitiveTokens.Radius.md
        static let padding = PrimitiveTokens.Size.notificationCardPadding
        static let chrome = SemanticTokens.Surface.notificationChrome // after Phase 1C
    }

    enum SearchField {
        static let cornerRadius = PrimitiveTokens.Radius.md
        static let height = PrimitiveTokens.Size.searchFieldHeight
        static let padding = PrimitiveTokens.Size.panelPadding
    }

    enum Chip {
        static let height = PrimitiveTokens.Size.chipHeight
        static let cornerRadius = PrimitiveTokens.Radius.sm
        static let font = PrimitiveTokens.Typography.chip
    }

    enum Panel {
        static let background = SemanticTokens.Surface.panelFill
        static let material = SemanticTokens.MaterialStyle.floatingShell
        static let padding = PrimitiveTokens.Size.panelPadding
        static let cornerRadius = PrimitiveTokens.Radius.lg
    }

    enum GlassPanel {
        static let material = SemanticTokens.MaterialStyle.elevatedGlass
        static let tint = SemanticTokens.Surface.glassTint
        static let sheen = SemanticTokens.Surface.glassSheen
        static let borderHighlight = SemanticTokens.Border.glassHighlight
        static let borderInner = SemanticTokens.Border.glassInner
        static let cornerRadius = PrimitiveTokens.Radius.lg
    }
}
```

**2B. Migrate views to ComponentTokens**

Replace direct `SemanticTokens`/`PrimitiveTokens` references in component views:

| File | Before | After |
|------|--------|-------|
| `CardSurface.swift:28` | `PrimitiveTokens.Radius.md` | `ComponentTokens.Card.cornerRadius` |
| `CardSurface.swift:102` | `PrimitiveTokens.Size.cardPadding` | `ComponentTokens.Card.padding` |
| `CardSurface.swift:115` | `SemanticTokens.Surface.cardFill` | `ComponentTokens.Card.background` |
| `SearchFieldSurface.swift` | scattered token refs | `ComponentTokens.SearchField.*` |
| `PromptCueChip.swift` | scattered token refs | `ComponentTokens.Chip.*` |
| `GlassPanel.swift` | scattered token refs | `ComponentTokens.GlassPanel.*` |

**Files changed**: New `ComponentTokens.swift`, + 5-6 component views
**Verification**: `swift test` + `xcodebuild build` + visual spot-check

---

### Phase 3: Hardcoded Value Cleanup (minimal visual change)

> Tokenize remaining hardcoded values.

**3A. `CardStackView.swift` — stacked shade opacities**

Replace inline `Color.black.opacity(0.02/0.04/0.05)` with `SemanticTokens.Surface.stackedShade*` (added in Phase 1C).

**3B. `StackNotificationCardSurface.swift` — chrome overlay**

Replace `Color.black.opacity(0.015)` with `SemanticTokens.Surface.notificationChrome`.

**3C. `CardSurface.swift:74` — glassHighlight opacity**

Replace `.opacity(0.18)` with a semantic token or primitive opacity value.

**3D. `CapturePanelRuntimeViewController.swift` — AppKit bridge**

Create `AppKitTokens.swift` to bridge NSColor/CALayer values:

```swift
enum AppKitTokens {
    enum Layer {
        static func panelBorder(for appearance: NSAppearance) -> CGColor {
            // adaptive NSColor → CGColor
        }
        static func panelBackground(for appearance: NSAppearance) -> CGColor { ... }
        static func panelShadow(for appearance: NSAppearance) -> (color: CGColor, opacity: Float, radius: CGFloat, offset: CGSize) { ... }
    }
}
```

**3E. Update validation script**

Add rules for:
- `Color.black.opacity(` / `Color.white.opacity(` in non-design-system files
- `NSColor` hardcoded values in ViewController files

**Files changed**: `CardStackView.swift`, `StackNotificationCardSurface.swift`, `CardSurface.swift`, `CapturePanelRuntimeViewController.swift`, new `AppKitTokens.swift`, `validate_ui_tokens.py`
**Verification**: `python3 scripts/validate_ui_tokens.py --all` + `xcodebuild build`

---

### Phase 4: Reusable Modifiers (zero visual change)

> Extract common styling patterns into composable ViewModifiers.

**4A. `CardStyleModifier`**

```swift
struct CardStyleModifier: ViewModifier {
    let isSelected: Bool
    let style: CardSurfaceStyle

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(shape)
            .overlay { shape.stroke(borderColor, lineWidth: strokeWidth) }
            .shadow(...)
    }
}

extension View {
    func cardStyle(isSelected: Bool = false, style: CardSurfaceStyle = .standard) -> some View {
        modifier(CardStyleModifier(isSelected: isSelected, style: style))
    }
}
```

**4B. `InteractiveModifier`**

```swift
struct InteractiveModifier: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .background(interactiveBackground)
            .onHover { isHovered = $0 }
            .simultaneousGesture(...)
            .animation(PrimitiveTokens.Motion.quick, value: isHovered)
    }

    private var interactiveBackground: Color {
        if isPressed { return SemanticTokens.Surface.cardPressed }
        if isHovered { return SemanticTokens.Surface.cardHover }
        return .clear
    }
}
```

**Files changed**: New `CardStyleModifier.swift`, `InteractiveModifier.swift`, update consuming views
**Verification**: `xcodebuild build` + manual hover/click testing

---

### Phase 5: AppUIConstants Cleanup (zero visual change)

> Separate layout constants from token-like values.

**5A. Audit `AppUIConstants`**

- Values that are token-like (padding, spacing, line height) → move to `PrimitiveTokens.Size` or `ComponentTokens`
- Values that are truly layout-specific (panel width, max height) → keep in `AppUIConstants`
- Timeouts → keep in `AppUIConstants` (not design tokens)

**Candidates to move**:

| Current | Move to |
|---------|---------|
| `captureSurfaceInnerPadding (24)` | `ComponentTokens.SearchField.innerPadding` |
| `captureSurfaceTopPadding (12)` | `ComponentTokens.SearchField.topPadding` |
| `captureEditorVerticalInset (12)` | `ComponentTokens.CaptureEditor.verticalInset` |
| `captureEditorBottomBreathingRoom (8)` | `ComponentTokens.CaptureEditor.bottomPadding` |
| `captureTextLineHeight (22)` | Already `PrimitiveTokens.LineHeight.capture` |
| `horizontalMargin (24)` | Already `PrimitiveTokens.Space.xl` |
| `verticalMargin (24)` | Already `PrimitiveTokens.Space.xl` |

**Keep in AppUIConstants**: `stackPanelWidth`, `capturePanelWidth`, `settingsPanelWidth/Height`, all `Timeout` values.

**Files changed**: `AppUIConstants.swift`, `ComponentTokens.swift`, consuming views
**Verification**: `xcodebuild build`

---

## 4. Phase Dependencies

```
Phase 1 (Token Foundation)
    │
    ├──→ Phase 2 (Component Tokens)
    │        │
    │        └──→ Phase 4 (Reusable Modifiers)
    │
    ├──→ Phase 3 (Hardcoded Cleanup)
    │
    └──→ Phase 5 (AppUIConstants)
```

- Phase 1 is prerequisite for all others
- Phases 2, 3, 5 can run in parallel after Phase 1
- Phase 4 depends on Phase 2

---

## 5. Verification Checklist Per Phase

```bash
# Every phase must pass all of these:
swift test                                          # core logic unchanged
xcodegen generate                                   # project file valid
xcodebuild -project PromptCue.xcodeproj \
  -scheme PromptCue -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build                     # compiles
python3 scripts/validate_ui_tokens.py --all         # no hardcoded values

# Phase 3+ additionally:
python3 scripts/validate_ui_tokens.py --all --strict  # after script update
```

---

## 6. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Renaming tokens breaks consuming code | Each phase is purely additive first, then migrate |
| Visual regression | Zero visual change target per phase; QA via `PROMPTCUE_OPEN_DESIGN_SYSTEM=1` |
| Over-abstraction (ComponentTokens too granular) | Start with 5 component groups, expand only when needed |
| AppKit bridge complexity | `AppKitTokens` is a thin wrapper, not a new rendering path |
| Phase 4 modifiers conflict with existing `CardSurface` | `CardStyleModifier` replaces `CardSurface` gradually — keep both during migration |

---

## 7. Files Inventory

### Will be created

| File | Phase |
|------|-------|
| `PromptCue/UI/DesignSystem/ComponentTokens.swift` | 2 |
| `PromptCue/UI/DesignSystem/AppKitTokens.swift` | 3 |
| `PromptCue/UI/DesignSystem/ViewModifiers/CardStyleModifier.swift` | 4 |
| `PromptCue/UI/DesignSystem/ViewModifiers/InteractiveModifier.swift` | 4 |

### Will be modified

| File | Phase(s) |
|------|----------|
| `PrimitiveTokens.swift` | 1 |
| `SemanticTokens.swift` | 1 |
| `CardSurface.swift` | 2, 3 |
| `SearchFieldSurface.swift` | 2 |
| `PromptCueChip.swift` | 2 |
| `GlassPanel.swift` | 2 |
| `StackNotificationCardSurface.swift` | 3 |
| `CardStackView.swift` | 3 |
| `CapturePanelRuntimeViewController.swift` | 3 |
| `AppUIConstants.swift` | 5 |
| `validate_ui_tokens.py` | 3 |
| `project.yml` | 2 (new files need registration) |
