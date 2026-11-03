# SCons profile for the Godot export templates we compile ourselves (the F-Droid
# APK, every CI export and the bots on main and pull requests:
# .github/scripts/build-stripped-template.sh, .github/workflows/build.yml): turns off the engine parts the game
# never uses, for a smaller binary. For templates only, never the editor build
# (the editor imports the SVG art and needs its importers). Pass it as
# profile=<path to this file>; compilation_profile.gdbuild beside it goes in as
# build_profile=<path>.
#
# Kept on because the game needs them: gdscript, enet and multiplayer (LAN
# co-op), noise (FastNoiseLite in the map generator), regex (name checks),
# webp (imported textures are stored as lossless WebP), freetype and brotli
# (fonts, including the built-in default one), mbedtls, the advanced GUI
# (RichTextLabel, SpinBox, TextEdit, FileDialog) and the OpenGL driver.
#
# A script that uses a class removed here fails at runtime, not at build time:
# after using a new engine class or module, check it is not switched off here.
# The stripped bots in CI catch what a bot reaches. Changing this file (or
# compilation_profile.gdbuild) makes CI rebuild every template: hours.

# 2D only, no physics bodies (pathing is AStarGrid2D), no navigation servers.
disable_3d = "yes"
disable_physics_2d = "yes"
disable_physics_3d = "yes"
disable_navigation_2d = "yes"
disable_navigation_3d = "yes"
disable_xr = "yes"

# GL Compatibility renderer on every platform.
vulkan = "no"

# No ZIPReader / ZIPPacker.
minizip = "no"

module_basis_universal_enabled = "no"
module_bcdec_enabled = "no"
module_bmp_enabled = "no"
module_camera_enabled = "no"
module_csg_enabled = "no"
module_dds_enabled = "no"
module_gltf_enabled = "no"
module_godot_physics_2d_enabled = "no"
module_godot_physics_3d_enabled = "no"
module_gridmap_enabled = "no"
module_hdr_enabled = "no"
module_interactive_music_enabled = "no"
module_jolt_physics_enabled = "no"
module_jpg_enabled = "no"
module_jsonrpc_enabled = "no"
module_ktx_enabled = "no"
module_mobile_vr_enabled = "no"
module_mp3_enabled = "no"
module_msdfgen_enabled = "no"
module_navigation_2d_enabled = "no"
module_navigation_3d_enabled = "no"
module_objectdb_profiler_enabled = "no"
module_ogg_enabled = "no"
module_openxr_enabled = "no"
module_raycast_enabled = "no"
module_svg_enabled = "no"
module_tga_enabled = "no"
module_theora_enabled = "no"
module_upnp_enabled = "no"
module_visual_shader_enabled = "no"
module_vorbis_enabled = "no"
module_webrtc_enabled = "no"
module_websocket_enabled = "no"
module_webxr_enabled = "no"
module_zip_enabled = "no"

# The fallback text server instead of the advanced one is smaller (no ICU,
# no HarfBuzz) but can't lay out right-to-left or complex scripts, e.g. in a
# player or village name. Off for now; uncomment both lines to switch.
# module_text_server_adv_enabled = "no"
# module_text_server_fb_enabled = "yes"
