# Kitty Sliding Tabs

A minimal tab bar for Kitty on macOS. Tab numbers come first and are slightly dimmer than their titles. The Catppuccin Mocha mauve highlight slides behind stationary labels in 180 ms, with inset rounded corners and no shadow.

![Kitty tab bar with three example tabs named Editor, Shell, and Logs. The Shell tab has a rounded mauve highlight.](preview.png)

## Install

Tested with Kitty 0.50.0 on a Retina Mac, using JetBrains Mono at 20, 28, and 36 pt. The slide uses the Catppuccin Mocha palette and expects a terminal background of `#1e1e2e`.

1. Clone the repo and open `fonts/KittyInsetCorners-Regular.ttf` in Font Book. Install the font. It contains the two corner glyphs.
2. From the cloned directory, copy the tab renderer, configuration snippet, and shader files. If you already have a custom `tab_bar.py`, back it up before replacing it. The commands prompt before overwriting existing files.

   ```sh
   kitty_dir="${KITTY_CONFIG_DIRECTORY:-${XDG_CONFIG_HOME:-$HOME/.config}/kitty}"
   mkdir -p "$kitty_dir/shaders"
   cp -i tab_bar.py sliding-tabs.conf "$kitty_dir/"
   cp -i shaders/active-tab-slide-lite.* "$kitty_dir/shaders/"
   ```

3. Add this line to `kitty.conf` after your color theme. If you already set `custom_shaders`, review that setting before adding the snippet, since the snippet selects its own shader pipeline.

   ```conf
   include sliding-tabs.conf
   ```

4. Restart Kitty so it loads the font and renderer. Open another tab with **⌘T** and switch tabs to see the animation.

## How it works

`tab_bar.py` draws the rounded tab and tracks the highlight position. The shader draws the moving highlight in one pass and needs no extra full-window textures to store animation state. If the tab row is crowded or the font and display geometry differ from the supported layout, the highlight switches instantly.

To change the duration, edit `SLIDE_SECONDS` in `tab_bar.py`.
