# ECONOMY_AND_PROGRESSION — Oyun İçi Ekonomi ve İlerleme

> **Durum:** Faz 1 taslağı (2026-11-16).
>
> **Bu belgede:** Bütün miktarlar **öneridir** (K-26…K-30). Değerler veri tablolarından ve uzaktan yapılandırmadan okunur; kod değişmeden ayarlanır.
>
> **Temel kural:** Pay-to-win yok. Ekonomideki hiçbir şey zar, kural ya da eşleştirmeyi etkilemez.

## 1. Para birimi

> **Faz 2 ve sonrası güncelleme (2026-11-17):**
> - Kesinleşen karar **Altın + Elmas**; ikisi de gerçek parayla satın alınabilir.
> - Altın: maç girişi, maç ödülü, günlük giriş, görev / başarım, standart kozmetik.
> - Elmas: yalnızca premium kozmetik.
> - Bu bölüm ve §4'ün "giriş ücreti yok" varsayımının yerine [economy/GOLD_AND_DIAMOND_ECONOMY.md](economy/GOLD_AND_DIAMOND_ECONOMY.md) geçerli. Risk notu: [RISK_GOLD_ENTRY_MATCHES.md](RISK_GOLD_ENTRY_MATCHES.md).


- **Tek para birimi: Altın** (K-27).
  - **Kaynaklar:** Oynayarak kazanılır (maç, görev, giriş, seviye, başarım, ödüllü reklam, Kulüp hediyesi) ve satın alınır (IAP).
  - **Harcama alanları:** Kozmetik mağaza, görev yenileme (ilk yenilemeden sonra), ad değiştirme (2. değişiklikten itibaren).
- **İkinci (premium) para birimi** (elmas vb.) MVP'de **yok**.
  - Gerekçe: ikinci para birimi; fiyat algısını bulandırır, düzenleme ve şeffaflık riskini artırır, mağaza ve muhasebe karmaşasını büyütür.
  - Sezon sistemiyle birlikte (v1.1) yeniden değerlendirilir.
- **Kaybetme yok:** Altın maçta **kaybedilmez**; giriş ücreti ya da bahis yok (K-28; MONETIZATION §5).

## 2. Kaynaklar ve harcamalar

**Ekonomi dengesi** (aktif oyuncu: günde 10 maç, reklam izliyor; tahmin):

| Kaynak | Günlük ortalama (altın) |
|---|---|
| Maç ödülleri (4 kişilik, ortalama sıra 2,5 → maç başı ~35) | ~350 |
| Günlük giriş (7 günlük döngünün ortalaması) | ~257 |
| Günlük görevler (3 görev, ortalama ~125, + 100 tamamlama bonusu) | ~475 |
| Ödüllü reklam: ücretsiz altın (5 × 50) | 250 |
| Ödüllü reklam: maç ödülünü ikiye katlama (5 × ~35) | ~175 |
| **Toplam** | **~1.500** (reklamsız ~1.080) |

**Fiyatlarla karşılaştırma:**

| Kozmetik | Fiyat (altın) | Aktif oyuncu için süre |
|---|---|---|
| Sıradan | 400 | ~yarım gün |
| Nadir | 1.200 | ~1 gün |
| Epik | 2.500 | ~2 gün |
| Efsane | 5.000 | ~3–4 gün |

- **Hedef his:** Oynayan oyuncu birkaç günde bir istediği bir şeyi alabilir. Satın alma bunu hızlandırır.
- **0,99 USD'lik paket** (1.000 altın) ≈ aktif oyuncunun bir günlük oyun kazancı.
- **Doğrulama:** Bu tablo yumuşak çıkış verileriyle yeniden ölçülür. Hedef ölçüt, "ilk kozmetik satın alma" medyanının 2. gün civarında olmasıdır.

**Enflasyon önlemleri:**
- Yeni kozmetik akışı (haftalık vitrin, aylık yenilik).
- Efsane öğeler.
- Ad değiştirme ve görev yenileme ücretleri.
- Altınla alınamayan doğrudan paketler oyun içi ekonomiyi şişirmez.

## 3. XP ve seviye

- **Eğri:** Seviye L'den L+1'e gereken XP = **100 + 25 × (L − 1)**. Seviye 50'den sonra sabit 1.325.

| Seviye | Bu seviyeden sonrakine | Toplam XP | Yaklaşık süre (günde 10 maç, ~300 XP) |
|---|---|---|---|
| 2 | 125 | 100 | İlk oturum |
| 5 | 200 | 550 | 2. gün |
| 10 | 325 | 1.800 | ~6 gün |
| 20 | 575 | 6.175 | ~3 hafta |
| 30 | 825 | 13.050 | ~6 hafta |
| 50 | 1.325 | 34.300 | ~4 ay |

- **Seviye ödülleri:**
  - Her seviyede **50 + 10 × L altın** (en fazla 300).
  - Her 5 seviyede bir kozmetik:

