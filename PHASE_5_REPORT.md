# Faz 5 Raporu — Arkadaşlar ve Özel Odalar

> **Tarih:** 2026-11-17
> **Sürüm:** 0.6.0 (Android versionCode 6)
> **APK:** `build/android/KizmaBirader-0.6.0-debug.apk` (29,4 MB; SHA-256 `98913e4364eebdbaff32ccbbe6cea1bfc6ac10d73af6bd2a6b88c19551f73c72`; izinler INTERNET, VIBRATE)
> **Sunucu:** https://kizmabirader-game-dev.kizmabirader.workers.dev (Cloudflare Free) + Supabase `kizmabirader-dev` (Free) + Hyperdrive (Free)
> **Git:** Faz 4 commit'i `34050a8`. Faz 5 ayrı bir commit olarak hazırlandı (SHA: §9). Push yapılmadı.
> **Gerçek cihaz:** 0.6.0 telefonda **denenmedi**. "Bulutta doğrulandı" satırları masaüstündeki Godot istemcisi ve Node test istemcileriyle gerçek buluta karşı yapıldı.

## 0. Özet

| Durum | Özellik |
|---|---|
| ✅ Bulutta doğrulandı | Oyuncu arama (ad / ad#etiket), arkadaşlık isteği gönderme / kabul / ret / iptal, çift istek engeli, karşılıklı istek → arkadaşlık, arkadaş silme, engelleme / engel kaldırma, oyuncu profili; canlı çevrimiçi durumu (çevrimiçi / odada / maçta / çevrimdışı); maç daveti (gönderme, canlı alma, kabul, çift kabulün tek işlenmesi, ret, 2 dakikada süre dolması, yalnızca arkadaşa, engellenene davet yok, başka odadaki oyuncu kabul edemez); 2 ve 4 kişilik özel oda (kod, katılma, yanlış kod, dolu oda, renkler, hazır, oda sahibinin başlatması, yetkisiz başlatma, ayrılma, sahiplik devri, boş odanın kapanması, kod deneme sınırı, lobide yeniden bağlanma); odadan başlayan maçın **mevcut MatchRoom**'da oynanması ve Supabase'e `private` olarak kaydı, istatistiklerin güncellenmesi, maç sonrası odanın yeniden lobi olması |
| ✅ Yerelde doğrulandı | Yeni 7 ekranın çevrimdışı durumları (yükleniyor / bağlantı hatası / boş), ekran görüntüleri, oda kodu biçimi |
| ⛔ Denenmedi | Gerçek telefonda kullanım; iOS |
| Değişmedi | Hızlı eşleşme, maç ekranı, oyun motoru, kurallar, ekonomi (altınlı maçlar kapalı) |

## 1. Mimari (mevcut sistem korunarak)

| Parça | Görev | Yeni mi? |
|---|---|---|
| Supabase tabloları `friendships`, `friend_requests`, `blocks` | Arkadaşlık verisi (Faz 3.2'den, değişmedi) | Hayır |
| Supabase işlevleri (migration `20261117160000_phase5_social.sql`) | `search_players`, `send_friend_request`, `respond_friend_request`, `cancel_friend_request`, `remove_friend`, `block_player`, `unblock_player`, `my_friends`, `my_friend_requests`, `my_blocks`, `get_player_profile` (oyuncu **JWT'den**: `auth.uid()`); sunucu için `game.social_check`, `game.friend_ids` (yalnızca `game_server`) | Evet |
| **SocialHub** Durable Object (`/v1/hub`) | Arkadaşların canlı durumu (yalnızca arkadaşlara itilir), içeriksiz "değişti" bildirimleri, maç davetleri, oda dizini, oyuncunun hangi oda / maçta olduğu, oda kodu deneme sınırı | Evet |
| **PrivateRoom** Durable Object (`/v1/room/<kod>`) | Lobi: üyeler, renkler, hazır, oda sahibi, başlatma, ayrılma, zaman aşımı | Evet |
| **MatchRoom** | Özel odanın maçı da burada (`mode: "private"`): aynı motor, sunucu zarı, protokol, yeniden bağlanma, Faz 4 kaydı. Yeni: maç başında / sonunda oyuncuların durumunu hub'a, maç sonunu odaya bildirir. | Hayır (küçük ek) |
| Godot | `OnlineSocial`, `OnlineHub`, `OnlineRoom` servisleri ve 7 ekran. Maç ekranı **aynı** (`MatchScreen` + `OnlineMatchController`). | Evet |

- **Çevrimiçi durum için seçilen yol (K-64):** Supabase Realtime yerine oyun sunucusundaki SocialHub.
  - Durum sürekli sorgulanmıyor, olay olunca itiliyor.
  - JWT doğrulaması ve hız sınırı oyun sunucusuyla aynı.
  - Godot için ayrı bir Realtime (Phoenix) istemcisi gerekmedi.
- **Mimari belgeden sapma:** Belgede odanın aynı nesnede maça "dönüşmesi" planlanmıştı. Bunun yerine oda yeni bir MatchRoom oluşturuyor; böylece MatchRoom değişmeden yeniden kullanılıyor. `ONLINE_ARCHITECTURE.md` güncellendi.

## 2. Arkadaş sistemi

- **Arama:**
  - "Ayşe" ad başlangıcıyla arar; "Ayşe#1234" etiketle tam eşleşme arar. En çok 20 sonuç; `%` ve `_` karakterleri kaçışlanır.
  - Kendi hesabı ve engel olan oyuncular (iki yönde de) sonuçlarda hiç görünmez.
- **İstekler:**
  - Aynı kişiye ikinci istek → `ALREADY_PENDING`; arkadaşa istek → `ALREADY_FRIENDS`.
  - Karşı taraf zaten istek göndermişse yeni istek kabul sayılır.
  - Eşzamanlı istekler oyuncu çifti başına kilitle sıraya girer.
  - Sınırlar: 200 arkadaş, 50 bekleyen giden istek.
- **Engelleme:**
  - Arkadaşlığı ve bekleyen istekleri iki yönde kaldırır; arama, profil, istek ve davetleri engeller.
  - Kimin kimi engellediği görünmez (iki yön de `NOT_ALLOWED` / `NOT_FOUND`).
- **Profil:** ad#etiket, avatar, çevrimiçi toplamlar, ilişki, arkadaşlık tarihi; durum yalnızca arkadaşlara.
- **Canlılık:** İstek, kabul ve silme sonrası karşı tarafa içeriksiz bir bildirim gider. Karşı taraf veriyi RLS ile Supabase'ten yeniden okur, yani bildirim veri taşımaz.

## 3. Davetler

- Davet yalnızca odadaki oyuncudan arkadaşına gönderilebilir, aradaki engel olmamalı ve oda lobi aşamasında, dolmamış olmalı.
- Davet 120 saniye geçerli. Süre dolunda iki tarafa da "süresi doldu" bildirilir (sunucu alarmı).
- Aynı kişiye aynı oda için ikinci davet yeni davet oluşturmaz. Kabul bir kez işlenir; tekrar kabul aynı yanıtı döner.
- Davet edilen başka bir odadaysa `ALREADY_IN_ROOM`, maçtaysa `IN_MATCH` döner.
- Ana menüde "Davetler" kartı canlı sayaçla gösteriliyor. Davet gelince kısa titreşim var.

## 4. Özel odalar

| Konu | Uygulama |
|---|---|
| Kod | 6 karakter, karışabilen harf/rakam yok (31 karakter, ~8,9×10⁸ kod); sunucuda `crypto.getRandomValues` ile, modulo yanlılığı olmadan üretiliyor |
| Deneme sınırı | Oyuncu başına 10 dakikada 8 yanlış kod; sonrasında doğru kod da reddedilir (`RATE_LIMITED`) |
| Katılma | Kodla ya da davetle; dolu oda, oynanan oda, başka oda / maç kontrolleri sunucuda |
| 2 kişi | Katılan, oda sahibinin karşı rengini alır. İki oyuncu da renk seçebilir; diğeri karşı renge geçer ve iki "hazır" sıfırlanır (K-08; K-57 onayı bekliyor). Kırmızı–sarı / yeşil–mavi dışında çift oluşamaz. |
| 4 kişi | Her oyuncu boş bir renk seçer; alınmış renk `COLOR_TAKEN` |
| Başlatma | Yalnızca oda sahibi (`NOT_HOST`); oda dolu olmalı (`ROOM_NOT_FULL`); diğer herkes hazır olmalı (`NOT_READY`) |
| Koltuklar | Tahta sırasına göre (kırmızı, yeşil, sarı, mavi); her oyuncu kendi rengini sol altta görür (mevcut maç ekranı) |
| Ayrılma | Lobiden ayrılan çıkar. Oda sahibi ayrılırsa ilk katılan kalan oyuncu sahip olur (K-71). Boş oda kapanır, kodu geçersizleşir. |
| Kopma | Lobide 2 dakika içinde dönen oyuncu yerini korur; maçta mevcut yeniden bağlanma geçerli |
| Zaman aşımı | 30 dakika hareketsiz lobi kapanır |
| Maç sonrası | Oda yeniden lobi olur ("tekrar oyna"); maç ekranındaki "tekrar oyna" ve "çık" lobiye döner |

## 5. Güvenlik

- Kimlik her yerde JWT'den alınıyor: Supabase'te `auth.uid()`, sunucuda doğrulanmış `sub`. İstemcinin "kim olduğum" bilgisi hiçbir yerde kullanılmıyor.
- İstemci arkadaşlık, istek ve engel tablolarına doğrudan yazamıyor (SQL testinde `insufficient_privilege`).
- Oda sahipliği, üyelik, renk, hazır durumu ve başlatma yalnızca PrivateRoom'da değişiyor. Maça yalnızca koltukta oturan kullanıcılar bağlanabiliyor (mevcut MatchRoom kuralı).
- Zar ve sonuç yine yalnızca sunucuda. İstemci koltuk, zar ya da sonuç gönderemiyor; protokol bilinmeyen alanları reddediyor.
- Davet ve kod denemeleri tekrar işlenmiyor ve hız sınırına tabi. Her WebSocket bağlantısı için mesaj hız sınırı var.
- **Faz 4 commit'inden sonra güvenlik incelemesinin bulduğu iki sorun düzeltildi:**
  - Geliştirme rotasında başka bir oyuncuyu onu olmadan test maçına koymak artık mümkün değil; her insan koltuğu kendi JWT'siyle onay vermeli.
  - Eşleştiricide bir oyuncunun beklerken iki kez eşleşmesine yol açan yarış koşulu giderildi.

## 6. Testler

### 6.1 Gerçek bulut (Supabase + Cloudflare)

| Test | Sonuç | Kapsam |
|---|---|---|
| `supabase/tests/phase5_test.sql` (yeni) | **31 / 31** | Arama ve etiket, joker karakter kaçışı, kendine istek, çift istek, ilişki, gönderenin kabul edememesi, doğrudan yazma yasağı, kabul / ret / iptal, karşılıklı istek, silme, engelleme etkileri (arama, istek, profil, gizlilik), engel kaldırma, `game_server` işlevleri, istemci / anonim yetkisizliği |
| `server/worker/test/social_room_test.mjs --remote` (yeni) | **58 / 58** | §0'daki bütün oda, davet, durum ve kayıt senaryoları (5 gerçek misafir hesap) |
| `godot_online_test.mjs --remote` | **2 / 2 geçti** | Hızlı eşleşme maçı (Faz 4 kontrolleriyle) **ve** yeni özel oda testi |
| `phase4_test.sql` | 35 / 35 | Bu fazda gerileme yok (Faz 4 kapanışında) |
| `rls_economy_test.sql` | 61 / 61 | Bu fazda gerileme yok (Faz 4 kapanışında) |
| `api_e2e_test.mjs` | 26 / 26 | Bu fazda gerileme yok (Faz 4 kapanışında) |

Yeni Godot özel oda testinde iki gerçek Godot istemcisi şu adımları geçti:
- Supabase üzerinden arkadaş oldular; istek karşı tarafa canlı ulaştı.
- Birbirlerini çevrimiçi ve "odada" gördüler.
- A davet etti, B kabul edip odaya girdi.
- Renk değişince karşı renge geçiş oldu; hazır olunmadan başlatma reddedildi.
- Başlatılan aynı maç oynandı ve bitti, kayıt bildirimi geldi.
- Oda yeniden lobi oldu; A'nın geçmişinde `private` maç göründü ve galibiyeti sayıldı.

### 6.2 Yerel

| Test | Sonuç |
|---|---|
| TS kural motoru | **85 / 85** |
| Godot birim + sahne | **36 / 36** (yeni: 7 sosyal / oda ekranının çevrimdışı açılması, oda kodu biçimi) |
| Worker yerel (`local_ws_test.mjs`) | **26 / 26** (yeni: başkasını onaysız maça koyamama) |
| Oda testi yerel (`social_room_test.mjs`, veritabanısız) | **32 / 32** (arkadaş, durum ve davet bölümleri veritabanı istediği için yalnızca bulutta) |
| Godot çevrimiçi (yerel sunucu) | **2 / 2** |
| `tsc --noEmit` | Temiz |

### 6.3 Bulutta yeniden çalıştırılamayan test

- `local_ws_test.mjs --remote` (onay kontrolü ve eşleştirici düzeltmesiyle) bu fazın sonunda başlatıldı. Ancak **Supabase'in IP başına saatte 30 anonim kayıt sınırına** takıldı (`guest sign-in failed (429)`); gün içindeki testler bu sınırı doldurmuştu.
- Sınır dolduğu için bu test bulutta **yeniden çalıştırılamadı**; iki kez denendi, ikisinde de 429 döndü.
- Bu iki değişiklik yerelde test edildi (26/26). Eşleştirici düzeltmesi bulutta dolaylı olarak çalıştı: hızlı eşleşme bulut Godot testinden geçti.
- Onay kontrolünün bulut sonucu yok; sınır sıfırlanınca `local_ws_test.mjs --remote` yeniden çalıştırılmalı.
- Not: Gerçek kullanıcılar farklı IP'lerden geldiği için bu sınır oyunculara değil, tek bilgisayardan çok sayıda test hesabı açmaya etki ediyor.

## 7. Arayüz

Ekran görüntüleri: `docs/phase5_screens/`. 53–57 numaralı görüntüler ekran turunda enjekte edilen **örnek** satırlarla çekildi; uygulama sahte veri göstermez.

| Ekran | Not |
|---|---|
| Arkadaşlar (alt sekme) | Oyuncu Ara, İstekler (sayaç), Davetler (sayaç), durum sırasına göre arkadaşlar, lobideyken "Davet et" |
| Oyuncu Ara | Ad / ad#etiket; satırda ilişkiye göre Ekle / Kabul et |
| İstekler | Gelen (kabul / reddet), gönderilen (iptal), engellenenler (engeli kaldır) |
| Oyuncu profili | Durum, toplamlar, ilişkiye göre ekle / kabul / çıkar / engelle / odama davet et |
| Davetler | Canlı liste, geri sayım, Katıl / Reddet, süresi doldu |
| Özel Oda | 2 / 4 kişilik oluştur, kodla katıl, "odaya dön" |
| Oda lobisi | Büyük kod + kopyala, oyuncular (renk, oda sahibi, hazır, bağlantı koptu), boş koltuklar, renk seçimi, çevrimiçi arkadaşları davet, ayrıl, Hazırım / Maçı başlat |

Her ekranda yükleniyor, bağlantı hatası (tekrar dene), boş liste ve davet süresi doldu durumları var. Ana menüde Özel Oda ve Davetler kartı, alt sekmede Arkadaşlar artık gerçek ekranlara gidiyor; mod seçiminde Özel oda açıldı.

## 8. Ücretsiz plan kullanımı

Kullanım ölçülmedi; aşağıdaki değerler kod akışından hesaplandı.

- **Ücretli bir şey açılmadı.** Yeni Durable Object sınıfları ücretsiz planın SQLite DO'ları.
- **Özel oda başına:** Oda oluşturma ve başlatma birkaç DO isteği. Lobide her eylem bir mesaj; tipik bir lobi 10–30 mesaj.
- **Maç:** Mevcut MatchRoom yükü, Faz 3.4'teki ölçümlerle aynı.
- **Hub:**
  - Oturum başına bir bağlantı.
  - Çevrimiçi durum yalnızca bağlanma, kopma ve oda / maç değişince gönderiliyor.
  - Boşta bağlantılar uykuda (hibernation); WebSocket ping'lerini çalışma ortamı yanıtlıyor.
- **Supabase:** Arkadaş işlemleri tek RPC.
  - Hyperdrive sorguları: hub bağlantısı başına 1 (arkadaş listesi), davet başına 2–3, oda üyesi başına 1 (ad kartı).
  - Günlük 100.000 sorgu sınırının çok altında.
- **Bu testlerde görülen tek sınır:** Supabase anonim kayıt sınırı (§6.3).
- **Herkese açık test öncesi:** Cloudflare Workers Paid önerisi (K-58) aynen geçerli. Tek hub ileride kullanıcı kimliğine göre bölünmeli.

## 9. Git

- Faz 4: `34050a8` (feat: complete persistent player profiles and match history).
- Faz 5: ayrı commit (SHA bu raporun commit'inde; kullanıcıya iletildi). Push yapılmadı.

## 10. Açık konular

- **K-57:** 2 kişilik odada iki oyuncunun da renk seçebilmesi uygulandı; onay bekliyor.
- **K-71:** Oda sahibi ayrılınca ilk katılan sahip oluyor; onay bekliyor.
- **K-72 / K-73:** Davet süresi ve sınırları ile kod deneme sınırı; onay bekliyor.
- **Gerçek cihaz:** İki telefonla arkadaş ekleme, davet ve özel oda maçı.
- **4 kişilik özel oda gerçek cihazda:** Dört telefon gerekiyor. Sunucuda 4 Node istemcisiyle doğrulandı; dört Godot istemcisiyle tam maç denenmedi.
- 4 kişilik **hızlı eşleşme** kapsam dışı kaldı (yalnızca özel odada 4 kişi var).
