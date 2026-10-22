PSX Building Kit Free
=====================

16 modular PS1-style pieces to build a brick cottage, taken from PSX Building Kit (113 pieces for
any house, shop or block: walls in five finishes, doors, windows, stairs, railings, roofs, a level
to walk): https://heyheythere.itch.io/psx-building-kit
Low-poly, one point-filtered texture atlas, the shading baked into vertex colours, real-world
scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per piece, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per piece, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per piece, still (any 3D app)
textures/   atlas.png, the one texture every piece uses, and the seamless floor, wall and roof
            textures it tiles from, 128x128 a metre, for your own geometry
icons/      an icon per piece, 256x256 PNG with transparency
props.json  every piece: title, group, size, triangles, parts and animations
blender/    every piece in one .blend, the atlas packed in
addons/     the Godot addon, psx_building_kit/: this folder is a Godot 4.3+ project that opens
            on its gallery (.gdignore keeps Godot out of the other folders)

The grid
--------
Everything snaps to a 2 m grid, 3 m high. A floor piece covers one 2 x 2 m cell, its pivot at the
cell's centre on the floor; the grass is 4 x 4 m. A wall is 2 m long and 0.2 m thick, centred on
a cell's edge, its front facing -Y in Blender (+Z in Godot, -Z in Unity), the brick in front and
the plaster behind; turn it 90 degrees for the other edges, to face out. A post fills the corner
where two walls turn. The door and the window go at the same point and turn as their wall. The
roof spans a cottage two cells deep: put it on the walls' tops (3 m) over each cell along the
ridge, on the edge between the two cells; each end wall takes the gable and the verge over it, at
3 m, turned to face out, and the chimney goes on the ridge with the roof. The lantern goes on the
wall's line by the door, turned to face out.

Godot 4.3 and later
-------------------
Copy addons/psx_building_kit/ into your project's addons/ folder. Each piece is a scene in
props/: drag it into your level and turn on grid snapping at 1 m. It has a box collider
(StaticBody3D) on each of its parts: the doorway's leave the way through clear and the door's
move with it. A piece with animations has an AnimationPlayer:

    door.get_node("AnimationPlayer").play("open")   # door: the piece in your level

The door opens and stays open: play it backwards to shut it.
demo/gallery.tscn shows every piece: drag to turn, arrows to browse, A for all of them.
PSX Building Kit uses the same addon folder: it installs over this one.
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