| Seviye | Ödül |
|---|---|
| 5 | Avatar |
| 10 | Çerçeve |
| 15 | Zar |
| 20 | Piyon seti |
| 25 | Tahta |
| 30 | Çerçeve |
| 40 | Efsane zar |
| 50 | Efsane çerçeve |

- **Seviyenin işlevi:** Seviye yalnızca görünür bir **deneyim göstergesidir**. Eşleştirmede kullanılmaz (MVP).

## 4. Maç ödülleri

### 4.1 Hızlı maç

| Mod | Sıra / sonuç | Altın | XP |
|---|---|---|---|
| 2 Kişi | Galibiyet | 60 | 40 |
| 2 Kişi | Mağlubiyet | 10 | 15 |
| 4 Kişi | 1. | 80 | 50 |
| 4 Kişi | 2. | 40 | 35 |
| 4 Kişi | 3. | 15 | 25 |
| 4 Kişi | 4. | 5 | 15 |
| Herhangi | Ayrıldı (terk) | 0 | 0 |
| Herhangi | Maç geçersiz (sunucu hatası) | 0 + telafi (§4.4) | 0 |

**Ek XP:** Yenen piyon başına +2 XP (en fazla +10), bitirilen piyon başına +2 XP.

### 4.2 Bot doldurmalı maç (K-05)

- Altın ve XP **× 0,5**, yukarı yuvarlanır.
- Görevler ilerler; haftalık galibiyet sıralamasına **sayılmaz**.

### 4.3 Özel oda ve pratik

- **Özel oda:**
  - Altın **yok**; XP **× 0,5**.
  - Görevlerden yalnızca "arkadaşla oyna" türü ilerler.
  - Başarımlarda yalnızca sosyal kategori ilerler.
  - Sıralamaya sayılmaz.
  - **Gerekçe:** Aynı kişinin iki hesabıyla ya da anlaşmalı arkadaşlarla ödül toplamasını (farming) anlamsız kılmak.
- **Pratik (bot, çevrimdışı):** Ödül yok; yalnızca eğitim başarımı ("İlk pratik").

### 4.4 Telafi

- **Ne zaman:** Sunucu kaynaklı geçersiz maçta.
- **Ne verilir:** Her oyuncuya 50 altın (`compensation`, maç başına bir kez) ve gelen kutusuna özür mesajı.
- **Sınır:** Günde en fazla 3 telafi.

## 5. Tek seferlik ödüller

| Olay | Ödül |
|---|---|
| Hesabı güvenceye alma (misafir → kalıcı) | 200 altın |
| İlk arkadaş | 100 altın |
| Eğitim tamamlandı | 100 altın + "Çaylak" çerçevesi |
| Bildirimlere izin | **Yok.** İzin karşılığı ödül politika ihlalidir. |

## 6. Günlük giriş ödülü

**7 günlük döngü** (öneri):

| Gün | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Altın | 50 | 100 | 150 | 200 | 300 | 400 | 600 |
| Ek | — | — | — | — | — | — | İlk döngüde avatar |

- **Gün sınırı:** TR saatiyle 00:00 (UTC+3; DATABASE_SCHEMA §1).
- **Gün kaçırılırsa:** Döngü **sıfırlanmaz, durur**: kaldığı günden devam eder (öneri; yumuşak tasarım). Alternatif: sıfırlanır (daha yüksek geri dönüş baskısı).
- **Kulüp üyeleri:** Ayrıca günde 100 altın kulüp hediyesi alır (MONETIZATION §4).

## 7. Görevler ve başarımlar

### 7.1 Günlük görevler (MVP)

- **Sayı:** Her gün **3 görev**, havuzdan ağırlıklı rastgele seçilir; aynı türden iki görev gelmez.
- **Tamamlama bonusu:** 3 görev de bitince **100 altın**.
- **Yenileme:** Günde 1 ücretsiz; sonra ödüllü reklamla (günde 2) ya da 100 altın.

| Görev | Hedef | Ödül (altın / XP) |
|---|---|---|
| Hızlı maç oyna | 3 | 100 / 20 |
| Hızlı maç kazan (2 kişilikte galibiyet ya da 4 kişilikte 1.) | 1 | 150 / 30 |
| 4 kişilikte ilk 2'ye gir | 2 | 150 / 30 |
| Rakip piyon ye | 5 | 150 / 30 |
| Piyon bitir | 6 | 120 / 25 |
| 6 at | 8 | 100 / 20 |
| Arkadaşınla oyna (özel oda) | 1 | 150 / 30 |
| Maçta emoji gönder | 3 | 80 / 15 |

- **Haftalık görevler:** v1.1 (K-52). 5 görev, daha büyük hedefler, haftalık bonus sandığı (sabit içerik).

### 7.2 Başarımlar (MVP, ~20)

