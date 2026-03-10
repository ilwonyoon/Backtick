# Settings Panel Redesign Research

> Research date: 2026-03-10
> Target: PromptCue (Backtick) macOS menu-bar utility

---

## 1. Findings Per App

### 1.1 Raycast

| Attribute | Detail |
|---|---|
| **Layout pattern** | Top tab bar (not sidebar). Tabs: General, Appearance, Extensions, Advanced, About |
| **Tab structure** | Horizontal tabs across the top of a wide window. Extensions tab has a secondary sidebar for extension list with a right-side detail panel (master-detail within a tab) |
| **Iconography** | Outline-style icons with bold stroke widths and consistent corner radii. Custom icon set, not SF Symbols |
| **Section organization** | 5 top-level tabs. Each tab contains grouped form sections with headers |
| **Typography** | Inter typeface family (400, 500, 600, 700 weights). Clear hierarchy: section headers in semibold, descriptions in regular weight at smaller size |
| **Interactive elements** | Standard macOS toggles, dropdown pickers, keyboard shortcut recorders, segmented controls for theme selection (Light/Dark/System) |
| **Window sizing** | ~680x500, not resizable vertically, Extensions tab expands width for master-detail |
| **Key takeaway** | Tab bar works for Raycast because they have many extensions requiring a browsable list. The Extensions tab essentially becomes a sidebar+detail pattern inside one tab |

### 1.2 Alfred

| Attribute | Detail |
|---|---|
| **Layout pattern** | Left sidebar with icons + right detail pane. Classic macOS preferences pattern |
| **Sidebar structure** | ~180px wide. Each item has a colored icon (32x32) and a label. Items: General, Features, Workflows, Appearance, Remote, Powerpack, Advanced, Usage, Update |
| **Iconography** | Custom colorful icons, each section has a unique color. Not SF Symbols but similar visual weight |
| **Section organization** | 9 top-level sidebar items. Features section has sub-tabs within the detail pane. Appearance has a theme browser |
| **Typography** | System font (San Francisco). Section titles in bold, form labels in regular weight, descriptions in secondary color at 12-13pt |
| **Interactive elements** | Checkboxes (not toggles), text fields, keyboard shortcut recorders, color wells, dropdown menus |
| **Window sizing** | ~780x560, fixed size per section (window resizes per selection) |
| **Key takeaway** | The colored icon sidebar creates strong visual anchors for quick navigation. Each section feels distinct. This is the gold standard for preference windows with 5-10 sections |

### 1.3 macOS System Settings (Ventura+)

| Attribute | Detail |
|---|---|
| **Layout pattern** | NavigationSplitView: persistent left sidebar + scrolling detail pane. Replaced the old tab-bar System Preferences |
| **Sidebar structure** | ~220px wide. Grouped sections with gray uppercase headers (e.g., no header for top items, then unlabeled groups separated by spacing). Each row: 28x28 rounded-rect icon + label. Selection uses system accent highlight |
| **Iconography** | SF Symbols rendered at 16pt inside 28x28 rounded-rect badges with solid fill colors (multicolor: blue for General, gray for Accessibility, green for Battery, etc.) |
| **Section organization** | ~25 top-level items grouped into logical clusters: identity (Apple ID), connectivity (Wi-Fi, Bluetooth), device (Display, Sound), system (General, Privacy) |
| **Typography** | SF Pro. Sidebar labels: 13pt regular. Detail pane: section headers 15pt semibold, row labels 13pt regular, descriptions 11pt secondary color |
| **Interactive elements** | SwiftUI Toggle (capsule style), Picker (menu style and segmented), grouped Form with inset rounded-rect rows, navigation drill-down for sub-pages |
| **Window sizing** | ~680x580 minimum, resizable. Sidebar collapses on narrow widths |
| **Key takeaway** | The grouped-form-inside-detail-pane pattern is now the platform convention. Using GroupBox/Form with inset style gives the modern macOS look. Colored rounded-rect icon badges are the standard iconography pattern |

### 1.4 Linear (Desktop App)

