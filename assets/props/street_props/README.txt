PSX Street Props Free
=====================

12 PS1-style props for a street, taken from PSX Street Props (157 props, 49 of them working):
https://heyheythere.itch.io/psx-street-props
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
addons/     the Godot addon, psx_street_props/: this folder is a Godot 4.3+ project that opens on
            its gallery (.gdignore keeps Godot out of the other folders)

Placing them
------------
Pivots sit on the ground. A prop faces +Z in Godot (-Y in Blender). The pavement is 2 by 2 m and
15 cm up, its kerb towards the road; the road is 6 m across, in 4 m lengths to lay end to end.
They match PSX Vehicles' pavement and road.

Godot 4.3 and later
-------------------
Copy addons/psx_street_props/ into your project's addons/ folder. Each prop is a scene in props/:
drag it into your level. It has a box collider (StaticBody3D) on each of its parts, and the moving
parts' colliders move with them. A prop with animations has an AnimationPlayer:

    dumpster_green.get_node("AnimationPlayer").play("open")   # dumpster_green: the prop in your level

The street lamp, the dumpster and the wheelie bin are machines: their scene root has machine.gd.
The lamp starts lit and a use switches it off, the next on again; the bins' lids open on a use
and shut on the next.

    dumpster_green.use()   # what the player's use key calls

demo/gallery.tscn shows every prop: drag to turn, arrows to browse, A for all of them at once.
The props use one material, props.tres: the atlas times the vertex colours, lit, so your lights
and flashlights fall on them; the lamp's glow is unshaded, so it shines in the dark. For the full
PS1 look (vertex snap, affine textures, 240p, dither), our PSX Look shaders turn them over in one
line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the props through it (P toggles it).
PSX Street Props uses the same addon folder: it installs over this one.

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material. The lamp's glow is a part of its own (lamp_cobra_lamp) over the lens:
hide it to switch the lamp off.

Animations
----------
The dumpster and the wheelie bin: open.

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
