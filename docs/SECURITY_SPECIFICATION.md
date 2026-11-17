# SECURITY_SPECIFICATION — Güvenlik ve Hile Önleme

> **Durum:** Faz 1 taslağı (2026-11-16).
>
> **Faz 2 sonrası güncelleme (2026-11-17):** Oyun sunucusu artık Cloudflare Workers + Durable Objects; Redis yok. Bu belgedeki "Node.js sunucusu", "Redis" ve "service role ile yazma" geçen maddelerin yerine [architecture/SECURITY_ARCHITECTURE.md](architecture/SECURITY_ARCHITECTURE.md) geçerli. Tehdit modeli, hesap, reklam, gizlilik ve olay müdahalesi bölümleri geçerli.
>
> **Temel kabul:** **İstemci düşmandır.** Değiştirilmiş APK, bellek düzenleyici, sahte istek gönderen bot ya da araya giren vekil sunucu (proxy) her zaman mümkündür. Oyunun adaleti ve ekonomisi yalnızca sunucuda korunur.

## 1. Tehdit modeli (özet)

| Varlık | Tehdit | Ana savunma |
|---|---|---|
| Zar ve hamle | İstemcinin zarı ya da konumu değiştirmesi, sırası dışında oynaması | Otoriter sunucu, sunucu RNG, `legalMoves` doğrulaması (§5) |
| Maç sonucu | Sahte sonuç, ödül tekrarı | Sonucu yalnızca sunucu yazar; idempotency anahtarı (§6) |
| Altın / envanter | Doğrudan DB yazma, yarış koşulu, negatif bakiye | RLS ile yazma yok; tek işlem + `FOR UPDATE`; `CHECK` (§4, §6) |
| Satın almalar | Sahte makbuz, tekrar oynatma, iade sonrası kullanma | Sunucu doğrulaması, benzersiz işlem kimliği, mağaza bildirimleri (§7) |
| Reklam ödülü | Reklamı izlemeden ödül, sınırı aşma | SSV + niyet kaydı + günlük sınır (§8) |
| Hesap | Belirteç çalma, kimlik avı, e-posta ele geçirme | Kısa ömürlü JWT, güvenli depolama, yeniden doğrulama gerektiren işlemler (§10) |
| Sosyal | Davet / istek spam'i, taciz | Yalnızca arkadaş daveti, sınırlar, engelleme, serbest sohbet yok (§9) |
| Altyapı | DoS, anahtar sızıntısı | Hız sınırı, CDN / WAF, gizli anahtar yönetimi (§3) |

## 2. Kimlik doğrulama ve oturum

- **Kimlik:** Supabase Auth; JWT erişim belirteci kısa ömürlü (~1 sa), dönen yenileme belirteci.
- **İstemcide saklama:** Yenileme belirteci **Android Keystore / iOS Keychain** ile korunan güvenli depoda tutulur; düz `user://` dosyasında değil.
  - Erişim belirteci yalnızca bellekte tutulur.
- **Sunucuda doğrulama** (API + gerçek zamanlı servis):
  - İmza: asimetrik anahtarlarda JWKS önbelleği, 10 dk yenileme; simetrikte yalnızca sunucudaki gizli anahtar.
  - `exp` (±30 sn saat toleransı), `aud = "authenticated"`, `iss = <proje>`.
  - `sub` → `profiles` var mı, `banned_until` geçmiş mi, `deletion_requested_at` boş mu.
- **Anonim hesaplar:** Gerçek bir kullanıcıdır, ama kötüye kullanım riski yüksektir (sınırsız hesap açma). Önlemler:
  - Anonim hesap oluşturmaya IP ve cihaz bazlı sınır.
  - Supabase CAPTCHA seçeneği (Turnstile / hCaptcha) ancak kötüye kullanım görülürse açılır.
  - Anonim hesaplara IAP dışında ekonomi sınırları: günlük reklam ödülü aynı.
  - Misafir hesaptan **altın transferi yok**; zaten oyuncular arası transfer de yok.
- **Çıkış ve iptal:** Çıkışta yenileme belirteci iptal edilir. Hesap silme ve yasak durumlarında bütün oturumlar sunucudan sonlandırılır (Supabase yönetici çıkışı + gerçek zamanlı bağlantı kapatma).
- **Tek oturum:** Aynı kullanıcı için tek aktif gerçek zamanlı bağlantı (NETWORK §3).

## 3. Gizli anahtarlar ve yapılandırma