| Attribute | Detail |
|---|---|
| **Layout pattern** | Modal settings overlay with left sidebar + right detail pane |
| **Sidebar structure** | ~200px wide. Sections grouped under uppercase gray headers: "Account", "Workspace", "Team Settings". Minimal hover states, no icons in sidebar (text-only with section headers) |
| **Iconography** | Minimal. No sidebar icons. Content area uses sparse, functional icons only where needed |
| **Section organization** | Three major groups: Account (Profile, Preferences, Notifications), Workspace (General, Members, Labels, Integrations, API, Import/Export), Team (features, members) |
| **Typography** | Inter Display for headings, Inter for body. Sidebar labels 13pt medium weight. Section headers 11pt uppercase, letter-spaced, secondary color. Detail titles 15-17pt semibold |
| **Interactive elements** | Custom toggle switches (not native), dropdown selects, text inputs with subtle borders, segmented pickers, action buttons aligned right |
| **Window sizing** | Full modal overlay (~800x600 content area). Not a separate window |
| **Key takeaway** | Text-only sidebar with strong grouping headers works when sections are numerous and grouping matters more than quick visual scanning. The uppercase section headers are distinctive. LCH color space for theme generation is advanced but relevant for dark/light mode work |

### 1.5 CleanShot X

| Attribute | Detail |
|---|---|
| **Layout pattern** | Top tab bar with icons. Tabs: General, Wallpaper, Shortcuts, Quick Access, Recording, Screenshots, Annotate, Cloud, Advanced, About |
| **Sidebar structure** | No sidebar. Horizontal icon tabs across the top (toolbar-style, similar to classic NSPreferencesWindow) |
| **Iconography** | Small icons (~16pt) in each tab, monochrome SF Symbols or custom icons. Tab labels below icons |
| **Section organization** | 10 top-level tabs. Each tab is a scrollable form with logical groupings separated by spacing/dividers |
| **Typography** | System font. Section headers bold, form labels regular, descriptions in secondary gray |
| **Interactive elements** | Checkboxes, dropdown menus, keyboard shortcut recorders, folder pickers, radio buttons for mutually exclusive options |
| **Window sizing** | ~560x480, fixed size |
| **Key takeaway** | Even with 10 sections, CleanShot sticks with top tabs because each section is shallow (few controls per tab). The icon+label tab style provides fast visual scanning. Relevant precedent since both apps handle screenshots |

### 1.6 Bartender / Ice (Menu Bar Utilities)

| Attribute | Detail |
|---|---|
| **Layout pattern** | **Bartender**: Top tab bar (Menu Items, General, Appearance, Hot Keys, Advanced, Updates). **Ice**: Settings window with sectioned layout and tabs for different configuration areas |
| **Sidebar structure** | Neither uses a sidebar. Both use compact tabbed interfaces appropriate for their focused feature sets |
| **Iconography** | Minimal. Bartender uses small icons in tabs. Ice uses SF Symbols in its settings sections |
| **Section organization** | Bartender: 6 tabs. Ice: Layout, Appearance, Hotkeys sections. Both keep it compact with few top-level categories |
| **Typography** | System font throughout. Standard macOS form styling |
| **Interactive elements** | Bartender: two-column layout in Menu Items (list + detail). Both use checkboxes, dropdowns, keyboard shortcut recorders. Ice uses drag-and-drop for menu bar arrangement |
| **Window sizing** | Bartender: ~560x420. Ice: ~500x400. Both compact and non-resizable |
| **Key takeaway** | Menu bar utilities keep settings compact. 4-6 sections maximum. The constraint is that these apps are utilities, not productivity suites, so settings should feel lightweight. Bartender's Menu Items tab with list+detail is relevant for any section that manages a collection |

---

## 2. Pattern Comparison Matrix

