# SECURITY_ARCHITECTURE — Yeni Mimaride Güvenlik

> **Durum:** Faz 2 sonrası güncelleme (2026-11-17).
>
> **Kapsam:** Cloudflare + Supabase mimarisine özgü güvenlik gereksinimleri. Genel tehdit modeli, hesap güvenliği, reklam, gizlilik ve olay müdahalesi [../SECURITY_SPECIFICATION.md](../SECURITY_SPECIFICATION.md)'de geçerli. Bu belge oradaki "Node.js sunucusu" ve "Redis" geçen maddelerin **yerine** geçer.

## 1. Temel ilkeler

1. **İstemciye güvenilmez.** İstemci yalnızca **istek** gönderir (zar at, şu piyonu oyna, şunu satın al). Hiçbir sonucu belirlemez.
2. **Tek otorite:**
   - maç durumu → Cloudflare MatchRoom;
   - bakiye ve defter → Supabase Postgres.
3. **En az yetki:** Her bileşen yalnızca işi için gereken yetkiyi taşır.
4. **Her ekonomi işlemi atomik ve idempotenttir.**
5. **Gizli anahtar istemcide yoktur.**

## 2. Gizli anahtarların yönetimi

| Anahtar / kimlik bilgisi | Nerede | Asla |
|---|---|---|
| Supabase **service role / gizli API anahtarı** (`sb_secret_…`) | Kullanılırsa yalnızca Cloudflare gizli anahtarı. Tercihen hiç kullanılmaz; yerine K-59 seçenek A, sınırlı Postgres rolü. | **Godot istemcisi, depo, belgeler, günlükler** |
| Postgres `game_server` rolünün parolası (Hyperdrive) | Hyperdrive yapılandırması / Cloudflare gizli anahtarı | Aynı |
| Maç bileti HMAC anahtarı, `resumeToken` anahtarı | Cloudflare gizli anahtarı | Aynı |
| Google Play servis hesabı (JSON), App Store Server API özel anahtarı | Cloudflare gizli anahtarı | Aynı |
| Supabase JWT imzalama **özel** anahtarı | Yalnızca Supabase'de (asimetrik anahtarlar). Cloudflare yalnızca **genel** anahtarı JWKS'ten alır. | Cloudflare'de bile yok |
| Android yükleme anahtarı, iOS sertifikaları | Depo dışında, şifreli yedekli | Depo |

**İstemcide yalnızca gizli olmayan değerler bulunur:**
- Supabase proje URL'si ve **publishable / anon anahtar** (RLS ile korunur);
- oyun sunucusu adresi;
- reklam uygulama kimliği.

