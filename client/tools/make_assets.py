"""Generates the Phase 2 vector assets of the "Akşam Masası" design system
(docs/UI_UX_DESIGN_SYSTEM.md §7) as SVG files that Godot imports directly.
Shapes and colours are the same as the Phase 1 prototype (docs/design/_src/board.js).

    python client/tools/make_assets.py

Writes client/assets/pawns/pawn_<color>.svg, client/assets/dice/dice_<n>.svg,
client/assets/icons/<name>.svg. Status of every asset: client/assets/ASSETS.md.
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets"

COL = {
    "red": {"base": "#e5484d", "dark": "#a8262b", "light": "#ff8e91", "sym": "triangle"},
    "green": {"base": "#2fb463", "dark": "#1c7a40", "light": "#7be0a3", "sym": "circle"},
    "yellow": {"base": "#f5b70a", "dark": "#b27f00", "light": "#ffd968", "sym": "square"},
    "blue": {"base": "#3a7bf7", "dark": "#1f4fb8", "light": "#86adff", "sym": "diamond"},
}


def symbol(kind: str, cx: float, cy: float, r: float, fill: str) -> str:
    if kind == "triangle":
        return f'<path d="M{cx} {cy - r}L{cx + r * 0.95} {cy + r * 0.7}L{cx - r * 0.95} {cy + r * 0.7}Z" fill="{fill}"/>'
    if kind == "circle":
        return f'<circle cx="{cx}" cy="{cy}" r="{r * 0.85}" fill="{fill}"/>'
    if kind == "square":
        return f'<rect x="{cx - r * 0.75}" y="{cy - r * 0.75}" width="{r * 1.5}" height="{r * 1.5}" rx="{r * 0.2}" fill="{fill}"/>'
    return f'<path d="M{cx} {cy - r}L{cx + r} {cy}L{cx} {cy + r}L{cx - r} {cy}Z" fill="{fill}"/>'


def pawn(color: str) -> str:
    c = COL[color]
    C = 100.0  # one board cell
    # Pawn origin (0, 0) = the cell centre; the image is 128 x 128 for one cell + margins.
    body = (f"M{-C * .34} {C * .22}C{-C * .30} {-C * .05} {-C * .12} {-C * .10} {-C * .10} {-C * .20}"
            f"L{C * .10} {-C * .20}C{C * .12} {-C * .10} {C * .30} {-C * .05} {C * .34} {C * .22}Z")
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="-64 -64 128 128">
  <defs>
    <radialGradient id="g" cx="35%" cy="28%" r="75%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity=".95"/>
      <stop offset="22%" stop-color="{c["light"]}"/>
      <stop offset="70%" stop-color="{c["base"]}"/>
      <stop offset="100%" stop-color="{c["dark"]}"/>
    </radialGradient>
  </defs>
  <ellipse cx="0" cy="{C * .33}" rx="{C * .44}" ry="{C * .16}" fill="#1b0f35" opacity=".35"/>
  <ellipse cx="0" cy="{C * .26}" rx="{C * .40}" ry="{C * .17}" fill="{c["dark"]}"/>
  <path d="{body}" fill="url(#g)" stroke="#ffffff" stroke-width="{C * .06}" stroke-linejoin="round"/>
  <circle cx="0" cy="{-C * .30}" r="{C * .25}" fill="url(#g)" stroke="#ffffff" stroke-width="{C * .06}"/>
  {symbol(c["sym"], 0, C * .08, C * .09, "rgba(255,255,255,0.88)")}
</svg>
'''


PIPS = {1: [(50, 47)], 2: [(30, 27), (70, 67)], 3: [(30, 27), (50, 47), (70, 67)], 4: [(30, 27), (70, 27), (30, 67), (70, 67)],
        5: [(30, 27), (70, 27), (50, 47), (30, 67), (70, 67)], 6: [(30, 25), (70, 25), (30, 47), (70, 47), (30, 69), (70, 69)]}


def dice(value: int) -> str:
    pips = "".join(f'<circle cx="{x}" cy="{y}" r="8.5" fill="{"#e5484d" if value == 1 else "#2a1f3d"}"/>' for x, y in PIPS[value])
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 100 100">
  <defs><linearGradient id="d" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#ffffff"/><stop offset="100%" stop-color="#f1e3cf"/></linearGradient></defs>
  <rect x="6" y="10" width="88" height="86" rx="22" fill="#d9c2a0"/>
  <rect x="6" y="4" width="88" height="86" rx="22" fill="url(#d)" stroke="#ffffff" stroke-width="2"/>
  {pips}
</svg>
'''


ICONS = {
    "menu": '<path d="M5 7h14M5 12h14M5 17h14" fill="none" stroke="#f6efff" stroke-width="2.4" stroke-linecap="round"/>',
    "chat": '<path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v7a2.5 2.5 0 0 1-2.5 2.5H10l-4.5 3.5V16A2.5 2.5 0 0 1 4 13.5z" fill="none" stroke="#f6efff" stroke-width="2.2" stroke-linejoin="round"/><circle cx="9" cy="10" r="1.1" fill="#f6efff"/><circle cx="15" cy="10" r="1.1" fill="#f6efff"/>',
    "back": '<path d="M14.5 5.5 8 12l6.5 6.5" fill="none" stroke="#f6efff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
    "close": '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11" fill="none" stroke="#2a1f3d" stroke-width="2.6" stroke-linecap="round"/>',
    "gear": '<circle cx="12" cy="12" r="3.2" fill="none" stroke="#f6efff" stroke-width="2.2"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M5.5 18.5l1.7-1.7M16.8 7.2l1.7-1.7" fill="none" stroke="#f6efff" stroke-width="2.2" stroke-linecap="round"/>',
    "robot": '<rect x="5" y="8" width="14" height="11" rx="3.5" fill="none" stroke="#f6efff" stroke-width="2"/><path d="M12 4.5V8" stroke="#f6efff" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="4" r="1.4" fill="#f6efff"/><circle cx="9.3" cy="13" r="1.4" fill="#f6efff"/><circle cx="14.7" cy="13" r="1.4" fill="#f6efff"/><path d="M3 12.5v3M21 12.5v3" stroke="#f6efff" stroke-width="2" stroke-linecap="round"/>',
    "person": '<circle cx="12" cy="8.5" r="3.6" fill="#f6efff"/><path d="M5 19.5c.6-3.6 3.4-5.6 7-5.6s6.4 2 7 5.6z" fill="#f6efff"/>',
    "trophy": '<path d="M7 4h10v4a5 5 0 0 1-10 0z" fill="#ffc531"/><path d="M7 5H4v2a3 3 0 0 0 3 3M17 5h3v2a3 3 0 0 1-3 3" fill="none" stroke="#ffc531" stroke-width="1.8"/><path d="M10.5 13h3v3.5H16V20H8v-3.5h2.5z" fill="#ffc531"/>',
    "star": '<path d="M12 2.8l2.6 5.6 6.1.7-4.5 4.2 1.2 6-5.4-3-5.4 3 1.2-6-4.5-4.2 6.1-.7z" fill="#ffd04a" stroke="#d49a00" stroke-width="1"/>',
    "wifi_off": '<path d="M3 3l18 18M8.5 16.5a5 5 0 0 1 7 0M5 13a10 10 0 0 1 5-2.6M19 13a10 10 0 0 0-3-2.1M2 9.5a15 15 0 0 1 4.5-2.8M22 9.5A15 15 0 0 0 11 5.6" fill="none" stroke="#ff8e91" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="19.5" r="1.3" fill="#ff8e91"/>',
    "replay": '<path d="M5 12a7 7 0 1 0 2.1-5" fill="none" stroke="#3d1c00" stroke-width="2.4" stroke-linecap="round"/><path d="M4 3.5V8h4.5" fill="none" stroke="#3d1c00" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    "exit": '<path d="M10 5H6.5A1.5 1.5 0 0 0 5 6.5v11A1.5 1.5 0 0 0 6.5 19H10M14 8l4 4-4 4M18 12H9" fill="none" stroke="#ff8e91" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
    # Phase 3.3: navigation and menu icons (white; tinted in code).
    "home": '<path d="M4 11.2 12 4.5l8 6.7V19a1.5 1.5 0 0 1-1.5 1.5H15v-5.5H9v5.5H5.5A1.5 1.5 0 0 1 4 19z" fill="#f6efff"/>',
    "friends": '<circle cx="9" cy="8.5" r="3.3" fill="#f6efff"/><path d="M2.8 19.5c.5-3.4 3-5.3 6.2-5.3s5.7 1.9 6.2 5.3z" fill="#f6efff"/><circle cx="16.8" cy="9.4" r="2.6" fill="#f6efff" opacity=".75"/><path d="M16.2 13.6c2.7 0 4.6 1.6 5 4.4h-4.7c-.3-1.7-1-3.1-2.1-4.1.5-.2 1.1-.3 1.8-.3z" fill="#f6efff" opacity=".75"/>',
    "bag": '<path d="M5.2 8.5h13.6l-1 11.2a1.6 1.6 0 0 1-1.6 1.4H7.8a1.6 1.6 0 0 1-1.6-1.4z" fill="#f6efff"/><path d="M8.8 10V7.2a3.2 3.2 0 0 1 6.4 0V10" fill="none" stroke="#f6efff" stroke-width="2" stroke-linecap="round"/>',
    "quest": '<path d="M6.5 3.5h11A1.5 1.5 0 0 1 19 5v16l-7-4.2L5 21V5a1.5 1.5 0 0 1 1.5-1.5z" fill="#f6efff"/>',
    "lock": '<rect x="5" y="10.5" width="14" height="10" rx="2.6" fill="#ffc531"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" fill="none" stroke="#ffc531" stroke-width="2.2"/><circle cx="12" cy="15.2" r="1.6" fill="#7a4b00"/><path d="M12 15.5v2.4" stroke="#7a4b00" stroke-width="1.6" stroke-linecap="round"/>',
    "phone": '<rect x="7" y="2.8" width="10" height="18.4" rx="2.4" fill="none" stroke="#f6efff" stroke-width="2"/><path d="M10.5 18h3" stroke="#f6efff" stroke-width="2" stroke-linecap="round"/>',
    "globe": '<circle cx="12" cy="12" r="8.6" fill="none" stroke="#f6efff" stroke-width="2"/><path d="M3.6 12h16.8M12 3.4c2.4 2.4 3.6 5.3 3.6 8.6s-1.2 6.2-3.6 8.6c-2.4-2.4-3.6-5.3-3.6-8.6s1.2-6.2 3.6-8.6z" fill="none" stroke="#f6efff" stroke-width="1.8"/>',
    "chevron": '<path d="M9.5 5.5 16 12l-6.5 6.5" fill="none" stroke="#f6efff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
    "pencil": '<path d="M4.5 19.5l1-4.2L15.8 5a1.8 1.8 0 0 1 2.5 0l.7.7a1.8 1.8 0 0 1 0 2.5L8.7 18.5z" fill="#f6efff"/><path d="M4.5 19.5h15" stroke="#f6efff" stroke-width="1.8" stroke-linecap="round"/>',
    "medal": '<path d="M8 2.8h3l1.6 5.4-2.9 1.4zM16 2.8h-3l-1.1 3.7 1.6 3.2 1.4-.7z" fill="#ff8e91"/><circle cx="12" cy="15" r="6" fill="#ffc531"/><circle cx="12" cy="15" r="3.8" fill="none" stroke="#c88a00" stroke-width="1.4"/>',
    "book": '<path d="M4 5.5C6.8 4.3 9.4 4.4 12 6c2.6-1.6 5.2-1.7 8-.5v13c-2.8-1.2-5.4-1.1-8 .5-2.6-1.6-5.2-1.7-8-.5z" fill="none" stroke="#f6efff" stroke-width="2" stroke-linejoin="round"/><path d="M12 6v13" stroke="#f6efff" stroke-width="2"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke="#f6efff" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>',
    "hourglass": '<path d="M6.5 3.5h11M6.5 20.5h11M8 3.5c0 4.5 4 5.5 4 8.5s-4 4-4 8.5M16 3.5c0 4.5-4 5.5-4 8.5s4 4 4 8.5" fill="none" stroke="#f6efff" stroke-width="2" stroke-linecap="round"/>',
    "podium": '<rect x="9" y="6" width="6" height="15" rx="1.2" fill="#f6efff"/><rect x="2.5" y="11" width="6" height="10" rx="1.2" fill="#f6efff" opacity=".8"/><rect x="15.5" y="13.5" width="6" height="7.5" rx="1.2" fill="#f6efff" opacity=".65"/>',
    "sound": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" fill="#f6efff"/><path d="M15.5 9a4.2 4.2 0 0 1 0 6M18 6.5a7.8 7.8 0 0 1 0 11" fill="none" stroke="#f6efff" stroke-width="2" stroke-linecap="round"/>',
}


def icon(body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24">{body}</svg>\n'


# 9-slice game buttons (UI_UX_DESIGN_SYSTEM §5.1): 240 x 120 px, radius 44, 3D bottom edge.
BUTTONS = {
    "primary": ("#ffc35a", "#ff9a1f", "#ff8a0a", "#c25f00"),
    "secondary": ("#fffdf8", "#fff8ee", "#fff3e2", "#e8d3b4"),
    "berry": ("#ff86ab", "#ff6e9b", "#ff5d8f", "#b8295a"),
    "mint": ("#7ff0c6", "#4fe0ad", "#2fd39a", "#13875f"),
}


def button(top: str, mid: str, bottom: str, edge: str, pressed: bool) -> str:
    y = 10 if pressed else 2
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="240" height="120" viewBox="0 0 240 120">
  <defs><linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="{top}"/><stop offset="55%" stop-color="{mid}"/><stop offset="100%" stop-color="{bottom}"/></linearGradient></defs>
  <rect x="2" y="12" width="236" height="106" rx="44" fill="{edge}"/>
  <rect x="2" y="{y}" width="236" height="104" rx="44" fill="url(#b)"/>
  <rect x="34" y="{y + 5}" width="172" height="5" rx="2.5" fill="#ffffff" opacity=".45"/>
</svg>
'''


def ghost(pressed: bool) -> str:
    a = ".16" if pressed else ".08"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="240" height="120" viewBox="0 0 240 120">
  <rect x="3" y="3" width="234" height="114" rx="44" fill="#ffffff" fill-opacity="{a}" stroke="#ffffff" stroke-opacity=".2" stroke-width="3"/>
</svg>
'''


def main() -> None:
    (ROOT / "ui").mkdir(parents=True, exist_ok=True)
    for name, colors in BUTTONS.items():
        (ROOT / "ui" / f"button_{name}.svg").write_text(button(*colors, False), encoding="utf-8")
        (ROOT / "ui" / f"button_{name}_pressed.svg").write_text(button(*colors, True), encoding="utf-8")
    (ROOT / "ui" / "button_ghost.svg").write_text(ghost(False), encoding="utf-8")
    (ROOT / "ui" / "button_ghost_pressed.svg").write_text(ghost(True), encoding="utf-8")
    for sub in ("pawns", "dice", "icons"):
        (ROOT / sub).mkdir(parents=True, exist_ok=True)
    for c in COL:
        (ROOT / "pawns" / f"pawn_{c}.svg").write_text(pawn(c), encoding="utf-8")
    for v in range(1, 7):
        (ROOT / "dice" / f"dice_{v}.svg").write_text(dice(v), encoding="utf-8")
    for name, body in ICONS.items():
        (ROOT / "icons" / f"{name}.svg").write_text(icon(body), encoding="utf-8")
    print("wrote", len(COL), "pawns,", 6, "dice,", len(ICONS), "icons")


if __name__ == "__main__":
    main()
