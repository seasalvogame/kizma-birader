# Faz 2 — İnceleme ve Teknik Plan

> **Tarih:** 2026-11-16.
>
> **Durum:** Faz 2'nin başında, kod yazılmadan önce hazırlandı.
>
> **Kaynaklar:**
> - Faz 2 talimatı (kullanıcının kesinleştirdiği kararlar).
> - Faz 1 belgeleri (`docs/`).
> - Tahta geometrisi: `docs/design/board/board_map.json`.
> - Prototipler: `docs/design/screens/`.

## 1. Dosya kontrolü

| Beklenen | Bulunan |
|---|---|
| 13 belge (talimattaki liste) | Hepsi `docs/` altında, aynı adlarla ✅ |
| Ek Faz 1 belgeleri | `LOCALIZATION_SPECIFICATION.md`, `TESTING_AND_PERFORMANCE.md`, `USER_FLOWS.md` |
| `board_map.json` | `docs/design/board/board_map.json` (kökte değil) |
| Tahta şeması | `docs/design/board/board_indices.png` |
| 10 ekran prototipi | `docs/design/screens/01…10_*.png` + `overview.png`; kaynak: `docs/design/_src/` |
| Faz 1 raporu | `PHASE_1_REPORT.md` (kökte) |

Eksik dosya yok. Farklı adlandırılmış dosya yok.

## 2. Mevcut tasarımın ve kararların özeti

- **Tahta:**
  - 15×15 ızgara, 52 parkur hücresi.
  - Başlangıç parkur indeksleri: kırmızı 0, yeşil 13, sarı 26, mavi 39.
  - Yıldızlar 8, 21, 34, 47.
  - Renk başına 5 koridor hücresi + orta bitiş; adım 0–56.
  - Renk köşeleri saat yönünde: kırmızı sol üst, yeşil sağ üst, sarı sağ alt, mavi sol alt.
