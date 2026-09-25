# omarchy-headlint

![preview](preview.png)

An [Omarchy](https://omarchy.org/) shell plugin: type a URL into a bar panel and lint its `<head>` (OGP, title, favicon, canonical, robots) with [headlint](https://github.com/polidog/headlint). og:image / twitter:image are rendered as an SNS-style card, and favicons are rendered at their real size (capped at 64px).

Check messages come from headlint and are currently in Japanese.

## Requirements

- [headlint](https://github.com/polidog/headlint)
- `curl` (used to fetch images)

```bash
cargo install --locked --git https://github.com/polidog/headlint --rev dea85036c6b707752f46e2682991fe92b9d9242d
```

## Install

```bash
omarchy plugin add https://github.com/polidog/omarchy-headlint
omarchy plugin enable polidog.headlint --section right
```

## Uninstall

```bash
omarchy plugin disable polidog.headlint
omarchy plugin remove polidog.headlint
```

Fetched images live under `$XDG_RUNTIME_DIR/omarchy-headlint/` (tmpfs, cleared on logout). The plugin writes nothing else.

## Usage

| Action | Result |
|--------|--------|
| Left-click the icon | Open the panel (URL field focused) |
| Type a URL and press Enter | Analyze (`https://` is optional) |
| Right-click the icon | Re-analyze the last URL |
| Click the card | Open the page in your browser |
| Esc | Close |

The icon turns to the urgent color when any check fails (✗).

From scripts:

```bash
omarchy-shell polidog.headlint analyze https://polidog.jp
```

Keybinding that analyzes the URL on the clipboard (`~/.config/hypr/bindings.lua`):

```lua
o.bind("SUPER SHIFT, S", "exec", "omarchy-shell polidog.headlint analyze \"$(wl-paste)\"")
```

## Test

```bash
node test.js
```

## License

MIT
