# CLOUDFLARE_ARCHITECTURE — Workers + Durable Objects Oyun Sunucusu

> **Durum:** Faz 2 sonrası güncelleme (2026-11-17). Tasarım ve araştırma; **kod yok, hesap yok**.
>
> **Kaynaklar:** Cloudflare'in resmi belgeleri, 2026-11-17'de okundu (§9). Limitler ve fiyatlar değişebilir; Faz 3 başında yeniden kontrol edilmeli.
>
> **İşaretler:**
> - **(resmi):** Resmi belgede açıkça yazıyor.
> - **(ölçüldü):** Bu projede ölçüldü.
> - **(tahmin):** Varsayıma dayalı.
> - **(doğrulanacak):** Faz 3 / 5'te denenecek.

## 1. Neden Workers + Durable Objects

- **Durable Object (DO):** Kimliği olan, **tek iş parçacıklı** bir sunucu nesnesi. Kendi kalıcı deposu (SQLite) ve WebSocket bağlantıları vardır (resmi).
  - Aynı kimliğe gelen bütün istekler aynı nesneye gider.
  - Bu, "her maçın tek bir yetkili odası" ihtiyacına doğrudan uyar: kilit, Redis ve "hangi süreçte" eşlemesi gerekmez.
- **Sunucu kiralama ve bakım yok:** İşletim sistemi, ölçekleme ve TLS yönetilir.
- **Ücretsiz planda kullanılabilir:** Durable Objects ücretsiz planda da var; ancak yalnızca SQLite depolama arka ucuyla (resmi).
- **Sınırlar:** DO bir veritabanı değildir. Kalıcı ve ilişkisel veriler (cüzdan, defter, profil) **Supabase Postgres'te** kalır. DO yalnızca süren maçın ve kuyruğun geçici ama kalıcı durumunu tutar.

## 2. Limitler ve fiyatlar (resmi, 2026-11-17)

### 2.1 Workers

| Limit | Ücretsiz | Paid |
|---|---|---|
| İstek | **100.000 / gün** | Ayda 10 milyon dahil, sonra milyon başına 0,30 USD |
| CPU süresi (HTTP isteği başına) | **10 ms** | Varsayılan 30 sn, en fazla 5 dk; ayda 30 milyon CPU-ms dahil, sonra milyon CPU-ms başına 0,02 USD |
| Bellek (izolat başına) | 128 MB | 128 MB |
| Worker boyutu (sıkıştırılmamış) | 64 MiB | 64 MiB |
| Çağrı başına alt istek | 50 | 10.000 |
| Ortam değişkeni (Worker başına) | 64 | 128 |
| Aylık en düşük ücret | Yok | **5 USD** (hesap başına) |

- **Ücretsiz günlük limit aşılırsa:** Hata 1027 döner (resmi).
  - Rota "fail open" ise Worker atlanır.
  - Rota "fail closed" ise hata sayfası döner. Güvenlik açısından kritik Worker'lar için bu öneriliyor.
- **Sıfırlama:** Günlük sayaçlar **00:00 UTC**'de (Türkiye saatiyle 03:00) sıfırlanır (resmi).

### 2.2 Durable Objects

