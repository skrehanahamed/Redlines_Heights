PSX Metro Kit Free
==================

15 modular PS1-style pieces to build a Soviet metro platform, taken from PSX Metro Kit (112 pieces
for the whole station, from the street to the tunnels: the hall, the tracks and tunnels, a train,
the escalators, the vestibule, the duty room and the street, working machines, a level to walk and
solve):
https://heyheythere.itch.io/psx-metro-kit
Low-poly, one point-filtered texture atlas, the shading baked into vertex colours, real-world
scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per piece, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per piece, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per piece, still (any 3D app)
textures/   atlas.png, the one texture every piece uses, and the seamless wall and floor
            textures it tiles from, 128x128 a metre, for your own geometry
icons/      an icon per piece, 256x256 PNG with transparency
props.json  every piece: title, group, size, triangles, parts and animations
blender/    every piece in one .blend, the atlas packed in
addons/     the Godot addon, psx_metro_kit/: this folder is a Godot 4.3+ project that opens on
            its gallery (.gdignore keeps Godot out of the other folders)

The grid
--------
Everything snaps to a 2 m grid, the hall 4 m high. A floor or ceiling piece covers one 2 x 2 m
cell, its pivot at the cell's centre on the floor (the ceiling hangs 4 m above its pivot). A wall
is 2 m long and 0.2 m thick, centred on a cell's edge, its front facing -Y in Blender (+Z in
Godot, -Z in Unity); turn it 90 degrees for the other edges. A post or the column fills the corner
where walls meet. The track lies in a 4 m bay beside the platform's edge, its pivot on the
trackbed in the bay's middle, 1.35 m under the platform; the track walls stand on the trackbed and
rise to the hall's ceiling. The station name and the fire cabinet go against a wall, 0.1 m off
its line.

Godot 4.3 and later
-------------------
Copy addons/psx_metro_kit/ into your project's addons/ folder. Each piece is a scene in props/:
drag it into your level and turn on grid snapping at 1 m. It has a box collider (StaticBody3D) on
each of its parts. A piece with animations has an AnimationPlayer:

    cabinet.get_node("AnimationPlayer").play("open")   # cabinet: the fire hose cabinet in your level

An animation plays there and back (the cabinet opens and shuts): pause it halfway to leave it
open.
demo/gallery.tscn shows every piece: drag to turn, arrows to browse, A for all of them.
PSX Metro Kit uses the same addon folder: it installs over this one.
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
