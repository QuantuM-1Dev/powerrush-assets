"""Remove the green background from the item art, then make:
  out/<name>.png        transparent 512x512 inventory icon
  out/<name>_dark.png   dark silhouette for undiscovered Index entries
Background is removed by flood-filling from the image edges (it stops at the dark outline),
plus enclosed holes that are clearly background colour. Edge pixels are un-mixed from the
green so there's no green fringe."""
import numpy as np, os, sys, glob
from PIL import Image
from scipy import ndimage

SRC, OUT = "src", "out"
os.makedirs(OUT, exist_ok=True)
SIZE, MARGIN = 512, 0.05
DARK = (28, 30, 44)

def process(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = im.shape
    edge = np.concatenate([im[:8].reshape(-1, 3), im[-8:].reshape(-1, 3), im[:, :8].reshape(-1, 3), im[:, -8:].reshape(-1, 3)])
    bg = np.median(edge, axis=0)
    d = np.linalg.norm(im - bg, axis=2)

    near = d < 70
    lab, n = ndimage.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgmask = np.isin(lab, list(border))
    # enclosed holes: very close to bg colour and not tiny
    sizes = ndimage.sum(np.ones_like(lab), lab, index=np.arange(n + 1))
    tight = d < 32
    for i in range(1, n + 1):
        if i in border or sizes[i] < 120:
            continue
        comp = lab == i
        if tight[comp].mean() > 0.6:
            bgmask |= comp

    # soft alpha on a thin band around the background
    band = ndimage.binary_dilation(bgmask, iterations=3) & ~bgmask
    alpha = np.ones((h, w), np.float32)
    alpha[bgmask] = 0
    a_band = np.clip((d - 40) / (130 - 40), 0, 1)
    alpha[band] = a_band[band]

    # un-mix green from partially transparent edge pixels
    rgb = im.copy()
    m = (alpha > 0.02) & (alpha < 0.999)
    a = alpha[m][:, None]
    rgb[m] = np.clip((im[m] - (1 - a) * bg) / a, 0, 255)
    # remove leftover green spill on the band
    sp = band & (alpha > 0)
    g = rgb[..., 1]
    lim = np.maximum(rgb[..., 0], rgb[..., 2]) + 10
    g[sp] = np.minimum(g[sp], lim[sp])

    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    img = img.crop(bbox)
    side = int(max(img.size) * (1 + 2 * MARGIN))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.size[0]) // 2, (side - img.size[1]) // 2))
    icon = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    name = os.path.splitext(os.path.basename(path))[0]
    icon.save(os.path.join(OUT, name + ".png"))

    al = np.asarray(icon.getchannel("A"))
    dark = np.zeros((SIZE, SIZE, 4), np.uint8)
    dark[..., 0], dark[..., 1], dark[..., 2] = DARK
    dark[..., 3] = al
    Image.fromarray(dark, "RGBA").save(os.path.join(OUT, name + "_dark.png"))
    return name, float((alpha == 0).mean())

for f in sorted(glob.glob(os.path.join(SRC, "*.png"))):
    n, frac = process(f)
    print(f"{n}: {frac*100:.0f}% removed")
