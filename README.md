# ghostty-matrix-shader

A [Ghostty](https://ghostty.org) custom shader that plays Matrix rain in the
background of unfocused splits.

Ghostty runs one copy of the shader per split. The focused split is left
untouched; the others get green glyph rain wherever they show the terminal's
default background, so their text stays readable on top of it.

## Requirements

- Ghostty 1.3 or later, for the `iFocus` and `iBackgroundColor` shader uniforms.
- Linux. The shader assumes OpenGL's bottom-up `fragCoord`; on macOS (Metal)
  the rain would fall upwards.

## Install

```sh
git clone https://github.com/Pierrotws/ghostty-matrix-shader.git
mkdir -p ~/.config/ghostty/shaders
ln -s "$PWD/ghostty-matrix-shader/matrix-unfocused.glsl" ~/.config/ghostty/shaders/
```

The symlink keeps the shader up to date with `git pull`.

## Configure

Add to `~/.config/ghostty/config`:

```
custom-shader = ~/.config/ghostty/shaders/matrix-unfocused.glsl
custom-shader-animation = always
unfocused-split-opacity = 1
```

- `custom-shader` loads the shader. Ghostty also resolves a relative path
  against the config file's directory, so `shaders/matrix-unfocused.glsl`
  works too.
- `custom-shader-animation = always` is required. By default only the focused
  split redraws on every frame, so the rain would stand still exactly where it
  should fall.
- `unfocused-split-opacity = 1` is optional. Ghostty dims unfocused splits by
  drawing a translucent rectangle over them, which dims the rain as well.

Reload the configuration with `ctrl+shift+,` or restart Ghostty. If the shader
fails to compile, Ghostty ignores it and logs the error; remove the
`custom-shader` line to get back to a plain terminal.

## Tuning

The constants at the top of `matrix-unfocused.glsl` set the glyph cell size,
fall speeds, trail length, glyph density, colors and opacity. They are in
physical pixels: on a HiDPI screen, double `CELL` and `STROKE`.

## Behaviour

- The rain only shows through the default background. Programs that paint
  their own background color, such as a full-screen editor theme or a status
  bar, hide it.
- When the Ghostty window itself loses focus, every split counts as unfocused,
  the one you were typing in included, so they all show the rain.
- With `custom-shader-animation = always`, every split redraws at the screen's
  refresh rate, including the focused one. Expect some steady GPU use with many
  splits open.
- Shaders cannot use the terminal font, so the glyphs are random strokes on a
  3x3 grid rather than real katakana.
- The animation clock wraps every hour, so the rain jumps once an hour. Without
  that, float precision would make it stutter in splits left open for days.
