"""Kızma Birader — mantıksal tahta geometrisi (MAP_SPECIFICATION.md).

Tek kaynak: 15x15 ızgara, 52 hücrelik ortak parkur, renk başına 5 renkli
koridor hücresi + ortadaki bitiş (6 adımlık bitiş koridoru), 4 bekleme alanı.
Çıktılar:
  docs/design/board/board_map.json   — koordinatlar, indeksler, yollar
  docs/design/board/board_indices.png — indeksli şema (belgeler için)
  docs/design/_src/board_data.js     — prototiplerin okuduğu kopya

Koordinatlar: x = sütun (0 solda), y = satır (0 üstte). Hareket saat yönünde.

    python docs/design/_src/board_geometry.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "board"
OUT.mkdir(exist_ok=True)

N = 15
TRACK_LEN = 52
HOME_LEN = 5            # renkli koridor hücreleri
STEPS_TO_GOAL = 56      # başlangıç hücresinden (adım 0) bitişe (adım 56)

# Ortak parkur, kırmızının başlangıç hücresinden (1,6) saat yönünde.
segments = [
    [(x, 6) for x in range(1, 6)],          # sol kol üst sıra →
    [(6, y) for y in range(5, -1, -1)],     # üst kol sol sütun ↑
    [(7, 0)],                               # üst kol uç
    [(8, y) for y in range(0, 6)],          # üst kol sağ sütun ↓
    [(x, 6) for x in range(9, 15)],         # sağ kol üst sıra →
    [(14, 7)],                              # sağ kol uç
    [(x, 8) for x in range(14, 8, -1)],     # sağ kol alt sıra ←
    [(8, y) for y in range(9, 15)],         # alt kol sağ sütun ↓
    [(7, 14)],                              # alt kol uç
    [(6, y) for y in range(14, 8, -1)],     # alt kol sol sütun ↑
    [(x, 8) for x in range(5, -1, -1)],     # sol kol alt sıra ←
    [(0, 7)],                               # sol kol uç
    [(0, 6)],                               # kırmızı başlangıcından önceki hücre
]
TRACK = [c for seg in segments for c in seg]
assert len(TRACK) == TRACK_LEN and len(set(TRACK)) == TRACK_LEN

# Renkler saat yönünde (öneri, karar K-R01): kırmızı sol üst, yeşil sağ üst,
# sarı sağ alt, mavi sol alt. Her rengin başlangıcı bir öncekinin 13 ilerisi.
COLORS = ["red", "green", "yellow", "blue"]
START_INDEX = {c: 13 * i for i, c in enumerate(COLORS)}
YARD_RECT = {"red": (0, 0), "green": (9, 0), "yellow": (9, 9), "blue": (0, 9)}   # 6x6 sol üst köşe
HOME_COLUMN = {
    "red": [(x, 7) for x in range(1, 6)],
    "green": [(7, y) for y in range(1, 6)],
    "yellow": [(x, 7) for x in range(13, 8, -1)],
    "blue": [(7, y) for y in range(13, 8, -1)],
}
GOAL_CELLS = [(x, y) for x in range(6, 9) for y in range(6, 9)]      # orta 3x3
# Bekleme alanındaki 4 piyon yuvası (6x6 alanın içindeki 2x2 düzen).
YARD_SLOTS_LOCAL = [(1.5, 1.5), (3.5, 1.5), (1.5, 3.5), (3.5, 3.5)]
STAR_OFFSET = 8          # her rengin başlangıcının 8 ilerisi (klasik yıldız)


def path_for(color: str) -> list:
    """Adım 0..50 ortak parkur, 51..55 renkli koridor, 56 bitiş."""
    start = START_INDEX[color]
    steps = [TRACK[(start + i) % TRACK_LEN] for i in range(51)]
    steps += HOME_COLUMN[color]
    steps.append("GOAL")
    assert len(steps) == STEPS_TO_GOAL + 1
    return steps


safe_track = sorted({START_INDEX[c] for c in COLORS} | {(START_INDEX[c] + STAR_OFFSET) % TRACK_LEN for c in COLORS})
# Kontrol: her rengin adım 50'si koridor girişinin hemen önü olmalı.
for c in COLORS:
    last = TRACK[(START_INDEX[c] + 50) % TRACK_LEN]
    first_home = HOME_COLUMN[c][0]
    assert abs(last[0] - first_home[0]) + abs(last[1] - first_home[1]) == 1, (c, last, first_home)

data = {
    "grid": N,
    "coordinate_system": "x = sütun (0 = sol), y = satır (0 = üst); hareket saat yönünde",
    "track_length": TRACK_LEN,
    "home_column_length": HOME_LEN,
    "steps_to_goal": STEPS_TO_GOAL,
    "track": [list(c) for c in TRACK],
    "colors_clockwise": COLORS,
    "start_track_index": START_INDEX,
    "safe_track_indices": safe_track,
    "star_track_indices": sorted((START_INDEX[c] + STAR_OFFSET) % TRACK_LEN for c in COLORS),
    "home_columns": {c: [list(p) for p in HOME_COLUMN[c]] for c in COLORS},
    "goal_cells": [list(p) for p in GOAL_CELLS],
    "yards": {c: {"rect": [YARD_RECT[c][0], YARD_RECT[c][1], 6, 6],
                  "slots": [[YARD_RECT[c][0] + sx, YARD_RECT[c][1] + sy] for sx, sy in YARD_SLOTS_LOCAL]} for c in COLORS},
    "paths": {c: [p if p == "GOAL" else list(p) for p in path_for(c)] for c in COLORS},
    "two_player_colors": {"default": ["red", "yellow"], "alternative": ["green", "blue"]},
}
(OUT / "board_map.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
# Prototipler (screens.html) aynı veriyi bu dosyadan okur.
(Path(__file__).resolve().parent / "board_data.js").write_text(
    "window.BOARD = " + json.dumps(data, ensure_ascii=False) + ";\n", encoding="utf-8")

# --- İndeksli şema -------------------------------------------------------------
CELL = 64
img = Image.new("RGB", (N * CELL + 2, N * CELL + 2), "#fff8ec")
d = ImageDraw.Draw(img)
try:
    font = ImageFont.truetype("arialbd.ttf", 18)
    small = ImageFont.truetype("arial.ttf", 13)
except OSError:
    font = small = ImageFont.load_default()
FILL = {"red": "#e5484d", "green": "#2fb463", "yellow": "#f5b70a", "blue": "#3a7bf7"}
LIGHT = {"red": "#fbd3d4", "green": "#cdeedb", "yellow": "#fdecb4", "blue": "#d3e2fd"}


def star(cx, cy, r, fill):
    import math
    pts = []
    for k in range(10):
        rr = r if k % 2 == 0 else r * 0.45
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill, outline="#8a6a00")


def box(x, y):
    return [x * CELL + 1, y * CELL + 1, x * CELL + CELL, y * CELL + CELL]


for c in COLORS:
    x0, y0 = YARD_RECT[c]
    d.rectangle([x0 * CELL + 1, y0 * CELL + 1, (x0 + 6) * CELL, (y0 + 6) * CELL], fill=LIGHT[c], outline="#5b4636", width=2)
    for sx, sy in YARD_SLOTS_LOCAL:
        cx, cy = (x0 + sx) * CELL + CELL // 2, (y0 + sy) * CELL + CELL // 2
        d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=FILL[c], outline="#3b2a20", width=2)
    d.text(((x0 + 3) * CELL, (y0 + 3) * CELL), c.upper(), fill="#3b2a20", font=font, anchor="mm")
for i, (x, y) in enumerate(TRACK):
    color = None
    for c in COLORS:
        if START_INDEX[c] == i:
            color = FILL[c]
    d.rectangle(box(x, y), fill=color or "#ffffff", outline="#5b4636", width=1)
    if i in safe_track and color is None:
        cx, cy = x * CELL + CELL // 2, y * CELL + CELL // 2
        star(cx, cy - 13, 11, "#ffd23f")
    d.text((x * CELL + CELL // 2, y * CELL + CELL // 2 + (8 if i in safe_track else 0)), str(i),
           fill="#1b1b1b" if color is None else "#ffffff", font=font, anchor="mm")
for c in COLORS:
    for k, (x, y) in enumerate(HOME_COLUMN[c]):
        d.rectangle(box(x, y), fill=FILL[c], outline="#5b4636", width=1)
        d.text((x * CELL + CELL // 2, y * CELL + CELL // 2), f"K{k + 1}", fill="#ffffff", font=small, anchor="mm")
cx0, cy0, cx1, cy1 = 6 * CELL + 1, 6 * CELL + 1, 9 * CELL, 9 * CELL
mid = ((cx0 + cx1) / 2, (cy0 + cy1) / 2)
d.polygon([(cx0, cy0), (cx0, cy1), mid], fill=FILL["red"])
d.polygon([(cx0, cy0), (cx1, cy0), mid], fill=FILL["green"])
d.polygon([(cx1, cy0), (cx1, cy1), mid], fill=FILL["yellow"])
d.polygon([(cx0, cy1), (cx1, cy1), mid], fill=FILL["blue"])
d.text(mid, "BİTİŞ", fill="#ffffff", font=small, anchor="mm")
img.save(OUT / "board_indices.png", optimize=True)
print("track", TRACK[:3], "... safe", safe_track)
for c in COLORS:
    p = path_for(c)
    print(c, "start", p[0], "step50", p[50], "home", p[51], "->", p[55])
