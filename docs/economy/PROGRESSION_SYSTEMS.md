# PROGRESSION_SYSTEMS — Faz 6'da uygulanan ilerleme sistemleri

> Kaynak tasarım: [ECONOMY_AND_PROGRESSION.md](../ECONOMY_AND_PROGRESSION.md). Bu belge **uygulanan** değerleri ve kuralları anlatır.
> Bütün sayılar sunucunun yapılandırmasındadır (Supabase `app_config`). Kaynak dosyalar `shared/config/*.json`.
> `node server/worker/scripts/progression_config.mjs --check | --apply` dosyaları veritabanıyla karşılaştırır ya da uygular; denge değişikliği için migration gerekmez.

## 0. Ortak ilkeler

- **Kim hesaplar:** Her şey sunucuda hesaplanır.
  - XP, görev ilerlemesi, başarım sayaçları ve haftalık puan, oyun sunucusunun Supabase'e maç sonucunu kaydettiği **aynı veritabanı işleminde** güncellenir: `game.record_match` → `game._after_match`.
  - Bu işlem maç başına bir kez çalışır.
  - İstemci hiçbir sayı göndermez. Tablolara yazamaz ve sunucu işlevlerini çağıramaz (RLS + yetkiler).
- **Ödülleri toplama:** Oyuncu ödülü kendi JWT'siyle bir RPC çağrısı yaparak toplar.
  - Toplama tek satırlık bir güncellemedir: ödül en fazla bir kez verilir, eşzamanlı isteklerde de.
  - Altın, defter (`game._apply`) üzerinden ve tekil bir idempotency anahtarıyla ödenir.
  - XP, `xp_events` üzerinden ve (oyuncu, neden, kaynak) başına bir kez verilir.
- **Zaman:** TR günü 00:00 (UTC+3), TR haftası pazartesi 00:00. Yalnızca sunucu saati kullanılır; cihaz saatinin etkisi yoktur.
- **Ödül kasmaya karşı (K-75):**
  - Oyuncunun ayrılmasıyla **30 hamleden önce** biten maç kimseye ödül vermez.
  - Maçtan ayrılan oyuncu hiçbir ödül almaz.
  - Maçlardan günde en çok **1500 XP**. Haftalık puanda günde en çok **300**.
  - Özel odada XP **yarıdır**; görev ve başarımlardan yalnızca **arkadaşla oyna** türleri ilerler; sıralamaya sayılmaz.
  - Test maçları ve çevrimdışı (bot / pratik) maçlar hiçbir şey vermez.

## 1. XP ve seviye (6.1)

| Maç | 1. | 2. | 3. | 4. |
|---|---|---|---|---|
| Hızlı, 2 kişi | 40 | 15 | — | — |
| Hızlı, 4 kişi | 50 | 35 | 25 | 15 |
| Özel oda | yukarıdakinin yarısı (yukarı yuvarlanır) | | | |

- **Seviye eğrisi:**
  - L'den L+1'e gereken XP = 100 + 25 × (L − 1); 50. seviyeden sonra sabit 1.325.
  - En yüksek seviye 100 (yapılandırmayla artırılabilir).
  - 5. seviyeye 550 XP, 10. seviyeye 1.800 XP ile ulaşılır.
- **Seviye ödülü:**
  - Her yeni seviyede 50 + 10 × L Altın, en çok 300.
  - 5 / 10 / 25 / 50 / 100. seviyelerde rozet.
- XP maç süresine bağlı değildir; yalnızca sıraya bağlıdır.

## 2. Görevler (6.2)

- **Atama:**
  - Her gün 3 günlük, her hafta 4 haftalık görev.
  - Şablon havuzundan, oyuncuya ve döneme göre deterministik seçilir; her gruptan en fazla bir görev.
- **Metrikler:** tamamlanan maç, galibiyet, kendi attığın zar, 2 / 4 kişilik maç, arkadaşla maç, giriş günü.
- **Süresi biten görevler:** Tamamlanmış ama toplanmamış eski dönem görevleri "toplanmamış ödüller" olarak kalır ve toplanabilir.
- **Ödüller:** Günlük görevler 60–200 Altın + 15–45 XP; haftalık görevler 300–600 Altın + 60–120 XP.

