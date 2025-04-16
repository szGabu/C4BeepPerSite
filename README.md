# Different C4 Sound Per Site

![Version](https://img.shields.io/badge/version-1.0.1-blue)
![AMX Mod X](https://img.shields.io/badge/AMXX%201.8.2-Required-orange)

A Counter-Strike plugin that changes the C4 beeping sound based on which bomb site the explosive was planted.

## Features

- Unique Sounds Per Bombsite
  - Different pitch for bomb beeping sounds depending on which site the bomb is planted at
- Support for Bombsite C
  - Includes support for the Bombsite C with an even lower pitched sound than sites A and B (Bombsite C appears in some uncommon defusal maps like `de_foption`)
- Resource Optimization
  - By default, the plugin effectively frees up to 4 sound resource slots from the server by unprecaching the original C4 beeping sounds


## Compatible Games

- Counter-Strike
- Counter-Strike: Condition Zero

## Installation

1. Manually compile the .sma file or get the working binary and install it in your server
2. Download and install the contents of assets.zip (if you're on AlliedModders) or the release .zip file in your game directory
   - The .zip file may also include the source code, but only the included sound is required
3. Copy the file to the following directory:
   - `c4_sound_site.amxx` → `addons/amxmodx/plugins/`
4. Add the plugin to your `plugins.ini` file:
```
c4_sound_site.amxx
```

## Configuration

### ConVars

```c
// Enables the plugin.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
amx_c4ptc_enabled "1"
```

### Compiler Options

The plugin source code includes compiler options that can be modified before compiling:

```c
// Enable if you want to unprecache the game's stock C4 beeping sounds
// Since beeps will be handled by the plugin these are not needed anymore
// This action will effectively free you up 4 sound resource slots in the server
// However, enabling this will break custom maps and plugins that make use of these  
// By the nature of these sounds it's extremely unlikely though
#define UNPRECACHE_SOUNDS   1
```