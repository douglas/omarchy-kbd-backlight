# Keyboard backlight for Omarchy

A bar widget that sets the keyboard backlight brightness. It is for laptops
that have a backlit keyboard but no key to control it.

- Click the icon to open a slider. It has one notch per hardware level
  (ThinkPads have three: off, low, high).
- Scroll on the icon to step the level up or down.
- In the open panel, `h` / `l` (or the arrow keys) step the level.

The widget hides itself when the machine has no `*kbd_backlight` LED, so the
same bar layout works on desktops too.

## Requirements

- `brightnessctl` (Omarchy installs it). It changes the level through
  systemd-logind, so no root or udev rule is needed.

## Install

```bash
omarchy plugin add https://github.com/douglas/omarchy-kbd-backlight.git --enable
```

## Remove

```bash
omarchy plugin remove io.github.douglas.kbd-backlight
```

## Keybinding

The panel registers the IPC target `io.github.douglas.kbd-backlight`, so you
can bind a key to open it:

```bash
omarchy-shell io.github.douglas.kbd-backlight toggle
```

## License

MIT
