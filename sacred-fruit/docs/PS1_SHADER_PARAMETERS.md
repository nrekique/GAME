# PS1 Shader Parameters

The PS1 retro look is controlled by a number of exported variables in
`res://scripts/ps1_shader_manager.gd`.  Tweak these values at runtime or set them on a
`GAME` autoload node to change the appearance globally.

| Property | Description | Range / default |
|----------|-------------|-----------------|
| `enable_ps1_geometry_shader` | Toggle the whole effect on/off | bool, `true`
| `vertex_snap` | Quantize world‑space vertex positions to this grid size | `32–1024` (`320`)
| `color_steps` | Number of posterization color levels | `2–64` (`32`)
| `posterize_strength` | How strongly colors are stepped | `0.0–1.0` (`0.35`)
| `affine_warp` | Distort UVs to simulate PS1 affine texture mapping | `0.0–1.0` (`0.08`)
| `uv_jitter` | Per‑vertex UV jitter amplitude | `0.0–0.02` (`0.0006`)
| `jitter_depth_independent` | Apply jitter regardless of depth | bool, `true`
| `jitter_z_coordinate` | Include z axis in jitter | bool, `false`
| `affine_texture_mapping` | Enable affine texture mode | bool, `false`
| `affine_mapping_strength` | Strength of affine mapping | `0.0–1.0` (`0.0`)
| `alpha_scissor_threshold` | Cut out alpha below this value | `0.0–1.0` (`0.0`)
| `dithering_enabled` | Enable color dithering | bool, `true`
| `dither_strength` | Dither intensity | `0.0–2.0` (`1.2`)
| `dither_resolution_scale` | Scale factor for dither texture resolution | `1–8` (`2`)
| `light_dither_enabled` | Enable lighting dither | bool, `true`
| `light_dither_texture` | Custom dither texture (Texture2D) | —
| `light_dither_scale` | Scale factor for lighting dither texture | `0.1–16.0` (`1.0`)
| `light_dither_strength` | Lighting dither intensity | `0.0–1.0` (`0.2`)
| `light_dither_levels` | Number of dither levels for lighting | `1–16` (`5`)

### Notes

- Enabling `enable_ps1_geometry_shader` loads `res://shaders/ps1_geometry.gdshader` at
  runtime.  If the shader file is missing, a warning is printed.
- Global shader parameters such as `dither_texture` and `dither_levels` are set via
  `RenderingServer.global_shader_parameter_set` and require the corresponding project
  settings (`rendering/global_shader_parameters/...`) to exist.

Adjust parameters live in the editor using the `GAME` autoload or via worldspawn
properties (`sf_ps1_shader`, `sf_ps1_dither_strength`, etc.).