- **Service role anahtarı, mağaza servis hesabı ve App Store anahtarları:**
  - **Yalnızca** Cloudflare gizli anahtarlarında (`wrangler secret`) ya da gizli anahtar yöneticisinde bulunur. Service role anahtarı tercihen **hiç kullanılmaz**; oyun sunucusu sınırlı yetkili `game_server` rolüyle bağlanır (K-59).
  - Depoda (`.env.example` hariç, sahte değerlerle), istemci derlemesinde ve belgelerde **asla** yer almaz.
- **İstemcide bulunabilecekler:** Supabase URL + **anon (publishable) anahtar** (RLS ile güvenli), AdMob uygulama kimliği, FCM yapılandırması. Bunlar gizli değildir, ama RLS ve sunucu doğrulaması olmadan güvenli de değildir.
- **İmzalama anahtarları:** Android yükleme anahtarı ve iOS sertifikaları depo dışında, şifreli yedekli tutulur. Google Play App Signing kullanılır.
- **Denetim:** CI'da gizli anahtar taraması (gitleaks); depo ilk günden `.gitignore` ile korunur.
- **Döndürme:** Bir anahtar sızarsa döndürme prosedürü belgelenir (Faz 10 kontrol listesi): service role ve JWT anahtarı döndürme, mağaza anahtarı iptali.

## 4. Supabase RLS

- **Politikalar:** Ayrıntı DATABASE_SCHEMA §4. Özet:
  - Bütün tablolarda RLS açık; `anon` ve `authenticated` rollerinden yetkiler geri alınmış.
  - İstemci yalnızca **kendi** satırlarını **okur**.
  - Başkasına ait veriler yalnızca `security definer` RPC'lerle, güvenli sütunlarla ve engelleme filtresiyle gelir.
  - Ekonomi, maç, istatistik ve satın alma tablolarına **hiçbir istemci yazma politikası yoktur**.
- **RPC'ler:** `search_path` sabit; girdiler doğrulanmış; dinamik SQL yok.
- **Testler:** Her migration'dan sonra otomatik RLS testleri çalışır (iki kullanıcıyla okuma / yazma reddi).
- **Supabase güvenlik denetleyicisi:** Advisors / linter uyarıları CI'da sıfırda tutulur.

## 5. Hamle doğrulama ve zar

- **Zar:** Yalnızca yetkili oyun sunucusunda (Cloudflare MatchRoom), kriptografik rastgele sayı üreteciyle ve modulo sapması olmadan üretilir. Üst üste iki 6'dan sonraki atış yalnızca 1–5'tir (GAME_RULES §6.2). İstemcinin gönderdiği hiçbir alan zarı etkilemez; istemciden zar değeri kabul edilmez.
  - Zar yalnızca: (a) sıra o oyuncudaysa, (b) tur aşaması `roll` ise, (c) `turnId` güncelse üretilir.
- **Hamle:**
  - İstemci yalnızca `pawn` (0–3) gönderir.
  - Sunucu `legalMoves(state, dice)` listesinde olup olmadığını kontrol eder.
  - Hedef konum, yeme ve bitiş **sunucuda** hesaplanır.
- **Sıra ve zaman:** Sunucu zamanlayıcıları tek otoritedir. Hamle `deadline`'dan sonra gelirse reddedilir (NETWORK §7).
- **Tekrar:** `reqId` tekrarı yeniden işlenmez. `turnId` / `stateVersion` eskiyse reddedilir.
- **Bilgi sızıntısı:** Ludo'da gizli bilgi yoktur. Gelecekteki zarlar önceden üretilmez ve istemciye gönderilmez.
- **Denetlenebilirlik:** Her maçın olay günlüğü 90 gün saklanır (zar, hamle, sunucu zamanı). v1.1'de commit–reveal tohumu (TECHNICAL_ARCHITECTURE §6).
- **İstatistiksel denetim:** Zar dağılımı her gün toplu olarak ki-kare testinden geçirilir. Sapma uyarısı RNG ya da kod hatası alarmıdır.

## 6. Maç sonuçları ve ödül manipülasyonu

- **Sonucu kim yazar:** Maç sonucunu yalnızca gerçek zamanlı servis üretir ve işçi Postgres'e yazar. Ödül bu işlemin içinde verilir; istemcinin "ödül talep et" ucu **yoktur** (maç için).
- **İdempotency:** `wallet_transactions.idempotency_key` (`match:<id>:seat:<n>`) benzersiz; outbox tekrar denese de ödül iki kez yazılmaz.
- **Çiftlik (farming) önlemleri:**
  - **Özel odalar:** Altın yok, XP azaltılmış; "kazan" görevleri ilerlemez (ECONOMY §4.3). Kendi kendine iki hesapla oynamayı anlamsız kılar.
  - **Hızlı maç:** Aynı iki hesap kısa aralıkla sürekli eşleşir ve biri sürekli terk ederse işaretlenir.
  - **Bot doldurmalı maçlarda** ödül yarıya iner.
