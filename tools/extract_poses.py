#!/usr/bin/env python3
"""Extract individual pose sprites from the three character sprite sheets."""
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

ART  = Path("/home/user/evanGame/art")
ORIG = ART / "originals"

# ── Morphological cleanup ────────────────────────────────────────────────────

def morph_open(img_rgba, radius=2):
    """Erode then dilate the alpha channel to remove isolated speckle noise."""
    r, g, b, a = img_rgba.split()
    for _ in range(radius):
        a = a.filter(ImageFilter.MinFilter(3))   # erode
    for _ in range(radius):
        a = a.filter(ImageFilter.MaxFilter(3))   # dilate
    return Image.merge("RGBA", (r, g, b, a))

# ── Background removal ───────────────────────────────────────────────────────

def remove_bg_dark(cell_img, threshold=80):
    """Black background → transparent. Keep pixels brighter than threshold."""
    arr = np.array(cell_img.convert("RGB"), dtype=np.int32)
    lum = arr[:,:,0] + arr[:,:,1] + arr[:,:,2]
    alpha = np.where(lum > threshold, 255, 0).astype(np.uint8)
    rgba = np.dstack([arr[:,:,:3].astype(np.uint8), alpha])
    img = Image.fromarray(rgba, "RGBA")
    return morph_open(img, radius=2)

def remove_bg_robot(cell_img):
    """Remove the blue-gray background from the robot photo sprite sheet.
    The background is ~(R=186, G=202, B=216) — blue-gray from phone-camera lighting.
    Character has: dark pencil strokes (brightness<145) and saturated color accents (sat>55)."""
    arr = np.array(cell_img.convert("RGB"), dtype=np.float32)
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    brightness = (r + g + b) / 3.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    saturation = mx - mn
    # Keep dark pencil strokes OR colored accents (yellow joints, red marks)
    is_fg = (brightness < 148) | (saturation > 55)
    alpha = np.where(is_fg, 255, 0).astype(np.uint8)
    rgba = np.dstack([arr.astype(np.uint8), alpha])
    img = Image.fromarray(rgba, "RGBA")
    return morph_open(img, radius=2)

def auto_crop(img, margin=12):
    """Trim transparent edges and add a small margin."""
    arr = np.array(img)
    a = arr[:,:,3]
    rows = np.where(np.any(a > 20, axis=1))[0]
    cols_idx = np.where(np.any(a > 20, axis=0))[0]
    if not len(rows):
        return img
    h, w = arr.shape[:2]
    r0 = max(0, rows[0] - margin)
    r1 = min(h, rows[-1] + margin + 1)
    c0 = max(0, cols_idx[0] - margin)
    c1 = min(w, cols_idx[-1] + margin + 1)
    return img.crop((c0, r0, c1, r1))

def skip_top_label(img_rgba, min_gap_rows=6, max_label_frac=0.40):
    """
    Skip label text at the top of a cell.
    Only scans the top max_label_frac of the image for a gap — this avoids
    misidentifying gaps between robot limbs (which appear lower in the cell).
    """
    arr = np.array(img_rgba)
    alpha = arr[:,:,3]
    row_has_content = np.any(alpha > 20, axis=1)
    h = arr.shape[0]
    search_limit = int(h * max_label_frac)

    content_rows = np.where(row_has_content)[0]
    if not len(content_rows):
        return img_rgba

    first_content = int(content_rows[0])
    i = first_content
    while i < search_limit:
        if not row_has_content[i]:
            gap_start = i
            while i < h and not row_has_content[i]:
                i += 1
            gap_end = i
            if gap_end - gap_start >= min_gap_rows and gap_end < search_limit:
                return img_rgba.crop((0, gap_end, img_rgba.size[0], h))
        else:
            i += 1
    return img_rgba  # no label-gap found — keep as-is

# ── Grid extractor ───────────────────────────────────────────────────────────

def extract_grid(img_path, cols, rows, poses, remove_fn,
                 top_frac=0.0, bot_frac=0.0,
                 left_frac=0.0, right_frac=0.0,
                 global_top=0, global_bottom=0, skip_label=False):
    """Split img into a cols×rows grid.  poses is a flat list in row-major order.
    skip_label: if True, use gap-detection to strip text labels at the top of each cell."""
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size

    if global_top > 0:
        img = img.crop((0, global_top, w, h))
        h -= global_top
    if global_bottom > 0:
        img = img.crop((0, 0, w, h - global_bottom))
        h -= global_bottom

    cw, ch = w // cols, h // rows
    print(f"  {img_path.name}: {w}×{h} → cells {cw}×{ch}")

    results = {}
    for idx, pose in enumerate(poses):
        row, col = divmod(idx, cols)
        x0 = col * cw
        y0 = row * ch
        ix0 = x0 + int(cw * left_frac)
        iy0 = y0 + int(ch * top_frac)
        ix1 = (x0 + cw) - int(cw * right_frac)
        iy1 = (y0 + ch) - int(ch * bot_frac)
        cell = img.crop((ix0, iy0, ix1, iy1))
        bg_removed = remove_fn(cell)
        if skip_label:
            bg_removed = skip_top_label(bg_removed, min_gap_rows=6)
        cropped = auto_crop(bg_removed)
        results[pose] = cropped
        print(f"    [{row},{col}] {pose}: {cropped.size}")
    return results

# ── Spiky Monster ─────────────────────────────────────────────────────────────
print("\nExtracting SPIKY poses...")
spiky = extract_grid(
    ORIG / "2edfe3db-6826-4ff4-abfa-e42b1876a7af.jpg",
    cols=3, rows=2,
    poses=["stand", "walk", "punch", "crouch", "jump", "hurt"],
    remove_fn=remove_bg_dark,
    top_frac=0.02, bot_frac=0.24,
)
for pose, img in spiky.items():
    p = ART / f"spiky_{pose}.png"
    img.save(p); print(f"  → {p}")

# ── Penguin ───────────────────────────────────────────────────────────────────
print("\nExtracting PENGUIN poses...")
penguin = extract_grid(
    ORIG / "Gemini_Generated_Image_3l2z7r3l2z7r3l2z.png",
    cols=2, rows=3,
    poses=["stand", "walk", "punch", "crouch", "jump", "hurt"],
    remove_fn=remove_bg_dark,
    top_frac=0.04, bot_frac=0.24,
)
for pose, img in penguin.items():
    p = ART / f"penguin_{pose}.png"
    img.save(p); print(f"  → {p}")

# ── Robot / Mech ──────────────────────────────────────────────────────────────
# Photo is taken from a tablet — the top ~60px has a dark device-bezel shadow.
print("\nExtracting ROBOT poses...")
robot = extract_grid(
    ORIG / "Gemini_Generated_Image_f2pj66f2pj66f2pj.png",
    cols=2, rows=3,
    poses=["stand", "walk", "punch", "jump", "crouch", "hurt"],
    remove_fn=remove_bg_robot,
    top_frac=0.22, bot_frac=0.06,
    left_frac=0.06, right_frac=0.06,
    global_top=160, global_bottom=145,  # strip bezel shadow above, desk below
)
for pose, img in robot.items():
    p = ART / f"robot_{pose}.png"
    img.save(p); print(f"  → {p}")

print("\nAll done!")
