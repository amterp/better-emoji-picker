# Better Emoji Picker (BEP) - Specification

**Version**: 1.1
**Status**: In Development

## Overview

BEP is a native macOS application that replaces the built-in emoji picker with a faster, more keyboard-friendly alternative. The key differentiator is that BEP **stays open** after selecting an emoji, allowing rapid insertion of multiple emojis without repeatedly invoking the picker.

## Why BEP?

The built-in macOS emoji picker (Ctrl+Cmd+Space) has several limitations:

| Issue | Built-in Behavior | BEP Solution |
|-------|------------------|--------------|
| Closes after selection | Dismisses immediately | Stays open for multiple selections |
| Slow startup | Can lag, especially first open | Pre-loaded, instant popup |
| Large emoji display | Fixed size, wastes space | Compact grid (10 per row) |
| Smart suggestions | Context-aware suggestions hijack UX | Always shows full picker |
| Search speed | Acceptable but not instant | Instant fuzzy filtering |

## Features

### Core Features (MVP)

1. **Instant Popup** - Appears immediately when shortcut is pressed
2. **Stays Open** - Does not dismiss after selecting an emoji
3. **Instant Search** - Fuzzy filtering as you type
4. **Compact Grid** - 10 emojis per row, smaller cells
5. **Keyboard Navigation** - Arrow keys to move, Enter to insert, Escape to dismiss
6. **Position Near Mouse** - Appears at mouse cursor position
7. **Frecent Emojis** - Combined frequency + recency ranking shown when search is empty
8. **Copy Mode** - Cmd+C copies emoji to clipboard (with toast feedback) instead of inserting
9. **Setup Wizard** - Guides user through initial permissions and shortcut setup
10. **Toggle Shortcut** - Same shortcut opens and closes the picker

### Deferred Features

- Skin tone selection and preferences
- Custom favorites/pinned emojis
- Configurable grid density
- Custom shortcut configuration UI
- In-app auto-updates (Sparkle) - MVP uses GitHub releases + Homebrew Cask

## Technical Specification

### Platform Requirements

- **macOS**: 13.0+ (Ventura) - for modern SwiftUI features
- **Architecture**: Universal (Intel + Apple Silicon)

### App Type

- **Menu Bar App**: Runs in background with menu bar icon
- **No Dock Icon**: `LSUIElement = true` in Info.plist
- **Always Running**: Launches at login (optional)

### Shortcut

- **Default**: Ctrl+Cmd+Space (same as system emoji picker)
- **Requirement**: User must disable system shortcut first
- **Setup Wizard**: Guides user through disabling system shortcut

### Permissions

- **Accessibility**: Required for:
  - Simulating keyboard input to insert emoji (primary method)
  - Simulating Cmd+V to paste emoji (fallback method)

### Window Behavior

- **Type**: Floating panel (NSPanel)
- **Level**: Above all windows
- **Dismissal**: Escape key, click outside, or losing focus
- **Persistence**: Stays open after emoji selection
- **Toggle**: Re-invoking shortcut while open closes the picker

### Window Positioning

- **Anchor**: Top-left corner of window at mouse cursor
- **Edge Handling** (flip anchor):
  - If insufficient space to the right: right edge aligns with mouse instead
  - If insufficient space below: bottom edge aligns with mouse instead
- **Screen Bounds**: Use `NSScreen.main.visibleFrame` to account for menu bar and Dock

### Search Behavior

- **Trigger**: Any typing while picker is focused
- **Matching**: Against emoji names and keywords
- **Algorithm**: Implementation discretion — start simple (e.g., token prefix), iterate based on feel
- **Performance**: Filter completes in <16ms (one frame at 60fps)
- **Empty State**: Shows frecent emojis, then all emojis grouped by category

### Emoji Data

- **Source**: Bundled JSON file with all Unicode emojis
- **Fields per emoji**:
  - `emoji`: The emoji character itself
  - `name`: Primary name (e.g., "grinning face")
  - `keywords`: Array of searchable terms
  - `category`: Category for grouping (when not searching)
- **Updates**: Manual updates when Unicode releases new emojis

### Keyboard Navigation

