import numpy as np
from PIL import Image

np.random.seed(42)

# --- Generate skyscraper_0_win.png (for Wins2: 14 cols x 8 rows) ---
w0, h0 = 1024, 1024
im0 = np.zeros((h0, w0, 3), dtype=np.uint8)

cols0 = 14
rows0 = 8

dx0 = w0 / cols0
dy0 = h0 / rows0

for r in range(rows0):
    for c in range(cols0):
        # Random lit probability (R channel)
        r_val = int(np.random.uniform(20, 255))
        # Warmth variation (G channel)
        g_val = int(np.random.uniform(40, 230))
        
        y0 = int(r * dy0 + 5)
        y1 = int((r + 1) * dy0 - 24) # 29px spandrel
        x0 = int(c * dx0 + 4)
        x1 = int((c + 1) * dx0 - 4)  # 6-8px mullion
        
        im0[y0:y1, x0:x1, 0] = r_val
        im0[y0:y1, x0:x1, 1] = g_val

Image.fromarray(im0).save("assets/town/skyscraper_0_win.png")
print("Saved assets/town/skyscraper_0_win.png")

# --- Generate skyscraper_2_win.png (for Wins1: 32 cols x 24 rows) ---
w2, h2 = 1024, 1024
im2 = np.zeros((h2, w2, 3), dtype=np.uint8)

cols2 = 32
rows2 = 24

dx2 = w2 / cols2
dy2 = h2 / rows2

for r in range(rows2):
    for c in range(cols2):
        r_val = int(np.random.uniform(20, 255))
        g_val = int(np.random.uniform(40, 230))
        
        y0 = int(r * dy2 + 2)
        y1 = int((r + 1) * dy2 - 2)
        x0 = int(c * dx2 + 2)
        x1 = int((c + 1) * dx2 - 2)
        
        im2[y0:y1, x0:x1, 0] = r_val
        im2[y0:y1, x0:x1, 1] = g_val

Image.fromarray(im2).save("assets/town/skyscraper_2_win.png")
print("Saved assets/town/skyscraper_2_win.png")
