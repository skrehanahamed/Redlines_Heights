Retro FPS Textures Free
=======================

16 textures in the look of the mid-90s PC shooters, taken from Retro FPS Textures (141 textures):
https://heyheythere.itch.io/retro-fps-textures
Every one is an indexed PNG on the same 256-colour palette, lightly ordered-dithered, at 64 pixels
to the metre, and again at 32. Walls, floors and ceilings tile seamlessly both ways, the trim
sideways; the door, the switches and the blood splat don't tile, and the splat has on-or-off
transparency.

What's in the zip
-----------------
textures/64/   every texture by category, 64 px a metre: most are 64x64, the door 64x128,
               a switch 32x32
textures/32/   the same at half the size
palette/       the palette: palette.png (16 x 16 swatches, in index order) and
               retro-fps-textures.gpl for GIMP, Aseprite and Krita, to paint your own art on it
addons/        the Godot addon, retro_fps_textures/: this folder is a Godot 4.3+ project that opens
               on its demo room (.gdignore keeps Godot out of the other folders)

Godot 4.3 and later
-------------------
Copy addons/retro_fps_textures/ into your project's addons/ folder. materials/ has a
StandardMaterial3D per texture: point filtered without mipmaps, repeating, lit by your lights, the
splat an alpha-scissor cutout. Drag one onto a mesh. To tile a texture once a metre, give your
mesh UVs in metres, or set the material's UV1 scale (or Triplanar) to fit.
demo/room.tscn is a room to try them in: pick a surface with up / down, its texture with left /
right, Space for the next set of them.
Retro FPS Textures uses the same addon folder: it installs over this one.

Other engines and apps
----------------------
Use textures/64/ or textures/32/. Set the filtering to nearest/point, mipmaps and compression off
and repeat (wrap) on. For the splat, use alpha test / cutout (alpha clip at 0.5).

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
