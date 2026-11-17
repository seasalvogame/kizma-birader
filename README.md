# Kızma Birader Online (çalışma adı)

Klasik yıldızlı Kızma Birader / Ludo tahtasında oynanan, çevrimiçi çok oyunculu mobil masa oyunu.

| Konu | Değer |
|---|---|
| Platform | Android ve iOS |
| Motor | Godot 4 |
| Ekran | Yalnızca dikey |
| İş modeli | Ücretsiz; reklam, uygulama içi satın alma ve Kulüp Üyeliği |
| Diller | TR / EN |

> **Durum:** **Faz 2 — Oyun motoru, Godot iskeleti ve çevrimdışı oynanabilir oyun** tamamlandı (2026-11-17, sürüm 0.2.0).
> - **Faz 2 sonrası güncelleme (2026-11-17):** Kararlar güncellendi ve çevrimiçi mimari Cloudflare Workers + Durable Objects + Supabase olarak yeniden planlandı (yalnızca belgeler). Rapor: [PHASE_2_POST_UPDATE_REPORT.md](PHASE_2_POST_UPDATE_REPORT.md).
> - **Faz 3 sürüyor:** 3.1 ve 3.2 tamam; 3.3 oynanabilir sürüm 0.3.0 ve yerel sunucu iskeleti hazır. Rapor: [PHASE_3_3_REPORT.md](PHASE_3_3_REPORT.md).
> - Rapor: [PHASE_2_REPORT.md](PHASE_2_REPORT.md) · Plan: [docs/PHASE_2_PLAN.md](docs/PHASE_2_PLAN.md) · Faz 1: [PHASE_1_REPORT.md](PHASE_1_REPORT.md)
> - Karar bekleyen konular: [docs/DECISIONS_AND_OPEN_QUESTIONS.md](docs/DECISIONS_AND_OPEN_QUESTIONS.md)

## Klasörler

| Klasör | İçerik |
|---|---|
| `client/` | Godot 4 istemcisi (yalnızca dikey); GDScript kural motoru, tahta, maç ekranı, testler. [client/README.md](client/README.md) |
| `server/game-engine/` | TypeScript kural motoru (sunucu otoritesi için). [README](server/game-engine/README.md) |
| `server/worker/` | Cloudflare Worker + Durable Objects oyun sunucusu (Faz 3.3 iskeleti). [README](server/worker/README.md) |
| `shared/rules_test_vectors/` | İki motorun eşitlik testleri (TS üretir, GDScript koşar) |
| `shared/config/` | Örnek ekonomi yapılandırması |
| `supabase/` | Supabase şeması (`migrations/`), CLI yapılandırması, RLS / ekonomi / API testleri. Kurulum: [docs/setup/SUPABASE_SETUP.md](docs/setup/SUPABASE_SETUP.md) |
| `docs/` | Ürün, tasarım ve teknik belgeler |
| `build/` | Derleme çıktıları (APK) |

```sh
cd server/game-engine && npm install && npm test                          # 73 test
godot_console --headless --path client res://tests/test_runner.tscn     # 27 test
```

## Belgeler (`docs/`)