## 3. Günlük giriş (6.3)

| Gün | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Ödül | 30 XP | 100 Altın | 50 XP | 200 Altın | 80 XP | 300 Altın | 500 Altın + 100 XP + "Sadık Oyuncu" rozeti (ilk kez) |

- Günde bir kez.
- **Gün kaçırılırsa (K-74):** Döngü kaldığı günden sürer; yalnızca ardışık gün serisi 1'e döner.
- Her giriş, haftalık "N farklı gün giriş yap" görevini ilerletir.

## 4. Başarımlar (6.4)

- **Başarım listesi (12):**
  - İlk maç, ilk galibiyet.
  - 10 / 50 / 100 maç; 10 / 50 galibiyet.
  - 3 / 5 maçlık galibiyet serisi.
  - 2 kişilikte 25 galibiyet; 4 kişilikte birincilik.
  - Arkadaşla 10 maç.
- **Sayaçlar:** `player_counters` tablosunda tutulur. Seri, hızlı maç galibiyetleriyle artar; mağlubiyet ya da ayrılma seriyi sıfırlar.
- **Ödüller:** Altın + XP. Bazı başarımlar rozet de verir: Kıdemli, Şampiyon, Durdurulamaz, Sosyal Kelebek.
- **Rozetler:** Oyuncu açtığı rozetlerden birini profilinde gösterebilir (`set_profile_badge`). Arkadaş profili ve sıralama bu rozeti gösterir.
- **Yeni başarım eklemek:** `achievements_config.json` dosyasına bir satır eklenir. Yeni bir metrik gerekmiyorsa kod değişmez.

## 5. Haftalık sıralama (6.5) — puanlar nasıl kazanılır

| Hızlı maç | 1. | 2. | 3. | 4. |
|---|---|---|---|---|
| 2 kişi | **10** | **2** | — | — |
| 4 kişi | **15** | **8** | **4** | **1** |

- **Neden böyle (adalet):**
  - Maç başına beklenen puan 2 kişide 6, 4 kişide 7. 4 kişilik maçlar daha uzun sürdüğü için saat başına puan yakın kalır.
  - Galibiyet ve iyi sıra, salt maç sayısından çok daha değerlidir: 2 kişide kazanmak, kaybetmekten 5 kat fazla puan getirir.
- **Sayılmayanlar:** Özel oda, test maçı, ayrılınan maç, erken biten maç. Günlük puan sınırı 300.
- **Sıralama ölçütleri (eşitlikte sırayla):**
  1. Puan
  2. Galibiyet
  3. Daha az maç
  4. O puana önce ulaşan
- **Dönem:** TR haftası (pazartesi 00:00 → pazar 23:59). Geçmiş haftalar saklanır ve "Geçen hafta" sekmesinde görünür.
- **Ödüller:**

  | Sıra | Ödül |
  |---|---|
  | 1 | 2.000 Altın + "Haftanın Şampiyonu" rozeti |
  | 2–10 | 1.000 Altın + "Haftanın İlk 10'u" rozeti |
  | 11–100 | 500 Altın |

  - Ödüller yalnızca Altın ve rozettir; oyunda avantaj sağlamaz.
  - Altınlı maçlar kapalı olduğu için Altın şu an yalnızca biriktirilir.
- **Hafta sonu dağıtımı:**
  - Cloudflare zamanlanmış tetikleyicisi her saat başı (dakika 7) `game.leaderboard_maintenance()` işlevini çalıştırır (rol `game_server`).
  - İşlev bitmiş her haftayı bir kez kapatır ve ödülleri öder.
  - Haftanın satırı kilitlenir; defter anahtarı hafta ve oyuncu başına tektir. Tekrar ya da paralel çalışma ikinci kez ödemez.
- **Henüz yok:** Mağaza öncesi, ilk 100'de işbirliği ya da hile denetimi (ECONOMY_AND_PROGRESSION §8). Ödülleri bekletme mekanizması K-76 olarak açık konu.
