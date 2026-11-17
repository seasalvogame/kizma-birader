# Kızma Birader — Godot 4 istemcisi

| Konu | Değer |
|---|---|
| Godot | 4.7.2 |
| Renderer | Compatibility (OpenGL ES 3) |
| Ekran | **Yalnızca dikey** |
| Referans tuval | 720×1560 px (360×780 pt × 2); `canvas_items` ölçekleme, `expand` |
| Faz 2 kapsamı | Çevrimdışı oynanabilir pratik maç (2 / 4 kişi, insan / bot / aynı cihazda sırayla) |

```sh
# Projeyi içe aktar
godot_console --headless --path client --import

# Testler (kurallar, iki motor eşitliği, tahta, maç akışı, düzen, dokunma)
godot_console --headless --path client res://tests/test_runner.tscn [-- --only=<dosya parçası>]

# Ekran görüntüsü turu (geliştirme)
godot_console --path client --resolution 540x1170 res://tests/visual/screenshot_tour.tscn -- \
  --shots=<mutlak klasör> --settings-path=user://tour/settings.cfg --safe-insets=94,48 --locale=tr

# Android debug APK
godot_console --headless --path client --export-debug "Android Debug" ../build/android/KizmaBirader-0.2.0-debug.apk

# Yardımcı betikler (Python)
python client/tools/sync_board_map.py     # tahta verisinin kopyası (bayt bayt aynı olmalı; test denetler)
python client/tools/make_assets.py        # piyon, zar, ikon, buton SVG'leri
python client/tools/make_translations.py  # tr.po / en.po
```

## Klasörler

| Klasör | İçerik |
|---|---|
| `scripts/game/rules/` | **GDScript kural motoru:** TS motorunun eşi; Node'a bağlı değil (`RefCounted`) |
| `scripts/game/` | `MatchController`: süreler, bot ve otopilot, otomatik tek hamle, animasyon senkronu (arayüz kodu yok) |
| `scripts/board/` | `BoardView` (tahta `board_map.json`'dan çizilir, döndürme, dokunma), `PawnSprite`, `DiceView` |
| `scripts/ui/` | Tasarım sistemi (`UiTokens`, `UiPalette`, `UiTheme`, `UiKit`), `Avatar`, `PlayerCard`, `NightBackground`, `SafeArea` |
| `scripts/ui/screens/` | `PracticeSetupScreen`, `MatchScreen` (maç menüsü, onay, sonuç dahil) |
| `scripts/app/` | `main.gd` (ekran yönlendirici), `settings.gd` (autoload) |
| `scripts/animation/` | Boş. Animasyonlar şimdilik ilgili görsellerde (`PawnSprite`, `DiceView`, `MatchScreen`). |
| `assets/` | Fontlar (OFL), SVG piyon, zar, ikon ve buton; durum listesi `assets/ASSETS.md` |
| `data/board_map.json` | Tek kaynağın kopyası |
| `localization/` | `tr.po`, `en.po` |
| `themes/` | Boş. Tema kodda kuruluyor (`UiTheme`). |
| `tests/` | Headless test koşucusu, birim ve sahne testleri, ekran görüntüsü turu (dışa aktarılmaz) |
| `tools/` | Python yardımcıları (Godot içe aktarmaz: `.gdignore`) |

## Kural motoru ile arayüzün ayrımı

```
MatchScreen ──(dokunma)──► MatchController ──► MatchSession ──► GameEngine (saf kurallar)
     ▲                            │
     └────(applied: olaylar)──────┘   (görünüm animasyonu bitince view_done())
```

- **Arayüz** yalnızca olayları canlandırır ve durumu gösterir.
- **Kuralların tamamı** `scripts/game/rules/` içinde.
- **Zar** çevrimdışı modda cihazın rastgele sayı üretecinden gelir; çevrimiçi maçlarda yalnızca sunucudan gelecek.
