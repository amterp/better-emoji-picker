# Better Emoji Picker (BEP) - Specification

**Version**: 1.0
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
6. **Position Near Cursor** - Appears near the text insertion point
7. **Recent/Frequent Emojis** - Shown when search field is empty
8. **Copy Mode** - Cmd+C copies emoji to clipboard instead of inserting
9. **Setup Wizard** - Guides user through initial permissions and shortcut setup

### Deferred Features

- Skin tone selection and preferences
- Custom favorites/pinned emojis
- Configurable grid density
- Custom shortcut configuration UI

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
  - Simulating Cmd+V to paste emoji
  - Detecting text cursor position for window placement

### Window Behavior

- **Type**: Floating panel (NSPanel)
- **Level**: Above all windows
- **Position**: Near text cursor, or mouse position as fallback, or screen center as final fallback
- **Dismissal**: Escape key, click outside, or losing focus
- **Persistence**: Stays open after emoji selection

### Search Behavior

- **Trigger**: Any typing while picker is focused
- **Algorithm**: Fuzzy matching on emoji names and keywords
- **Performance**: Filter completes in <16ms (one frame at 60fps)
- **Empty State**: Shows recent and frequent emojis

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

### Insertion Mechanism

1. Save current clipboard contents
2. Copy emoji to clipboard
3. Simulate Cmd+V keystroke via CGEvent
4. Restore original clipboard contents (after brief delay)

Note: This approach requires Accessibility permission.

## Architecture

### Directory Structure

```
BetterEmojiPicker/
├── BetterEmojiPickerApp.swift         # App entry point, menu bar setup
├── Views/
│   ├── SetupWizardView.swift          # First-run permission/shortcut setup
│   ├── PickerWindow.swift             # Main floating panel container
│   ├── SearchFieldView.swift          # Search input field
│   ├── EmojiGridView.swift            # Grid of emoji cells
│   └── EmojiCellView.swift            # Individual emoji button
├── ViewModels/
│   ├── PickerViewModel.swift          # Picker state and logic
│   └── SetupViewModel.swift           # Setup wizard state
├── Models/
│   ├── Emoji.swift                    # Emoji data model
│   └── EmojiCategory.swift            # Category enum
├── Services/
│   ├── EmojiStore.swift               # Emoji loading, search, history
│   ├── HotkeyService.swift            # Global shortcut registration
│   ├── PasteService.swift             # Clipboard and paste simulation
│   ├── CursorPositionService.swift    # Text cursor location detection
│   └── PermissionService.swift        # Accessibility permission handling
├── Protocols/
│   ├── EmojiStoreProtocol.swift       # For testability
│   ├── HotkeyServiceProtocol.swift
│   ├── PasteServiceProtocol.swift
│   └── PermissionServiceProtocol.swift
├── Resources/
│   └── emojis.json                    # Bundled emoji data
└── Tests/
    ├── EmojiStoreTests.swift
    ├── FuzzySearchTests.swift
    └── PickerViewModelTests.swift
```

### Testability Strategy

Services that interact with macOS APIs (hotkey, paste, cursor position, permissions) are defined via protocols. This allows:

1. **Unit tests** to use mock implementations
2. **Production code** to use real implementations
3. **Clear separation** between business logic and system integration

Areas that are intentionally NOT unit tested (but manually tested):
- Actual hotkey registration (Carbon API)
- Actual paste simulation (CGEvent)
- Actual accessibility permission prompts

### Data Flow

```
User presses shortcut
    → HotkeyService detects it
    → App shows PickerWindow near cursor
    → User types search query
    → PickerViewModel filters via EmojiStore
    → EmojiGridView updates instantly
    → User presses Enter
    → PasteService inserts emoji
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

### Empty State (No Search)

- **Section 1**: "Recent" - last 20 used emojis
- **Section 2**: "Frequent" - top 20 by usage count
- **Divider**: Subtle line between sections

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
