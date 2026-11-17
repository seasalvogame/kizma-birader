# Faz 2 Sonrası Güncelleme Raporu — Kararlar ve Teknik Mimari Revizyonu

> **Tarih:** 2026-11-17
>
> **Kapsam:** Yalnızca belgeler ve teknik plan.
> - **Oyun kodu, testler ve yapılandırma dosyaları değiştirilmedi.** Faz 3'e başlanmadı.
> - **Hesap açılmadı, anahtar istenmedi, ücretli hizmet alınmadı.**
>
> **Kontrol:** Güncellemeden sonra mevcut testler yeniden koşuldu: TypeScript **73 / 73**, GDScript **27 / 27** (değişiklik yok, beklenen sonuç).
>
> **Faz 3 senin onayını bekliyor.**

## 1. İncelenen mevcut belgeler

- **Raporlar:** `PHASE_1_REPORT.md`, `PHASE_2_REPORT.md`, `docs/PHASE_2_PLAN.md`, `README.md`.
- **Faz 1 belgeleri (16):**
  - GAME_DESIGN_DOCUMENT, GAME_RULES, MAP_SPECIFICATION;
  - UI_UX_DESIGN_SYSTEM, UI_SCREEN_SPECIFICATIONS, USER_FLOWS;
  - TECHNICAL_ARCHITECTURE, DATABASE_SCHEMA, NETWORK_PROTOCOL, SECURITY_SPECIFICATION;
  - MONETIZATION_DESIGN, ECONOMY_AND_PROGRESSION, LOCALIZATION_SPECIFICATION;
  - TESTING_AND_PERFORMANCE, DEVELOPMENT_ROADMAP, DECISIONS_AND_OPEN_QUESTIONS.
- **Faz 2 belgeleri:** COMPATIBILITY_REPORT, ECONOMY_TWO_CURRENCY_DESIGN, RISK_GOLD_ENTRY_MATCHES; `client/README.md`, `client/assets/ASSETS.md`, `server/game-engine/README.md`.
- **Kod (yalnızca okundu, değişmedi):**
  - `server/game-engine/src/`: `state.ts` (2 kişilik renk doğrulaması), `ruleset.ts`, `engine.ts` (üçüncü 6 yolu), `dice.ts`.
- **Yeni kararlarla çelişen 25'ten fazla yer bulundu.** Örnekler:
  - Redis ve Node.js sunucusu atıfları;
  - "üçüncü 6 → tur biter";
  - "altın paketleri askıda";
  - iade için −1.000.000'a kadar eksi bakiye kısıtı;
  - `three_sixes` olayı;
  - altın paketinde "yalnızca kozmetik için" metni;
  - Redis'te tutulan oda, davet ve sıralama.

  Hepsi aşağıda listelenen dosyalarda düzeltildi.

## 2. Güncellenen dosyalar

**Yeni:**

| Dosya | İçerik |
|---|---|
| `docs/architecture/ONLINE_ARCHITECTURE.md` | Çevrimiçi mimarinin giriş noktası; bileşenler, maç yaşam döngüsü, kurtarma özeti |
| `docs/architecture/CLOUDFLARE_ARCHITECTURE.md` | Workers + DO limitleri (kaynaklı), DO tasarımı, zar, hibernation, bölge, **motorun uyumluluk ölçümü** |
| `docs/architecture/SUPABASE_ARCHITECTURE.md` | Plan limitleri, Auth, veri modeli farkları, en az yetkili erişim, RLS, Realtime tasarımı |
| `docs/architecture/SECURITY_ARCHITECTURE.md` | Anahtar yönetimi, kimlik, zar ve hamle doğrulama, ekonomi güvenliği, kurtarma, hız sınırları |
| `docs/architecture/COST_AND_SCALING.md` | Ücretsiz plan limitleri, 100 / 500 / 1.000 eşzamanlı oyuncu tahmini, limit aşımı, geçiş tetikleyicileri |
| `docs/economy/GOLD_AND_DIAMOND_ECONOMY.md` | **Ekonominin tek kaynağı:** kesin kararlar, açık kararlar (E-2…E-7), defter SQL'i, giriş ve ödül akışı, satın alma altyapısı |
| `PHASE_2_POST_UPDATE_REPORT.md` | Bu rapor |