| Pattern | Best For | Apps Using It | Pros | Cons |
|---|---|---|---|---|
| **Sidebar + Detail** | 6+ sections, deep settings | Alfred, System Settings, Linear | Scales well, always visible nav, feels modern | Requires wider window, more complex layout |
| **Top Tab Bar** | 3-7 sections, shallow settings | Raycast, CleanShot X, Bartender | Familiar macOS pattern, compact, simple | Breaks down with many tabs, no grouping |
| **Single Scroll** | 1-3 sections | Current PromptCue | Simplest implementation | No navigation, loses context, hard to find settings |

---

## 3. Recommendation for PromptCue

### Recommended Pattern: Sidebar + Detail (Alfred / System Settings hybrid)

**Rationale:**

1. PromptCue has 5 distinct setting categories that map cleanly to sidebar items
2. The sidebar pattern is now the macOS platform convention (System Settings Ventura+)
3. It scales gracefully if future settings are added (AI features, export options, etc.)
4. With only 5 items, the sidebar stays clean without needing group headers
5. Alfred's colored-icon approach provides the visual warmth the current plain design lacks
6. The window size (560px wide) can accommodate a narrow sidebar (180px) + detail pane (380px) without feeling cramped

**Why not top tabs?** With exactly 5 sections, tabs would work too. But the sidebar pattern future-proofs the design and aligns with the System Settings convention that users now expect on macOS 14+.

**Why not Linear's text-only sidebar?** PromptCue has too few items for text-only to feel justified. Icons provide faster scanning for 5 items.

---

## 4. Proposed Sidebar Structure

### Window Specifications

| Property | Value |
|---|---|
| Window size | 620x520 (wider than current to fit sidebar, shorter since detail panes are focused) |
| Sidebar width | 180px |
| Detail pane width | 440px |
| Style mask | `.titled, .closable` |
| Toolbar style | `.preference` (keeps the title bar compact) |
| Background | `.windowBackground` with vibrancy in sidebar |
| Resizable | No (fixed size, like Alfred) |

### Sidebar Items

```
+---------------------------+
|  [icon] General           |  <- Selected state: accent highlight
|  [icon] Capture           |
|  [icon] Stack             |
|  [icon] Screenshots       |
|  [icon] Sync              |
+---------------------------+
```

### Icon Assignments (SF Symbols)

| Section | SF Symbol | Badge Color | Rationale |
|---|---|---|---|
| **General** | `gearshape.fill` | Gray (`NSColor.systemGray`) | Universal settings icon, matches System Settings > General |
| **Capture** | `rectangle.and.pencil.and.ellipsis` | Blue (`NSColor.systemBlue`) | Represents text capture/editing, the core action |
| **Stack** | `square.stack.fill` | Purple (`NSColor.systemPurple`) | Stacked cards metaphor, matches the Stack panel concept |
| **Screenshots** | `camera.viewfinder` | Orange (`NSColor.systemOrange`) | Screenshot/camera context, visually distinct |
| **Sync** | `arrow.triangle.2.circlepath.icloud.fill` | Teal (`NSColor.systemTeal`) | iCloud sync, matches Apple's cloud iconography |

### Icon Rendering Style (System Settings pattern)

Each icon should be rendered as an SF Symbol inside a rounded-rect badge:
- Badge size: 28x28
- Corner radius: 6pt
- Symbol size: 16pt, `.font(.system(size: 16, weight: .medium))`
- Symbol rendering: `.monochrome` white on colored badge fill
- Badge uses solid fill with the assigned color

### Sidebar Row Specifications

| Property | Value | Token |
|---|---|---|
| Row height | 32px | New: `PrimitiveTokens.Size.settingsRowHeight` |
| Row padding horizontal | 12px | `PrimitiveTokens.Space.sm` |
| Row padding vertical | 4px | `PrimitiveTokens.Space.xxs` |
| Icon-to-label spacing | 8px | `PrimitiveTokens.Space.xs` |
| Label font | 13pt medium | `PrimitiveTokens.Typography.meta` weight `.medium` |
| Selection indicator | Rounded rect fill with accent color | System `.selectedContentBackgroundColor` |
| Selection label color | White | Standard macOS sidebar behavior |

---

## 5. Proposed Section Content