- **Görev ve başarım:** İlerleme sunucuda maç olaylarından hesaplanır. Talep ucu yalnızca `completed_at` doluysa ve `claimed_at` boşsa çalışır.
- **Günlük giriş:** Sunucu tarihine göre çalışır (TR günü); istemci saati değiştirilerek tekrarlanamaz.

## 7. Satın alma sahteciliği

- **Doğrulama:** Her satın alma **sunucuda** doğrulanır:
  - **Google:** Play Developer API `purchases.products.get` / `purchases.subscriptionsv2.get` (servis hesabı).
  - **Apple:** App Store Server API (imzalı JWS işlem bilgisi, Apple kök sertifika zinciri doğrulaması).
- **Bağlama:** `obfuscatedAccountId` (Google) / `appAccountToken` (Apple) = sunucunun verdiği, kullanıcıya bağlı UUID. Başka bir kullanıcının makbuzunu kullanma girişimi tespit edilir.
- **Tekrar oynatma:** `unique (platform, transaction_id)`. Aynı belirteç ikinci kez gelirse ödül verilmez, önceki sonuç döner.
- **Ortam:** Sandbox makbuzları yalnızca `staging` ortamında ve test hesaplarında kabul edilir; üretimde reddedilir.
- **İade ve iptal:** Google RTDN + Voided Purchases API, Apple `REFUND` / `REVOKE` bildirimleri ile:
  - altın geri alınır (bakiye negatife düşebilir, sınırlı);
  - öğe envanterden kaldırılır;
  - abonelik kapatılır.
  - Tekrarlayan iade istismarında (ör. 3 iade) hesap işaretlenir (MONETIZATION §3.7).
- **Onaylama:** Ödül sunucuda verildikten **sonra** onaylanır (Google `acknowledge` / `consume`, Apple `finish`). Google'da 3 gün içinde onaylanmayan satın alma iade edilir; sunucu ödülü verdiyse istemci başarısız olsa da işçi onaylar.

## 8. Reklam ödülü sahteciliği

- **Doğrulama:** Ödül **yalnızca** AdMob sunucudan sunucuya doğrulama (SSV) geri çağrısıyla verilir.
  - İmza Google'ın yayınladığı genel anahtarlarla doğrulanır.
  - `custom_data = intentId`, `user_id` eşleşmesi kontrol edilir.
  - `transaction_id` benzersizdir.
- **Hak kontrolü:** Niyet (intent) oluşturulurken günlük ve yerleşim (placement) başına sınırlar kontrol edilir; niyet 15 dk geçerlidir.
- **Bölgesel uyumluluk:** Kişiselleştirilmemiş reklamlarda da SSV çalışır (doğrulanacak).

## 9. Hız sınırları, spam ve davet kötüye kullanımı

- **WSS sınırları:** NETWORK §10.
- **REST:** Kullanıcı ve IP başına jeton kovası (token bucket): Cloudflare Worker ve Durable Object'lerde (architecture/SECURITY_ARCHITECTURE §8).
  - Kimlik doğrulama uçları için Supabase'in kendi sınırları + CAPTCHA seçeneği.
- **Arkadaşlık:**
  - Bekleyen giden istek ≤ 50; günde ≤ 100 istek.
  - Aynı kişiye reddedildikten sonra 7 gün yeni istek yok.
  - Sınırlar 200 arkadaş / 200 engel (engel sınırı yüksek tutulabilir).
- **Davet:** Yalnızca arkadaşlara; engelleme kontrolü; sınırlar NETWORK §10'da.
  - Push davetleri kişi başına saatte en fazla 10 kez gönderilir; kullanıcı bildirim ayarına uyulur.
- **İçerik:**
  - Serbest sohbet yok.
  - Görünen ad filtreden geçer: TR / EN yasaklı sözcük listesi, benzer karakter (leet) normalizasyonu, rezerve adlar ("admin", "destek", marka adları).
  - Şikâyet edilen ad, moderasyonla zorla değiştirilebilir (`force_rename`).
- **Kod tahmini:** Özel oda kodu 6 karakter, 31 karakterlik alfabe (~887 milyon olasılık) + `room.join` sınırı. Oda kodları 10 dk sonra geçersizdir.

