## Sacred Fruit Game Constants
## Centralized definitions for layer masks, z-indices, UI dimensions, physics, and timings.
## This reduces magic numbers throughout the codebase and makes tuning easier.

class_name Constants
extends Node

# ============================================================================
# CANVAS LAYER ASSIGNMENTS
# ============================================================================
# Layers control the rendering order and interaction depth of 2D UI elements.
# Lower numbers render first (behind), higher numbers render last (in front).

## Crosshair UI layer (player HUD overlay)
const LAYER_CROSSHAIR: int = 10

## Dialogue UI panel layer (NPC conversation interface)
const LAYER_DIALOGUE_UI: int = 30

## Sandstorm/weather overlay effect layer
const LAYER_WEATHER_OVERLAY: int = 60

## Photo mode menu layer (camera tools, settings)
const LAYER_PHOTO_MENU: int = 100

## Runtime debug HUD - perf overlay (performance budgets, metrics)
const LAYER_DEBUG_PERF_HUD: int = 120

## Runtime debug HUD - AI state overlay (controller state, patrol routes)
const LAYER_DEBUG_AI_HUD: int = 121

# ============================================================================
# UI Z-INDEX ASSIGNMENTS
# ============================================================================
# Z-index controls layering within CanvasLayers. Higher = rendered on top.
# Used for photo mode toolbar/filmstrip and guide overlays.

## Photo mode guides (grid, golden ratio, etc.) - background layer
const ZINDEX_PHOTO_GUIDES_BG: int = -1

## Photo mode toolbar and filmstrip - top layer
const ZINDEX_PHOTO_TOOLBAR: int = 200

# ============================================================================
# UI DIMENSIONS & SPACING
# ============================================================================
# Hardcoded offsets, paddings, and corner radii for UI elements.

## Dialogue panel corner radius (pixels)
const DIALOGUE_CORNER_RADIUS: int = 10

## Dialogue choice button corner radius (pixels)
const DIALOGUE_CHOICE_CORNER_RADIUS: int = 6

## Photo mode root margin offset from top (pixels)
const PHOTO_ROOT_MARGIN_OFFSET_TOP: float = 76.0

## Photo mode root padding (left/top offsets, pixels)
const PHOTO_ROOT_PADDING: float = 10.0

# ============================================================================
# CAMERA & PHOTOGRAPHY SETTINGS
# ============================================================================
# Default values for camera FOV, ISO, shutter speed, etc.

## Gameplay camera default field of view (degrees)
const GAMEPLAY_DEFAULT_FOV: float = 90.0

## Photo mode camera default FOV (degrees)
const PHOTO_DEFAULT_FOV: float = 70.0

## Photo mode default ISO setting
const PHOTO_DEFAULT_ISO: float = 400.0

## Photo mode ISO for bright lighting (overexposed)
const PHOTO_ISO_BRIGHT: float = 100.0

## Photo mode reference ISO for exposure calculations
const PHOTO_REFERENCE_ISO: float = 200.0

# ============================================================================
# DIALOGUE SYSTEM
# ============================================================================
# Pacing and reveal rates for dialogue text and character animation.

## Dialogue text reveal rate (characters per second)
const DIALOGUE_REVEAL_RATE: float = 90.0

# ============================================================================
# PHYSICS & MOVEMENT
# ============================================================================
# Player movement, collision, and physics constants.

## Air control movement coefficient multiplier
## Applied as: k = 32.0 * AIR_CONTROL * dot_val * dot_val * delta
## Affects how responsive air strafing/mid-air control feels
const PLAYER_AIR_CONTROL_MULTIPLIER: float = 32.0

# ============================================================================
# WEATHER & PARTICLE EFFECTS
# ============================================================================
# Sandstorm and weather particle system configuration.

## Sandstorm particle spread (normal/default mode, pixels)
const SANDSTORM_SPREAD_NORMAL: float = 25.0

## Sandstorm particle spread (rain mode, pixels)
const SANDSTORM_SPREAD_RAIN: float = 12.0

## Color component normalization divisor (RGB 0-255 to 0-1)
## Used to convert 8-bit color channels to normalized floats
const COLOR_COMPONENT_NORMALIZE: float = 255.0

# ============================================================================
# DEBUG & LOGGING
# ============================================================================
# Tuning parameters for debug systems and performance monitoring.

## Photo mode layout debug print interval (seconds)
## How often to dump layout state when enable_layout_debug_print is true
const PHOTO_LAYOUT_DEBUG_INTERVAL: float = 2.0

## I/O trace ring buffer capacity (number of events)
## Maximum events stored in IOManager trace history
const IO_TRACE_CAPACITY: int = 256
