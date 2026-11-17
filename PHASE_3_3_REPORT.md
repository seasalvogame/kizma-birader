# Faz 3.3 Raporu — Oynanabilir Oyun (İş Akışı A) ve Cloudflare İskeleti (İş Akışı B)

> **Tarih:** 2026-11-17
> **Sürüm:** 0.3.0 (Android versionCode 3)
> **APK:** `build/android/KizmaBirader-0.3.0-debug.apk` (29,2 MB; SHA-256 `645a5283a529ada60ff49b3610cc0c1388850d4a2871cd13402bde7ca05d363e`)
> **Ekran görüntüleri:** `docs/phase3_3_screens/` (`overview.png`)

## 0. Başlangıç incelemesi: sorular ve cevaplar

| Soru | Faz 3.3 öncesi | Faz 3.3 sonrası |
|---|---|---|
| Uygulama açılınca ne görülüyor? | Doğrudan "Maç kur" ekranı | **Ana menü:** profil, 2 ve 4 kişilik oyun kartları, Özel Oda / Pratik, çevrimiçi duyurusu, gerçek istatistikler, alt gezinme çubuğu |
| Ana menü hazır mı? | Hayır | **Evet** |
| Oyun tahtası görsel olarak hazır mı? | Evet (Faz 2) | Evet. Ayrıca **arka plan hatası düzeltildi**: gece zemini Faz 2'den beri hiç çizilmiyordu (§1.3). |
| Taşlar gerçekten hareket ediyor mu? | Evet: kare kare zıplama, yeme, bitiş animasyonları | Aynı |
| Zar animasyonu ve sıra geçişleri var mı? | Evet | Evet |
| Botla baştan sona maç oynanabiliyor mu? | Evet (testli) | Evet (testli) |
| 2 ve 4 kişilik maçlar görsel olarak çalışıyor mu? | Evet | Evet. 2 kişilikte renk seçimi de var. |
| Eksik ekranlar | Ana menü, mod seçimi, profil, ayarlar, kurallar, sekmeler | Hepsi eklendi. Çevrimiçi gerektirenler dürüst "yakında" ekranlarıyla. |
| İlk oynanabilir APK için gerekenler | Menü kabuğu, eski kural metninin düzeltilmesi, sürüm | Yapıldı; APK hazır |

## 1. Oyun tarafı (İş Akışı A)

### 1.1 Tamamlanan özellikler

**Ana menü** (prototip `03_ana_menu` temel alındı):
- Profil satırı: avatar, ad, "Misafir · çevrimdışı".
- Ayarlar düğmesi.
- 2 Kişi (mavi) ve 4 Kişi (kırmızı) oyun kartları: 3B kenar ve zar görseli.
- Özel Oda (YAKINDA) ve Pratik kartları.
- "Çevrimiçi maçlar yakında" kartı.
- Bu cihazdaki pratik maçlardan **gerçek** istatistikler.

**Diğer ekranlar:**
- **Alt gezinme:** Ana Sayfa, Arkadaşlar, Mağaza, Görevler, Sıralama.
- **Oyun modu seçimi:**
  - Botlara karşı (çalışıyor);
  - Aynı telefonda (çalışıyor);
  - Çevrimiçi hızlı maç (YAKINDA);
  - Özel oda (YAKINDA).
- **Maç kur:**
  - **Renk seçimi:** dört renk. 2 kişilikte rakip otomatik olarak karşı köşeye oturuyor: kırmızı–sarı, yeşil–mavi.
  - 2 / 4 kişi; her koltuk Bot ya da Oyuncu.
  - Tahta, seçilen renk sol altta kalacak şekilde dönüyor.
- **Profil:**
  - oyuncu adı (3–16 karakter, doğrulamalı, kaydediliyor ve maçta görünüyor);
  - 6 avatar rengi;
  - pratik istatistikleri;
  - Başarımlar (YAKINDA);
  - hesap durumu (misafir).
- **Ayarlar:** dil (TR / EN, anında); tek hamleyi otomatik oyna; hızlı animasyon; renk sembolleri; titreşim; azaltılmış hareket; "Nasıl oynanır"; sürüm. Ses ve müzik için "yakında" notu.
- **Nasıl oynanır:** 8 maddelik kurallar. İki 6'dan sonraki 1–5 sınırı, K-56 kararı gereği **anlatılmıyor**.
- **Yakında ekranları** (Arkadaşlar, Mağaza, Görevler, Sıralama, Başarımlar, Çevrimiçi Maç, Özel Oda):
  - özelliğin ne olacağını anlatıyor;
  - "Çevrimiçi hesap gerekiyor · Yakında" etiketi taşıyor;
  - "Pratik maç oyna" düğmesi sunuyor.
  - **Sahte bakiye, sahte ödül ya da sahte liste yok.**

