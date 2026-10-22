PSX Survival Pickups Free
=========================

15 PS1-style survival-horror items to pick up and inspect, taken from PSX Survival Pickups (69
pickups, a Unity package, a demo level to walk): https://heyheythere.itch.io/psx-survival-pickups
Low-poly, one 1024x1024 point-filtered texture atlas, the shading baked into vertex colours,
real-world scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per item, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per item, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per item, still (any 3D app)
textures/   atlas.png, the one texture every item uses
icons/      an inventory icon per item, 256x256 PNG with transparency
props.json  every item: title, group, size, triangles, parts, animations, and its pickup (the item
            it gives, how many, its title and text, the clip an inspect plays)
blender/    every item in one .blend, the atlas packed in
addons/     the Godot addon, psx_survival_pickups/: this folder is a Godot 4.3+ project that opens
            on its gallery (.gdignore keeps Godot out of the other folders)

Items
-----
Each pickup gives an item by name: first_aid_kit, pill_bottle, note, diary and ink_ribbon are PSX
Horror UI's icon names too, and the ammo boxes give PSX Firearms' ammo_9mm (15) and ammo_12ga (8).
PSX Horror UI: https://heyheythere.itch.io/psx-horror-ui
PSX Firearms:  https://heyheythere.itch.io/psx-firearms

Godot 4.3 and later
-------------------
Copy addons/psx_survival_pickups/ into your project's addons/ folder. Each item is a scene in
props/ with a box collider (StaticBody3D) on each of its parts. Its scene root has pickup.gd, set
up in the inspector: its kind (item, save or storage), the item it gives and how many, its title
and text, and its reveal, the clip an inspect plays. Use it with the player's items, an Array of
names:

    $Key.picked.connect(func(item): print("got ", item))
    $Key.use(items)          # an item: into items, and gone
    $Typewriter.use(items)   # a save: takes an ink_ribbon from items, types, emits saved
    $ItemBox.use(items)      # storage: opens, and shuts on the next use

inspect.gd holds an item up close over the game, to turn with the mouse or the arrows and read; E
plays its reveal, Esc puts it away:

    var inspect := preload("res://addons/psx_survival_pickups/inspect.gd").new()
    add_child(inspect)
    inspect.open($Diary)
    await inspect.closed

demo/gallery.tscn shows every item: drag to turn, arrows to browse, A for all of them, I to
inspect. PSX Survival Pickups uses the same addon folder: it installs over this one.
The items use one material, props.tres: the atlas times the vertex colours, lit, so your lights
and torches fall on them. For the full PS1 look (vertex snap, affine textures, 240p, dither), our
PSX Look shaders turn them over in one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the items through it (P toggles it).

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material.

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
