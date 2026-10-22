PSX Japanese Town Kit Free
==========================

15 modular PS1-style pieces to build a Japanese street corner, taken from PSX Japanese Town Kit
(213 pieces for a whole country town of the late Showa era: houses, shops, a konbini, apartments,
a shrine, the railway and its level crossing, working machines, a level to walk and solve):
https://heyheythere.itch.io/psx-japanese-town-kit
Low-poly, one point-filtered texture atlas, the shading baked into vertex colours, real-world
scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per piece, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per piece, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per piece, still (any 3D app)
textures/   atlas.png, the one texture every piece uses, and the seamless wall and ground
            textures it tiles from, 128x128 a metre, for your own geometry
icons/      an icon per piece, 256x256 PNG with transparency
props.json  every piece: title, group, size, triangles, parts and animations
blender/    every piece in one .blend, the atlas packed in
addons/     the Godot addon, psx_japanese_town_kit/: this folder is a Godot 4.3+ project that
            opens on its gallery (.gdignore keeps Godot out of the other folders)

The grid
--------
Everything snaps to a 2 m grid, the walls 3 m high. The lane and the gravel are 4 x 4 m tiles,
their pivot at the tile's centre on the ground. A wall is 2 m long and 0.2 m thick, centred on a
cell's edge, its front facing -Y in Blender (+Z in Godot, -Z in Unity); turn it 90 degrees for
the other edges. A post fills the corner where walls meet. The block wall stands 1.55 m, the
gatepost by its gap. The utility pole's wires run 8 m along +X to the next pole.

Godot 4.3 and later
-------------------
Copy addons/psx_japanese_town_kit/ into your project's addons/ folder. Each piece is a scene in
props/: drag it into your level and turn on grid snapping at 1 m. It has a box collider
(StaticBody3D) on each of its parts. A piece with animations has an AnimationPlayer:

    machine.get_node("AnimationPlayer").play("press")   # machine: the vending machine in your level

demo/gallery.tscn shows every piece: drag to turn, arrows to browse, A for all of them.
PSX Japanese Town Kit uses the same addon folder: it installs over this one.
The pieces use one material, props.tres: the atlas times the vertex colours, lit, so your lights
fall on them. For the full PS1 look (vertex snap, affine textures, 240p, dither), our PSX Look
shaders turn them over in one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the pieces through it (P toggles it).

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material.

The Japanese lettering is drawn from k8x12 by Num Kadoma (littlelimit.net): "Unlimited permission
is granted to use, copy, and distribute it, with or without modification, either commercially
and noncommercially."

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
