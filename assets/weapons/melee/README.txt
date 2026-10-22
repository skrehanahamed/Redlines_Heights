PSX Melee Weapons Free
======================

A PS1-style kitchen knife, crowbar, steel pipe and flashlight that swing, the flashlight lighting
too, and a training dummy to hit, taken from PSX Melee Weapons (21 weapons and tools, 33
animations): https://heyheythere.itch.io/psx-melee-weapons
Low-poly, one 512x512 point-filtered texture atlas, the shading baked into vertex colours,
real-world scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per prop, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per prop, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per prop, still (any 3D app)
textures/   atlas.png, the one texture every prop uses
icons/      an inventory icon per prop, 256x256 PNG with transparency
props.json  every prop: title, group, size, triangles, parts and animations, and each weapon's data
blender/    every prop in one .blend, the atlas packed in
addons/     the Godot addon, psx_melee_weapons/: this folder is a Godot 4.3+ project that opens on
            its gallery (.gdignore keeps Godot out of the other folders)

The weapons
-----------
A weapon stands upright with its origin in the grip, where the hand holds it, the knife's point
and the flashlight's lens the way the model faces. Its entry in props.json has a "melee" with:
  swing, hit, reach   the animation of a blow, how far into it (0 to 1) the blow lands, and how far
                      it reaches in metres
  use, toggle         the animation of its use, and whether that turns it on with its first half
                      and off with its second (the flashlight)
  light, glow         the light it casts while on (spot, where in its own space, Blender's axes:
                      metres, +Z up, forward to -Y; range, angle, colour, energy) and the parts
                      that glow (the lens)
The crowbar and flashlight are PSX Horror Props' own, to hold:
https://heyheythere.itch.io/psx-horror-props

Each of the four weapons also comes in first-person hands with fitted sleeves: fp_kitchen_knife,
fp_crowbar, fp_steel_pipe and fp_flashlight. Their origin is the eye; put one under your camera
and play its idle, draw, swing or stab, use (where supported), or inspect clip. These view models
are not pickups: the loose weapon is the world item. The range equips the version with hands.

Godot 4.3 and later
-------------------
For first-person models, rotate the scene 180 degrees around Y under your camera, set the
near clip to 0.01 m and disable the held model colliders.

Copy addons/psx_melee_weapons/ into your project's addons/ folder. Each prop is a scene in props/:
drag it into your level, or under your camera for a weapon in hand. It has a box collider
(StaticBody3D) on each of its parts (free them on a weapon in hand). A prop with animations has an
AnimationPlayer; the flashlight has a light on its body, "Light", off:

    crowbar.get_node("AnimationPlayer").play("swing")   # crowbar: the crowbar in your player's hand

Every weapon has pickup.gd, an item to take; inspect.gd holds one up to turn over. icons/ has the
inventory icons. demo/gallery.tscn shows every prop: drag to turn, arrows to browse, A for all of
them at once, G for the range: WASD and the mouse, left click to swing, right click to use, the
wheel or 1-9 to change, Esc to leave. demo/gallery.gd is how it holds, swings and lights them.
The props use one material, props.tres: the atlas times the vertex colours, lit, so the
flashlight and your own lights fall on them. For the full PS1 look (vertex snap, affine textures,
240p, dither), our PSX Look shaders turn them over in one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the props through it (P toggles it).
PSX Melee Weapons uses the same addon folder: it installs over this one.

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material.

Animations
----------
kitchen knife (stab), crowbar (swing, pry), steel pipe (swing), flashlight (swing, switch) and
training dummy (hit).

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
