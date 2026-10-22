PSX Mall Kit Free
=================

15 modular PS1-style pieces to build a corner of a supermarket, taken from PSX Mall Kit (192
supermarket and mall pieces, escalators, shutters, a food court, a laundromat, working machines,
a level to walk and solve):
https://heyheythere.itch.io/psx-mall-kit
Low-poly, one 1024x1024 point-filtered texture atlas, the shading baked into vertex colours,
real-world scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per piece, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per piece, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per piece, still (any 3D app)
textures/   atlas.png, the one texture every piece uses, and the seamless floor, wall and
            ceiling textures it tiles from, 128x128 a metre, for your own geometry
icons/      an icon per piece, 256x256 PNG with transparency
props.json  every piece: title, group, size, triangles, parts and animations
blender/    every piece in one .blend, the atlas packed in
addons/     the Godot addon, psx_mall_kit/: this folder is a Godot 4.3+ project that opens on
            its gallery (.gdignore keeps Godot out of the other folders)

The grid
--------
Everything snaps to a 2 m grid, 3 m high. A floor or ceiling piece covers one 2 x 2 m cell, its
pivot at the cell's centre on the floor (a ceiling hangs 3 m above its pivot, so both go at the
same point). A wall is 2 m long and 0.2 m thick, centred on a cell's edge, its front facing -Y in
Blender (+Z in Godot, -Z in Unity); turn it 90 degrees for the other edges. A post fills the corner
where walls meet. The opening wall is 4 m long, its pivot on the corner between two edges, the
supermarket behind it; the entrance, the sliding doors and the sign go at its point and turn. The
freezer doors go against a wall, 0.1 m off its line.

Godot 4.3 and later
-------------------
Copy addons/psx_mall_kit/ into your project's addons/ folder. Each piece is a scene in props/:
drag it into your level and turn on grid snapping at 1 m. It has a box collider (StaticBody3D) on
each of its parts: the opening's leave the way through clear and the doors' move with them. A
piece with animations has an AnimationPlayer:

    doors.get_node("AnimationPlayer").play("open")   # doors: the sliding doors in your level

An animation plays there and back (the doors part and close): pause it halfway to leave them open.
The checkout's belt loops instead.
demo/gallery.tscn shows every piece: drag to turn, arrows to browse, A for all of them.
PSX Mall Kit uses the same addon folder: it installs over this one.
The pieces use one material, props.tres: the atlas times the vertex colours, lit, so your lights
fall on them. For the full PS1 look (vertex snap, affine textures, 240p, dither), our PSX Look
shaders turn them over in one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the pieces through it (P toggles it).

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material.

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
