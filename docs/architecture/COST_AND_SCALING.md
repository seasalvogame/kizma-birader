# COST_AND_SCALING — Ücretsiz Plan Limitleri, Maliyet ve Ölçek

> **Durum:** Faz 2 sonrası güncelleme (2026-11-17).
>
> **Önemli uyarı:** Bu belgedeki kullanım ve maliyet rakamları **tahmindir**.
> - **Kesin olanlar:** Plan limitleri ve birim fiyatlar (resmi kaynak, §8).
> - **Ölçülenler:** Maç başına eylem sayısı, durum boyutu ve işlem süresi (CLOUDFLARE_ARCHITECTURE §5).
> - **Tahmin olanlar:** Oyuncu davranışı, maç temposu ve bunlardan türeyen kullanım.
>
> Gerçek değerler Faz 5'teki yük ve kota testleriyle ölçülecek.
>
> **Öncelik** (senin kararın): Ücretsiz planlarla geliştirmek ve test etmek; mümkünse ilk yayını karşılamak. **Güvenlik, oyun tutarlılığı ve performanstan ödün verilmez.**

## 1. Kısa sonuç

| Dönem | Ücretsiz plan yeterli mi? | Aylık tahmini maliyet |
|---|---|---|
| Geliştirme, iç testler, birkaç kişilik kapalı test | **Evet** (her iki tarafta) | **0 USD** |
| Kapalı beta (onlarca oyuncu, ara ara) | Sınırda. Cloudflare'in günlük satır yazma limiti zorlar. | 0–5 USD |
| Herkese açık yayın (100+ eşzamanlı oyuncu) | **Hayır** | Önerilen en düşük **~30 USD** (Cloudflare 5 + Supabase 25) |
| 500 eşzamanlı | Hayır | **~35–180 USD** + olası Supabase bilgi işlem yükseltmesi (tahmin) |
| 1.000 eşzamanlı | Hayır | **~100–390 USD** + olası Supabase bilgi işlem yükseltmesi (tahmin) |

**Ücretsiz plan neden yayına yetmiyor:**
1. **Cloudflare limitleri:** Ücretsiz Durable Objects'te günde **100.000 satır yazma** ve **100.000 istek** sınırı var. Aşılınca işlemler hata veriyor; maçlar yarıda kalır. Sayaçlar 00:00 UTC'de (TR 03:00) sıfırlanıyor.
2. **Supabase Free'nin eksikleri:** **Otomatik yedek yok**; bu, gerçek parayla satın alınan altın ve Elmas bakiyeleri için kabul edilemez. Ayrıca proje bir hafta hareketsiz kalınca duraklatılıyor.

Bu ikisi, "ücretsiz kalalım" önceliğinin "güvenlik ve tutarlılıktan ödün verme" önceliğiyle çatıştığı yer. Önerim yayında ücretli plana geçmek (K-58, K-38).

## 2. Kullanım modeli (girdiler)

| Girdi | Değer | Tür |
|---|---|---|
| Maç başına eylem (zar + hamle), 2 kişilik | Ort. 337 (p90 457) | **Ölçüldü** (300 bot maçı) |
| Maç başına eylem, 4 kişilik (3 sıra belli olana kadar) | Ort. 1.525 (p90 2.027) | **Ölçüldü** (300 bot maçı) |
| Eylem başına ortalama süre (animasyon + düşünme) | 1,6 sn | Tahmin |
| → Maç süresi | 2 kişilik ~9 dk, 4 kişilik **~41 dk** | Tahmin |
| → Aktif bir maçta saatte eylem | ~2.250 | Tahmin |
| Çevrimiçi oyuncuların maçta olan payı | %80 | Tahmin |
| Maçtakilerin 2 / 4 kişilik dağılımı | %50 / %50 (oyuncu bazında) | Tahmin |
| → Eşzamanlı maç sayısı | 0,3 × eşzamanlı oyuncu | Türetilmiş |
| Gün boyu ortalama eşzamanlılık / tepe | %40 | Tahmin |
| Durum boyutu | 1,1–1,7 KB (tek satır) | **Ölçüldü** |

> **Ürün notu:** 4 kişilik maçın ölçülen uzunluğu, tahmini tempoyla ~41 dakikaya denk geliyor. Bu, K-25 kararının ("3 sıra belli olana kadar") bir sonucu. Hem oyuncu deneyimini hem maliyeti etkiler. Karar senin; yalnızca ölçümü bildiriyorum.

## 3. Cloudflare kullanımı (tahmin)

**En büyük kalem: SQLite'a yazılan satır.** Üç kalıcı yazma stratejisi (K-60):