| Ölçü | Ücretsiz | Paid |
|---|---|---|
| İstek (HTTP, RPC, **WebSocket mesajı**, alarm çağrısı) | **100.000 / gün** | Ayda 1 milyon dahil, sonra milyon başına 0,15 USD |
| Süre (GB-sn) | **13.000 GB-sn / gün** | Ayda 400.000 GB-sn dahil, sonra milyon GB-sn başına 12,50 USD |
| SQLite: okunan satır | 5 milyon / gün | Ayda 25 milyar dahil, sonra milyon başına 0,001 USD |
| SQLite: **yazılan satır** | **100.000 / gün** | Ayda 50 milyon dahil, sonra milyon başına **1,00 USD** |
| SQLite: depolanan veri | Toplam 5 GB | 5 GB-ay dahil, sonra GB-ay başına 0,20 USD |
| DO sınıfı (hesap başına) | 100 | 500 |
| CPU (istek başına) | 30 sn (en fazla 5 dk'ya ayarlanabilir) | Aynı |
| Gelen WebSocket mesajı boyutu | 32 MiB | 32 MiB |
| Nesne başına istek hızı | Yumuşak sınır: **1.000 istek / sn** (nesne tek iş parçacıklı) | Aynı |
| Nesne sayısı | Sınırsız | Sınırsız |

**Faturalandırma ayrıntıları (resmi):**
- **WebSocket mesajları:**
  - Gelen mesajlar faturada **20:1** oranıyla sayılır: 100 gelen mesaj = 5 istek.
  - Giden mesajlar ve gelen protokol ping'leri **ücretsizdir**.
  - Bağlantı kurmak 1 istektir.
- **Süre:** Nesne başına **128 MB** üzerinden hesaplanır; kullanılan bellek fark etmez.
  - Hibernation'a uygun boşta nesneler süre ücreti biriktirmez.
  - Hibernation API'si olmadan `accept()` kullanılırsa **bağlantının bütün süresi** faturalanır.
- **Alarm:** Her `setAlarm()` çağrısı **1 yazılan satır** sayılır.
- **Ücretsiz plan:** Limit aşılırsa o türdeki işlemler **hata verir**. Ücretsiz planda aşım ücreti yoktur; hizmet durur.

**Belgelerdeki tutarsızlıklar** (Faz 3'te Cloudflare'e sorulmalı):
- Ücretsiz planda nesne başına depolama: Tabloda yalnızca 10 GB yazıyor, SSS bölümünde ise "ücretsiz planda 1 GB" deniyor. Bizim için önemsiz: maç durumu ~1–2 KB.
- Silme işlemleri: Fiyat tablosu ile dipnot çelişiyor.
- Nesne başına en fazla WebSocket bağlantısı: Belgede sayı yok; "örnek başına binlerce istemci" deniyor. Bizim için önemsiz: maç başına en fazla 4 bağlantı.

### 2.3 Diğer Cloudflare hizmetleri

- **Hyperdrive** (Workers'tan Postgres'e havuzlu bağlantı): Ücretsiz planda da var; günde 100.000 sorgu (resmi). Supabase, Cloudflare'in desteklenen veritabanları arasında listeleniyor ve özel bir Postgres rolüyle bağlanma örneği var (resmi). Kullanım kararı: K-59.
- **Cron Triggers:** Ücretsiz planda HTTP isteği gibi **10 ms CPU** sınırına tabidir (resmi). Hesap başına tetikleyici sayısı **doğrulanacak**.

## 3. Tasarım

### 3.1 Worker (giriş kapısı)

**Uçlar:**

| Uç | Ne yapar |
|---|---|
| `GET /v1/config` | Sürüm, bakım ve özellik bayrakları (önbellekli) |
| `GET /v1/queue` (WebSocket yükseltme) | Hızlı maç kuyruğu → ilgili Matchmaker DO |
| `GET /v1/match/{id}` (WebSocket yükseltme) | Maç → ilgili MatchRoom DO |
| `GET /v1/room/{code}` (WebSocket yükseltme) | Özel oda → `idFromName("room:" + kod)` MatchRoom DO |
| `POST /v1/iap/verify`, `/v1/webhooks/*` | Satın alma doğrulama, mağaza bildirimleri (K-61) |
| `POST /v1/rewards/*` | Ödül talepleri (günlük giriş, görev, reklam SSV): doğrulama + Postgres işlevi |

**Kimlik doğrulama:**
- Supabase JWT'si, Supabase'in JWKS uç noktasındaki **genel anahtarlarla** doğrulanır: imza, `exp`, `iss`, `aud`, `sub`.
  - Bunun için Supabase'in asimetrik imzalama anahtarlarının açık olması gerekir.
  - JWKS önbelleğe alınır.
  - Yalnızca beklenen algoritmalara izin verilir (ES256 / RS256; projenin kullandığı algoritma **doğrulanacak**).
- **Belirteç URL'de taşınmaz** (sunucu günlüklerine düşer). WebSocket'te bağlantıdan sonraki ilk mesaj (`hello`) içinde gelir, 5 sn içinde gelmezse bağlantı kapatılır (NETWORK_PROTOCOL §3).
  - **Doğrulanacak:** Bu doğrulama Worker'da mı, DO'da mı yapılacak? İlk mesaj DO'ya ulaşacağı için doğrulamanın DO'da yapılması, ya da Worker'ın yükseltmeden önce kısa ömürlü bir bilet istemesi seçenekleri Faz 3'te kıyaslanacak.
- **Bilet:** Matchmaker, eşleşen her oyuncuya MatchRoom'a giriş için imzalı, kısa ömürlü bir **bilet** verir (maç + koltuk + kullanıcı + son kullanma zamanı; HMAC). MatchRoom, JWT'deki kullanıcı ile biletin kullanıcısını eşleştirir.
- **CPU:** Ücretsiz planda Worker isteği başına 10 ms CPU sınırı var. Bir ES256 / RS256 imza doğrulaması bunun çok altında olmalı (**doğrulanacak**).

### 3.2 Durable Object sınıfları

| Sınıf | Kimlik | Görev |
|---|---|---|
| `MatchRoom` | Hızlı maçta `newUniqueId()`; özel odada `idFromName("room:" + kod)` | Bir maçın tek otoritesi (§3.3) |
| `Matchmaker` | `idFromName("q:" + mod + ":" + seviye)`, ör. `q:2p:lobby_100` | Kuyruk, renk tercihi, bot önerisi, maç kurma |

- **Tek Matchmaker'ın kapasitesi:** Yumuşak sınır 1.000 istek / sn. MVP için fazlasıyla yeterli (tahmin).
- **Ölçek gerekirse:** Kuyruklar bölgeye ya da seviyeye göre bölünür. **Redis bu yüzden gerekmez** (DECISIONS §8.1).

### 3.3 MatchRoom

**Aşamalar:** `lobby` (yalnızca özel oda: koltuk, renk seçimi, hazır) → `playing` → `settling` → `finished` / `void`.

**Kalıcı durum** (DO'nun SQLite deposu):

| Tablo | İçerik |
|---|---|
| `state` | Tek satır: motor durumu (JSON, ölçülen boyut 1,1–1,7 KB), `seq`, son tarihler (deadline) |
| `meta` | Oyuncular, bilet anahtarı, giriş seviyesi, yapılandırma sürümü |
| `outbox` | Postgres'e gönderilmeyi bekleyen kayıtlar (emanet, sonuç); tekrar deneme sayacı |
| `events` (isteğe bağlı) | Son N olay (yeniden bağlanmada eksik olayları göndermek için halka tampon) |

**Eylem işleme sırası** (mevcut `MatchSession` mantığı):
1. Bağlantı → koltuk eşleşmesi (bağlantı eki: `serializeAttachment`, en fazla 16 KB, hibernation'dan sağ çıkar; resmi).
2. Şema doğrulaması ve bağlantı başına hız sınırı.
3. İstek kimliği (`reqId`) tekrarı mı? Tekrarsa önceki yanıt yeniden gönderilir. Son yanıtlar koltuk başına durumda saklanır, hibernation'da kaybolmaz.
4. Zar gerekiyorsa **sunucu** üretir (§3.4); `GameEngine.apply`.
5. Yeni durum **tek satır** olarak yazılır, sonra olaylar yayınlanır. Önce yazma, sonra yayın: yayınlanmış ama kaydedilmemiş bir zar olamaz.

**Süreler ve zamanlayıcılar:**
- Zar 10 sn, hamle 12 sn. Son tarih durumda tutulur.
- Zamanlayıcı **DO Alarm**'ıdır: kalıcıdır, nesne yeniden başlasa da çalışır.
  - Her `setAlarm()` 1 yazılan satır sayılır.
  - **Doğrulanacak:** Bekleyen bir alarmın hibernation'ı engelleyip engellemediği. Belgede "alarmlar, gelen istekler ve zamanlanmış geri çağrılar hibernation'ı engeller" deniyor; bunun bekleyen alarmı mı, yalnızca çalışan alarm işleyicisini mi kastettiği net değil. Maliyete etkisi büyük: COST_AND_SCALING §3.
- `setTimeout` / `setInterval` **kullanılmaz**: hibernation'ı engeller ve süre ücreti doğurur (resmi).

**Botlar ve otopilot:**
- Mevcut motorun `chooseBotMove` işlevi kullanılır.
- "İnsan gibi" gecikme (0,7–1,3 sn) alarmla ya da bir sonraki olayla tetiklenir.
- Tek geçerli hamle (K-20), sunucuda **zarla aynı işlemde** uygulanır. Zamanlayıcı gerekmez; istemci yolu ~400 ms gösterir.

**Kopma:**
- `webSocketClose` olayı ya da otomatik ping yanıtının zaman damgası izlenir (`getWebSocketAutoResponseTimestamp`; **doğrulanacak**).
- Kopan oyuncunun turunda süre dolunca otopilot oynar (K-23).
- 2 kişilikte rakip 90 sn kopuk kalırsa "Zaferi al" alarmla açılır.

**Maç sonu:**
1. Sonuç `outbox`'a yazılır.
2. `settle_match` Postgres işlevi çağrılır (idempotent).
3. Başarısız olursa alarmla üstel geri çekilmeyle tekrar denenir: 1 sn → … → 15 dk, 24 saate kadar.
4. Başarılı olunca nesnenin deposu temizlenir (`deleteAll`).

### 3.4 Zar üretimi (sunucu)

- **Kaynak:** Web Crypto `crypto.getRandomValues` ile **reddetme örneklemesi** (modulo sapması yok). Bu yöntem Workers'ta ve Node'da aynı çalışır. Web Crypto, Workers'ta `nodejs_compat` bayrağı olmadan da kullanılabilir (resmi).
- **Kural (K-13):** `turn.sixes == 2` ise zar **1–5** aralığında eşit olasılıkla üretilir; aksi hâlde 1–6.
- **Savunma:** Motor `sixes == 2` iken 6 değerini `INVALID_DICE` ile reddeder. Zar kaynağında bir hata olsa bile kural çiğnenemez.
- **İstemci:** Zar değeri göndermez. Protokolde böyle bir alan yoktur; bilinmeyen alanlar şema doğrulamasında reddedilir.
- **Denetim:** Her zar, durum satırı ve (tutulursa) olay günlüğüyle kalıcıdır. Maç sonunda `match_events` olarak Postgres'e gider.

### 3.5 Hibernation

- **Karar:** WebSocket'ler `ctx.acceptWebSocket()` (Hibernation API) ile kabul edilir.
- **Bedeli:** Nesne boşta iken bellekten atılabilir; uyandığında yapıcı (constructor) yeniden çalışır ve bellekteki durum sıfırlanır (resmi).
  - Bu yüzden her olayın başında durum SQLite'tan okunur: 1 satır, okuma limitleri bol.
  - Bağlantı başına bilgi `serializeAttachment` ile taşınır.
- **Ping:** İstemcinin WebSocket **protokol ping**'ine çalışma ortamı otomatik `pong` döner; bu hibernation'ı bozmaz ve faturalanmaz (resmi).
  - Uygulama düzeyinde 15 sn'lik `ping` mesajı **kaldırıldı**: her biri faturalanan bir istek olurdu ve nesneyi uyandırırdı.
  - Godot `WebSocketPeer`'ın otomatik protokol ping gönderme ayarı **doğrulanacak**.

## 4. Bölge ve gecikme

- **Yerleşim:** Bir DO, belgelere göre ilk isteğin geldiği yere yakın bir veri merkezinde oluşur. "Location hint" (`eeur`, `weur`, …) yalnızca bir ipucudur (resmi).
- **Hızlı maçta yer:** Matchmaker maç nesnesini oluşturur, yani nesne Matchmaker'ın bulunduğu yere yakın olur.
  - Türkiye'den oynayanlar için ipucu `eeur` ya da `weur` olarak verilebilir (K-62).
- **Beklenen gecikme:** Türkiye'den Avrupa'daki bir veri merkezine gidiş-dönüş ~30–70 ms (**tahmin**; Faz 5'te ölçülecek).
  - Sıra tabanlı bir oyun için yeterli. Hedef: uçtan uca p95 < 150 ms (TESTING §5).
- **Supabase bölgesi:** Önerilen `eu-central-1` (Frankfurt) (K-37). MatchRoom Postgres'e yalnızca maç başında (emanet) ve sonunda (sonuç) gider; hamle başına veritabanı çağrısı **yoktur**. Bu yüzden DO ile Supabase arasındaki mesafe oyun akıcılığını etkilemez.

## 5. TypeScript motorunun Workers uyumluluğu (ölçüldü)

Ölçüm: esbuild 0.28.2 ile deneme paketlemesi ve 1.200 bot maçlık simülasyon. Proje dosyalarına dokunulmadı; geçici betikler kullanıldı.

| Konu | Sonuç |
|---|---|
| Node'a özgü bağımlılık | **Yalnızca bir tane:** `src/dice.ts` → `import { randomInt } from "node:crypto"`. Tarayıcı / nötr hedefe paketleme bu satırda kırılıyor (ölçüldü). |
| `node:crypto` Workers'ta | `nodejs_compat` bayrağıyla destekleniyor. Belgede istisna listesi var, `randomInt` bu listede yok (resmi). Yine de Web Crypto'ya geçmek önerilir: bayrak gerekmez, Node 20+'da da çalışır. |
| JSON içe aktarma (`board_map.json`, `with { type: "json" }`) | esbuild sorunsuz paketliyor (ölçüldü) |
| Dosya sistemi, yerel (native) modül, ağ | **Yok** (motor saf) |
| `structuredClone` | Kullanılıyor (`state.ts`). Workers'ta mevcut olması beklenir (**doğrulanacak**: workerd içinde test) |
| Paket boyutu (küçültülmüş) | **15,9 KB** (ölçüldü). Limit 64 MiB. |
| Eylem başına işlem süresi | Node 24'te **38 µs** (2 kişilik), **56 µs** (4 kişilik); JSON kopyalama dahil (ölçüldü). DO limitinin (30 sn) çok altında. |
| Durum boyutu (JSON) | Ortalama 1,1 KB (2 kişilik) / 1,3 KB (4 kişilik); en çok 1,7 KB (ölçüldü) |
| Eylem başına olay yükü | ~110 bayt (ölçüldü) |
| Maç başına eylem (zar + hamle; bot maçları) | 2 kişilik **ort. 337** (p50 307, p90 457); 4 kişilik **ort. 1.525** (p50 1.476, p90 2.027) (ölçüldü, 300'er maç) |
| K-13 kuralının (üçüncü atış 1–5) maç uzunluğuna etkisi | İhmal edilebilir: 337 → 341, 1.525 → 1.510 eylem (ölçüldü; gürültü düzeyinde) |

**Faz 3'te yapılacak uyarlamalar** (motor yeniden yazılmaz). **1 ve 2 Faz 3.1'de yapıldı** (2026-11-17): Web Crypto zar kaynağı ve K-13; esbuild nötr paketi 16,9 KB, `node:` atfı yok. workerd'de çalıştırma 3.3'te.
1. **Zar:** `dice.ts`'e Web Crypto tabanlı, aralık alabilen bir kaynak eklenir (1–6 ya da 1–5). `cryptoDice` (Node) testler için kalabilir ya da kaldırılır.
2. **K-13:**
   - Kural seti alanı değişir (GAME_RULES §12).
   - Motorun `roll` yolu güncellenir (TS + GDScript).
   - İstemcinin yerel zarı (`dice_source.gd`) çevrimdışı pratikte aynı kuralı uygular.
   - Vektörler yeniden üretilir; yeni testler eklenir (TESTING §2.1).
3. **Tahta verisinin yolu:** `../../../docs/design/board/board_map.json`, paketlemede sorun çıkarmıyor. Yine de `shared/` altında, betikle eşitlenen bir kopya önerilir (istemcide yapıldığı gibi).
4. **İkili test ortamı:** Motor testleri Node'da (Vitest) kalır. Ek olarak `@cloudflare/vitest-pool-workers` ile workerd içinde de koşulur (**doğrulanacak**).
5. **`MatchSession`:** İstek kimliği önbelleği, hibernation'dan sağ çıkacak biçimde durumun içine ya da bağlantı ekine taşınır.

## 6. Kod güncellemesi, yeniden başlatma, kurtarma

- **Kod dağıtımı:** Hibernation API ile kabul edilen soketler yalnızca belirli koşullarda kapatılır: ertelenmiş güncellemede `max_delay` dolarsa ya da strateji `immediate` ise (resmi).
  - İstemci her durumda yeniden bağlanma ve tam durum alma (`match.snapshot`) yolunu destekler.
  - Dağıtımlar yoğun saat dışında yapılır.
- **Nesne yeniden başlarsa:**
  - Yapıcı durumu SQLite'tan yükler.
  - Alarm kalıcıdır.
  - Son kayıtlı eylemden devam edilir. Her eylem kalıcı yazıldığı için kayıp yoktur.
- **Kalıcı yazma sıklığı (K-60):**
  - Başlangıç önerisi: **her eylemden sonra**. En güvenli seçenek; maliyeti en yüksek (COST_AND_SCALING §3).
  - Alternatif: tur sonunda yazmak. Bedeli, çökmede son turun yeniden oynanması (zar yeniden atılır). Bu bir adalet sorunu olduğu için ölçüm ve kararla seçilecek.
- **Veri kaybı** (çok düşük olasılık): Maç `void` sayılır; Postgres'teki mutabakat işi emanetleri iade eder (SECURITY_ARCHITECTURE §7).

## 7. Ortamlar ve yapılandırma

| Ortam | Cloudflare | Supabase |
|---|---|---|
| `local` | `wrangler dev` (yerel workerd, DO ve SQLite taklidi) | Supabase CLI yerel yığın |
| `dev` | Ayrı Worker adı / ortam | Ayrı ücretsiz proje |
| `staging` | Ayrı ortam (sandbox satın almaları) | Ayrı proje |
| `prod` | Ayrı ortam | Ayrı proje (Pro önerilir, K-38) |

- **Yapılandırma:** `wrangler.jsonc`:
  - DO bağları;
  - `migrations` içinde `new_sqlite_classes` (ücretsiz plan SQLite ister);
  - `compatibility_date`.
- **Gizli anahtarlar:** `wrangler secret put` ile verilir; depoda bulunmaz. Yerelde `.dev.vars` kullanılır ve `.gitignore`'dadır.
- **Ücretsiz plan uyarısı:** Bazı ücretsiz Supabase projeleri bir haftalık hareketsizlikten sonra duraklatılır (SUPABASE_ARCHITECTURE §6). Geliştirme ortamı için not.

## 8. Açık teknik konular

| No | Konu | Ne zaman |
|---|---|---|
| T-1 | Bekleyen alarmın hibernation'ı engelleyip engellemediği; olay başına faturalanan gerçek süre | Faz 3 denemesi |
| T-2 | JWT'nin Worker'da mı, DO'da mı doğrulanacağı; Worker CPU süresi (10 ms ücretsiz) | Faz 3 |
| T-3 | Godot `WebSocketPeer` protokol ping ayarı; mobil ağda yarı açık bağlantı tespiti | Faz 4 |
| T-4 | Kalıcı yazma sıklığı (K-60) ve bunun maliyete etkisi | Faz 3–5 ölçüm |
| T-5 | DO yerleşimi ve TR'den gecikme (K-62) | Faz 5 |
| T-6 | Cron Trigger sayısı ve ücretsiz planda 10 ms CPU ile mutabakat işinin sığması (gerekirse Supabase `pg_cron`) | Faz 3 |
| T-7 | Supabase'e erişim yöntemi: Hyperdrive + özel rol ya da gizli API anahtarı + RPC (K-59) | Faz 3 denemesi |

## 9. Kaynaklar (erişim: 2026-11-17)

- Durable Objects fiyatlandırma: https://developers.cloudflare.com/durable-objects/platform/pricing/
- Durable Objects limitleri: https://developers.cloudflare.com/durable-objects/platform/limits/
- Workers limitleri: https://developers.cloudflare.com/workers/platform/limits/
- Workers fiyatlandırma: https://developers.cloudflare.com/workers/platform/pricing/
- WebSocket Hibernation: https://developers.cloudflare.com/durable-objects/best-practices/websockets/
- Veri konumu ve yerleşim ipuçları: https://developers.cloudflare.com/durable-objects/reference/data-location/
- `node:crypto` desteği: https://developers.cloudflare.com/workers/runtime-apis/nodejs/crypto/
- Hyperdrive fiyatlandırma: https://developers.cloudflare.com/hyperdrive/platform/pricing/
- Hyperdrive ile Supabase: https://developers.cloudflare.com/hyperdrive/examples/connect-to-postgres/postgres-database-providers/supabase/