## 10. Hesap çalma riskleri

- **Riskli eylemlerde yeniden doğrulama:**
  - e-posta değiştirme;
  - hesap silme;
  - bağlı kimlik kaldırma (son kimlik kaldırılamaz).
  - Yöntem: son 5 dk içinde giriş, ya da şifre / yeniden sosyal giriş.
- **Bildirim:** E-posta değişikliği ve yeni cihaz girişi e-posta ile bildirilir (e-posta hesabı varsa).
- **Kimlik avına karşı:** Uygulama içinde "destek ekibi şifreni sormaz" bilgisi bulunur. Destek, kullanıcıyı oturum kimliğiyle tanır.
- **Misafir hesap:** En zayıf halka cihazın kendisidir. Değerli hesaplar için (satın alma yapmış misafir) hesap bağlama güçlü biçimde önerilir.

## 11. Sunucu tarafı günlükleme ve denetim

- **Güvenlik olayları:** Başarısız JWT doğrulama, hız sınırı aşımı, `ILLEGAL_MOVE`, `STALE_TURN` patlamaları, IAP doğrulama hatası, SSV imza hatası, RLS ihlal denemesi (Postgres günlüğü), yönetim işlemleri. Hepsi `security=true` etiketiyle ayrı akışa yazılır.
- **Yönetim işlemleri:** `moderation_actions` ve yönetim günlüğü (kim, ne zaman, neden). Yönetim paneli ayrı kimlik ve 2FA ister.
- **Kişisel veri:** Günlüklerde e-posta yok; IP son okteti maskelenir; kullanıcı kimliği takma ada çevrilir (günlük toplama tarafında).

## 12. Oyuncu şikâyetleri ve moderasyon

- **Akış:** Şikâyet → `reports` (otomatik ek: maç kimliği, son 50 olay, ad / avatar anlık görüntüsü) → moderasyon kuyruğu (basit yönetim paneli, Faz 6).
- **Otomatik kurallar** (öneri):
  - 24 saatte 5 farklı kişiden "uygunsuz ad" şikâyeti → ad geçici olarak "Oyuncu#tag" yapılır, inceleme beklenir.
  - Aynı maçta birden çok "oyunu bozma" şikâyeti → terk ve zaman aşımı istatistikleriyle birlikte incelenir.
- **Yaptırımlar:** uyarı, zorla ad değişikliği, emoji susturma, geçici yasak (1 / 7 / 30 gün), kalıcı yasak. Kullanıcıya gerekçe bildirilir (gelen kutusu).
- **Gizlilik:** Şikâyet eden kişinin kimliği şikâyet edilene **gösterilmez**.

## 13. Hile tespiti

- **Ludo'da hilenin başlıca biçimleri:**
  - **İşbirliği:** 4 kişilik maçta aynı kişinin birden çok hesabı ya da anlaşmalı oyuncular, birini kazandırmak için oynar.
  - **Otomasyon / bot hesapları:** Görev ve reklam ödülü toplama.
  - **İstismar:** Kasıtlı kopma ve terk ile ceza kaçırma.
- **Sinyaller ve önlemler:**

| Sinyal | Eylem |
|---|---|
| Aynı cihaz kimliğinden (Android ID / IDFV) ya da IP'den aynı hızlı maça birden çok hesap | Eşleştirici aynı cihaz / IP'yi aynı maça koymaz (IP için yumuşak kural: NAT / CGNAT yaygın) |
| 4 kişilik maçta bir oyuncunun sürekli diğerine yenilmeye çalışması (piyonları yenme menziline sokma, sürekli zaman aşımı) | İşaret + inceleme |
| İnsan dışı zamanlama (her hamle aynı ms aralığında, 24 sa kesintisiz) | İşaret; ödüllü reklam sınırının sıkılaştırılması |
| Çok yüksek terk oranı | Kademeli eşleştirme cezası (GAME_RULES §11.6) |

- **Uygulama:** Tespit, gece toplu analiz (SQL / iş akışı) ile yapılır; gerçek zamanlı ağır analiz MVP'de yok.
- **Hesap güvenilirlik puanı:** İşaretlenen hesaplar dereceli moda (v1.1) alınmaz.

## 14. İstemci sağlamlaştırma (ikincil savunma)

İstemci tarafı önlemler yalnızca **maliyeti artırır**; güvenlik sunucudadır.