**Uygulama:**
- `wrangler secret put` ile ortam başına ayrı değerler.
- Yerelde `.dev.vars` (`.gitignore`'da).
- CI'da gizli anahtar taraması (gitleaks).
- Hesaplarda 2FA; Cloudflare API belirteçleri en az yetkiyle (yalnızca ilgili Worker'ı dağıtma).
- **Döndürme:** Her anahtar için belgelenmiş döndürme adımları (Faz 10 kontrol listesi).
  - Sızıntı şüphesinde önce döndürme yapılır, sonra inceleme.
  - JWT anahtarları JWKS üzerinden döner; istemci güncellemesi gerekmez.

## 3. Kimlik ve yetkilendirme

- **İstemci:** Supabase Auth'tan JWT alır (misafir, Google, Apple, e-posta).
- **Cloudflare:** JWT'yi her bağlantıda ve her REST isteğinde doğrular:
  - JWKS genel anahtarıyla **imza**;
  - `exp`, `iss`, `aud`, `sub`;
  - izin verilen algoritmalar listesi.
- **Belirteç URL'de taşınmaz.**
- **Maça giriş:** JWT + Matchmaker'ın verdiği **bilet** (maç, koltuk, kullanıcı, son kullanma; HMAC). Biletin kullanıcısı JWT'deki `sub` ile aynı olmalı.
  - Bir oyuncu başka bir koltuk için eylem gönderemez: koltuk bağlantıya bağlıdır, mesajda koltuk alanı yoktur.
- **Tek oturum:** Aynı kullanıcı aynı maça ikinci bir bağlantıyla gelirse önceki bağlantı `SESSION_REPLACED` ile kapatılır.
- **Yasak ve silme:** Worker, bağlantı ve ekonomi isteklerinde yasak / silinme durumunu kontrol eder (önbellekli, kısa ömürlü).
- **Misafir hesapların ekonomi sınırları:** K-63 (misafirin satın alma yapıp yapamayacağı).

## 4. Supabase'de veri erişimi

- **RLS:** Bütün tablolarda açık. İstemci yalnızca **kendi** satırlarını okur (SUPABASE_ARCHITECTURE §6).
- **İstemci yazamaz:** Cüzdan, defter, envanter, satın alma, maç ve istatistik tablolarına istemci yazma politikası yoktur.
  - Profil düzenleme gibi istemci kaynaklı değişiklikler de Worker'daki doğrulanmış uçlar ve sunucu işlevleri üzerinden yapılır.
- **Oyun sunucusu:** Yalnızca belirli işlevleri çağırabilir (`game_server` rolü, `EXECUTE` yetkisi; K-59). Tablolara genel yazma yetkisi yoktur.
- **İşlevlerin güvenliği:**
  - `security definer`, sabit `search_path`, dinamik SQL yok.
  - Girdi doğrulaması: dizi uzunluğu, tutar aralığı, bilinen nedenler.
- **Denetim:** Supabase güvenlik denetleyicisi (Advisors) uyarıları sıfırda tutulur. RLS testleri her migration'da koşar.

## 5. Zar ve hamle doğrulama

- **Zar:**
  - Yalnızca MatchRoom üretir: Web Crypto, reddetme örneklemesi.
  - Zar ancak üç koşul birlikte sağlanınca üretilir:
    - sıra o oyuncudadır;
    - aşama `roll`'dur;
    - `turnId` günceldir.
  - **İstemciden zar değeri hiçbir koşulda kabul edilmez.** Protokolde zar alanı yok; bilinmeyen alanlar şema doğrulamasında reddedilir.
- **Üst üste iki 6'dan sonraki atış 1–5 (K-13):**
  - Zar kaynağında uygulanır.
  - Motor ayrıca `sixes == 2` iken 6'yı reddeder (iki katmanlı savunma).
  - Kural istemcide **değil**, sunucuda uygulanır. Çevrimdışı pratikte yerel motor aynı kuralı uygular, ama oradaki sonuç hiçbir ödüle bağlı değildir.
- **Hamle:**
  - İstemci yalnızca piyon numarası (0–3) gönderir.
  - Sunucu geçerli hamle listesinde olup olmadığını denetler. Hedef, yeme ve bitişi kendisi hesaplar.
  - Geçersiz istek durumu değiştirmez (motorun mevcut davranışı; testli).
- **Tekrar ve sıra:**
  - `reqId` tekrarı → ilk yanıt yeniden gönderilir.
  - Eski `turnId` → `STALE_TURN`.
  - Sırası olmayan → `NOT_YOUR_TURN`.
  - Bunlar mevcut motor ve `MatchSession`'da testli: TS 73, GDScript 27 test.
- **Süre:** Sunucunun saati otoritedir. Son tarihten sonra gelen hamle reddedilir; 150 ms tolerans (NETWORK_PROTOCOL §7).

## 6. Ekonomi güvenliği

| Gereksinim | Uygulama |
|---|---|
| Bakiye sunucuda | Bakiye yalnızca Postgres'te; istemci yalnızca okur |
| Atomik işlem | Her hareket tek Postgres işleminde: defter satırı + bakiye + (varsa) envanter / emanet. Cüzdan satırı `SELECT … FOR UPDATE` ile kilitlenir. |
| Negatif bakiye yok | `CHECK (coins >= 0)` ve `CHECK (gems >= 0)`. Harcama öncesi bakiye kontrolü. İade sonrası açık bakiyeye yazılmaz, `wallet_debts` kaydına yazılır (E-6). |
| Çift ödül / çift ödeme yok | `wallet_transactions.idempotency_key` benzersiz. Maç girişi `entry:<maç>:<kullanıcı>`, ödül `payout:<maç>:<kullanıcı>`, satın alma `iap:<platform>:<transaction_id>`. Aynı anahtar ikinci kez gelirse işlem yapılmaz, önceki sonuç döner. |
| Maç girişi ve ödülün izlenmesi | `match_entries` (emanet) + defter. Maç sonucu sunucunun hesapladığı paylarla dağıtılır (`computePayout`; havuzdan fazla ödeme matematiksel olarak imkânsız, testli). |
| Elmas maçta kullanılmaz | Emanet işlevi yalnızca `gold` kabul eder (veritabanı düzeyinde kısıt) |
| Transfer ve nakde çevirme yok | Böyle bir işlev ve uç **yoktur** |
| Satın alma doğrulaması | Yalnızca sunucuda: Google Play Developer API ve App Store Server API / imzalı işlem (JWS) doğrulaması. İstemcinin "başarılı" bildirimi tek başına **yeterli değildir**. `(platform, transaction_id)` benzersiz. |
| İade ve iptal | Mağaza bildirimleri (Google RTDN, App Store Server Notifications V2) imza doğrulamasıyla alınır; `revoke_purchase` idempotent |
| Denetim | Gece işi: bakiye = defter toplamı denetimi (örneklemli). Sapma P1 olaydır (SECURITY_SPECIFICATION §17). |

## 7. Kurtarma ve tutarlılık

| Durum | Davranış | Para birimleri |
|---|---|---|
| İstemci koptu | Maç sürer, otopilot oynar; geri dönüşte tam durum | Etkilenmez |
| MatchRoom yeniden başladı | Durum her eylemden sonra DO deposunda (K-60); alarm kalıcı; kaldığı yerden sürer | Etkilenmez |
| Emanet sırasında hata | `escrow_match_entry` tek işlem: ya herkesten alınır ya hiç kimseden. Maç başlamaz. | Tutarlı |
| Maç bitti, Supabase erişilemiyor | Sonuç DO `outbox`'ında bekler; üstel geri çekilmeyle tekrar denenir; `settle_match` idempotent | Gecikmeli ama kayıpsız |
| MatchRoom verisi kaybolur (çok düşük olasılık) | Maç `void`. **Mutabakat işi** belirli süreyi (öneri: 6 saat) aşan `held` emanetleri iade eder. | İade edilir |
| Kod güncellemesi | İstemci yeniden bağlanır, tam durumu alır | Etkilenmez |

## 8. Hız sınırları ve kötüye kullanım

- **Bağlantı başına (MatchRoom / Matchmaker):** Bellekte jeton kovası. Limitler NETWORK_PROTOCOL §10'da: bütün mesajlarda patlamada 30 / sn, sürekli 10 / sn.
  - Aşılırsa `RATE_LIMITED`; sürerse bağlantı kapanır.
  - **Maliyet yanı:** Her gelen mesaj faturalandığı için (20:1), aşırı mesaj gönderen istemci erkenden kesilir.
- **Kullanıcı ve IP başına (Worker):** REST ve bağlantı açma sınırları.
  - Cloudflare'in hız sınırlama özellikleri (WAF kuralları ya da Workers rate-limiting bağı) — ücretsiz planda hangilerinin kullanılabildiği **doğrulanacak**.
  - Yedek olarak sınırlar DO'da sayılır.
- **Hesap açma:** Supabase'in anonim kayıt sınırı (IP başına saatte 30) + gerekirse CAPTCHA.
  - Mobil uygulamada CAPTCHA'nın nasıl gösterileceği **doğrulanacak** (web görünümü gerekebilir).
- **Oda kodu tahmini:** `room.join` dakikada 20; kodlar 6 karakter, karışabilecek karakterler hariç.
- **Ekonomi istismarı:**
  - Günlük ücretsiz altın ve telafi günde sınırlı.
  - Çoklu hesapla telafi toplama: cihaz ve hesap sinyalleri gözlenir; v1.1'de Play Integrity / App Attest (K-40).
- **4 kişilik altınlı maçta işbirliği** (arkadaşların aynı maça girip birini kazandırması):
  - Hızlı maçta arkadaşlar aynı kuyruğa birlikte giremez.
  - Özel odada altınlı maç yok (öneri, E-4 ile birlikte karar).
  - Gece analizi: aynı kişilerle tekrarlanan maçlar.
- **Ücretsiz plan kotalarını tüketme saldırısı:** Kötü niyetli trafik günlük kotayı bitirirse hizmet o gün durur. Bu, yayında Paid planın önerilme nedenlerinden biri (K-58, COST_AND_SCALING §5).

## 9. Günlükleme ve izleme

- **Ne günlüğe yazılmaz:** JWT, anahtar, e-posta, tam IP.
- **Kimlik alanları:** `userId` takma kimlikle, ayrıca `matchId` ve `traceId`.
- **Cloudflare:** Workers günlükleri ve DO metrikleri. Ekonomi ve güvenlik olayları ayrıca Postgres'te denetim kaydı olarak tutulur (defter zaten denetim izidir).
- **Uyarılar:**
  - kota kullanımı (%70 ve %90);
  - satın alma doğrulama hata oranı;
  - mutabakat sapmaları;
  - `settle_match` birikimi.

## 10. Güvenlik testleri (Faz 5)

- Protokol bulanıklaştırma; başka maçın ya da koltuğun eylemi; zar alanı eklenmiş mesaj (reddedilmeli).
- Aynı `reqId`'yi 5 kez gönderme → tek zar.
- **Üçüncü atış:** 10.000 "iki 6 sonrası" atışta hiç 6 çıkmaması ve 1–5'in dağılımının ki-kare testinden geçmesi.
- **Ekonomi:**
  - Eşzamanlı emanet;
  - çift `settle_match`;
  - aynı makbuzun iki kez gönderilmesi;
  - sahte makbuz;
  - iade sonrası borç.
- **RLS:** Başka kullanıcının cüzdanını okuma ve yazma denemeleri.
- **Hız sınırları:** Her sınırın aşılması.
- **Kurtarma:** Maç ortasında DO'nun yeniden başlatılması; sonuç kaydı sırasında Supabase kesintisi.