**Gezinme ve mobil davranış:**
- Gezinme yığını; Android **geri tuşu** önceki ekrana dönüyor.
- Maç içinde geri tuşu maç menüsünü açıyor, maçı sessizce kapatmıyor.
- Ana menüde geri tuşu uygulamadan çıkıyor.

**Maç:**
- Faz 2 maç ekranı korundu.
- Maç bitince yerel istatistikler kaydediliyor.
- **Titreşim:** yeme ve bitişte kısa titreşim (ayar açıksa; yalnızca telefonda).

**Metin düzeltmesi:**
- Kurulum ekranındaki kural özeti eski "üçüncü 6 turu bitirir" kuralını yazıyordu; kaldırıldı.
- Yeni kural hiçbir metinde geçmiyor.

**Yeni varlıklar:** 15 ikon (ev, arkadaşlar, çanta, görev, kilit, telefon, küre, ok, kalem, madalya, kitap, onay, kum saati, ses, podyum). 89 yeni TR / EN metin.

### 1.2 Değiştirilen dosyalar (istemci)

| Dosya | Değişiklik |
|---|---|
| `scripts/app/main.gd` | Yığın tabanlı yönlendirici, Android geri tuşu, maç sonu istatistiği |
| `scripts/app/settings.gd` | Profil adı ve avatar, son kurulum, yerel istatistikler, `vibrate()` |
| `scripts/ui/app_screen.gd` (**yeni**) | Menü ekranlarının ortak tabanı: zemin, güvenli alan, başlık, kaydırma, alt bölüm, alt gezinme |
| `scripts/ui/nav_bar.gd`, `play_card.gd`, `menu_card.gd` (**yeni**) | Alt gezinme, büyük oyun kartı, cam menü kartı |
| `scripts/ui/screens/home_screen.gd`, `mode_select_screen.gd`, `info_screen.gd`, `profile_screen.gd`, `settings_screen.gd`, `rules_screen.gd` (**yeni**) | Yeni ekranlar |
| `scripts/ui/screens/practice_setup_screen.gd` | Ortak tabana taşındı; renk seçimi; geri tuşu; dil seçimi ayarlara taşındı |
| `scripts/ui/screens/match_screen.gd` | `match_over` sinyali, `handle_back()`, titreşim |
| `scripts/ui/night_background.gd` | Boyut hatası düzeltildi; ışıltı yumuşatıldı |
| `scripts/ui/avatar.gd` | `set_fill()` |
| `tools/make_assets.py`, `tools/make_translations.py` | Yeni ikonlar ve metinler (üretilen SVG ve PO dosyaları dahil) |
| `project.godot`, `export_presets.cfg` | 0.3.0 / versionCode 3; `quit_on_go_back=false` |
| `tests/scene/test_app_navigation.gd` (**yeni**), `tests/visual/screenshot_tour.gd` | Yeni testler ve yeni ekranlarla tur |

Kural motoru (TS / GDScript) bu adımda **değişmedi**.

### 1.3 Bulunan ve düzeltilen hata

- **Belirti:** Gece zemininin boyutu `(0, 0)` kalıyordu. Tasarımdaki mor ışıltılı zemin ve yıldızlar **Faz 2'den beri hiç görünmüyordu**; ekranda düz siyaha yakın varsayılan renk vardı. Faz 2 ekran görüntülerinde de böyle.
- **Kanıt:** Geçici bir hata ayıklama çıktısında zemin `(0, 0)`, ebeveyni `(793, 1560)` olarak ölçüldü.
- **Neden:** `set_anchors_preset` kenar boşluklarını sıfırlamıyor.
- **Çözüm:** `set_anchors_and_offsets_preset`.

### 1.4 APK

| Konu | Değer |
|---|---|
| Yol | `build/android/KizmaBirader-0.3.0-debug.apk` |
| Paket | `com.kizmabirader.prototype` |
| Sürüm | 0.3.0 (3) |
| SDK | min 24, target 36 |
| Ekran | Yalnızca dikey (`screenOrientation=1`, `aapt` ile doğrulandı) |
| İzin | Yalnızca titreşim |
| İmza | Debug sertifikası |

**Cihazda denenmedi:** Telefon bağlı değildi (`adb devices` boş).

## 2. Cloudflare tarafı (İş Akışı B)

### 2.1 Tamamlananlar (yerelde)

**`server/worker/`** (Wrangler 4.163, workerd 1.20261116):
- **Yönlendirici Worker:** `/v1/health`; `/v1/match/:id` (WebSocket); `/v1/dev/matches`.
  - Dev ucu eşleştirici gelene kadar maç kurmak için var.
  - Oturan oyunculardan birinin geçerli JWT'sini istiyor.
  - Renk kuralını uyguluyor.