- **Kurallar** (Faz 2'de kesinleşenler ✅, hâlâ öneri olanlar ⏳):

| Kural | Durum |
|---|---|
| Yalnızca 6 ile çıkış | ✅ |
| 6 → ek zar | ✅ |
| Üçüncü 6 → tur biter | ✅ |
| Yıldızlar ve başlangıçlar güvenli | ✅ |
| Bitişte tam sayı | ✅ |
| 2 kişilik bitiş ve 4 kişilik "3 sıra belli olana kadar" | ✅ |
| Zar 10 sn, seçim 12 sn | ✅ |
| Çıkan piyon başlangıç karesine konur (K-11) | ⏳ |
| Yeme sonrası ek zar (K-14) | ⏳ |
| Bitişe girince ek zar (K-15) | ⏳ |
| Yığılma serbest, blokaj yok, yığında hepsi yenir (K-18) | ⏳ |
| Tek hamlenin otomatik oynanması (K-20) | ⏳ |
| AFK, kopma, terk (K-22…K-24) | ⏳ |
| Renk köşeleri (K-07) ve 2 kişilik renk çifti (K-08) | ⏳ |

- **Görsel:** "Akşam Masası": gece moru zemin, yıldız dokusu, krem kartlar, mango ana buton, Baloo 2 + Nunito, tokenlar (UI_UX_DESIGN_SYSTEM). Yalnızca dikey ekran; tahta kare; yerel oyuncu sol altta.
- **Mimari:** Godot 4 istemci; Supabase (Auth, Postgres, RLS; istemci yazamaz); Node.js otoriter sunucu (WSS); Redis.

## 3. Bulunan çelişkiler (kod yazmadan önce raporlanan)

| # | Faz 1 belgesi | Faz 2 kararı | Ne yapılacak |
|---|---|---|---|
| Ç1 | ECONOMY §1, DECISIONS K-27: **tek para birimi** | **Altın + Elmas** | Karar uygulanır. ECONOMY, MONETIZATION, DATABASE_SCHEMA ve DECISIONS belgeleri alt faz 2.6'da güncellenir. |
| Ç2 | ECONOMY §1, MONETIZATION §5, K-28: **giriş ücreti / ödül havuzu yok** (kumar algısı riski) | **Altınlı maç giriş bedeli + sunucuda hesaplanan ödül** | Karar uygulanır (bu fazda yalnızca yapılandırma tasarımı). Talimatın istediği **mevzuat / mağaza risk notu** ayrı belge olarak hazırlanır (`docs/RISK_GOLD_ENTRY_MATCHES.md`). Notun ana önerisi: Altın **gerçek parayla satın alınamasın**. Talimat altın kaynaklarını maç, görev, günlük ödül ve reklam olarak sayıyor ama bu açıkça yazılmamış; bu bir karar konusu. |
| Ç3 | TECHNICAL_ARCHITECTURE §9, K-53: **Supabase Realtime MVP'de kullanılmaz** | Supabase Realtime: çevrimiçi durumu, davetler, sosyal bildirimler | Karar uygulanır. Mimari belgesi güncellenir; iki kalıcı bağlantının pil ve yeniden bağlanma riski risk listesinde kalır. |
| Ç4 | TECHNICAL_ARCHITECTURE §15: `server/packages/rules`, `client/` | Talimat: `server/game-engine/`; Godot klasörleri `scenes/`, `scripts/`… | **`server/game-engine/`** kullanılır. Godot projesi **`client/`** altında kurulur ve önerilen klasörler onun içinde olur. Gerekçe: proje kökünde kurulursa Godot `docs/`, `server/` ve `node_modules` klasörlerini de içe aktarmaya çalışır. Faz 1 belgesi de `client/` diyordu. |
| Ç5 | `board_map.json` tek kaynak, ama Godot `res://` dışını dışa aktarılmış APK'da okuyamaz | — | Kaynak `docs/design/board/board_map.json` olarak kalır. Godot için `client/data/board_map.json` **kopyası** betikle üretilir; bir test kopyanın kaynakla **bayt bayt aynı** olduğunu doğrular. TS motoru kaynağı doğrudan okur. |

Ç1–Ç3 senin açık kararların; belgeler sana uyacak şekilde güncellenecek. Ç4–Ç5 uygulama ayrıntısı.

## 4. Teknik plan — alt fazlar

Her alt faz kendi testleriyle kapanır; sonuçlar rapora yazılır.

| Alt faz | İş | Test / kabul |
|---|---|---|
| **2.1** TS oyun motoru | `server/game-engine/`: `BoardGeometry` (JSON'dan), `Ruleset`, `GameState` / `PlayerState` / `PawnState`, `DiceManager` (enjekte edilebilir kaynak), `MoveValidator`, `CaptureResolver`, `TurnManager`, `WinCondition`, `GameEvent`, `GameEngine` (saf; durum + eylem → yeni durum + olaylar), `MatchSession` (istek kimliği ile tekrar koruması), `Bot` (belirleyici öncelik listesi) | Vitest: talimattaki 18 senaryo + ek kurallar; board_map doğrulama testleri; fast-check ile değişmezler (binlerce rastgele maç) |
| **2.2** Ortak test vektörleri | `shared/rules_test_vectors/`: elle yazılmış senaryolar + TS'nin ürettiği "altın" beklenen sonuçlar; tohumlu rastgele maç izleri (her adımın durum özeti) | TS kendi vektörlerini yeniden üretip karşılaştırır |
| **2.3** GDScript motoru + Godot iskeleti | `client/`: `project.godot` (dikey, ölçekleme, güvenli alan), klasör yapısı, `scripts/game/rules/` (motorun GDScript eşi, Node bağımlılığı yok), headless test koşucusu | GDScript birim testleri + **bütün** ortak vektörler ve rastgele maç izleri TS ile birebir |
| **2.4** Tahta, piyon, zar görselleri | Tahta `board_map.json`'dan çizilir; döndürme (yerel renk sol altta); piyon ve zar görselleri Faz 1 prototipiyle aynı tasarımdan; tema tokenları, fontlar | Her renk için döndürme testi; hücre koordinatı testleri; 7 ekran oranında görüntü |
| **2.5** Oynanabilir çevrimdışı maç | Pratik menüsü (2 / 4 kişi, koltuk: insan / bot); maç ekranı (oyuncu kartları, sayaç halkası 10 / 12 sn, zar alanı, ipucu); animasyonlar (zar, adım adım zıplama, yeme, bitiş); maç menüsü (çık / yeniden başlat); sonuç ekranı; TR / EN | Uçtan uca headless maçlar (insan koltuğu otomatik); düzen testleri; görüntü kontrolü |
| **2.6** Ekonomi ve mimari hazırlığı | Ekonomi tasarım güncellemesi (iki para birimi, giriş seviyeleri yapılandırması, defter, çift ödül engeli, negatif bakiye, telafi); altınlı maç risk notu; Supabase / Realtime / Redis mimari güncellemesi | Belgeler; yapılandırma şeması (JSON Schema) ve örnek doğrulama testi |
| **2.7** Uyumluluk araştırması ve cihaz | Supabase Auth + Godot (anonim giriş, kimlik bağlama, veri kaybı riski); reklam, IAP, giriş ve push eklentilerinin sürüm uyumu (kaynaklı araştırma); Android APK dışa aktarma | Rapor. Telefon bağlı değilse cihaz testi **yapılmadı** diye yazılır. |
| **2.8** Rapor | `PHASE_2_REPORT.md` | — |

## 5. Bu fazın kapsamı dışında kalanlar

- Gerçek ağ oyunu, Supabase projesi kurulumu, satın alma, reklam ve mağaza.
- Ses (varlık yok). Ses servisi iskeleti olabilir, ama ses dosyası placeholder olarak bile eklenmez.
- Gerçek avatar görselleri: Bu fazda harf + gradyan avatarlar kullanılır ve `assets/ASSETS.md` dosyasında **placeholder** olarak işaretlenir.

## 6. Bilinen kısıtlar

- **Telefon bağlı değil:** Cihaz testi şu an mümkün değil. APK dışa aktarılır, kurulumu senin bağlantına kalır.
- **iOS:** Mac olmadığı için derleme ve test **yok**.
- **Supabase'in canlı doğrulaması:** Bir Supabase projesi (URL + anon anahtar) gerekiyor. Yerel Supabase yığını Docker ister ve C: diskinde 4,6 GB boş alan var; birkaç GB'lık imajlar için yetersiz. Bu yüzden doğrulama, bir proje bilgisi verilmedikçe **belge ve kaynak araştırması** düzeyinde kalacak.
- **Ekran aracılığıyla görüntü:** Godot görüntüleri masaüstünde çekilir; mobil performans hakkında iddia içermez.
