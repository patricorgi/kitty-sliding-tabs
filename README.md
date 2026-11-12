# Kitty Sliding Tabs

A minimal Kitty tab bar for macOS with numbered tabs and a rounded highlight that slides in 180 ms.

![The rounded highlight slides between three Kitty tabs.](demo.gif)

## Install

Tested with Kitty 0.50.0 on a Retina Mac with JetBrains Mono (20, 28, and 36 pt). Install [the corner font](fonts/KittyInsetCorners-Regular.ttf) in Font Book, then copy the files from this repo.

```sh
kitty_dir="${KITTY_CONFIG_DIRECTORY:-${XDG_CONFIG_HOME:-$HOME/.config}/kitty}"
mkdir -p "$kitty_dir/shaders"
cp -i tab_bar.py sliding-tabs.conf "$kitty_dir/"
cp -i shaders/active-tab-slide-lite.* "$kitty_dir/shaders/"
```

Add `include sliding-tabs.conf` after your theme in `kitty.conf`, then restart Kitty. The snippet selects its own shader pipeline. Crowded tab rows or unsupported font and display geometry use an instant highlight.

## Colors

Catppuccin Mocha is the default. To use another theme, edit the two files below.

1. In `sliding-tabs.conf`, set `tab_bar_background` and `inactive_tab_background` to your theme’s terminal `background`. Set the highlight with `active_tab_background`, the title colors with the two `*_tab_foreground` settings, and the index colors with `fmt.fg._RRGGBB` in the two title templates.
2. In `shaders/active-tab-slide-lite.slang`, match the five palette constants to those same colors using decimal RGB values from 0 to 255. For example, `#CBA6F7` becomes `float3(203, 166, 247)`. Restart Kitty to load the edited shader.