### 5.1 General

| Setting | Control Type | Description |
|---|---|---|
| Appearance | Segmented picker: Light / Dark / Auto | App color scheme override |
| Launch at login | Toggle | Start PromptCue when macOS boots |
| Menu bar icon | Picker (icon variants) | Choose menu bar icon style |
| Show in Dock | Toggle | Whether to show dock icon (LSUIElement toggle) |

### 5.2 Capture

| Setting | Control Type | Description |
|---|---|---|
| Quick Capture shortcut | Keyboard shortcut recorder | Default: Cmd + backtick |
| Toggle Stack shortcut | Keyboard shortcut recorder | Default: Cmd + 2 |
| AI Export Tail | Text field + toggle | Append text to AI exports |
| Auto-focus on open | Toggle | Whether capture panel grabs focus on open |
| Default capture format | Picker: Plain / Markdown / Code | Format for new captures |

### 5.3 Stack

| Setting | Control Type | Description |
|---|---|---|
| Card retention | Picker: 1h, 4h, 8h, 24h, Forever | How long cards live (default: 8h) |
| Max visible cards | Stepper: 5-50 | Cards shown before overflow |
| Sort order | Picker: Newest first / Oldest first | Default stack ordering |
| Auto-copy on capture | Toggle | Copy to clipboard when card is created |
| Show copy confirmation | Toggle | Flash notification on copy |

### 5.4 Screenshots

| Setting | Control Type | Description |
|---|---|---|
| Watch folder | Folder picker with path display | Screenshot source folder |
| Auto-attach to capture | Toggle | Auto-detect and attach recent screenshots |
| Detection window | Picker: 5s, 10s, 30s, 60s | How recent a screenshot must be |
| Thumbnail size | Segmented: Small / Medium / Large | Preview size in cards |

### 5.5 Sync

| Setting | Control Type | Description |
|---|---|---|
| iCloud Sync | Toggle (with status indicator) | Enable/disable CloudKit sync |
| Sync status | Read-only label | "Synced", "Syncing...", "Error: ..." |
| Last sync time | Read-only label | Timestamp of last successful sync |
| Sync on cellular | Toggle | Allow sync on non-Wi-Fi (if applicable) |
| Reset sync data | Destructive button | Clear cloud data and re-upload |

---

## 6. Detail Pane Layout Pattern

Follow the macOS System Settings grouped-form pattern:

```
+-----------------------------------------------+
|  Section Title (15pt semibold)                 |
|                                                |
|  +-------------------------------------------+|
|  | Label                        [Control]    ||  <- Inset grouped row
|  |-------------------------------------------|│
|  | Label                        [Control]    ||
|  |-------------------------------------------|│
|  | Label                        [Control]    ||
|  +-------------------------------------------+|
|                                                |
|  Description text (11pt, secondary color)      |
|                                                |
|  +-------------------------------------------+|
|  | Another Group Title                       ||
|  |-------------------------------------------|│
|  | Label                        [Control]    ||
|  +-------------------------------------------+|
+-----------------------------------------------+
```

### Detail Pane Typography

| Element | Font | Token Reference |
|---|---|---|
| Section title | 15pt semibold | `PrimitiveTokens.Typography.panelTitle` |
| Row label | 13pt regular | `PrimitiveTokens.Typography.meta` |
| Row description | 11pt regular, secondary color | `PrimitiveTokens.FontSize.micro` + `SemanticTokens.Text.secondary` |
| Group box | Inset grouped style | `SemanticTokens.Surface.cardFill` background, `SemanticTokens.Border.subtle` border |

### Detail Pane Spacing

| Element | Value | Token |
|---|---|---|
| Top padding | 24px | `PrimitiveTokens.Space.xl` |
| Side padding | 24px | `PrimitiveTokens.Space.xl` |
| Section title to group | 8px | `PrimitiveTokens.Space.xs` |
| Between groups | 20px | `PrimitiveTokens.Space.lg` |
| Row height (inside group) | 36px | New: `PrimitiveTokens.Size.settingsFormRowHeight` |
| Row internal padding | 12px horizontal | `PrimitiveTokens.Space.sm` |
| Group corner radius | 12px | `PrimitiveTokens.Radius.sm` |