**Taşınan:** `docs/ECONOMY_TWO_CURRENCY_DESIGN.md` → `docs/economy/GOLD_AND_DIAMOND_ECONOMY.md`. Eski dosya kısa bir yönlendirme notuna dönüştürüldü; iki kopya çelişmesin diye.

**Güncellenen:**

| Dosya | Değişiklik |
|---|---|
| `docs/DECISIONS_AND_OPEN_QUESTIONS.md` | K-08, K-13, K-27, K-36, K-37, K-38, K-53 güncellendi. **Yeni §8:** kesinleşen kararlar, yeni açık kararlar (K-55…K-64), geçersiz kalan eski kararlar. |
| `docs/GAME_RULES.md` | §2 renk seçimi; §3 zar (yalnızca sunucu, 1–5 kuralı); §6.2 ve ayrıntısı; ardışık 6 sayacı; §11.8 kurtarma; §12 `third_six_action: "exclude_six"`; §14 örnekler |
| `docs/MAP_SPECIFICATION.md` | 2 kişilik renkler |
| `docs/NETWORK_PROTOCOL.md` | Cloudflare uç noktaları; tek oyun bağlantısı; protokol ping (uygulama ping'i kaldırıldı); `queue.join` / `room.create` / `room.set_seat` renk alanları; `COLOR_*`, `INSUFFICIENT_FUNDS`, `DEBT_OUTSTANDING` hataları; sosyal mesajlar Realtime'a; `three_sixes` kaldırıldı; `st` saat alanı; idempotency DO'da |
| `docs/TECHNICAL_ARCHITECTURE.md` | Yeni mimariye göre yeniden yazıldı (bölüm numaraları korundu); §16: Node.js ve Redis alternatif olarak |
| `docs/DATABASE_SCHEMA.md` | Negatifsiz Altın + Elmas, `currency`, yeni nedenler, `price_gems`, Redis'siz oda ve sıralama, `game_server` rolü, işlev adları |
| `docs/SECURITY_SPECIFICATION.md` | Yeni güvenlik belgesine yönlendirme; anahtarlar, zar, hız sınırı, sorumluluk tablosu |
| `docs/MONETIZATION_DESIGN.md` | Elmas paketleri; altın paketleri yeniden aktif; iade → borç (eksi bakiye yok); §5 giriş bedeli |
| `docs/ECONOMY_AND_PROGRESSION.md` | Güncel ekonomi notu |
| `docs/RISK_GOLD_ENTRY_MATCHES.md` | Satın alınabilir altınla **yeniden yazıldı**; Google Play ve Apple politikalarının ilgili maddeleri (alıntı ve kaynak) |
| `docs/USER_FLOWS.md` | Cloudflare katılımcıları, emanet adımı, renk seçimi, kurtarma |
| `docs/TESTING_AND_PERFORMANCE.md` | workerd / yerel Supabase; üçüncü atış testleri; renk yarışı; DO yeniden başlatma; kota testleri |
| `docs/DEVELOPMENT_ROADMAP.md` | F2 tamamlandı; **F3–F5 yeniden tanımlandı**; F6+ taslak; risk kaydı (R3, R9, R11, R12) |
| `docs/GAME_DESIGN_DOCUMENT.md` | IAP'de Elmas; altınlı maç; varsayımlar V1–V2 |
| `docs/UI_SCREEN_SPECIFICATIONS.md` | Oda ekranlarında renk seçici; altın ve Elmas paketi yasal metinleri |
| `docs/COMPATIBILITY_REPORT.md` | Yeni belgelere yönlendirme notu |
| `README.md`, `server/game-engine/README.md` | Durum, yeni belgeler, motorda planlanan değişiklikler |
| `PHASE_2_REPORT.md` | Başına "sonradan eklenen not"; rapor içeriği korunarak |

**Değiştirilmeyenler:** Bütün kod, testler, vektörler, `export_presets.cfg`, `economy_config.example.json`, APK, `PHASE_1_REPORT.md`, `docs/PHASE_2_PLAN.md` (tarihsel kayıt).

## 3. Kesinleşen oyun kararları

1. **Üst üste üçüncü 6 gelemez** (K-13):
   - İki ardışık 6'dan sonraki atışta zar yalnızca **1–5** üretir; 6 hiçbir koşulda üretilmez.
   - Kural **yetkili sunucuda** uygulanır. Motor da savunma olarak 6'yı `INVALID_DICE` ile reddeder.
   - İstemciden zar kabul edilmez.
   - **Ölçüm:** Kuralın maç uzunluğuna etkisi ihmal edilebilir (2 kişilik 337 → 341 eylem; gürültü düzeyinde).
   - **Kod henüz eski kuralda** (tur biter). Değişiklik Faz 3'ün ilk işi: iki motor + vektörler + yeni testler.
2. **2 kişilikte renk seçimi** (K-08):
   - Dört renk seçilebilir; aynı renk yok.
   - Yalnızca karşılıklı çiftler: kırmızı–sarı, yeşil–mavi. Çakışmayı sunucu reddeder.
   - 4 kişilik düzen değişmedi.
   - **Mevcut motor bunu zaten destekliyor** (`createGame`, karşılıklı olmayan çifti reddediyor). Tahta döndürmesi her renk için Faz 2'de test edildi.
3. **Altın ve Elmas:**
   - İkisi de gerçek parayla satın alınabilir.
   - Altın: giriş, ödül, günlük giriş, görev / başarım, standart kozmetik.
   - Elmas: yalnızca premium kozmetik; maç girişinde ve bahiste **asla**.
   - Transfer ve nakde çevirme yok.
   - Bakiyeler sunucuda, defterli, negatifsiz, idempotent.
4. **Satın alma altyapısı:** Sunucu tarafı doğrulama; idempotency; iade ve iptal; satın alma geçmişi. Akış ve kurallar belgelendi; entegrasyon yok.

## 4. Yeni çevrimiçi mimari

```
Godot istemci ── JWT ──► Supabase Auth
     │  ├─ RLS'li okuma ──► Supabase Postgres (bakiye, defter, profil, maç geçmişi; tek otorite)
     │  └─ sosyal kanallar ► Supabase Realtime (çevrimiçi durumu, davet, bildirim; yalnızca menüde)
     └─ WSS / HTTPS + JWT ──► Cloudflare Worker (JWT doğrulama, hız sınırı, REST)
                                ├─► Matchmaker DO (kuyruk, renk tercihi, bot önerisi)
                                └─► MatchRoom DO (maç başına bir; zar, kurallar, süre, kopma, sonuç)
                                       └─ yalnızca sunucu işlevleri ──► Postgres (emanet / sonuç; tek işlem)
```

- **Otorite:**
  - Maç durumu ve kurallar → **yalnızca MatchRoom**.
  - Para birimleri → **yalnızca Postgres**.
  - Supabase Realtime **yetkili değildir**.
- **Redis yok.** Kuyruk, oda ve geçici veriler Durable Objects'in kendi deposunda.
- **Hamle başına veritabanı çağrısı yok.** Supabase yalnızca maç başında (emanet) ve sonunda (sonuç) çağrılır.
- **Ayrıntı:** `docs/architecture/ONLINE_ARCHITECTURE.md` ve bağlı belgeler.

## 5. Cloudflare ve Supabase teknik uygunluğu

**Cloudflare Workers + Durable Objects: uygun.**
- Durable Objects'in tek iş parçacıklı, kimlikli ve kendi depolu modeli "her maç bir yetkili oda" ihtiyacına doğrudan uyuyor. Ücretsiz planda da var (SQLite arka ucu).
- **Ölçülen motor uyumu** (geçici betiklerle; proje dosyaları değişmedi):
  - Tek Node'a özgü bağımlılık: `dice.ts` → `node:crypto randomInt`. Tarayıcı / nötr hedefe paketleme yalnızca bu satırda kırılıyor. Web Crypto'ya geçiş küçük bir iş.
  - JSON içe aktarma sorunsuz. Paket boyutu **15,9 KB**.
  - Eylem başına **38–56 µs**. Durum **1,1–1,7 KB**.
  - Maç başına ortalama eylem: 2 kişilik **337**, 4 kişilik **1.525**.
- **Belirsizlikler** (Faz 3 denemeleri):
  - bekleyen alarmın hibernation'a etkisi (maliyeti doğrudan etkiliyor);
  - JWT doğrulamanın yeri ve CPU süresi;
  - Godot'un protokol ping ayarı;
  - `structuredClone` ve testlerin workerd içinde koşması.

**Supabase: uygun.**
- Auth (misafir, Google, Apple, e-posta, bağlama), Postgres + RLS ve Realtime ihtiyaçları karşılıyor.
- Asimetrik JWT anahtarlarıyla Cloudflare'de hiçbir JWT sırrı tutulmadan doğrulama yapılabiliyor.
- Cloudflare Hyperdrive ile özel bir Postgres rolü üzerinden **en az yetkili** bağlantı mümkün; Cloudflare'in resmi Supabase örneği var.
- **Canlı doğrulama yapılmadı** (proje yok).

## 6. Ücretsiz plan limitleri ve maliyet analizi

**Resmi limitler** (2026-11-17; kaynaklar ilgili belgelerde):

| Servis | Ücretsiz planın kritik limitleri | Aşılınca |
|---|---|---|
| Workers | 100.000 istek / gün; HTTP isteği başına 10 ms CPU | Hata 1027 |
| Durable Objects | 100.000 istek / gün (WebSocket mesajı 20:1); 13.000 GB-sn / gün; **100.000 satır yazma / gün**; toplam 5 GB | İşlemler hata verir; 00:00 UTC'de sıfırlanır |
| Supabase | 500 MB veritabanı; 50.000 MAU; 5 GB çıkış; **200 Realtime bağlantısı**; 2 M Realtime mesajı / ay; **yedek yok**; **1 hafta hareketsizlikte duraklatma** | Kota uygulanır; Realtime'da ret ya da kopma |

**Tahmini kullanım:** Değerler **tahmin**. Girdiler: ölçülen eylem sayıları + eylem başına 1,6 sn, %80'i maçta, gün ortalaması tepenin %40'ı.

| | 100 eşzamanlı | 500 eşzamanlı | 1.000 eşzamanlı |
|---|---|---|---|
| Tepe eşzamanlı maç | 30 | 150 | 300 |
| DO satır yazma / gün (strateji A) | 1,3 M (ücretsiz limitin **13 katı**) | 6,5 M | 13 M |
| Realtime tepe bağlantı (yalnızca menüde) | 20 | 100 | 200 |
| MAU | ~5.800 | ~28.800 | ~57.600 |
| **Aylık tahmini toplam** | **~30 USD** | **~35–180 USD** + olası Supabase bilgi işlem yükseltmesi | **~100–390 USD** + olası bilgi işlem yükseltmesi |

**Sonuçlar:**
- **Geliştirme ve iç testler:** Ücretsiz planlar yeterli (0 USD).
- **Herkese açık yayın:** Ücretsiz planlar **yetmiyor**.
  - Cloudflare'in ücretsiz satır yazma limiti, gün boyunca ortalama ~1–3,5 eşzamanlı maça denk geliyor. Aşılınca maçlar yarıda kalır.
  - Supabase Free'de yedek yok; gerçek parayla alınan bakiyeler için bu kabul edilemez.
  - Önerilen en düşük yayın yapısı: **Cloudflare Workers Paid (5 USD) + Supabase Pro (25 USD) ≈ aylık 30 USD**.
- **Maliyeti en çok etkileyen iki tasarım kararı:**
  - **Hibernation:** Olmazsa 1.000 eşzamanlıda süre ücreti tek başına ~481 USD / ay.
  - **Kalıcı yazma stratejisi (K-60):** Maliyeti 6 kata kadar değiştiriyor.

## 7. Güvenlik değerlendirmesi

| Gereksinim | Durum (tasarım) |
|---|---|
| Service role anahtarı istemcide yok | ✅ İstemcide yalnızca URL + publishable anahtar. Service role tercihen sunucuda da kullanılmıyor (`game_server` rolü). |
| Oyun sunucusunun Supabase erişimi sınırlı | ✅ Tasarımda yalnızca belirli işlevlerde `EXECUTE` (K-59; Faz 3'te doğrulanacak) |
| Oyuncu yalnızca kendi verisine erişir | ✅ RLS planı; istemcinin hiçbir ekonomi, maç ya da satın alma tablosuna yazma politikası yok |
| Zar ve hamle sunucuda | ✅ Zar yalnızca MatchRoom'da; istemciden zar alanı yok. 1–5 kuralı iki katmanlı. |
| Ekonomi sunucuda, atomik, idempotent, negatifsiz | ✅ Tek işlem, `FOR UPDATE`, benzersiz anahtarlar, `CHECK (>= 0)`, iade sonrası borç kaydı |
| Satın alma doğrulaması sunucuda | ✅ Mağaza API'leri; `(platform, transaction_id)` benzersiz; bildirimler imza doğrulamalı |
| Maç kurtarma | ✅ DO deposu + kalıcı alarm + outbox + mutabakat (sonuçlanmamış emanet iadesi) |
| Hız sınırı ve kötüye kullanım | ✅ Bağlantı, kullanıcı ve IP başına; ücretsiz kotayı tüketme saldırısı riski not edildi |
| Anahtar yönetimi | ✅ `wrangler secret`, ortam başına ayrı, gitleaks, 2FA, döndürme |

**Tasarımın getirdiği yeni riskler:**
1. **Kota tüketme saldırısı:** Ücretsiz planda kötü niyetli trafik günlük kotayı bitirip oyunu durdurabilir. Ücretli plan ve hız sınırları bunu azaltır.
2. **Gizli API anahtarı yedek seçeneği (K-59 B):** Hyperdrive denemesi başarısız olursa geniş yetkili bir anahtar Cloudflare'de durmak zorunda kalır.
3. **4 kişilik altınlı maçta işbirliği.** Önerilen önlem: özel odada altınlı maç olmaması (E-4).

## 8. Eski mimariden kalan ve artık kullanılmayan kararlar

| Konu | Durum |
|---|---|
| VPS / VDS kiralama | **Kullanılmıyor** (başlangıç hedefi değil) |
| Node.js `api` / `realtime` / `worker` süreçleri | **Kullanılmıyor.** Yerlerine Worker, DO ve Cron geçti. Node.js test / araç ortamı olarak **kalıyor** ve oyun sunucusu için **alternatif** olarak korunuyor (TECHNICAL_ARCHITECTURE §16). |
| Redis (kuyruk, anlık görüntü, çevrimiçi durumu, sıralama, hız sınırı) | **Kullanılmıyor.** Ölçülmüş bir ihtiyaç olursa yeniden değerlendirilir. |
| Süreç devri ("yedek süreç anlık görüntüyü alır") | **Gereksiz.** DO kimliği maçı belirliyor; durum nesnenin deposunda. |
| Uygulama düzeyi 15 sn ping | **Kaldırıldı** (maliyet); yerine protokol ping |
| Üçüncü 6 → tur biter | **Değişti** (1–5) |
| E-1 önerisi "altın satın alınamasın" | **Geçersiz** (karar: satın alınabilir) |
| İade için eksi bakiye (−1.000.000) | **Kaldırıldı** (borç kaydı) |
| **Kalanlar** | TypeScript motor, ortak vektörler, GDScript eşi, Supabase (Auth / Postgres / RLS), Supabase Realtime (sosyal), protokolün genel yapısı, istemci mimarisi |

## 9. Faz 3–5 güncellenmiş yol haritası

Ayrıntı: `docs/DEVELOPMENT_ROADMAP.md`.

| Faz | İçerik | Ana test ölçütleri |
|---|---|---|
| **F3 — Backend ve altyapı** | 1–5 kuralı (iki motor + vektörler); motorun Cloudflare uyumu (Web Crypto zar, workerd testleri); Supabase `dev` projesi ve Auth; tablolar, RLS, sunucu işlevleri, `game_server` rolü; Cloudflare projesi, ortamlar, gizli anahtarlar, DO iskeleti; denemeler (alarm / hibernation, JWT, Hyperdrive); Godot'ta misafir girişi → Worker → DO bağlantısı; CI | Node ve workerd testleri yeşil; vektörler %100; 1–5 dağılım testi; RLS %100; çift çağrı → tek etki; istemcide sır yok |
| **F4 — Online sistem** | WebSocket protokolü; Matchmaker; özel oda; 2 / 4 kişilik maç; renk seçimi; arkadaş daveti (Realtime); sunucu otoriteli zar, hamle ve süre; kopma ve yeniden bağlanma; maç kurtarma; altın emanet, sonuç ve iade (test bakiyesi, bayrakla kapalı); istemci ekranları | Simüle istemcilerle tam maçlar, idempotency, yarışlar, DO yeniden başlatma |
| **F5 — Online oynanabilir sürüm** | Gerçek cihazlarda online maç; uçtan uca testler; hile ve güvenlik; altın muhasebesi; yük; WebSocket gecikmesi; kota ölçümü; Android performansı; iOS hazırlığı | 50+ kesintisiz cihazlar arası maç; kopmada kayıp yok; muhasebe tutarlı; maliyet modeli ölçümle güncel |

## 10. Açık kalan kararlar ve riskler

**Yeni açık kararlar** (DECISIONS §8.2):

| No | Konu | Önerim |
|---|---|---|
| K-55 | Hızlı maçta renk tercihi çakışması | Önce gelenin tercihi; diğeri karşı rengi alır |
| K-56 | 1–5 kuralı oyuncuya açıklansın mı | Evet, kurallar ekranında |
| K-57 | Özel odada renk seçim sırası | Kurucu seçer, katılan karşı rengi alır |
| K-58 | Cloudflare Paid'e geçiş zamanı | Herkese açık testten önce |
| K-59 | Sunucunun Supabase erişimi | Hyperdrive + `game_server` rolü |
| K-60 | Kalıcı yazma sıklığı | B (her eylem, alarm yedek); ölçümle |
| K-61 | Satın alma doğrulamasının yeri | Cloudflare Worker |
| K-62 | DO yerleşimi | Faz 5 ölçümüyle |
| K-63 | Misafir satın alma yapabilir mi | Evet; önce hesap bağlama güçlü öneri |
| K-64 | Arkadaş çevrimiçi durumu kanal tasarımı | Faz 4'te ölçümle |
| E-2…E-7 | Elmas ödülleri, kesinti, giriş seviyeleri ve özel oda, Elmas ↔ Altın dönüşümü, iade borcu, altınlı maçın ülke / yaş kapsamı | GOLD_AND_DIAMOND_ECONOMY §2 |

**Önceden açık olup hâlâ bekleyenler:**
- K-01…K-07, K-11, K-14, K-15, K-18, K-20, K-22…K-24, K-26, K-29…K-35, K-38…K-40, K-42…K-49, K-51, K-52, K-54.
- Bunların içinde kural olanlar, 1–5 kuralı işlenirken birlikte kesinleşirse vektörler bir kez yenilenir.

**Başlıca riskler:**
1. **Altınlı maçlarda mevzuat ve mağaza riski arttı:** Altın satın alınabiliyor.
   - Apple 5.3.3: gerçek para oyunu sayılırsa IAP ile para birimi satmak yasak.
   - Google: parayla satın alınan öğeyle girilip gerçek parasal değerli ödül kazanılan oyunlar yasak.
   - Bizim modelin "gerçek parasal değer" taşımadığı savı nakde çevirme ve transfer yokluğuna dayanıyor. **Hukuki görüş şart.**
2. **Ücretsiz planın yayına yetmemesi:** Kota bitince maçlar yarıda kalır.
3. **Cloudflare maliyet belirsizliği:** Hibernation ve alarm davranışı Faz 3'te ölçülmeli.
4. **4 kişilik maç uzunluğu:** Ölçüm ~1.500 eylem, tahmin ~40 dk. Deneyim ve maliyet etkisi; karar K-25 senin.
5. **Sınırlı cihaz testi ve iOS'un hiç denenmemiş olması.**
6. **Disk alanı:** C: diskinde ~2,8 GB boş. Yerel Supabase yığını Docker ister (**doğrulanacak**); Docker birkaç GB yer kaplar. Gerekirse yerel yığın yerine bulut `dev` projesiyle çalışılır.

## 11. Faz 3'e başlamadan önce gereken kullanıcı işlemleri

**Zorunlu:**
1. **Faz 3'e başlama onayı.**
2. **Supabase hesabı** (ücretsiz). Ardından:
   - `dev` projesinin bölgesi (öneri: Frankfurt `eu-central-1`, K-37);
   - projeyi senin mi açacağın, yoksa CLI ile girişini yapıp benim mi açacağım (`! npx supabase login` ile oturumu sen açarsın).
3. **Cloudflare hesabı** (ücretsiz).
   - `wrangler` girişini sen yaparsın: `! npx wrangler login`.
   - Başlangıçta `*.workers.dev` alt alanı yeterli; alan adı sonra.
4. **Gizli anahtarlar sohbet üzerinden paylaşılmamalı.**
   - Supabase URL ve publishable anahtar gizli değildir; paylaşılabilir.
   - Veritabanı parolası, gizli anahtar ve HMAC anahtarları için komutu sen çalıştırırsın: `! npx wrangler secret put <AD>`. Böylece değer bu sohbete hiç girmez.
5. **K-59 kararı** (önerim A: Hyperdrive + sınırlı rol) ve **K-56** (1–5 kuralının açıklanması).

**Önerilen (Faz 3 sırasında ya da sonrasında):**
6. **K-60, K-58 zamanlaması.** Bütçe beklentisinin teyidi: yayında aylık ~30 USD'den başlıyor.
7. **Hâlâ öneri olan kurallar:** K-11, K-14, K-15, K-18, K-20, K-22…K-24. 1–5 kuralıyla birlikte kesinleşirse vektörler bir kez yenilenir.
8. **Git deposu** (`git init`) onayı: altyapı kodu ve migration'lar için güçlü öneri.
9. **Telefonun bağlanması:** Faz 2 APK'sının cihaz testi; Faz 4–5 için şart.
10. **Daha sonra:**
    - Google Cloud OAuth istemcisi (Google girişi);
    - Apple Developer hesabı ve Mac erişimi (iOS);
    - altınlı maçlar için hukuk danışmanı (F10'dan önce; E-7).
