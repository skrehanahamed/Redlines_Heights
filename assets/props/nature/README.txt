PSX Nature Free
===============

15 PS1-style pieces for a desert, taken from PSX Nature (205 pieces for the desert, the snow, the
swamp, the jungle and its beach, the savanna, autumn and the alpine, 45 ground and water tiles, a
level to walk):
https://heyheythere.itch.io/psx-nature
Low-poly, one point-filtered texture atlas, the shading baked into vertex colours, real-world
scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per piece, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per piece, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per piece, still (any 3D app)
textures/   atlas.png, the one texture every piece uses, and the seamless sand and cracked earth,
            128x128 for 2 m, for your own terrain
icons/      an icon per piece, 256x256 PNG with transparency
props.json  every piece: title, group, size, triangles, parts and animations
blender/    every piece in one .blend, the atlas packed in
addons/     the Godot addon, psx_nature/: this folder is a Godot 4.3+ project that opens on its
            gallery (.gdignore keeps Godot out of the other folders)

Placing them
------------
Pivots sit on the ground at a piece's foot; trunks and cacti go a little into it, so they stand
on uneven ground too. The ground tiles are 4 by 4 m, their top 1 cm up, and meet any way round:
lay them on a 4 m grid and turn them freely. The edge tile has sand to its front and cracked earth
from 0.5 m past its middle. The mesa cliff is 4 m wide, to line up with the tiles, its front
facing -Y in Blender (+Z in Godot, -Z in Unity).

Godot 4.3 and later
-------------------
Copy addons/psx_nature/ into your project's addons/ folder. Each piece is a scene in props/: drag
it into your level and turn on grid snapping at 1 m for the tiles. It has a box collider
(StaticBody3D) on each of its parts; the agave, the tumbleweed and the skull have none, to walk
through. The Joshua tree has an AnimationPlayer, and its sway loops:

    joshua_tree.get_node("AnimationPlayer").play("sway")   # joshua_tree: the piece in your level

demo/gallery.tscn shows every piece: drag to turn, arrows to browse, A for all of them.
PSX Nature uses the same addon folder: it installs over this one.
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
