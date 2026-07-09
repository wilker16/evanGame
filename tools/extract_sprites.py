#!/usr/bin/env python3
"""Cut Evan's drawings out of the photos to make transparent game sprites.

Usage: python3 tools/extract_sprites.py
Reads art/originals/*.jpg, writes art/monster_spiky.png and art/monster_penguin.png
plus art/preview_*.png composites over a checkerboard for eyeballing the result.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = __file__.rsplit("/tools/", 1)[0]


def local_background(gray: np.ndarray, radius: int = 61) -> np.ndarray:
    """Estimate paper brightness per-pixel with a big median blur, so creases,
    shadows and uneven lighting cancel out when we divide by it."""
    img = Image.fromarray(gray.astype(np.uint8))
    bg = img.filter(ImageFilter.MedianFilter(radius))
    return np.asarray(bg).astype(np.float32)


def soft_alpha(strength: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """Map a 0..1 'ink-ness' map to alpha with a soft ramp between lo and hi."""
    a = (strength - lo) / (hi - lo)
    return np.clip(a, 0.0, 1.0)


def crop_to_content(rgba: np.ndarray, pad: int = 12) -> np.ndarray:
    ys, xs = np.where(rgba[:, :, 3] > 20)
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad, rgba.shape[0])
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad, rgba.shape[1])
    return rgba[y0:y1, x0:x1]


def despeckle(alpha: np.ndarray, min_px: int = 120) -> np.ndarray:
    """Drop tiny disconnected blobs (paper specks, dust)."""
    solid = alpha > 40
    labels, n = ndimage.label(solid)
    if n == 0:
        return alpha
    sizes = ndimage.sum(solid, labels, range(1, n + 1))
    keep = np.isin(labels, np.where(sizes >= min_px)[0] + 1)
    out = alpha.copy()
    out[~keep] = 0
    return out


def shrink(rgba: np.ndarray, max_dim: int = 800) -> np.ndarray:
    """Downscale so the web build stays light; in-game size is ~250px anyway."""
    h, w = rgba.shape[:2]
    s = max_dim / max(h, w)
    if s >= 1.0:
        return rgba
    img = Image.fromarray(rgba).resize((int(w * s), int(h * s)), Image.LANCZOS)
    return np.asarray(img)


def checker_preview(rgba: np.ndarray, path: str, cell: int = 24) -> None:
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    checker = np.where(((yy // cell + xx // cell) % 2) == 0, 200, 150).astype(np.uint8)
    bg = np.stack([checker] * 3, axis=-1).astype(np.float32)
    a = rgba[:, :, 3:4].astype(np.float32) / 255.0
    comp = rgba[:, :, :3].astype(np.float32) * a + bg * (1 - a)
    Image.fromarray(comp.astype(np.uint8)).save(path)


def extract_spiky() -> None:
    img = Image.open(f"{ROOT}/art/originals/spiky_monster_photo.jpg")
    # The drawing sits in the middle of the landscape photo.
    img = img.crop((980, 640, 2720, 2000))
    rgb = np.asarray(img).astype(np.float32)
    gray = rgb.mean(axis=2)
    bg = local_background(gray)
    ratio = gray / np.maximum(bg, 1.0)  # <1 where darker than local paper
    ink = 1.0 - ratio
    alpha = (soft_alpha(ink, 0.10, 0.35) * 255).astype(np.uint8)
    alpha = despeckle(alpha, min_px=600)

    # Darken strokes a touch so faint pencil reads on screen.
    stroke = np.clip(rgb * 0.55, 0, 255).astype(np.uint8)
    rgba = np.dstack([stroke, alpha])
    rgba = shrink(crop_to_content(rgba))
    Image.fromarray(rgba).save(f"{ROOT}/art/monster_spiky.png")
    checker_preview(rgba, f"{ROOT}/art/originals/preview_spiky.png")
    print("spiky:", rgba.shape)


def extract_penguin() -> None:
    img = Image.open(f"{ROOT}/art/originals/penguin_photo.jpg")
    # Portrait photo; penguin + its little ground mound in the middle.
    img = img.crop((820, 1300, 1620, 2820))
    rgb = np.asarray(img).astype(np.float32)
    gray = rgb.mean(axis=2)
    bg = local_background(gray)
    ratio = gray / np.maximum(bg, 1.0)
    darkness = 1.0 - ratio

    # Colour strokes (yellow chest, orange beak, blue eye) are barely darker
    # than paper, so also key on saturation.
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    saturation = (mx - mn) / np.maximum(mx, 1.0)

    ink = np.maximum(soft_alpha(darkness, 0.06, 0.30), soft_alpha(saturation, 0.10, 0.30))
    mask = ink > 0.35
    # Solidify the body: close small gaps, then fill enclosed holes.
    mask = ndimage.binary_closing(mask, structure=np.ones((9, 9)))
    mask = ndimage.binary_fill_holes(mask)
    alpha = np.where(mask, np.maximum(ink, 0.85), ink * 0.0)
    alpha = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    alpha = despeckle(alpha, min_px=4000)

    stroke = np.clip(rgb * 0.8, 0, 255).astype(np.uint8)
    rgba = np.dstack([stroke, alpha])
    rgba = shrink(crop_to_content(rgba))
    Image.fromarray(rgba).save(f"{ROOT}/art/monster_penguin.png")
    checker_preview(rgba, f"{ROOT}/art/originals/preview_penguin.png")
    print("penguin:", rgba.shape)


if __name__ == "__main__":
    extract_spiky()
    extract_penguin()
