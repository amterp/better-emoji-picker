# Better Emoji Picker (BEP)

A fast, keyboard-driven emoji picker for macOS.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)

## Features

- **Global hotkey**: `Ctrl+Cmd+Space` opens the picker from anywhere
- **Frecency**: Recent emojis sorted by frequency + recency
- **Fast search**: Type to filter emojis by name or keywords
- **Keyboard navigation**: Arrow keys + Enter to select
- **Pin mode**: Keep the picker open for multiple selections

## Installation

```bash
brew install amterp/tap/bep
```

After installing, you may need to clear the quarantine flag (unsigned app):

```bash
xattr -cr /Applications/BetterEmojiPicker.app
```

### Permissions

BEP requires **Accessibility** permission to paste emojis into other apps.

On first launch, click "Open System Settings" and enable BEP in:
**Privacy & Security → Accessibility**

## Usage

| Action | Key |
|--------|-----|
| Open picker | `Ctrl+Cmd+Space` |
| Search | Just type |
| Navigate | Arrow keys |
| Insert emoji | `Enter` |
| Copy to clipboard | `Cmd+C` |
| Toggle pin | `Cmd+P` |
| Close | `Escape` |

## Building from Source

```bash
git clone https://github.com/amterp/better-emoji-picker.git
cd better-emoji-picker/BetterEmojiPicker
xcodebuild -scheme BetterEmojiPicker -configuration Release build
```
