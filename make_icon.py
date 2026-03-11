import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

size = 1024
supersize = 2048

# 1. Background (Radial Gradient)
bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
center = size / 2
max_dist = size / math.sqrt(2)

print("Generating background...")
bg_pixels = bg.load()
for y in range(size):
    dy = y - center
    dy2 = dy * dy
    for x in range(size):
        dx = x - center
        dist = math.sqrt(dx * dx + dy2)
        factor = max(0.0, 1.0 - dist / max_dist)
        # Center #222222 (34), Edges #111111 (17)
        v = int(17 + factor * (34 - 17))
        bg_pixels[x, y] = (v, v, v, 255)

print("Drawing text...")
try:
    font_large = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 340)
    font_medium = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 250)
except Exception as e:
    print(f"Font loading error: {e}. Falling back to default.")
    font_large = ImageFont.load_default()
    font_medium = ImageFont.load_default()

txt_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
d = ImageDraw.Draw(txt_img)

# "ghb" (faded grey)
ghb_text = "ghb"
pri_text = "при"

# Use textbbox if available
try:
    bb_ghb = d.textbbox((0, 0), ghb_text, font=font_medium)
    w_ghb = bb_ghb[2] - bb_ghb[0]
    h_ghb = bb_ghb[3] - bb_ghb[1]

    bb_pri = d.textbbox((0, 0), pri_text, font=font_large)
    w_pri = bb_pri[2] - bb_pri[0]
    h_pri = bb_pri[3] - bb_pri[1]
except Exception as e:
    # fallback
    w_ghb, h_ghb = font_medium.getsize(ghb_text)
    w_pri, h_pri = font_large.getsize(pri_text)

# Layout
ghb_y = 150
pri_y = 520

ghb_x = (size - w_ghb) / 2
pri_x = (size - w_pri) / 2

# Draw "ghb" in faded grey
d.text((ghb_x, ghb_y), ghb_text, font=font_medium, fill=(130, 130, 130, 140))

# Strikethrough for "ghb"
line_y = ghb_y + h_ghb / 2 + 50
d.line([(ghb_x - 30, line_y), (ghb_x + w_ghb + 30, line_y)], fill=(130, 130, 130, 160), width=15)

# Small arrow
arrow_y = ghb_y + h_ghb + 110
arrow_x = size / 2
d.polygon([
    (arrow_x - 12, arrow_y), 
    (arrow_x + 12, arrow_y), 
    (arrow_x + 12, arrow_y + 35), 
    (arrow_x + 30, arrow_y + 35), 
    (arrow_x, arrow_y + 65), 
    (arrow_x - 30, arrow_y + 35), 
    (arrow_x - 12, arrow_y + 35)
], fill=(180, 180, 180, 180))

# Draw "при"
d.text((pri_x, pri_y), pri_text, font=font_large, fill=(255, 255, 255, 255))

# Merge text
bg.alpha_composite(txt_img)

print("Generating squircle mask...")
mask = Image.new('L', (size, size), 0)
mask_pixels = mask.load()
for y in range(size):
    ny = abs(y - center) / center
    ny5 = ny ** 5
    for x in range(size):
        nx = abs(x - center) / center
        if nx ** 5 + ny5 <= 1.0:
            mask_pixels[x, y] = 255

mask = mask.filter(ImageFilter.GaussianBlur(radius=1.0))

bg.putalpha(mask)

out_path = '/Users/aaa/Work/caramba-switcher/AppIcon.png'
bg.save(out_path)
print(f"Icon saved to {out_path}")
