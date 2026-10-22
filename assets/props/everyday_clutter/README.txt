PSX Everyday Clutter Free
=========================

12 PS1-style household props, taken from PSX Everyday Clutter (194 props, 51 of them working):
https://heyheythere.itch.io/psx-everyday-clutter
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
addons/     the Godot addon, psx_everyday_clutter/: this folder is a Godot 4.3+ project that opens
            on its gallery (.gdignore keeps Godot out of the other folders)

Placing them
------------
Pivots sit on the floor or the surface the prop rests on. A prop faces +Z in Godot (-Y in
Blender).

Godot 4.3 and later
-------------------
Catalog and individual prop views have no distance fog; walking demos retain their atmosphere.
Copy addons/psx_everyday_clutter/ into your project's addons/ folder. Each prop is a scene in
props/: drag it into your level. It has a box collider (StaticBody3D) on each of its parts, and
the moving parts' colliders move with them. A prop with animations has an AnimationPlayer:

    shoebox.get_node("AnimationPlayer").play("open")   # shoebox: the prop in your level

The lava lamp, the camcorder, the cassette player, the power drill and the shoebox are machines: their
scene root has machine.gd. The lava lamp starts lit and flowing and a use switches it off, the
next on again; the drill starts still and a use sets its chuck spinning; the others open on a use
and shut on the next.

    lava_lamp.use()   # what the player's use key calls

demo/gallery.tscn shows every prop: drag to turn, arrows to browse, A for all of them at once.
The props use one material, props.tres: the atlas times the vertex colours, lit, so your lights
and flashlights fall on them; the lava lamp's glow is unshaded, so it shows in the dark. For the
full PS1 look (vertex snap, affine textures, 240p, dither), our PSX Look shaders turn them over in
one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the props through it (P toggles it).
PSX Everyday Clutter uses the same addon folder: it installs over this one.

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material. The lava lamp's glowing blobs are parts of their own
(lava_lamp_lamp_1 to 4): hide them to switch it off.

Animations
----------
The lava lamp: flow. The camcorder, the cassette player and the shoebox: open. The power drill: spin.

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
