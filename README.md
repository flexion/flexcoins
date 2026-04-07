# FlexCoins

A 2D idle coin collector game built with [Godot 4.6](https://godotengine.org/) and GDScript.

Coins rain from the sky -- move your catcher to collect them, earn currency, and buy upgrades to earn even faster.

![FlexCoins](flexcoin.png)

## How to Play

- **Arrow keys** or **A/D** to move the catcher left and right
- Catch falling coins to earn currency
- Spend currency on upgrades in the shop panel:
  - **Spawn Rate** -- more coins fall per second
  - **Coin Value** -- each coin is worth more
  - **Catcher Speed** -- move the catcher faster
  - **Catcher Width** -- widen the catcher to catch more
- Your upgrade progress is saved automatically
- Close and reopen the game to see offline earnings

## Download

Grab the latest build from the [Releases](../../releases) page:

| Platform | File |
|----------|------|
| Windows | `FlexCoins-windows.zip` |
| macOS | `FlexCoins-macos.zip` |
| Linux | `FlexCoins-linux.zip` |
| Web | `FlexCoins-web.zip` |

## Building from Source

### Requirements

- [Godot 4.6](https://godotengine.org/download/) (standard build)

### Run in Editor

1. Clone this repository
2. Open the project in Godot (`project.godot`)
3. Press **F5** to run

### Export

1. Open **Project > Export** in the Godot editor
2. Select a preset (Windows, macOS, Linux, or Web)
3. Click **Export Project**

Or use the CLI:

```bash
godot --headless --export-release "Windows" build/FlexCoins.exe
godot --headless --export-release "macOS" build/FlexCoins.zip
godot --headless --export-release "Linux" build/FlexCoins.x86_64
godot --headless --export-release "Web" build/FlexCoins.html
```

## Project Structure

```
scenes/          Scene files (.tscn)
scripts/         GDScript files (.gd)
sounds/          Audio assets
```

## Tech Stack

- **Engine:** Godot 4.6 (Forward+ renderer)
- **Language:** GDScript
- **Architecture:** Composition-based scenes, autoload singleton for game state, signal-driven communication

## License

MIT