| Strateji | Maç-saati başına satır | Not |
|---|---|---|
| **A:** Her eylemden sonra durum + her eylemde `setAlarm` | ~4.500 | En basit |
| **B:** Her eylemden sonra durum; alarm yalnızca yedek (süre dolumunu bağlı istemcinin talebiyle işleme) | ~2.300 | Kurtarma güvencesi A ile aynı |
| **C:** Yalnızca tur sonunda yazma | ~1.200 | Çökmede son tur yeniden oynanır; adalet riski |

**Ücretsiz planla taşınabilecek maç-saati / gün** (günde 100.000 satır):

| Strateji | Maç-saati / gün | Gün boyu ortalama eşzamanlı maç |
|---|---|---|
| A | 22 | ~1 |
| B | 43 | ~2 |
| C | 83 | ~3,5 |

**Eşzamanlı oyuncuya göre aylık tahmin** (30 gün; Workers Paid planı; 5 USD taban ücret hariç):

| Ölçü | 100 eşzamanlı | 500 eşzamanlı | 1.000 eşzamanlı |
|---|---|---|---|
| Tepe eşzamanlı maç | 30 | 150 | 300 |
| Maç-saati / ay | 8.640 | 43.200 | 86.400 |
| Yazılan satır / ay, A | 38,9 M → **0 $** (50 M dahil) | 194 M → **~144 $** | 389 M → **~339 $** |
| Yazılan satır / ay, B | 19,9 M → 0 $ | 99 M → ~49 $ | 199 M → ~149 $ |
| Yazılan satır / ay, C | 10,4 M → 0 $ | 52 M → ~2 $ | 104 M → ~54 $ |
| DO istekleri / ay (WebSocket 20:1 dahil) | ~2 M → ~0,15 $ | ~10 M → ~1,4 $ | ~20 M → ~2,9 $ |
| DO süresi, **hibernation ile** (olay başına ~25 ms varsayımı) | 0,06 M GB-sn → 0 $ | 0,32 M → 0 $ | 0,64 M → ~3 $ |
| DO süresi, **hibernation olmadan** (en kötü durum) | 3,9 M GB-sn → ~44 $ | 19,4 M → **~238 $** | 38,9 M → **~481 $** |
| Worker istekleri / ay (oyuncu-saati başına 20 varsayımı) | 0,6 M → 0 $ | 2,9 M → 0 $ | 5,8 M → 0 $ |

**Sonuçlar:**
- **Hibernation zorunlu bir tasarım kuralı.** Olmazsa süre ücreti tek başına en büyük kalem olur.
  - Belirsizlik: bekleyen bir alarmın hibernation'ı engelleyip engellemediği (T-1). Faz 3'te ilk denenecek konu bu.
- **Yazma stratejisi maliyeti 6 kata kadar değiştiriyor.** Karar ölçümle verilecek (K-60). Önerim B: kurtarma güvencesinden ödün vermeden yazmaları yarıya indiriyor.
- **İstek ve Worker maliyeti ihmal edilebilir.**

## 4. Supabase kullanımı (tahmin)

| Ölçü | 100 eşzamanlı | 500 eşzamanlı | 1.000 eşzamanlı | Ücretsiz limit | Pro'da dahil |
|---|---|---|---|---|---|
| Realtime tepe bağlantı, **sürekli bağlı** | 100 | 500 | 1.000 | 200 | 500 (sonra 1.000 başına 10 $; harcama sınırı kapatılmalı) |
| Realtime tepe bağlantı, **yalnızca menüde** (SUPABASE_ARCHITECTURE §7) | 20 | 100 | 200 | 200 | 500 |
| Realtime mesaj / ay (oyuncu-saati başına 30 varsayımı) | 0,9 M | 4,3 M | 8,6 M → ~9 $ | 2 M | 5 M |
| MAU (günde 30 dk oturum, MAU ≈ 3 × DAU varsayımı) | ~5.800 | ~28.800 | ~57.600 | 50.000 | 100.000 |
| Günlük maç | ~1.400 | ~7.100 | ~14.200 | — | — |
| Veritabanı büyümesi (maç başına ~4,4 KB, kompakt kayıt) | ~6 MB / gün | ~31 MB / gün | ~63 MB / gün | **500 MB** (100 eşzamanlıda ~2–3 ayda dolar) | 8 GB |
| Çıkış trafiği / ay (oyuncu-saati başına 0,3 MB varsayımı) | ~9 GB | ~43 GB | ~86 GB | 5 GB | 250 GB |
| Yedek | — | — | — | **Yok** | Günlük, 7 gün |