- **MatchRoom Durable Object** (maç başına bir nesne, SQLite deposu):
  - **Motor:** Mevcut TypeScript motoru **değişmeden** kullanılıyor.
  - **Zar:** Yalnızca sunucuda; Web Crypto; iki 6'dan sonra 1–5.
  - **İstemci girdisi:** İstemci yalnızca istek gönderebiliyor (roll / move / leave). Zar ya da koltuk alanı gelirse mesaj reddediliyor.
  - **Koltuk:** JWT'nin `sub`'ına bağlı. Aynı koltuğa ikinci bağlantı gelirse eskisi kapatılıyor.
  - **Tekrar koruması:** İstek kimliğiyle; ilk sonuç yeniden dönüyor.
  - **Kalıcılık:** Her eylemden sonra **önce yazma, sonra yayın** (K-60 B).
  - **Alarm:** Tur süresi, bot gecikmesi ve otopilot için tek alarm.
  - **Bağlantılar:** Hibernation API.
  - **Yeniden bağlanma:** Tam durum (`match.snapshot`).
  - **Hız sınırı:** Bağlantı başına jeton kovası (saniyede 10, patlamada 30).
  - **Hata mesajları:** İç ayrıntıyı sızdırmıyor (`TRY_AGAIN`).
- **JWT doğrulaması:** Supabase'in genel JWKS'iyle (ES256), yalnızca Web Crypto. Worker'da hiçbir sır yok.

**Gizli bilgi:**
- Service role anahtarı ve veritabanı parolası Worker'da **yok**.
- `wrangler.jsonc` yalnızca herkese açık değerler içeriyor.

### 2.2 Gerçek Cloudflare dağıtımı: yapılamadı (senin işlemin gerekiyor)

- **Kuru çalıştırma** (`wrangler deploy --dry-run`) başarılı: paket 46 KB (sıkıştırılmış 10,9 KB), bağlar doğru.
- **Gerçek dağıtım durdu:** Hesapta henüz bir **workers.dev alt alan adı** yok. Wrangler'ın otomatik denediği ad başkasına ait.
  - Bu ad hesabının herkese açık adresi olacağı için seçimi sana bırakıldı.
  - **Hiçbir şey dağıtılmadı, ücretli hiçbir şey açılmadı.**

## 3. Çalıştırılan testler ve sonuçları

| Test | Sonuç | Ortam |
|---|---|---|
| TypeScript motor (`npm test`) | **85 / 85** | Node |
| Motor + Worker tip denetimi (`tsc --noEmit`) | Temiz | — |
| Godot (headless) | **33 / 33**; 4'ü yeni gezinme testi | Masaüstü |
| Worker yerel uçtan uca (`test/local_ws_test.mjs`) | **23 / 23** | `wrangler dev` (yerel workerd) + gerçek Supabase misafir JWT'leri |
| Ekran görüntüsü turu | 16 ekran, gözle kontrol edildi | Masaüstü 540×1170 |

**Godot'taki yeni gezinme testleri:**
- Her ekran açılıyor ve geri tuşu doğru çalışıyor.
- Sekmeler gezinme yığınını sıfırlıyor.
- Maç içinde geri tuşu menüyü açıyor.
- Ana menü 4 ekran boyutunda sığıyor (640×1136 … 1080×1440).
- Dokunma alanları ≥ 88 px.
- 2 kişilikte renkler her seçimde karşılıklı ve motor bu koltukları kabul ediyor.
- "Aynı telefonda" modunda diğer koltuklar Oyuncu oluyor.
- Profil adı doğrulanıyor.
- İstatistikler doğru kaydediliyor.

**Worker yerel testinin kapsamı:**
- **Maç kurma ucu:**
  - JWT'siz istek → 401;
  - karşılıklı olmayan renk → `COLOR_INVALID`;
  - maçta olmayan kullanıcı → 403.
- **Kimlik:**
  - kurcalanmış JWT → `AUTH_INVALID`;
  - maçta olmayan geçerli JWT → `NOT_IN_MATCH`;
  - kimlik doğrulamadan eylem → `AUTH_REQUIRED`;
  - her JWT kendi koltuğuna bağlanıyor.
- **Sunucu otoritesi:**
  - sırası olmayan → `NOT_YOUR_TURN`;
  - **istemciden zar değeri** → reddedildi;
  - istemciden koltuk numarası → reddedildi.
- **Tekrar gönderilen istek:** İlk sonuç döndü, ikinci zar atılmadı.
- **Hız sınırı:** 40 mesajlık patlamada 12 mesaj reddedildi.
- **İki gerçek istemci arasında tam 2 kişilik maç:**
  - sunucuda bitti (346 eylem, 204 zar);
  - zarların hepsi 1–6;
  - **iki 6'dan sonraki 6 atışın hiçbiri 6 değil**.
