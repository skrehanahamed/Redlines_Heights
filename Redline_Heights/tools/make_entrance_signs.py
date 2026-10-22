import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
if not os.path.exists(FONT_REG):
    FONT_REG = FONT_BOLD

def create_station_sign(name, line_sub, badge_letters, size=(295, 155)):
    # Dark charcoal background with subtle noise/shading
    w, h = size
    im = Image.new("RGBA", (w, h), (20, 22, 26, 255))
    draw = ImageDraw.Draw(im)
    
    # Outer thin border
    draw.rectangle([2, 2, w - 3, h - 3], outline=(45, 50, 56, 255), width=2)
    # Corner rivets / screws
    for rx, ry in [(8, 8), (w - 9, 8), (8, h - 9), (w - 9, h - 9), (w // 2, 8), (w // 2, h - 9)]:
        draw.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(120, 125, 130, 255))
    
    # Line 1: Station Name + " Station"
    # Choose font size so it fits comfortably within width (max ~270px)
    title_text = f"{name} Station"
    title_size = 23
    font_title = ImageFont.truetype(FONT_BOLD, title_size)
    while font_title.getlength(title_text) > w - 24 and title_size > 15:
        title_size -= 1
        font_title = ImageFont.truetype(FONT_BOLD, title_size)
    
    draw.text((12, 12), title_text, font=font_title, fill=(255, 255, 255, 255))
    
    # Line 2: Subtitle / Destination
    sub_size = 14
    font_sub = ImageFont.truetype(FONT_BOLD, sub_size)
    draw.text((12, 14 + title_size + 4), line_sub, font=font_sub, fill=(235, 240, 245, 255))
    
    # Line 3: Metro Route Badges (circles)
    circle_y = 14 + title_size + 4 + sub_size + 12
    circle_r = 18
    # Circle colors (Orange/Gold for Metro Line R1, like NYC subway N/Q/R line)
    badge_color = (255, 184, 28, 255) # Classic NYC Subway gold/yellow
    badge_font = ImageFont.truetype(FONT_BOLD, 22)
    
    cur_x = 16
    for badge in badge_letters:
        # circle
        draw.ellipse([cur_x, circle_y, cur_x + circle_r * 2, circle_y + circle_r * 2], fill=badge_color, outline=(20, 20, 20, 255), width=1)
        # letter inside
        bbox = badge_font.getbbox(badge)
        bw = bbox[2] - bbox[0]
        bh = bbox[3] - bbox[1]
        bx = cur_x + circle_r - bw / 2 - bbox[0]
        by = circle_y + circle_r - bh / 2 - bbox[1]
        draw.text((bx, by), badge, font=badge_font, fill=(0, 0, 0, 255))
        cur_x += circle_r * 2 + 8
        
    return im

def create_side_sign(name, size=(290, 85)):
    w, h = size
    im = Image.new("RGBA", (w, h), (20, 22, 26, 255))
    draw = ImageDraw.Draw(im)
    
    # Border & screws
    draw.rectangle([2, 2, w - 3, h - 3], outline=(45, 50, 56, 255), width=2)
    for rx, ry in [(6, 6), (w - 7, 6), (6, h - 7), (w - 7, h - 7), (w // 2, 6), (w // 2, h - 7)]:
        draw.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(120, 125, 130, 255))
        
    # Main text: Station Name
    title_size = 28
    font_title = ImageFont.truetype(FONT_BOLD, title_size)
    while font_title.getlength(name) > w - 24 and title_size > 16:
        title_size -= 1
        font_title = ImageFont.truetype(FONT_BOLD, title_size)
        
    draw.text((12, 10), name, font=font_title, fill=(255, 255, 255, 255))
    
    # Bottom subline: "SUBWAY • REDLINE TRANSIT"
    sub_font = ImageFont.truetype(FONT_BOLD, 11)
    draw.text((14, 52), "SUBWAY • REDLINE TRANSIT", font=sub_font, fill=(200, 210, 220, 255))
    
    # Small line badge on bottom right
    br_r = 10
    br_x = w - 32
    br_y = 50
    draw.ellipse([br_x, br_y, br_x + br_r * 2, br_y + br_r * 2], fill=(255, 184, 28, 255))
    rf = ImageFont.truetype(FONT_BOLD, 12)
    draw.text((br_x + 3, br_y + 1), "R1", font=rf, fill=(0, 0, 0, 255))
    
    return im

def make_entrance_texture(src_path, name, sub_text, out_path):
    base_img = Image.open(src_path).convert("RGBA")
    
    # 1. Main arch signs (two instances: station_1 and station_2)
    # Both are oriented with FLIP_TOP_BOTTOM in the texture
    st_sign1 = create_station_sign(name, sub_text, ["R", "1"], (295, 155))
    st_sign2 = create_station_sign(name, sub_text, ["R", "1"], (295, 155))
    
    # Flip top-bottom to match texture UV orientation
    st_sign1_flipped = st_sign1.transpose(Image.FLIP_TOP_BOTTOM)
    st_sign2_flipped = st_sign2.transpose(Image.FLIP_TOP_BOTTOM)
    
    base_img.paste(st_sign1_flipped, (715, 660))
    base_img.paste(st_sign2_flipped, (715, 830))
    
    # 2. Side railing signs (subway_top and subway_mid)
    side_sign1 = create_side_sign(name, (290, 85))
    side_sign2 = create_side_sign(name, (290, 85))
    
    side_sign1_flipped = side_sign1.transpose(Image.FLIP_TOP_BOTTOM)
    side_sign2_flipped = side_sign2.transpose(Image.FLIP_TOP_BOTTOM)
    
    base_img.paste(side_sign1_flipped, (720, 250))
    base_img.paste(side_sign2_flipped, (720, 350))
    
    # Convert to RGB (original is RGB without alpha) and save
    out_rgb = base_img.convert("RGB")
    out_rgb.save(out_path, quality=95)
    print(f"Saved {out_path}")

if __name__ == "__main__":
    src = "assets/metro/subway_entrance_v2_10.png"
    os.makedirs("assets/metro/signs", exist_ok=True)
    make_entrance_texture(src, "Island Plaza", "Redline Island • Metro Line R1", "assets/metro/signs/entrance_island_plaza.png")
    make_entrance_texture(src, "Atlanta Court", "Downtown • Metro Line R1", "assets/metro/signs/entrance_atlanta_court.png")
