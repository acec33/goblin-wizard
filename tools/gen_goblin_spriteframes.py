#!/usr/bin/env python3
"""Generate a Godot 4 SpriteFrames .tres for the Goblin from the files on disk.

Handles multiple animation variants per direction:
  run_<dir>_<n>   (running + running_alt, n = variant index)
  slash_<dir>_<n> (slash_attack variants)
  idle_<dir>      (single rotation still)
The goblin script picks a random variant per direction at play time.
"""
import os, glob, re

BASE = "Assets/Goblin"
RES = "res://Assets/Goblin"
OUT = "Assets/Goblin/goblin_frames.tres"
DIRS = ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]

def hy(d):
    return d.replace("_", "-")

def frames_in(folder):
    return sorted(glob.glob(f"{folder}/frame_*.png"))

anims = []  # (name, [disk paths], loop, speed)

# --- RUN: running/animations/*/<dir> (primary) + running_alt/<dir>[-hex] (alts) ---
for d in DIRS:
    h = hy(d)
    variants = []
    for folder in sorted(glob.glob(f"{BASE}/running/animations/*/{h}")):
        f = frames_in(folder)
        if f:
            variants.append(f)
    alt_root = f"{BASE}/running_alt"
    if os.path.isdir(alt_root):
        for name in sorted(os.listdir(alt_root)):
            full = f"{alt_root}/{name}"
            if os.path.isdir(full) and (name == h or re.fullmatch(re.escape(h) + r"-[0-9a-fA-F]{4,}", name)):
                f = frames_in(full)
                if f:
                    variants.append(f)
    for i, f in enumerate(variants):
        anims.append((f"run_{d}_{i}", f, True, 10.0))

# --- SLASH: slash_attack/animations/<dir>[number] ---
slash_root = f"{BASE}/slash_attack/animations"
for d in DIRS:
    h = hy(d)
    matched = []
    if os.path.isdir(slash_root):
        for name in sorted(os.listdir(slash_root)):
            full = f"{slash_root}/{name}"
            if os.path.isdir(full) and re.fullmatch(re.escape(h) + r"\d*", name):
                f = frames_in(full)
                if f:
                    matched.append(f)
    for i, f in enumerate(matched):
        anims.append((f"slash_{d}_{i}", f, False, 12.0))

# --- IDLE: running/rotations/<dir>.png single still ---
for d in DIRS:
    still = f"{BASE}/running/rotations/{hy(d)}.png"
    if os.path.exists(still):
        anims.append((f"idle_{d}", [still], True, 5.0))

# ---- write the .tres ----
def respath(p):
    return RES + p[len(BASE):]

order, id_for = [], {}
for _n, frames, _l, _s in anims:
    for f in frames:
        rp = respath(f)
        if rp not in id_for:
            id_for[rp] = f"{len(order) + 1}_f"
            order.append(rp)

ext_lines = [f'[ext_resource type="Texture2D" path="{rp}" id="{id_for[rp]}"]' for rp in order]

blocks = []
for name, frames, loop, speed in anims:
    fr = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % id_for[respath(f)] for f in frames)
    blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                  % (fr, "true" if loop else "false", name, f"{speed}"))

out = (f'[gd_resource type="SpriteFrames" load_steps={len(order) + 1} format=3]\n\n'
       + "\n".join(ext_lines) + "\n\n[resource]\nanimations = [" + ", ".join(blocks) + "]\n")
with open(OUT, "w") as fh:
    fh.write(out)

print(f"Wrote {OUT}")
print(f"  textures: {len(order)}")
print(f"  animations ({len(anims)}):")
for n, *_ in anims:
    print("   ", n)
