# Assets from the game aren't included in this repo, move an Export_Sprites (with bounds) here and run this to copy assets to the correct folder.
# ALSO ADD .gdignore to your Export_Sprites before opening godot or it'll import the stuff!!

# Requires pillow

import shutil
from pathlib import Path

from PIL import Image

export = Path("Export_Sprites/")
out = Path("assets/chicory/")

dog_animations = [
    "idle",
    "run", 
    "runup",
    "walk",
    "walkup",
    "jump",
    "hop_up", # for now i only want these while i get stuff ready for other anims
    "hop_down",
    "sit",
    # "doze",
    # "snooze",
    # "knockdown",
    # "phone",
    # "pet",
    # "item",
    # "transit",
    # "slouch",
    # "smit",
    # "droop",
    # "startled",
    # "lean",
    # "gasp",
    # "hit",
    # "toes",
    # "lay",
    # "hero",
    # "think",
    # "letter",
    # "tense",
    # "shake",
    # "breathe",
    # "look",
    # "floatstart", "float", "floatstop"
]

if not (export / ".gdignore").exists() or list(export.glob("*.import")):
    y = input(".gdignore does not exist, or a .import file exists in Export_Sprites. Create a .gdignore and delete all .import files? (y/n) ") == "y"
    if not y:
        exit()
    if not (export / ".gdignore").exists():
        (export / ".gdignore").touch()
    for i in export.glob("*.import"):
        i.unlink()

for anim in dog_animations:
    for fp in export.glob(f"sprDog_{anim}_*.png"):
        split = fp.stem.split("_")
        layer = split[-2]
        frame = int(split[-1])
        new = out / "dog" / anim / layer / f"{frame:02}.png"
        if anim == "idle":
            new_small = new
            new_small.parent.mkdir(parents=True, exist_ok=True)
            Image.open(fp).resize((150, 150)).save(new_small)
            new = out / "dog" / "idle_big" / layer / f"{frame:02}.png"
        new.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(fp, new)

for fp in export.glob("sprDog_hat_*"): # do something about 89 (horns 2)? and also hair?
    split = fp.stem.split("_")
    frame = int(split[-1])
    new_small = out / "hat" / f"{frame:02}.png"
    new_small.parent.mkdir(parents=True, exist_ok=True)
    Image.open(fp).resize((150, 150)).save(new_small)
    new = out / "hat_big" / f"{frame:02}.png"
    new.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(fp, new)

for fp in export.glob("sprDog_body_*"):
    split = fp.stem.split("_")
    frame = int(split[-1])
    new_small = out / "clothes" / f"{frame:02}.png"
    new_small.parent.mkdir(parents=True, exist_ok=True)
    Image.open(fp).resize((150, 150)).save(new_small)
    new = out / "clothes_big" / f"{frame:02}.png"
    new.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(fp, new)

for fp in export.glob("sprDog_body2_*"): # fix this ALSO add small
    continue
    split = fp.stem.split("_")
    frame = int(split[-1])
    new = out / "clothes" / f"{frame:02}_2.png"
    new.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(fp, new)

for fp in export.glob("sprDog_expression_*.png"):
    split = fp.stem.split("_")
    frame = int(split[-1]) + 1 # for normal
    new = out / "expression" / f"{frame:02}.png"
    new.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(fp, new)

# im = Image.new("RGBA", (12*4, 12*4), color=(0,0,0,0))
# for i, fp in enumerate(sorted(export.glob("sprMsquare_*.png"), key=lambda a: int(a.stem.split("_")[-1]))):
#     frame = int(fp.stem.split("_")[-1])
#     im2 = Image.open(fp)
#     im.paste(im2, ((i+1) % 4 * 12, (i+1)//4 * 12))

#     # new = out / "paint" / f"{frame:02}.png"
#     # new.parent.mkdir(parents=True, exist_ok=True)
#     # shutil.copy(fp, new)

# im.save(out / "paint.png")

shutil.copy(export / "sprRainbownoise_0.png", out / "paintnoise.png")

for fp in export.glob("sprBrush_*.png"):
    frame = int(fp.stem.split("_")[-1])
    new = out / "brush" / f"{frame}.png"
    new.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(fp, new)

head = export / "sprDog_head_0.png"
im = Image.new("RGBA", (750, 750))
im2 = Image.open(head)
im.paste(im2, box=(150, 50))
im.save(out / "expression" / "0_big.png")
im.resize((150, 150)).save(out / "expression" / "0.png")