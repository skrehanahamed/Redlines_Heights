PSX Animals Free
================

A PS1-style rabbit and crow with 6 animations each, taken from PSX Animals (14 animals, 84
animations): https://heyheythere.itch.io/psx-animals
Low-poly, one 1024x1024 point-filtered texture atlas, the shading baked into vertex colours,
real-world scale (1 unit = 1 metre).

What's in the zip
-----------------
glb/        one file per animal, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per animal, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per animal, in its bind pose (any 3D app)
textures/   atlas.png, the one texture every animal uses
icons/      an icon per animal, 256x256 PNG with transparency
props.json  every animal: title, group, size, triangles, parts and animations
blender/    both animals in one .blend, the atlas packed in
addons/     the Godot addon, psx_animals/: this folder is a Godot 4.3+ project that opens on
            its gallery (.gdignore keeps Godot out of the other folders)

The animals
-----------
Each is rigid parts that turn at their joints, the way PS1 animals were made, rigged: one mesh on an
armature, each part weighted whole to its bone (a foot under its shin, under its leg, under the
body), so turning one carries the ones below it. Each is bound as it stands, its bones named for its
joints. Its origin is on the ground under it, and it faces Blender's -Y (+Z in Godot and Unity).
Every animal has the same six animations:
  idle            a loop: the rabbit nibbles, the crow pecks
  walk, run       loops; they play in place, for your code to move the animal
  attack          a bite or a peck, once
  hit             a flinch, once, back to where it started
  death           a fall, once, ending on its side
Their lengths are in props.json.

Godot 4.3 and later
-------------------
Copy addons/psx_animals/ into your project's addons/ folder. Each animal is a scene in props/:
drag it into your level. It has its mesh on a Skeleton3D, a box collider (StaticBody3D) on each bone
that moves with it, and an AnimationPlayer:

    rabbit.get_node("AnimationPlayer").play("run")   # rabbit: an instance of props/rabbit.tscn

icons/ has the icons. demo/gallery.tscn shows every animal: drag to turn, arrows to browse, its
buttons to play its animations, A for all of them at once.
The animals use one material, props.tres: the atlas times the vertex colours, lit, so your
lights fall on them. For the full PS1 look (vertex snap, affine textures, 240p, dither), our PSX
Look shaders turn them over in one line: https://heyheythere.itch.io/psx-look
With PSX Look in res://addons/psx_look/, the gallery shows the animals through it (P toggles it).

Other engines and apps
----------------------
Use fbx/, glb/ or obj/ with textures/atlas.png. Set the texture's filtering to nearest/point and
turn off mipmaps for the crisp PS1 texels, and multiply it by the vertex colours (the baked
shading) in your material.

License: see LICENSE.txt. Made by heyheythere: https://heyheythere.itch.io

The rabbit has modeled eyes carried by its head bone.
