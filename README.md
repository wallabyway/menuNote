# menuNote

A tiny macOS menu bar scratchpad backed by a plain Markdown file.
Click the circle, read your note, flip **Edit** to change it. That's it.

![menuNote screenshot](docs/screenshot.png)
<sub>_(placeholder — real screenshot coming soon)_</sub>

## Features

- **Lives in the menu bar** — no Dock icon, no windows to manage.
- **Your file, your format** — the note is a regular `.md` file you choose, so it
  plays nicely with Obsidian, git, iCloud Drive, or any editor.
- **Preview by default** — lightweight Markdown rendering: `#`/`##`/`###`
  headings, `-`/`*` bullets, plus inline **bold**, _italic_, `code`, and links.
- **Edit toggle** — a small switch in the top-right flips to a plain-text editor.
- **Stays in sync** — the file is re-read every time the popover opens, and
  saved ~0.5 s after you stop typing (atomic writes).

## Requirements

- macOS 14 (Sonoma) or newer
- Xcode Command Line Tools (`xcode-select --install`)

## Build & install

```bash
git clone https://github.com/wallabyway/menuNote.git
cd menuNote
./build.sh   # swift build → .app bundle → ad-hoc sign → optional install to /Applications
```

The app is ad-hoc signed, so Gatekeeper will complain on first launch:
right-click the app → **Open**, or allow it in **System Settings → Privacy & Security**.

## First run

On first open, menuNote asks you to pick a Markdown file. Choose an existing
`.md`, or cancel to create a new one. You can switch files any time with the
small 📄 button next to the Edit toggle (hover it to see the current path).

The chosen path is stored in UserDefaults (`com.local.menunote`, key `notePath`).

## Project layout

| Path | What it is |
| --- | --- |
| `Sources/menuNote/App.swift` | The whole app: menu bar scene, file store, editor, Markdown preview |
| `assets/Info.plist` | Bundle config (`LSUIElement` hides the Dock icon) |
| `assets/regen-icon.sh` | Regenerates the app icon |
| `build.sh` | Build + bundle + sign script |

## Hacking

It's one SwiftUI file — open `App.swift` and go. Fonts live in the
`Font.andale` helper and the `MarkdownView` renderer; popover size is set in
`MenuNoteApp`.
