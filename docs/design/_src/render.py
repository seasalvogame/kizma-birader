"""Ekran prototiplerini (screens.html) PNG'ye çevirir: 360 x 780 CSS px, 3x
ölçek = 1080 x 2340 px (19,5:9 telefon). Başsız Chrome kullanır.

    python docs/design/_src/render.py [1 2 ...]

Çıktı: docs/design/screens/NN_<ad>.png ve docs/design/screens/overview.png
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "screens"
OUT.mkdir(exist_ok=True)
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
SCREENS = {
    1: "01_acilis", 2: "02_giris", 3: "03_ana_menu", 4: "04_mac_kur", 5: "05_eslestirme",
    6: "06_mac_4_kisi", 7: "07_mac_2_kisi", 8: "08_mac_sonucu", 9: "09_magaza", 10: "10_arkadaslar",
}


def render(index: int) -> Path:
    out = OUT / f"{SCREENS[index]}.png"
    url = (HERE / "screens.html").as_uri() + f"?s={index}"
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    "--force-device-scale-factor=3", "--window-size=360,1000", "--virtual-time-budget=4000",
                    f"--screenshot={out}", url], check=True, capture_output=True)
    Image.open(out).convert("RGB").crop((0, 0, 1080, 2340)).save(out, optimize=True)
    print("wrote", out.name)
    return out


def overview(paths: list) -> None:
    thumbs = [Image.open(p).resize((360, 780), Image.LANCZOS) for p in paths]
    cols = 5
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 380 + 20, rows * 800 + 20), "#0d0920")
    for i, t in enumerate(thumbs):
        sheet.paste(t, (20 + (i % cols) * 380, 20 + (i // cols) * 800))
    sheet.save(OUT / "overview.png", optimize=True)
    print("wrote overview.png")


if __name__ == "__main__":
    wanted = [int(a) for a in sys.argv[1:]] or list(SCREENS)
    done = [render(i) for i in wanted]
    if len(wanted) == len(SCREENS):
        overview(done)
