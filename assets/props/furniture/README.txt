PSX Furniture Free
==================

36 PS1-style household props to furnish a room, taken from PSX Furniture (476 props, 157
animations): https://heyheythere.itch.io/psx-furniture
Low-poly, one 1024x1024 point-filtered texture atlas, the shading baked into vertex colours,
real-world scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per prop, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per prop, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per prop, still (any 3D app)
textures/   atlas.png, the one texture every prop uses
icons/      an icon per prop, 256x256 PNG with transparency
props.json  every prop: title, group, size, triangles, parts and animations
blender/    every prop in one .blend, the atlas packed in
addons/     the Godot addon, psx_furniture/: this folder is a Godot 4.3+ project that opens on its
            gallery (.gdignore keeps Godot out of the other folders)

Placing them
------------
Pivots sit on the floor, or on the wall for wall-mounted props (their back on the wall's face).
The wall and floor are 2 m pieces, the wall 3 m high.

Godot 4.3 and later
-------------------
Catalog and individual prop views have no distance fog; walking demos retain their atmosphere.
Copy addons/psx_furniture/ into your project's addons/ folder. Each prop is a scene in props/:
drag it into your level. It has a box collider (StaticBody3D) on each of its parts, and the moving
parts' colliders move with them. A prop with animations has an AnimationPlayer:

    fridge_white.get_node("AnimationPlayer").play("open")   # fridge_white: the prop in your level

An animation plays there and back (a door opens and shuts): pause it halfway to leave it open.
demo/gallery.tscn shows every prop: drag to turn, arrows to browse, A for all of them at once.
The props use one material, props.tres: the atlas times the vertex colours, lit, so your lights
and flashlights fall on them. For the full PS1 look (vertex snap, affine textures, 240p, dither),
our PSX Look shaders turn them over in one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the props through it (P toggles it).
PSX Furniture uses the same addon folder: it installs over this one.

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material.

Animations
----------
nightstand, wardrobe, base unit, sink unit, wall cabinet, stove, fridge and kettle (open), TV
(turn), phone (lift), open box (close) and wall clock (tick, hours).

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