| Key | Action |
|-----|--------|
| Arrow keys | Move selection in grid |
| Enter | Insert selected emoji at cursor |
| Cmd+C | Copy selected emoji to clipboard |
| Escape | Dismiss picker |
| Any letter | Start/continue search |
| Backspace | Delete search character |

**Grid Navigation Edge Behavior:**
- **Horizontal**: Wrap to next/previous row at edges
- **Vertical**: Stop at top/bottom (no wrapping)
- **Partial last row**: Right arrow wraps to first emoji in next section
- **Initial selection**: First emoji in frecent section (if populated) or first emoji overall

### Insertion Mechanism

**Primary Method** (no clipboard involvement):
1. Use `CGEventKeyboardSetUnicodeString` to simulate typing the emoji directly
2. This avoids clipboard manipulation entirely

**Fallback Method** (if primary fails):
1. Save current clipboard contents
2. Copy emoji to clipboard
3. Simulate Cmd+V keystroke via CGEvent
4. Restore original clipboard contents after delay (default 200ms, configurable)
5. Restoration is debounced — if user inserts multiple emojis rapidly, only restore after the last one

Both methods require Accessibility permission.

### Storage

**Settings** (`~/Library/Application Support/BEP/settings.json`):
- User preferences (sync-friendly, user can git-manage)
- Contents:
  - `frecencyRows`: Number of rows to show in frecent section (default: 2)
  - `clipboardRestoreDelay`: Fallback paste delay in ms (default: 200)
  - `onboardingCompleted`: Boolean
  - Other user preferences as needed

**Frecency Data** (UserDefaults or local file):
- Per-emoji usage tracking, not sync-targeted
- Per emoji: `{ score: Float, lastUsed: Date }`

### Frecency Algorithm

Combines frequency and recency using incremental exponential decay:

**On each emoji use:**
```
timeSinceLastUse = now - lastUsed
decayFactor = e^(-λ × timeSinceLastUse_in_days)
score = (score × decayFactor) + 1.0
lastUsed = now
```

**When sorting for display:**
```
timeSinceLastUse = now - lastUsed
displayScore = score × e^(-λ × timeSinceLastUse_in_days)
```

**Decay constant**: λ ≈ 0.099 (7-day half-life)
- Emoji used today: full weight
- Emoji used 7 days ago: half weight
- Emoji used 30 days ago: ~6% weight

### Menu Bar

- **Icon**: Custom emoji-style face icon, designed to fit macOS menu bar aesthetic
- **Menu Items**:
  - Open Picker
  - Settings...
  - Setup Assistant... (re-trigger onboarding/permissions)
  - Quit BEP

## Architecture

### Directory Structure

```
BetterEmojiPicker/
├── BetterEmojiPickerApp.swift         # App entry point, menu bar setup
├── Views/
│   ├── SetupWizardView.swift          # First-run permission/shortcut setup
│   ├── SettingsView.swift             # User preferences UI
│   ├── PickerWindow.swift             # Main floating panel container
│   ├── SearchFieldView.swift          # Search input field
│   ├── EmojiGridView.swift            # Grid of emoji cells
│   └── EmojiCellView.swift            # Individual emoji button
├── ViewModels/
│   ├── PickerViewModel.swift          # Picker state and logic
│   ├── SettingsViewModel.swift        # Settings state
│   └── SetupViewModel.swift           # Setup wizard state
├── Models/
│   ├── Emoji.swift                    # Emoji data model
│   ├── EmojiCategory.swift            # Category enum
│   └── Settings.swift                 # User settings model
├── Services/
│   ├── EmojiStore.swift               # Emoji loading and search
│   ├── FrecencyService.swift          # Frecency tracking and scoring
│   ├── SettingsService.swift          # Settings persistence
│   ├── HotkeyService.swift            # Global shortcut registration
│   ├── InsertionService.swift         # Text insertion (keyboard sim + clipboard fallback)
│   └── PermissionService.swift        # Accessibility permission handling
├── Protocols/
│   ├── EmojiStoreProtocol.swift       # For testability
│   ├── FrecencyServiceProtocol.swift
│   ├── HotkeyServiceProtocol.swift
│   ├── InsertionServiceProtocol.swift
│   └── PermissionServiceProtocol.swift
├── Resources/
│   └── emojis.json                    # Bundled emoji data
└── Tests/
    ├── EmojiStoreTests.swift
    ├── FrecencyServiceTests.swift
    ├── SearchTests.swift
    └── PickerViewModelTests.swift
```

