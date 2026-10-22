PSX Tech Base Kit Free
======================

16 modular PS1-style pieces to build a retro FPS base room, taken from PSX Tech Base Kit (127
pieces for a military base: two-storey arenas, slime and lava pits, key doors and card readers, a
lift, a teleporter, the gateway, pickups, a level to solve):
https://heyheythere.itch.io/psx-tech-base-kit
Low-poly, one point-filtered texture atlas, the shading baked into vertex colours, real-world
scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per piece, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per piece, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per piece, still (any 3D app)
textures/   atlas.png, the one texture every piece uses, and the seamless tech and floor
            textures it tiles from, 128x128 a metre, for your own geometry
icons/      an icon per piece, 256x256 PNG with transparency
props.json  every piece: title, group, size, triangles, parts and animations
blender/    every piece in one .blend, the atlas packed in
addons/     the Godot addon, psx_tech_base_kit/: this folder is a Godot 4.3+ project that
            opens on its gallery (.gdignore keeps Godot out of the other folders)
unity/      a .unitypackage for Unity 6.3+ (Built-in and URP): prefabs, colliders, animation
            clips, a PSX shader and a demo scene

The grid
--------
Everything snaps to a 2 m grid, a storey 3 m high. A floor piece covers one 2 x 2 m cell, its
pivot at the cell's centre on the floor. A wall is 2 m long and 0.2 m thick, centred on a cell's
edge, its front facing -Y in Blender (+Z in Godot, -Z in Unity); turn it 90 degrees for the other
edges. A post fills the corner where two walls turn. The sliding doors go at the same point and
turn as their doorway. The button, the light and the sign have their backs on the wall's face.

Godot 4.3 and later
-------------------
Copy addons/psx_tech_base_kit/ into your project's addons/ folder. Each piece is a scene in
props/: drag it into your level and turn on grid snapping at 1 m. It has a box collider
(StaticBody3D) on each of its parts: the doorway's leaves the way through clear, the doors' move
with them. A piece with animations has an AnimationPlayer:

    door.get_node("AnimationPlayer").play("open")   # door: the piece in your level

The doors and the button are machines: their scene roots have machine.gd. A use slides the doors
open, or shut; the button sinks in and lights. Wire the doors to the button in the inspector
(needs), or in code:

    door.needs = [door.get_path_to(button)]   # button, door: the pieces in your level

demo/gallery.tscn shows every piece: drag to turn, arrows to browse, A for all of them.
PSX Tech Base Kit uses the same addon folder: it installs over this one.
The catalog is lit without distance fog so the whole collection stays visible.
The pieces use one material, props.tres: the atlas times the vertex colours, lit, so your lights
fall on them. For the full PS1 look (vertex snap, affine textures, 240p, dither), our PSX Look
shaders turn them over in one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the pieces through it (P toggles it).

Unity 6.3 and later
-------------------
Import the .unitypackage in unity/. Every piece is a prefab in Assets/PSXTechBaseKitFree/Prefabs/.
Demo/L_Demo.unity shows the pieces; Documentation.txt describes its controls.

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material.

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
