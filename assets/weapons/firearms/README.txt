PSX Firearms Free
=================

A PS1-style pistol and pump shotgun whose parts move, with their ammo, a magazine, a shell and a
steel target, taken from PSX Firearms (14 guns, 33 animations):
https://heyheythere.itch.io/psx-firearms
Low-poly, one 512x512 point-filtered texture atlas, the shading baked into vertex colours,
real-world scale (1 unit = 1 metre).

Both guns include an animated first-person view model (fp_pistol and fp_pump_shotgun):
origin at the eye, hands and fitted sleeves, idle, draw, fire, reload and inspect clips.
Put the view model under your camera at its origin, rotated 180 degrees around Y in Godot.
The shotgun also has its pump clip; the supporting hand follows the pump.

What's in the zip
-----------------
glb/        one file per prop, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per prop, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per prop, still (any 3D app)
textures/   atlas.png, the one texture every prop uses
icons/      an inventory icon per prop, 256x256 PNG with transparency
props.json  every prop: title, group, size, triangles, parts and animations, and each gun's data
blender/    every prop in one .blend, the atlas packed in
addons/     the Godot addon, psx_firearms/: this folder is a Godot 4.3+ project that opens on
            its gallery (.gdignore keeps Godot out of the other folders)

The guns
--------
A gun stands upright with its origin in the grip, where the hand holds it, and its muzzle the way
the model faces. Its entry in props.json has a "gun" with:
  muzzle, sight   points in the gun's own space (Blender's axes: metres, +Z up, the muzzle to -Y)
  ammo, rounds    the ammo prop it takes and how many rounds it holds
  fire, cycle     the animation of a shot, and the one after it (the shotgun's pump), if any
  reload          the animation that reloads it, if it has one
The ammo boxes and the shell are PSX Horror Props' own: https://heyheythere.itch.io/psx-horror-props

Godot 4.3 and later
-------------------
For first-person models, rotate the scene 180 degrees around Y under your camera, set the
near clip to 0.01 m and disable the held model colliders.

Copy addons/psx_firearms/ into your project's addons/ folder. Each prop is a scene in props/:
drag it into your level, or under your camera for a gun in hand. It has a box collider
(StaticBody3D) on each of its parts, and the moving parts' colliders move with them (free them
on a gun in hand). A prop with animations has an AnimationPlayer:

    pistol.get_node("AnimationPlayer").play("reload")   # pistol: the gun in your player's hand

icons/ has the inventory icons. demo/gallery.tscn shows every prop: drag to turn, arrows to
browse, A for all of them at once, G for the range: WASD and the mouse, left click to fire, right
click to aim, R to reload, I to inspect, the wheel or 1-9 to change guns, Esc to leave. demo/gallery.gd is how
it holds, fires and reloads them.
The props use one material, props.tres: the atlas times the vertex colours, lit, so your lights
and muzzle flashes fall on them. For the full PS1 look (vertex snap, affine textures, 240p,
dither), our PSX Look shaders turn them over in one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the props through it (P toggles it).
PSX Firearms uses the same addon folder: it installs over this one.

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material.

Animations
----------
pistol (fire, reload), pump shotgun (fire, pump) and steel target (hit).
fp_pistol (idle, draw, fire, reload, inspect); fp_pump_shotgun adds its pump clip.

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
