#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
PUBLIC = ROOT / "Website" / "public"
ICONSET = ASSETS / "PasteV.iconset"


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def gradient(size, start, end):
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            t = (x * 0.38 + y * 0.62) / size
            color = tuple(int(start[i] * (1 - t) + end[i] * t) for i in range(3)) + (255,)
            pixels[x, y] = color
    return image


def draw_icon(size):
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    bg = gradient(size, (43, 36, 27), (15, 42, 36))
    bg.putalpha(rounded_mask(size, int(size * 0.215)))
    image.alpha_composite(bg)

    draw = ImageDraw.Draw(image)

    def box(x1, y1, x2, y2):
        return tuple(int(v * scale) for v in (x1, y1, x2, y2))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(box(232, 214, 792, 838), radius=int(84 * scale), fill=(0, 0, 0, 115))
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(2, int(26 * scale))))
    image.alpha_composite(shadow, (0, int(28 * scale)))

    paper = gradient(size, (255, 242, 196), (215, 196, 139))
    paper_mask = Image.new("L", (size, size), 0)
    pm = ImageDraw.Draw(paper_mask)
    pm.rounded_rectangle(box(232, 214, 792, 838), radius=int(84 * scale), fill=255)
    paper.putalpha(paper_mask)
    image.alpha_composite(paper)

    draw.rounded_rectangle(box(388, 150, 636, 272), radius=int(38 * scale), fill=(23, 20, 15, 255))
    draw.arc(box(434, 84, 590, 240), start=190, end=350, fill=(246, 200, 76, 255), width=max(2, int(42 * scale)))
    draw.line(box(396, 220, 628, 220), fill=(91, 215, 164, 255), width=max(2, int(32 * scale)))

    line_color = (111, 97, 64, 185)
    draw.line(box(328, 306, 696, 306), fill=line_color, width=max(2, int(34 * scale)))
    draw.line(box(328, 418, 602, 418), fill=(111, 97, 64, 128), width=max(2, int(34 * scale)))
    draw.line(box(328, 530, 540, 530), fill=(111, 97, 64, 105), width=max(2, int(34 * scale)))

    bolt = [(648, 384), (426, 596), (558, 596), (494, 742), (716, 514), (584, 514)]
    bolt = [(int(x * scale), int(y * scale)) for x, y in bolt]
    draw.polygon(bolt, fill=(91, 215, 164, 255))
    draw.line(bolt + [bolt[0]], fill=(23, 20, 15, 255), width=max(2, int(24 * scale)), joint="curve")
    draw.polygon([(int(x * scale), int(y * scale)) for x, y in [(648, 384), (426, 596), (558, 596)]], fill=(246, 200, 76, 255))

    return image


def draw_template(size):
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    s = size / 32
    color = (0, 0, 0, 255)
    draw.rounded_rectangle((8*s, 8*s, 24*s, 27*s), radius=3*s, outline=color, width=max(1, int(2*s)))
    draw.rounded_rectangle((11*s, 5*s, 21*s, 11*s), radius=2*s, outline=color, width=max(1, int(2*s)))
    draw.line((12*s, 14*s, 20*s, 14*s), fill=color, width=max(1, int(2*s)))
    bolt = [(20*s, 15*s), (13*s, 21*s), (17*s, 21*s), (15*s, 26*s), (23*s, 18*s), (19*s, 18*s)]
    draw.polygon(bolt, fill=color)
    return image


def main():
    ASSETS.mkdir(exist_ok=True)
    PUBLIC.mkdir(parents=True, exist_ok=True)
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir()

    icon_sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for name, size in icon_sizes.items():
        draw_icon(size).save(ICONSET / name)

    draw_icon(1024).save(ASSETS / "app-icon.png")
    draw_icon(512).save(PUBLIC / "apple-touch-icon.png")
    draw_icon(192).save(PUBLIC / "icon-192.png")
    draw_icon(512).save(PUBLIC / "icon-512.png")
    draw_icon(64).save(PUBLIC / "favicon.png")
    draw_icon(256).save(PUBLIC / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    draw_template(64).save(ASSETS / "StatusIconTemplate.png")

    shutil.copyfile(ASSETS / "logo.svg", PUBLIC / "logo.svg")

    icns = ASSETS / "PasteV.icns"
    if icns.exists():
        icns.unlink()
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(icns)], check=True)
    print(icns)


if __name__ == "__main__":
    main()
