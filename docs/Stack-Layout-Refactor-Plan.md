# Stack Layout Refactor Plan

## Problem

CardStackView uses a flat `LazyVStack(spacing: 12)` where headers, carousels, cards, and sections are all siblings. This causes:

1. Header-to-card spacing is controlled by the parent's uniform spacing, not by each group
2. Pinned carousel ScrollView expands to fill available height (fixed with .frame(height:) hack)
3. Copied section is the only properly grouped section (has its own VStack)
4. No concept of "section gap" vs "header-to-card gap" vs "card-to-card gap"

## Current Structure (broken)

```
ScrollView
└── LazyVStack(spacing: 12)        ← uniform 12pt for everything
    ├── header("8 prompts")        ← sibling
    ├── pinnedCarousel             ← sibling (needs height hack)
    ├── cardRow                    ← sibling
    ├── cardRow                    ← sibling
    └── copiedSection              ← self-contained group (inconsistent)
        └── VStack(spacing: 12)
            ├── header("Copied")
            └── cards
```

## Target Structure

```
ScrollView
└── VStack(spacing: sectionGap)    ← section-to-section = 20pt
    │
    │  .padding(.top, panelTopInset)  ← 16pt breathing room at top
    │
    ├── PinnedSection               ← header + carousel as one group
    │   └── VStack(spacing: headerToCardGap)  ← 8pt
    │       ├── SectionHeader("N prompts", trailing: ⌘Select)
    │       └── pinnedCarousel(.frame(height: 72))
    │
    ├── ActiveSection               ← cards only (no header, prompts header is above)
    │   └── LazyVStack(spacing: cardGap)  ← 12pt
    │       ├── cardRow
    │       └── cardRow
    │
    └── CopiedSection               ← header + cards as one group
        └── VStack(spacing: headerToCardGap)  ← 8pt
            ├── SectionHeader("Copied N", trailing: controls)
            └── collapsedStack / LazyVStack(spacing: cardGap) for expanded
```

When no pinned cards: header goes directly above ActiveSection.

```
ScrollView
└── VStack(spacing: sectionGap)
    │  .padding(.top, panelTopInset)
    │
    ├── HeaderSection
    │   └── SectionHeader("N prompts", trailing: ⌘Select)
    │
    ├── ActiveSection
    │   └── LazyVStack(spacing: cardGap)
    │       ├── cardRow
    │       └── cardRow
    │
    └── CopiedSection
        └── ...
```

## Spacing Rules

| Token | Value | Usage |
|-------|-------|-------|
| `panelTopInset` | 16pt | Top of scroll content to first header (breathing room) |
| `sectionGap` | 20pt | Between sections (pinned→active, active→copied) |
| `headerToCardGap` | 8pt | Header bottom to first card in its group (consistent everywhere) |
| `cardGap` | 12pt | Between cards within a section (existing `cardStackSpacing`) |

Key invariant: **every StackSectionHeader has exactly `headerToCardGap` below it**, regardless of which section it belongs to. This is controlled by the header component itself, not by parent spacing.

## Implementation Steps

### Step 1: Extract section builders

Create three `@ViewBuilder` methods:
- `pinnedSection(cards:)` → VStack with header + carousel
- `activeSection(cards:)` → LazyVStack with card rows
- `copiedSection(cards:)` → already exists, adjust spacing

### Step 2: Replace flat LazyVStack with grouped VStack

```swift
ScrollView {
    VStack(spacing: 0) {
        if !pinnedCards.isEmpty {
            pinnedSection(cards: pinnedCards)
        }
        if !unpinnedCards.isEmpty {
            activeSection(cards: unpinnedCards)
        }
        if !copiedCards.isEmpty {
            copiedSection(cards: copiedCards)
        }
    }
}
```

### Step 3: Apply spacing tokens

Each section controls its own:
- Internal header-to-card gap via `.padding(.bottom, headerToCardGap)` on header
- Bottom margin via `.padding(.bottom, sectionGap)` on the section container

### Step 4: Move header into pinned section

Currently header("N prompts") is separate from pinnedCarousel. After refactor, header is INSIDE pinnedSection, creating a proper group.

When no pinned cards exist, header goes into activeSection instead.

## Verification

- [ ] Header-to-card spacing identical for Prompt and Copied sections
- [ ] Card-to-card spacing unchanged (12pt)
- [ ] Section-to-section gap wider than card-to-card (20pt)
- [ ] Pinned carousel height correct (72pt)
- [ ] Scroll behavior unchanged
- [ ] Hover/tap/right-click all working
- [ ] Empty state still works
- [ ] Selection mode header swap still works
- [ ] Copied collapse/expand still works

## Future: Memory Panel Readiness

Memory panel (Cmd+3) will be a separate NSPanel with its own views. But shared components should work across both:

- `StackSectionHeader` → rename to `SectionHeader` (generic, not Stack-specific)
- `StackNotificationCardSurface` → keep Stack-specific, Memory gets own surface
- Grouped VStack pattern → same architecture for Memory's project list → topic list

The layout refactor establishes the **grouped section pattern** that Memory panel will follow.

No Memory code in this refactor — just ensuring the architecture is reusable.

## Risk

LOW — purely layout restructure, no data/logic changes. All interactions go through same callbacks. Restore point: `pin-v2-before-layout-refactor`