---

## 7. Token Additions Required

New tokens to add to `PrimitiveTokens.swift` (all within existing enum structure):

```swift
// In PrimitiveTokens.Size
static let settingsSidebarWidth: CGFloat = 180
static let settingsDetailWidth: CGFloat = 440
static let settingsWindowWidth: CGFloat = 620   // sidebar + detail
static let settingsWindowHeight: CGFloat = 520
static let settingsRowHeight: CGFloat = 32
static let settingsFormRowHeight: CGFloat = 36
static let settingsIconBadgeSize: CGFloat = 28
static let settingsIconBadgeRadius: CGFloat = 6
static let settingsIconSymbolSize: CGFloat = 16

// In PrimitiveTokens.Typography
static let settingsSidebarLabel = Font.system(size: FontSize.meta, weight: .medium)
static let settingsSectionTitle = Font.system(size: FontSize.body, weight: .semibold)
static let settingsRowLabel = Font.system(size: FontSize.meta, weight: .regular)
static let settingsRowDescription = Font.system(size: FontSize.micro, weight: .regular)
```

New tokens to add to `SemanticTokens.swift`:

```swift
// In SemanticTokens.Surface
static let settingsSidebarSelection = Color(nsColor: .selectedContentBackgroundColor)
static let settingsGroupBackground = adaptiveColor(
    light: NSColor.white.withAlphaComponent(0.80),
    dark: NSColor.white.withAlphaComponent(0.06)
)
static let settingsSidebarBackground = Color(nsColor: .windowBackgroundColor)

// In SemanticTokens.Border
static let settingsGroupBorder = adaptiveColor(
    light: NSColor.black.withAlphaComponent(0.06),
    dark: NSColor.white.withAlphaComponent(0.08)
)
static let settingsRowSeparator = adaptiveColor(
    light: NSColor.separatorColor.withAlphaComponent(0.5),
    dark: NSColor.separatorColor.withAlphaComponent(0.3)
)
```

---

## 8. Implementation Notes

### SwiftUI Structure

```
SettingsView (NavigationSplitView)
  +-- SettingsSidebar (List with NavigationLink)
  |     +-- SettingsSidebarRow (icon badge + label)
  +-- Detail pane (switched by selection)
        +-- GeneralSettingsView (Form)
        +-- CaptureSettingsView (Form)
        +-- StackSettingsView (Form)
        +-- ScreenshotsSettingsView (Form)
        +-- SyncSettingsView (Form)
```

### Key Implementation Decisions

1. **Use `NavigationSplitView`** with `.columnVisibility` set to `.doubleColumn` and sidebar toggle hidden via `.toolbar(removing: .sidebarToggle)`
2. **Use SwiftUI `Form`** with `.formStyle(.grouped)` for the detail panes to get native inset grouped rows
3. **Use `@AppStorage`** for persisted preferences, bridging to `UserDefaults`
4. **Use `KeyboardShortcuts`** package (already a dependency) for shortcut recorders
5. **Window controller**: Create `SettingsPanelController` (NSWindowController) following the same pattern as `CapturePanelController` and `StackPanelController`
6. **Open via**: Menu bar dropdown "Settings..." or Cmd+, when any PromptCue window is active

### Accessibility

- Sidebar should support keyboard navigation (Tab, arrow keys)
- All controls need accessibility labels
- Shortcut recorders need VoiceOver descriptions
- Grouped form rows inherit macOS accessibility automatically when using SwiftUI Form

---

## Cursor IDE

> Research date: 2026-03-10
> Cursor is an AI-powered code editor built on VS Code (Electron). It maintains two distinct settings surfaces: the inherited VS Code Settings and a custom "Cursor Settings" panel for AI-specific configuration.

### 1.7 Cursor IDE