| Kategori | Başarımlar (ödül: altın + bazen kozmetik) |
|---|---|
| Maç | İlk galibiyet (100) · 10 / 100 / 500 galibiyet (200 / 1.000 + çerçeve / 3.000 + efsane zar) · Hiç piyon kaybetmeden kazan (300) · Son piyonla geri dönüş: diğerleri 3 bitirmişken 1. ol (500) |
| Ustalık | 10 / 100 / 1.000 piyon ye (100 / 500 / 2.000 + piyon seti) · 100 piyon bitir (500) · Üç 6 üst üste ("Şanssız şanslı"; 150; gizli) |
| Sosyal | İlk arkadaş (100) · 10 arkadaş (300) · Arkadaşla 10 maç (300 + avatar) |
| Koleksiyon | 10 kozmetik (300) · Bütün zarlar (1.000 + çerçeve) |
| Süreklilik | Seviye 10 / 25 / 50 (rozetler) · 7 gün üst üste giriş (300) |

- **Ödülün alınması:** Başarımlar sunucuda maç olaylarından ve istatistiklerden hesaplanır. Ödül **elle alınır**; kutlama anı oyuncunun kontrolündedir.

## 8. Sıralama

**MVP önerisi (K-26): Haftalık galibiyet sıralaması.**
- **Sayılanlar:** Hızlı maçlarda 2 kişilik galibiyet ya da 4 kişilik 1.'lik = 1 galibiyet. Bot doldurmalı maçlar ve özel odalar sayılmaz.
- **Sekmeler:** Genel ve Arkadaşlar.
- **Sıfırlanma:** Pazartesi 00:00 TR.
- **Haftalık ödüller** (otomatik, gelen kutusuna):

| Sıra | Ödül |
|---|---|
| 1 | 2.000 altın + "Haftanın Şampiyonu" çerçevesi (1 hafta kuşanılabilir) + kalıcı rozet |
| 2–10 | 1.000 altın + rozet |
| 11–100 | 500 altın + rozet |
| 101–1.000 | 150 altın |

- **Alternatif (prototipte görünen 🏆 kupa puanı):** Kupa ve dereceli sistemi.
  - Galibiyet +, mağlubiyet − (2 kişilikte ±24; 4 kişilikte 1.–4. için +30 / +10 / −10 / −24).
  - Kupaya göre eşleştirme, sezon sonu ödülleri.
  - MVP için oyuncu havuzu küçükken bekleme süresini uzatma riski var; **v1.1 önerisi**.
- **Hile önlemi:** Haftalık ilk 100 için otomatik tutarlılık denetimi; işbirliği sinyali varsa ödül bekletilir (SECURITY §13).

## 9. Kozmetikler

### 9.1 MVP kataloğu (öneri, K-30)

| Tür | Adet | Varsayılan (ücretsiz) | Altınla | Seviye / başarım | Doğrudan IAP / Kulüp |
|---|---|---|---|---|---|
| Avatar | 24 | 12 | 6 | 4 | 2 |
| Çerçeve | 6 | — | 2 | 3 | 1 (Kulüp) |
| Zar | 6 | 1 (Klasik Krem) | 3 | 1 | 1 (paket) |
| Piyon seti | 4 | 1 (Klasik Cam) | 1 | 1 | 1 (paket) |
| Tahta teması | 3 | 1 (Klasik) | 1 | — | 1 (paket) |
| Emoji seti | 2 | 1 | — | — | 1 (Kulüp) |

### 9.2 Fiyatlar

| Nadirlik | Altın | Görsel ipucu |
|---|---|---|
| Sıradan | 400 | Gri etiket |
| Nadir | 1.200 | Mor |
| Epik | 2.500 | Pembe |
| Efsane | 5.000 | Altın, hafif animasyon |

### 9.3 Vitrin ve kurallar

- **Günlük vitrin:** Her gün 3 ürün (biri %20 indirimli), bütün oyuncular için aynı; uzaktan yapılandırma ile.
- **Okunabilirlik kuralları:** Kozmetikler oynanabilirliği bozmaz (UI_UX_DESIGN_SYSTEM §7.4). Zar okunabilir, renk sembolleri görünür kalır.

## 10. Sezonlar ve etkinlikler (sonraki sürümler)

- **Sezon (v1.1, K-51):**
  - 6 haftalık sezon; ücretsiz ve Kulüp yolu olan sezon ilerleme şeridi (XP ile, satın alınabilir seviye **yok**).
  - Sezon kozmetikleri ve kupa sıralaması.
  - Sezon şeridi bir "battle pass"tir ve şeffaf içeriklidir; rastgele içerik yoktur.
- **Etkinlikler (v1.2+):**
  - Hafta sonu çift XP.
  - "Yıldız Avı": yıldız karelerinde durma görevleri.
  - Bayram temaları: Ramazan / Kurban bayramı ve yılbaşı tahta temaları.
  - Hızlı mod haftası.
- **Not:** Etkinlikler kural değiştirirse yeni bir `ruleset` olarak tanımlanır (GAME_RULES §12).