| Önlem | Ne zaman |
|---|---|
| Google Play Integrity API ve Apple App Attest | v1.1: şüpheli istemcileri işaretlemek için; ilk sürümde yalnızca günlük amaçlı (K-40 ile birlikte değerlendirilir) |
| GDScript'i ikili belirteç (token) olarak dışa aktarma | MVP; tersine mühendislik zorlaşır, imkânsız olmaz |
| Sertifika sabitleme (pinning) | **Önerilmez**: sertifika yenilemesinde uygulamayı kilitler. TLS doğrulaması yeterli. |
| Hata ayıklama derlemeleri | Ayrı paket adı (`.dev`); üretim API'sine bağlanamaz |

## 15. Gizlilik ve uyum

- **KVKK ve GDPR:**
  - Aydınlatma metni ve gizlilik politikası; açık rıza gereken işlemler (kişiselleştirilmiş reklam, analitik) için onay.
  - AB / BK / İsviçre için Google UMP onay penceresi (IAB TCF).
  - Veri indirme ve silme talepleri desteklenir.
- **iOS ATT:** Kişiselleştirilmiş reklam için App Tracking Transparency izni, bağlamlı açıklama ekranından sonra istenir. Reddedilirse kişiselleştirilmemiş reklam gösterilir.
- **Mağaza veri beyanları:** Google Play Veri Güvenliği formu ve Apple Gizlilik Etiketleri, kullanılan SDK'lara göre doldurulur (Faz 10).
- **Yaş:** Hedef 13+ (K-02).
  - 13 yaş altını hedeflemeyen bir uygulama olarak yaş beyanı alınıp alınmayacağı **karar konusudur** (K-02).
  - Alınırsa 13 yaş altına kişiselleştirilmemiş reklam ve sosyal özellik kısıtı uygulanır.
- **Veri en azı ilkesi:**
  - Konum, kişi listesi, kamera ve mikrofon izni **istenmez**.
  - Bildirim izni bağlam içinde istenir.

## 16. Sorumluluk dağılımı

| Konu | İstemci (Godot) | Oyun sunucusu (Cloudflare Workers + Durable Objects) | Supabase |
|---|---|---|---|
| Kimlik | Yerel girişi başlatır, belirteci güvenli saklar | JWT'yi doğrular, yasak / silme kontrolü | Kimlik sağlayıcı, belirteç üretimi, anonim / bağlama |
| Zar ve kurallar | Gösterir; yerel kural motoru **yalnızca** çevrimdışı pratikte | **Tek otorite**: RNG, `legalMoves`, uygulama, zaman | — |
| Maç sonucu ve ödül | Gösterir | Hesaplar; sonucu DO deposunda bekletir (outbox); idempotent tekrar | Atomik sunucu işlevleri, kalıcı kayıt, `CHECK` / `UNIQUE` kısıtları |
| Ekonomi | Altınla satın alma isteği | Fiyat kontrolü, tek işlem | RLS: okuma; kısıtlar |
| Satın alma | Platform penceresi, belirteci sunucuya iletir, onayı sunucudan sonra yapar | Mağaza API doğrulaması, ödül, iade işlemleri | Kayıtlar, benzersizlik |
| Reklam | SDK gösterimi, onay penceresi | SSV doğrulaması, sınırlar | Niyet kayıtları |
| Sosyal | Arayüz, engelle / şikâyet et | Sınırlar, engelleme filtresi, davet yönlendirme | İlişkiler, RLS |
| Gizli anahtarlar | Yalnızca genel anahtarlar (URL, anon / publishable anahtar) | `game_server` rol bilgisi (Hyperdrive), bilet HMAC anahtarı, mağaza kimlik bilgileri (Cloudflare gizli anahtarları) | JWT imzalama özel anahtarı, anahtar döndürme |
| Günlükleme | Çökme raporu, analitik (onaylı) | Güvenlik ve denetim günlükleri | Auth / DB günlükleri |

## 17. Olay müdahalesi

- **Hazırlık:**
  - Ciddiyet seviyeleri (P1: ekonomi / güvenlik açığı, P2: hizmet kesintisi, P3: hata).
  - İletişim listesi ve hazır duyuru metinleri.
  - Acil kapatma anahtarları (`app_config.feature_flags`: mağaza, reklam ödülü, özel oda, eşleştirme).
- **Ekonomi açığında:**
  1. İlgili uç kapatılır.
  2. Etkilenen işlemler `wallet_transactions` üzerinden bulunur.
  3. Geri alma betiği çalıştırılır.
  4. Etkilenen oyunculara bildirim gönderilir.