**Notlar:**
- **Maç kaydı kompakt tutulur.** Olay listesi yerine yalnızca eylem dizisi saklanır: zar ve piyon seçimi, Faz 2'deki iz biçimi gibi (`r6 m0 r3 …`). Motor belirleyici olduğu için maç bu diziden **birebir yeniden oynatılabilir**.
  - 2 kişilik maç ~1 KB, 4 kişilik ~4,6 KB (ölçülen eylem sayısıyla).
- **Bilgi işlem (compute):** Pro, bir "Micro" örneği karşılayan aylık 10 $ kredi içeriyor (resmi).
  - 500–1.000 eşzamanlı oyuncuda daha büyük bir örnek gerekip gerekmediği ve bunun fiyatı **ölçülecek ve doğrulanacak**.
- **MAU:** Anonim (misafir) kullanıcıların MAU'ya sayılıp sayılmadığı **doğrulanacak**.

## 5. Limit aşımında ne olur

| Servis | Ücretsiz plan | Ücretli plan |
|---|---|---|
| Workers | Günlük istek bitince **hata 1027**; rota ayarına göre Worker atlanır (fail open) ya da hata sayfası (fail closed) | Aşım faturalanır, hizmet sürer |
| Durable Objects | Günlük limit bitince o türdeki işlemler **hata verir**: maç durumu yazılamaz, mesajlar işlenmez | Aşım faturalanır |
| Supabase | Kotalar plana göre uygulanır. Realtime'da bağlantı ya da katılma reddi, mesaj hızında kopma. Ücretsiz projede 1 hafta hareketsizlikte duraklatma. | Pro'da harcama sınırı açıksa sınırlar uygulanır; kapatılırsa aşım faturalanır |

**Kesin kural:**
- Yayında **hiçbir maç**, bir günlük kota bittiği için yarıda kalmamalı.
- Bu yüzden herkese açık yayından önce:
  - Cloudflare Paid'e geçilmeli (K-58);
  - kota kullanımına %70 ve %90 uyarıları kurulmalı (SECURITY_ARCHITECTURE §9).

## 6. Ücretli plana geçiş gerektiren durumlar

| Tetikleyici | Geçiş |
|---|---|
| Herkese açık yayın ya da kalabalık kapalı beta | **Cloudflare Workers Paid** (aylık 5 USD) |
| Gerçek para ile ilk satın alma (prod) | **Supabase Pro** (yedekleme, duraklatılmama) |
| `staging` ve `prod` için ayrı Supabase projesi | Pro. Ücretsiz planda en fazla 2 etkin proje; `dev` + bir proje. |
| Realtime eşzamanlı bağlantı > 200 | Pro; > 500 için harcama sınırı kapatılmalı |
| Veritabanı > 500 MB ya da çıkış > 5 GB / ay | Pro |
| DO satır yazma > 50 M / ay | Paid planda kullanım ücreti başlar (milyon başına 1 $) |

## 7. Maliyeti düşüren tasarım kuralları (güvenlikten ödün vermeden)

1. **Hibernation API + alarm:** `setTimeout` yok.
2. **Uygulama düzeyi ping yok:** Protokol ping'i faturalanmaz.
3. **Tek geçerli hamle zarla aynı işlemde:** Ek zamanlayıcı ve yazma yok.
4. **Durum tek satır;** gereksiz indeks yok (her indeks yazma sayısını artırabilir; **doğrulanacak**).
5. **Hamle başına Supabase çağrısı yok:** Yalnızca maç başı ve sonu.
6. **Realtime yalnızca menüde.**
7. **Kompakt maç kaydı.**
8. **Hız sınırlarıyla kötü niyetli trafik** erken kesilir.

## 8. Kaynaklar (erişim: 2026-11-17)

- Cloudflare Durable Objects fiyatlandırma: https://developers.cloudflare.com/durable-objects/platform/pricing/
- Cloudflare Durable Objects limitleri: https://developers.cloudflare.com/durable-objects/platform/limits/
- Cloudflare Workers limitleri: https://developers.cloudflare.com/workers/platform/limits/
- Cloudflare Workers fiyatlandırma: https://developers.cloudflare.com/workers/platform/pricing/
- Supabase fiyatlandırma: https://supabase.com/pricing
- Supabase Realtime limitleri: https://supabase.com/docs/guides/realtime/limits
- Supabase proje duraklatma: https://supabase.com/docs/guides/platform/free-project-pausing

**Hesap betiği:** Tahminler, girdileri §2'deki tabloda olan küçük bir betikle hesaplandı. Faz 5'te ölçülen gerçek değerlerle yeniden çalıştırılacak; betik o fazda `tools/` altına alınacak.
