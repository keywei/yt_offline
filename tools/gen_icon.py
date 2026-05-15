"""Generate the launcher icon assets for yt_offline.

Design: deep tech-void background with subtle radial bloom, faint grid,
two concentric rings, and a neon-cyan eighth note in the centre.

Writes:
  assets/icon.png            (1024x1024, opaque) — legacy launcher
  assets/icon_foreground.png (1024x1024, alpha)  — adaptive foreground

Run:  python tools/gen_icon.py
"""

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
NEON = (0, 230, 255)
NEON_GLOW = (60, 180, 255)
BG_TOP = (12, 10, 36)
BG_BOTTOM = (1, 1, 8)


def _vertical_gradient() -> Image.Image:
    bg = Image.new('RGB', (SIZE, SIZE))
    draw = ImageDraw.Draw(bg)
    for y in range(SIZE):
        t = y / SIZE
        c = (
            int(BG_TOP[0] * (1 - t) + BG_BOTTOM[0] * t),
            int(BG_TOP[1] * (1 - t) + BG_BOTTOM[1] * t),
            int(BG_TOP[2] * (1 - t) + BG_BOTTOM[2] * t),
        )
        draw.line([(0, y), (SIZE, y)], fill=c)
    return bg


def _radial_bloom(canvas: Image.Image) -> Image.Image:
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for radius, alpha in [(440, 22), (340, 30), (240, 38), (140, 52)]:
        gd.ellipse(
            [SIZE // 2 - radius, SIZE // 2 - radius,
             SIZE // 2 + radius, SIZE // 2 + radius],
            fill=(40, 100, 220, alpha),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=40))
    return Image.alpha_composite(canvas.convert('RGBA'), glow)


def _grid(canvas: Image.Image) -> Image.Image:
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    color = (60, 100, 180, 14)
    spacing = 80
    for i in range(0, SIZE + 1, spacing):
        draw.line([(i, 0), (i, SIZE)], fill=color, width=1)
        draw.line([(0, i), (SIZE, i)], fill=color, width=1)
    return Image.alpha_composite(canvas, overlay)


def _rings(canvas: Image.Image) -> Image.Image:
    overlay = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse([90, 90, SIZE - 90, SIZE - 90],
                 outline=(0, 200, 230, 70), width=3)
    draw.ellipse([180, 180, SIZE - 180, SIZE - 180],
                 outline=(80, 160, 240, 36), width=2)
    return Image.alpha_composite(canvas, overlay)


def _make_note() -> Image.Image:
    """An eighth note in NEON colour, no glow yet, transparent background."""
    # Head — tilted ellipse via rotation.
    cx, cy = 430, 660
    head = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(head).ellipse(
        [cx - 140, cy - 95, cx + 140, cy + 95],
        fill=NEON + (255,),
    )
    head = head.rotate(-22, center=(cx, cy), resample=Image.BICUBIC)

    # Stem + flag on their own layer (compose at the end — Image.alpha_composite
    # returns a NEW image, so the ImageDraw must target the final layer).
    sf = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    sf_draw = ImageDraw.Draw(sf)
    stem_x = cx + 110
    stem_top = 240
    stem_bot = cy - 30
    sf_draw.rectangle([stem_x - 14, stem_top, stem_x + 14, stem_bot],
                      fill=NEON + (255,))
    flag = [
        (stem_x, stem_top),
        (stem_x + 180, stem_top + 70),
        (stem_x + 200, stem_top + 200),
        (stem_x + 160, stem_top + 250),
        (stem_x + 14, stem_top + 120),
        (stem_x + 14, stem_top),
    ]
    sf_draw.polygon(flag, fill=NEON + (255,))

    note = Image.alpha_composite(head, sf)
    return note


def _overlay_with_glow(canvas: Image.Image, note: Image.Image) -> Image.Image:
    """Composite the note with two halo passes (outer wide, inner tight)."""
    _, _, _, a = note.split()
    # Halo tinted to NEON_GLOW, alpha capped so it doesn't burn out.
    halo = Image.merge('RGBA', (
        Image.new('L', (SIZE, SIZE), NEON_GLOW[0]),
        Image.new('L', (SIZE, SIZE), NEON_GLOW[1]),
        Image.new('L', (SIZE, SIZE), NEON_GLOW[2]),
        a.point(lambda v: min(180, v)),
    ))
    outer = halo.filter(ImageFilter.GaussianBlur(radius=55))
    inner = halo.filter(ImageFilter.GaussianBlur(radius=18))
    canvas = Image.alpha_composite(canvas, outer)
    canvas = Image.alpha_composite(canvas, inner)
    canvas = Image.alpha_composite(canvas, note)
    return canvas


def render() -> None:
    note = _make_note()

    # Legacy full icon (opaque background).
    full = _vertical_gradient()
    full = _radial_bloom(full)
    full = _grid(full)
    full = _rings(full)
    full = _overlay_with_glow(full, note)
    full.convert('RGB').save('assets/icon.png', 'PNG')

    # Adaptive foreground (transparent background, just the note + glow).
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    fg = _overlay_with_glow(fg, note)
    fg.save('assets/icon_foreground.png', 'PNG')


if __name__ == '__main__':
    render()
    print('Wrote assets/icon.png + assets/icon_foreground.png')