- **Yeniden bağlanma** (60. eylemde): Tam durum aynı sıradan geldi.
- **Sunucu süreci öldürülüp yeniden başlatıldı** (120. eylemde): Maç kaldığı yerden sürdü.
- **Süre dolması:** Boşta kalan oyuncunun turunu sunucu oynadı; 3 zaman aşımından sonra otopilot açıldı. Bot + otopilot maçı yalnızca sunucu alarmlarıyla sonuna kadar oynandı.
- **Temizlik:** Test kullanıcıları silindi.

**Testte bulunan ve düzeltilen iki sorun:**
1. Şema hatasında yanıt istek kimliğini taşımıyordu; artık taşıyor.
2. Hız sınırı hatası da artık istek kimliğini ve `retryAfterMs` değerini taşıyor.

## 4. Gerçek bulutta test edilenler

| Özellik | Durum |
|---|---|
| Supabase Auth (gerçek misafir hesapları), JWKS ile JWT doğrulaması | ✅ Gerçek Supabase (yerel Worker testi bunu kullanıyor) |
| Supabase şeması, RLS, ekonomi işlevleri | ✅ Faz 3.2'de (61 + 15 test). Bu adımda şema değişmedi. |
| Worker dağıtımı, gerçek Durable Object, gerçek WebSocket | ❌ **Test edilmedi:** workers.dev alt alanı gerekli (§2.2) |
| Worker → Supabase bağlantısı (`game_server`) | ❌ Henüz kurulmadı (parola ve bağlantı yolu) |

## 5. Henüz test edilmeyenler

- **Android cihaz:** APK telefonda hiç açılmadı (telefon bağlı değildi). Dokunma, kaydırma, güvenli alan, geri tuşu, titreşim, performans **cihazda doğrulanmadı**.
- **Gerçek Cloudflare:** dağıtım, gecikme, ücretsiz kota kullanımı.
- **Supabase'e maç kaydı:** Worker'dan `start_match` / `finish_match` çağrısı.
- **Godot istemcisinin çevrimiçi sunucuya bağlanması:** Yok. Oyun şimdilik tamamen çevrimdışı.
- **iOS:** Derlenmedi.

## 6. Telefonunda test etmen gerekenler

1. **Kurulum:** APK'yı kur ve aç. Ana menü gelmeli; üst kısım çentiğe ya da kamera deliğine girmemeli.
2. **Profil:** Avatar ya da ada dokun, adını yaz, Kaydet'e bas. Ana menüde adın görünmeli.
3. **2 kişilik maç:**
   - **2 Kişi → Botlara karşı → renk seç** (ör. yeşil). Rakip mavi olmalı; tahtada senin rengin sol altta olmalı.
   - **OYNA** → maçı sonuna kadar oyna.
   - Kontrol et: zar atma; piyon seçme; yeme ve bitiş animasyonları; süre halkası; sonuç ekranı; "Tekrar oyna" ve "Ana menü".
4. **4 kişilik maç:** 4 Kişi → Botlara karşı → maçı oyna. İlk üç oyuncu bitince maç bitmeli.
5. **Android geri tuşu:**
   - Menü ekranlarında: bir önceki ekrana dönmeli.
   - Maçta: menü açılmalı.
   - Ana menüde: uygulamadan çıkmalı.
6. **Ayarlar:**
   - Dil İngilizce'ye geçmeli.
   - Titreşim açıkken yemede telefon titremeli.
   - Hızlı animasyon çalışmalı.
7. **Sekmeler:** Arkadaşlar, Mağaza, Görevler, Sıralama "yakında" ekranlarını göstermeli; "Pratik maç oyna" çalışmalı.
8. **Bildirmen yararlı olanlar:** Takılma, ısınma, yazıların taşması, yanlış yerleşim. Ekran görüntüsü göndermen yeterli.

## 7. Bir sonraki somut adım

1. **Senin işlemin:**
   - Cloudflare panelinde workers.dev alt alan adını kaydet: Workers & Pages → alt alan adı. Öneri: `kizmabirader` ya da benzeri.
   - Sonra `npx wrangler deploy` ile gerçek dağıtımı yapıp aynı uçtan uca testi bulutta koşturacağım.
2. **Telefon testi:** Bağlarsan APK'yı kurup cihazda doğrularım.
3. **Ardından:** Maç ekranını çevrimiçi oturuma bağlamak.
   - `MatchController`'ın yanına aynı `applied` / `finished` sinyallerini üreten bir `OnlineMatchSource` eklenecek.
   - Böylece **aynı maç ekranı** hem çevrimdışı hem çevrimiçi oynayacak.
   - Ana menüde "Çevrimiçi hızlı maç" ilk kez gerçekten açılacak; ilk sürümü 2 kişilik botsuz eşleşme ya da özel oda kodu olacak.