### Testability Strategy

Services that interact with macOS APIs (hotkey, insertion, permissions) are defined via protocols. This allows:

1. **Unit tests** to use mock implementations
2. **Production code** to use real implementations
3. **Clear separation** between business logic and system integration

Areas that are intentionally NOT unit tested (but manually tested):
- Actual hotkey registration (Carbon API)
- Actual text insertion (CGEvent keyboard simulation)
- Actual clipboard operations
- Actual accessibility permission prompts

### Data Flow

```
User presses shortcut
    → HotkeyService detects it
    → App shows PickerWindow at mouse position
    → User types search query
    → PickerViewModel filters via EmojiStore
    → EmojiGridView updates instantly
    → User presses Enter
    → InsertionService inserts emoji (keyboard sim, clipboard fallback)
    → FrecencyService records usage
    → Window stays open
    → User can continue or press Escape
```

## Setup Wizard Flow

First-run experience:

1. **Welcome Screen**
   - Explain what BEP does
   - "Let's set it up" button

2. **Accessibility Permission**
   - Explain why it's needed
   - "Open System Settings" button
   - Detect when permission is granted

3. **Disable System Shortcut**
   - Show exact steps with screenshots/instructions
   - "Open Keyboard Settings" button
   - Detect when system shortcut is disabled

4. **Test It**
   - "Press Ctrl+Cmd+Space to test"
   - Confirm BEP opens
   - "Setup Complete" screen

5. **Optional: Launch at Login**
   - Toggle to add to login items

## UI Specifications

### Picker Window

- **Width**: ~400px (fits 10 emojis at ~36px each + padding)
- **Height**: ~300px (shows ~6-7 rows)
- **Corner Radius**: 12px
- **Background**: System background with vibrancy
- **Shadow**: Standard floating panel shadow

### Search Field

- **Position**: Top of window
- **Placeholder**: "Search emojis..."
- **Auto-focus**: Yes, on window appear
- **Clear button**: Yes

### Emoji Grid

- **Layout**: LazyVGrid, 10 columns
- **Cell Size**: ~36x36px
- **Selection**: Highlighted background
- **Hover**: Subtle highlight

### Default View (No Search)

```
┌─────────────────────────────────────┐
│ [Search field]                      │
├─────────────────────────────────────┤
│ Frecent                             │
│ 😀 🎉 👍 ❤️ 🚀 😂 🔥 ✨ 🙏 💯        │
│ 🤔 😊 👀 💪 🎯 😅 🙌 💡 ✅ 🌟        │
├─────────────────────────────────────┤
│ Smileys & Emotion                   │
│ 😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃        │
│ ...                                 │
├─────────────────────────────────────┤
│ People & Body                       │
│ ...                                 │
└─────────────────────────────────────┘
```

- **Frecent Section**: Up to N rows (configurable, default 2), hidden when empty
- **All Emojis**: Grouped by Unicode category with headers
- **Category Order**: By expected usefulness (Smileys & Emotion first, then People, Animals, Food, etc.)

### Copy Mode

- **Trigger**: Cmd+C with an emoji selected
- **Feedback**: Brief toast notification ("Copied!")
- **Behavior**: Window closes after copy

## Software Principles

These principles guide all implementation decisions:

1. **Quality over speed**: We implement things well, never take shortcuts
2. **Pragmatic, not dogmatic**: Best practices serve us, not the other way around
3. **Testability**: Smart abstractions to maximize testable surface area
4. **Self-documenting code**: Clear naming, obvious structure
5. **Comments for "why"**: When code alone can't explain intent
6. **Newcomer-friendly**: Comments assume reader is unfamiliar with Swift/macOS
7. **Long-term maintainability**: Every decision considers future maintenance

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-24 | Initial specification |
| 1.1 | 2025-12-25 | Spec refinements: mouse positioning with edge flip, frecency algorithm, keyboard insertion, toggle shortcut, grid navigation edges, menu bar details, storage architecture, copy mode feedback |