| # | Belge | İçerik |
|---|---|---|
| 1 | [GAME_DESIGN_DOCUMENT.md](docs/GAME_DESIGN_DOCUMENT.md) | Ürün tanımı, ilkeler, modlar, döngüler, MVP kapsamı, başarı ölçütleri |
| 2 | [GAME_RULES.md](docs/GAME_RULES.md) | Bütün kurallar, ayarlanabilir kural seti şeması, örnekler |
| 3 | [MAP_SPECIFICATION.md](docs/MAP_SPECIFICATION.md) | 15×15 tahta, 52 parkur hücresi, koridorlar, yollar, ekrana yerleşim |
| 4 | [UI_UX_DESIGN_SYSTEM.md](docs/UI_UX_DESIGN_SYSTEM.md) | "Akşam Masası" görsel kimliği: renk, token, tipografi, bileşenler, hareket, tahta görselleri |
| 5 | [UI_SCREEN_SPECIFICATIONS.md](docs/UI_SCREEN_SPECIFICATIONS.md) | 26 ekranın ayrıntılı tanımı ve maç ekranı wireframe'leri |
| 6 | [USER_FLOWS.md](docs/USER_FLOWS.md) | Menü hiyerarşisi ve akış diyagramları (Mermaid) |
| 7 | [TECHNICAL_ARCHITECTURE.md](docs/TECHNICAL_ARCHITECTURE.md) | Genel teknik mimari: istemci, Cloudflare Workers + Durable Objects, Supabase, izleme, yedekleme |
| 8 | [DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md) | Tablolar, ilişkiler, indeksler, RLS politikaları |
| 9 | [NETWORK_PROTOCOL.md](docs/NETWORK_PROTOCOL.md) | WSS mesajları, yeniden bağlanma, idempotency, REST uçları |
| 10 | [SECURITY_SPECIFICATION.md](docs/SECURITY_SPECIFICATION.md) | Tehdit modeli, hile önleme, satın alma ve reklam güvenliği, sorumluluk dağılımı |
| 11 | [MONETIZATION_DESIGN.md](docs/MONETIZATION_DESIGN.md) | Reklam kuralları, IAP ürünleri ve doğrulama, Kulüp Üyeliği |
| 12 | [ECONOMY_AND_PROGRESSION.md](docs/ECONOMY_AND_PROGRESSION.md) | Altın, XP / seviye, ödüller, görevler, başarımlar, kozmetikler, sıralama |
| 13 | [LOCALIZATION_SPECIFICATION.md](docs/LOCALIZATION_SPECIFICATION.md) | TR / EN, anahtarlar, biçimler, sağdan sola düzen hazırlığı |
| 14 | [TESTING_AND_PERFORMANCE.md](docs/TESTING_AND_PERFORMANCE.md) | Test stratejisi, performans bütçeleri, cihaz matrisi, yayın kapısı |
| 15 | [DEVELOPMENT_ROADMAP.md](docs/DEVELOPMENT_ROADMAP.md) | F1–F10 fazları, MVP sonrası, risk kaydı |
| 16 | [DECISIONS_AND_OPEN_QUESTIONS.md](docs/DECISIONS_AND_OPEN_QUESTIONS.md) | Kararlar (K-01…K-54; Faz 2'de kesinleşenler işaretli), varsayımlar, açık sorular |
| — | [COMPATIBILITY_REPORT.md](docs/COMPATIBILITY_REPORT.md) | Faz 2: Supabase, reklam, IAP, giriş ve push eklentileri araştırması |
| — | [economy/GOLD_AND_DIAMOND_ECONOMY.md](docs/economy/GOLD_AND_DIAMOND_ECONOMY.md) | **Ekonominin tek kaynağı:** Altın + Elmas, giriş bedeli, defter, satın alma altyapısı (eski `ECONOMY_TWO_CURRENCY_DESIGN.md` buraya yönlendiriyor) |
| — | [architecture/ONLINE_ARCHITECTURE.md](docs/architecture/ONLINE_ARCHITECTURE.md) | Çevrimiçi mimarinin giriş noktası, maç yaşam döngüsü |
| — | [architecture/CLOUDFLARE_ARCHITECTURE.md](docs/architecture/CLOUDFLARE_ARCHITECTURE.md) | Workers + Durable Objects: limitler, tasarım, motorun uyumu (ölçüldü) |
| — | [architecture/SUPABASE_ARCHITECTURE.md](docs/architecture/SUPABASE_ARCHITECTURE.md) | Auth, Postgres, RLS, sunucu işlevleri, Realtime, plan limitleri |
| — | [architecture/SECURITY_ARCHITECTURE.md](docs/architecture/SECURITY_ARCHITECTURE.md) | Yeni mimaride güvenlik, anahtar yönetimi, ekonomi güvenliği, kurtarma |
| — | [architecture/COST_AND_SCALING.md](docs/architecture/COST_AND_SCALING.md) | Ücretsiz plan limitleri, 100 / 500 / 1.000 eşzamanlı oyuncu tahmini |
| — | [RISK_GOLD_ENTRY_MATCHES.md](docs/RISK_GOLD_ENTRY_MATCHES.md) | Altınlı maçların mevzuat ve mağaza risk notu (satın alınabilir altınla güncellendi) |

## Tasarım çıktıları (`docs/design/`)

| Yol | İçerik |
|---|---|
| `board/board_map.json` | Tahta geometrisi; kural motoru ve istemci için **tek kaynak** |
| `board/board_indices.png` | İndeksli tahta şeması |
| `screens/*.png` | 10 ekran prototipi (1080×2340) ve `overview.png` |
| `_src/` | Prototip kaynakları (HTML / CSS / JS), fontlar (SIL OFL), üretim betikleri |

Yeniden üretmek için (Python 3 + Pillow, Google Chrome gerekir):

```sh
python docs/design/_src/board_geometry.py   # board_map.json + board_indices.png
python docs/design/_src/render.py            # ekran PNG'leri + overview.png
```
