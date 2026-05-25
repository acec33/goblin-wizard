#!/usr/bin/env python3
"""Generate a Godot 4 SpriteFrames .tres for the blue-ninja from the files on disk."""
import os, glob

BASE = "Assets/blue-ninja"
RES = "res://Assets/blue-ninja"
OUT = "Assets/blue-ninja/blue_ninja_frames.tres"
DIRS = ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]

def hy(d):
    return d.replace("_", "-")

# (name, [disk paths], loop, speed)
anims = []

# --- walk: 8 directions ---
for d in DIRS:
    frames = sorted(glob.glob(f"{BASE}/walk/animations/walk/{hy(d)}/frame_*.png"))
    if frames:
        anims.append((f"walk_{d}", frames, True, 10.0))

# --- idle: animated south + stills for the rest ---
breath = sorted(glob.glob(f"{BASE}/Idle/animations/Breathing_Idle-2e7cd0e8/south/frame_*.png"))
for d in DIRS:
    if d == "south" and breath:
        anims.append(("idle_south", breath, True, 6.0))
    else:
        still = f"{BASE}/Idle/rotations/{hy(d)}.png"
        if os.path.exists(still):
            anims.append((f"idle_{d}", [still], True, 5.0))

# --- punch: left + right ---
for hand in ["left", "right"]:
    frames = sorted(glob.glob(f"{BASE}/punch/animations/punch/punch-{hand}/frame_*.png"))
    if frames:
        anims.append((f"punch_{hand}", frames, False, 14.0))

def respath(p):
    return RES + p[len(BASE):]

# unique textures -> ids, in first-seen order
order, id_for = [], {}
for _name, frames, _loop, _speed in anims:
    for f in frames:
        rp = respath(f)
        if rp not in id_for:
            id_for[rp] = f"{len(order) + 1}_f"
            order.append(rp)

ext_lines = [f'[ext_resource type="Texture2D" path="{rp}" id="{id_for[rp]}"]' for rp in order]

blocks = []
for name, frames, loop, speed in anims:
    fr = ", ".join(
        '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % id_for[respath(f)]
        for f in frames
    )
    blocks.append(
        '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
        % (fr, "true" if loop else "false", name, f"{speed}")
    )

out = (
    f"[gd_resource type=\"SpriteFrames\" load_steps={len(order) + 1} format=3]\n\n"
    + "\n".join(ext_lines)
    + "\n\n[resource]\nanimations = ["
    + ", ".join(blocks)
    + "]\n"
)
with open(OUT, "w") as fh:
    fh.write(out)

print(f"Wrote {OUT}")
print(f"  textures: {len(order)}")
print(f"  animations ({len(anims)}): " + ", ".join(n for n, *_ in anims))
