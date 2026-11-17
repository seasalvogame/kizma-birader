"""Cosmetic assets (Phase 7): dice and pawn skins as SVG files, made with the same
vector style as the base assets (tools/make_assets.py, "Akşam Masası").

    python client/tools/make_cosmetics.py

Writes client/assets/cosmetics/dice/<skin>/dice_<n>.svg and
client/assets/cosmetics/pawns/<skin>/pawn_<color>.svg. The default skins stay in
assets/dice and assets/pawns. Frames, profile effects, name styles, board themes and
emote bubbles are drawn in code (no files; see scripts/ui/cosmetics.gd).

Readability rules (UI_UX_DESIGN_SYSTEM §7.4): every pawn keeps its player colour AND its
colour symbol (triangle / circle / square / diamond); dice pips always have strong contrast.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets" / "cosmetics"

COL = {
    "red": {"base": "#e5484d", "dark": "#a8262b", "light": "#ff8e91", "sym": "triangle"},
    "green": {"base": "#2fb463", "dark": "#1c7a40", "light": "#7be0a3", "sym": "circle"},
    "yellow": {"base": "#f5b70a", "dark": "#b27f00", "light": "#ffd968", "sym": "square"},
    "blue": {"base": "#3a7bf7", "dark": "#1f4fb8", "light": "#86adff", "sym": "diamond"},
}

PIPS = {1: [(50, 47)], 2: [(30, 27), (70, 67)], 3: [(30, 27), (50, 47), (70, 67)], 4: [(30, 27), (70, 27), (30, 67), (70, 67)],
        5: [(30, 27), (70, 27), (50, 47), (30, 67), (70, 67)], 6: [(30, 25), (70, 25), (30, 47), (70, 47), (30, 69), (70, 69)]}

# skin: (edge, top, bottom, outline, pip, pip_one, pip_shape)
DICE = {
    "night":   ("#120b26", "#4a3a85", "#241845", "#7d6bc4", "#fff3e2", "#ffc14d", "circle"),
    "mango":   ("#b45309", "#ffd38a", "#f08a24", "#fff1d6", "#4a2300", "#ffffff", "circle"),
    "emerald": ("#0f5132", "#5fe3a8", "#1c7a50", "#c9f7e2", "#ffffff", "#ffe08a", "circle"),
    "star":    ("#0b0d33", "#3b40a0", "#171a4a", "#8f95ff", "#ffd04a", "#ff8e91", "star"),
    "aurora":  ("#3b0d4f", "#5eead4", "#a855f7", "#ffffff", "#ffffff", "#fde047", "circle"),
    "master":  ("#b27f00", "#fffaf0", "#f6dfae", "#d49a00", "#b27f00", "#e5484d", "ring"),
}


def star_path(cx: float, cy: float, r: float) -> str:
    import math
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append(f"{cx + rr * math.cos(a):.2f} {cy + rr * math.sin(a):.2f}")
    return "M" + "L".join(pts) + "Z"


def pip(shape: str, x: float, y: float, fill: str) -> str:
    if shape == "star":
        return f'<path d="{star_path(x, y, 10.5)}" fill="{fill}"/>'
    if shape == "ring":
        return f'<circle cx="{x}" cy="{y}" r="7.5" fill="none" stroke="{fill}" stroke-width="4"/><circle cx="{x}" cy="{y}" r="2.6" fill="{fill}"/>'
    return f'<circle cx="{x}" cy="{y}" r="8.5" fill="{fill}"/>'


def dice(skin: str, value: int) -> str:
    edge, top, bottom, outline, pip_c, pip_one, shape = DICE[skin]
    pips = "".join(pip(shape, x, y, pip_one if value == 1 else pip_c) for x, y in PIPS[value])
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100">
  <defs><linearGradient id="d" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="{top}"/><stop offset="100%" stop-color="{bottom}"/></linearGradient></defs>
  <rect x="6" y="10" width="88" height="86" rx="22" fill="{edge}"/>
  <rect x="6" y="4" width="88" height="86" rx="22" fill="url(#d)" stroke="{outline}" stroke-width="2.5"/>
  <rect x="18" y="9" width="64" height="5" rx="2.5" fill="#ffffff" opacity=".35"/>
  {pips}
</svg>
'''


def symbol(kind: str, cx: float, cy: float, r: float, fill: str) -> str:
    if kind == "triangle":
        return f'<path d="M{cx} {cy - r}L{cx + r * 0.95} {cy + r * 0.7}L{cx - r * 0.95} {cy + r * 0.7}Z" fill="{fill}"/>'
    if kind == "circle":
        return f'<circle cx="{cx}" cy="{cy}" r="{r * 0.85}" fill="{fill}"/>'
    if kind == "square":
        return f'<rect x="{cx - r * 0.75}" y="{cy - r * 0.75}" width="{r * 1.5}" height="{r * 1.5}" rx="{r * 0.2}" fill="{fill}"/>'
    return f'<path d="M{cx} {cy - r}L{cx + r} {cy}L{cx} {cy + r}L{cx - r} {cy}Z" fill="{fill}"/>'


def gradient(c: dict) -> str:
    return f'''<radialGradient id="g" cx="35%" cy="28%" r="75%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity=".95"/>
      <stop offset="22%" stop-color="{c["light"]}"/>
      <stop offset="70%" stop-color="{c["base"]}"/>
      <stop offset="100%" stop-color="{c["dark"]}"/>
    </radialGradient>'''


def pawn(skin: str, color: str) -> str:
    c = COL[color]
    C = 100.0
    body = (f"M{-C * .34} {C * .22}C{-C * .30} {-C * .05} {-C * .12} {-C * .10} {-C * .10} {-C * .20}"
            f"L{C * .10} {-C * .20}C{C * .12} {-C * .10} {C * .30} {-C * .05} {C * .34} {C * .22}Z")
    shadow = f'<ellipse cx="0" cy="{C * .33}" rx="{C * .44}" ry="{C * .16}" fill="#1b0f35" opacity=".35"/>'
    base = f'<ellipse cx="0" cy="{C * .26}" rx="{C * .40}" ry="{C * .17}" fill="{c["dark"]}"/>'
    sym = symbol(c["sym"], 0, C * .08, C * .09, "rgba(255,255,255,0.9)")
    if skin == "crown":
        # classic pawn with a small gold crown on the head
        head = f'<circle cx="0" cy="{-C * .30}" r="{C * .25}" fill="url(#g)" stroke="#ffffff" stroke-width="{C * .06}"/>'
        crown = (f'<path d="M{-C * .2} {-C * .44}L{-C * .2} {-C * .62}L{-C * .1} {-C * .52}L0 {-C * .66}L{C * .1} {-C * .52}'
                 f'L{C * .2} {-C * .62}L{C * .2} {-C * .44}Z" fill="#ffd04a" stroke="#b27f00" stroke-width="{C * .03}" stroke-linejoin="round"/>')
        parts = f'<path d="{body}" fill="url(#g)" stroke="#ffffff" stroke-width="{C * .06}" stroke-linejoin="round"/>{head}{crown}'
    elif skin == "star":
        # the head is a star
        head = f'<path d="{star_path(0, -C * .32, C * .33)}" fill="url(#g)" stroke="#ffffff" stroke-width="{C * .05}" stroke-linejoin="round"/>'
        parts = f'<path d="{body}" fill="url(#g)" stroke="#ffffff" stroke-width="{C * .06}" stroke-linejoin="round"/>{head}'
    else:  # gem: faceted body with a sparkle
        gem = (f'M0 {-C * .58}L{C * .30} {-C * .28}L{C * .30} {C * .12}L0 {C * .28}L{-C * .30} {C * .12}L{-C * .30} {-C * .28}Z')
        facet = (f'<path d="M0 {-C * .58}L{C * .30} {-C * .28}L0 {-C * .12}L{-C * .30} {-C * .28}Z" fill="#ffffff" opacity=".35"/>'
                 f'<path d="M0 {-C * .12}L{C * .30} {C * .12}L0 {C * .28}Z" fill="{c["dark"]}" opacity=".35"/>')
        sparkle = f'<path d="{star_path(C * .2, -C * .44, C * .08)}" fill="#ffffff"/>'
        parts = f'<path d="{gem}" fill="url(#g)" stroke="#ffffff" stroke-width="{C * .05}" stroke-linejoin="round"/>{facet}{sparkle}'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="-64 -64 128 128">
  <defs>
    {gradient(c)}
  </defs>
  {shadow}
  {base}
  {parts}
  {sym}
</svg>
'''


def main() -> None:
    for skin in DICE:
        d = ROOT / "dice" / skin
        d.mkdir(parents=True, exist_ok=True)
        for v in range(1, 7):
            (d / f"dice_{v}.svg").write_text(dice(skin, v), encoding="utf-8")
    for skin in ("crown", "star", "gem"):
        d = ROOT / "pawns" / skin
        d.mkdir(parents=True, exist_ok=True)
        for color in COL:
            (d / f"pawn_{color}.svg").write_text(pawn(skin, color), encoding="utf-8")
    print("dice skins:", ", ".join(DICE), "| pawn skins: crown, star, gem")


if __name__ == "__main__":
    main()