| Attribute | Detail |
|---|---|
| **Layout pattern** | **Dual settings system.** (1) VS Code Settings: inherited JSON/GUI search-based settings editor. (2) Cursor Settings: a custom single-page scrollable panel with grouped sections, accessed via a dedicated shortcut (Cmd+Shift+J) or gear icon in the sidebar. The Cursor Settings panel is the more interesting design to study |
| **Cursor Settings structure** | Single scrollable page divided into clearly labeled sections with horizontal dividers. No sidebar navigation within the Cursor Settings panel itself — it relies on vertical scrolling through all sections sequentially. Sections are stacked top-to-bottom in a single column |
| **Sections (top to bottom)** | **General** (account info, theme, telemetry), **Models** (model selection checkboxes for available AI models like GPT-4, Claude, etc.), **Features** (granular toggles for Cursor Tab/autocomplete, Chat, Cmd-K, copilot++, and other AI features with per-feature enable/disable), **Beta** (experimental feature flags), **Privacy** (privacy mode toggle, codebase indexing preferences) |
| **Iconography** | Minimal to none within the Cursor Settings panel. Section headers are text-only with no icons. The VS Code Settings side uses the standard VS Code gear icon in the activity bar. The Cursor Settings entry point uses a small gear/cursor icon in the sidebar |
| **Section organization** | Logical grouping by concern: identity/account first, then model configuration, then feature toggles, then experimental flags, then privacy. This mirrors a "general to specific" progression. AI-related settings dominate since that is Cursor's differentiator — standard editor settings remain in VS Code Settings |
| **Typography** | Inherits VS Code's system font stack (platform sans-serif). Section headers are bold/semibold at ~14-15pt. Setting labels are regular weight at ~13pt. Descriptions below toggles are smaller (~11-12pt) in a secondary/muted color. Monospace font used for model names and technical values |
| **Interactive elements** | **Toggle switches** for feature enable/disable (custom styled, not native OS toggles — pill-shaped with smooth animation). **Checkboxes** for model selection (grid/list of available models with checkboxes). **Dropdown selects** for default model choice. **Text inputs** for API keys and custom endpoints. **Radio buttons** for mutually exclusive options (e.g., privacy mode levels). **Destructive buttons** styled in red for actions like "Clear conversation history" |
| **Visual treatment** | Dark theme dominant (matches VS Code dark default). Settings panel uses the editor's background color with subtle card-like grouping through spacing rather than explicit card borders. Divider lines (1px, low-opacity) separate major sections. Generous vertical spacing between groups (~20-24px). Toggle rows use a consistent left-label, right-control alignment with description text below the label |
| **Window sizing** | Not a separate window — renders as a full tab/panel within the editor window, occupying the same space as an editor tab. Scrollable vertically. Width adapts to the editor pane width (typically 600-900px depending on sidebar state) |
| **Unique patterns** | (1) **Model grid**: AI models displayed as a selectable list with checkboxes, showing model name + provider, letting users enable/disable which models appear in the model picker. (2) **Feature-level granularity**: Each AI feature (Tab completion, Chat, Cmd-K inline editing) has its own toggle with a description, rather than a single "enable AI" switch. (3) **Beta section**: Dedicated area for experimental features with clear "beta" labeling, setting expectations about stability. (4) **Dual settings surfaces**: Deliberately separating AI settings (Cursor Settings) from editor settings (VS Code Settings) to avoid overwhelming users and to keep the AI configuration discoverable |
| **Key takeaway** | Cursor's most notable design decision is the **separation of AI-specific settings into their own dedicated panel** rather than mixing them into the existing VS Code settings search interface. The single-scroll approach works because there are relatively few sections (~5) with moderate depth. The lack of sidebar navigation within Cursor Settings is a deliberate simplicity choice — with only 5 sections, scrolling is faster than clicking. The model selection grid is a unique pattern worth noting for any app that lets users choose between multiple AI providers/models |

### Comparison with Previously Researched Apps

| Dimension | Cursor | vs. Other Apps |
|---|---|---|
| **Navigation** | Single scroll, no sidebar | Differs from Alfred/System Settings (sidebar) and Raycast/CleanShot (tabs). Closest to a simplified Linear approach but without even Linear's sidebar |
| **Settings separation** | Two distinct settings surfaces (inherited + custom) | Unique among researched apps. Others have a single unified settings interface. This split is a consequence of being built on VS Code but is an interesting pattern for apps that extend a platform |
| **AI settings treatment** | Dedicated panel with per-feature toggles and model grid | No direct comparison in other apps (none are AI-focused). However, the granular per-feature toggle pattern is similar to CleanShot's per-feature tabs |
| **Toggle style** | Custom pill-shaped toggles (web/Electron) | Similar to Linear (custom toggles). Differs from Alfred (checkboxes) and System Settings (native SwiftUI toggles) |
| **Information density** | Medium — generous spacing, descriptions under every toggle | Less dense than Alfred, similar to System Settings, less sparse than Linear |
| **Section identification** | Text headers with dividers, no icons | Similar to Linear's text-only approach. Differs from Alfred (colored icons) and System Settings (SF Symbol badges) |
| **Platform feel** | Web/Electron — does not feel native macOS | Least native of all researched apps. PromptCue should NOT follow this approach for platform feel, but CAN adopt the logical organization patterns |

### Relevance to PromptCue

1. **Section ordering pattern is worth adopting**: General > domain-specific features > experimental > privacy/sync mirrors a logical user mental model. PromptCue's proposed order (General > Capture > Stack > Screenshots > Sync) follows a similar "general to specific" progression.

2. **Per-feature toggle with description text** is a strong pattern: Each setting having a label + toggle + small description below keeps the interface self-documenting without needing a separate help system.

3. **Dedicated AI/specialized settings**: If PromptCue ever adds AI features (AI-powered prompt suggestions, smart categorization), Cursor's pattern of giving AI its own section rather than scattering AI toggles across other sections is a good precedent.

4. **What NOT to copy**: The single-scroll-no-sidebar approach works for Cursor because it lives inside an already-navigated editor window. For a standalone macOS settings panel, the sidebar + detail pattern (as already recommended) remains the better choice. Cursor's Electron-based toggle styles should also not be copied — native SwiftUI toggles are more appropriate for PromptCue.

5. **Model/provider selection grid**: Not directly applicable now, but if PromptCue adds support for multiple AI backends, Cursor's checkbox grid for model selection is a clean pattern to reference.

---

## Sources

- [Raycast Manual - Settings](https://manual.raycast.com/preferences)
- [Raycast Blog - A Fresh Look and Feel](https://www.raycast.com/blog/a-fresh-look-and-feel)
- [Alfred Help - Appearance & Theming](https://www.alfredapp.com/help/appearance/)
- [Alfred Help - Accessing Preferences](https://www.alfredapp.com/help/kb/access-preferences/)
- [Apple HIG - Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [How to Build macOS System-Like Settings in SwiftUI](https://medium.com/@schopenlaam/macos-app-settings-9ee3f8d50e57)
- [Linear Blog - How We Redesigned the Linear UI](https://linear.app/now/how-we-redesigned-the-linear-ui)
- [Linear Changelog - Personalized Sidebar and New Settings Pages](https://linear.app/changelog/2024-12-18-personalized-sidebar)
- [CleanShot X Features](https://cleanshot.com/features)
- [Bartender 3 Preferences](https://www.macbartender.com/b3gettingstarted/bartender-preferences/)
- [Ice Menu Bar Manager - GitHub](https://github.com/jordanbaird/Ice)
- [Linear Design - The SaaS Design Trend](https://blog.logrocket.com/ux-design/linear-design/)
- [Cursor Documentation - VS Code Migration](https://cursor.com/docs/configuration/migrations/vscode)
- [Cursor Help - Customization](https://cursor.com/help/customization/themes)
- [Cursor CLI Configuration Reference](https://cursor.com/docs/cli/reference/configuration)
- [Cursor GitHub Repository](https://github.com/getcursor/cursor)
