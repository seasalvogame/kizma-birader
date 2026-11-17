# Faz 4 Raporu — Kalıcı Oyuncu Hesapları, Maç Geçmişi ve İstatistikler

> **Tarih:** 2026-11-17
> **Sürüm:** 0.5.0 (Android versionCode 5)
> **APK:** `build/android/KizmaBirader-0.5.0-debug.apk` (29,3 MB; SHA-256 `2e8f3beae57d5c1c7034cc461de719ac5196f0889dd3be373ddb9d95672ed352`; izinler INTERNET, VIBRATE)
> **Sunucu:** https://kizmabirader-game-dev.kizmabirader.workers.dev (Cloudflare, ücretsiz plan) + Supabase `kizmabirader-dev` (Free) + Cloudflare Hyperdrive (ücretsiz)
> **Git:** Faz 3.4 ve Faz 4 değişiklikleri **henüz commit edilmedi** (onayını bekliyor). Push yapılmadı.
> **Gerçek cihaz:** 0.5.0 telefonda **denenmedi**. Aşağıdaki "bulutta doğrulandı" satırları masaüstündeki Godot istemcisi ve test betikleriyle gerçek buluta karşı yapıldı.

## 0. Özet

| Durum | Özellik |
|---|---|
| ✅ Tamam, bulutta doğrulandı | Sunucunun maç sonucunu Supabase'e yazması (kısıtlı `game_server` rolü, Hyperdrive), tekrar yazmama, istatistiklerin bir kez artması, maç geçmişi ve ayrıntısı, profil adı/avatarı (sunucu doğrulamalı), başkasının verisini değiştirememe, istemcinin sonuç/istatistik yazamaması, misafir hesabın uygulama yeniden açılınca korunması |
| ✅ Tamam, yerelde doğrulandı | Profil / Maç Geçmişi / Maç Ayrıntısı / Hesap ekranları (yükleniyor, hata, çevrimdışı, boş durumlar), çevrimdışı önbellek, oturum dosyasının yeniden okunması |
| 🟡 Kod hazır, uçtan uca denenmedi | Misafiri **e-postayla** kalıcı yapma (doğrulama bağlantısı → "Kontrol et" → parola) ve e-postayla giriş. Supabase'in yerleşik e-postası yalnızca kuruluş üyelerine gönderiyor → **senin kendi adresinle** denenmeli (§6). |
| ⛔ Hesap bilgisi gerektiği için yapılmadı | Google ve Apple ile bağlama (kod hazır, düğmeler "bu sürümde yok" diye kapalı), üretim SMTP, iOS derlemesi (Mac + Apple Developer) |
| Kapsam dışı (dokunulmadı) | Altın/Elmas ekonomisi, satın alma, reklam, mağaza, arkadaşlar, özel oda, 4 kişilik çevrimiçi. Altınlı maçlar kapalı (`gold_matches_enabled = false`). |

## 1. Sunucu ↔ Supabase bağlantısı (A)

- **Rol:** `game_server` (LOGIN, en fazla 20 bağlantı). Yalnızca iki SECURITY DEFINER işlevini çalıştırabilir:
  - `game.record_match(...)`: biten maçı tek işlemde yazar.
  - `game.player_names(ids)`: eşleşmede adları okur, en fazla 4 kimlik.
- **Tablolara doğrudan erişimi yok.** SQL testi ve kurulum betiği bunu doğruladı.
- **Service Role anahtarı hiçbir yerde kullanılmıyor.** İstemcide yalnızca herkese açık publishable anahtar var.
- **Parola:** Kurulum betiği `server/worker/scripts/setup_game_server_db.mjs` parolayı bellekte üretir.
  - Supabase'e yalnızca SCRAM-SHA-256 özeti gider.
  - Parola Hyperdrive yapılandırmasında durur: Git'te, istemcide ve Worker değişkenlerinde yok.
  - Betiği kullanıcı kendi terminalinde çalıştırdı; parola sohbete hiç gelmedi.
- **Neden Hyperdrive (sorun ve çözüm):**
  - İlk tasarım Worker'dan doğrudan TCP + TLS bağlantısıydı.
  - Supabase veritabanı sertifikaları kendi kök CA'sıyla ("Supabase Root 2021 CA") imzalı. Workers TCP soketleri yalnızca genel CA'lara güveniyor.
  - Sonuç: yerelde `TLS handshake failed: UnknownIssuer`; bulutta yeniden deneme döngüsü yüzünden "Too many subrequests".
  - Çözüm Cloudflare Hyperdrive (Free planda var, günde 100.000 sorgu):
    - doğrudan bağlantı;
    - **önbellek kapalı** (kayıt çağrısı da bir `select`);
    - kaynak bağlantı sınırı 5.
  - Bulutta ölçülen gidiş-dönüş: ~100 ms.
  - Sunucu veritabanına yalnızca maç başında ve sonunda gidiyor, hamle başına gitmiyor.
- **Not:** Betiğin son adımı ("4/4", bilgisayardan havuzlayıcı üzerinden bağlantı testi) "password authentication failed" verdi.
  - Hyperdrive oluşturulurken doğrudan bağlantıyla aynı parolayı doğruladı.
  - Bulut testleri de bu yoldan geçti.
  - Muhtemel neden: Supabase havuzlayıcısının kimlik önbelleği.
  - Worker bu yolu kullanmadığı için oyunu etkilemiyor.
- Yeni geliştirme rotası: `GET /v1/health?db=1`, yalnızca `ALLOW_DEV_ROUTES` açıkken, tek gidiş-dönüşle veritabanı yolunu kontrol eder.

## 2. Maç kayıtları ve istatistikler (B, C)

- **Kim yazar:**
  - Yalnızca oyun sunucusu (Durable Object), oyun bittiğinde kendi doğruladığı durumdan.
  - İstemci hiçbir sonuç göndermez; tablolara yazamaz (REST testinde 403/404).
- **Kayıt içeriği:**

  | Tablo | Alanlar |
  |---|---|
  | `matches` | id, tür (`quick` / `private` / `test`), oyuncu sayısı, kural seti, başlangıç ve bitiş, bitiş nedeni (`finished` / `left`), durum `finished`, sunucu sürümü (Cloudflare sürüm kimliği), protokol sürümü, hamle sayısı, son durumun FNV-1a özeti |
  | `match_players` | koltuk, renk, sıra (1..n, benzersiz), kullanıcı / bot, ayrıldı mı, o anki `ad#etiket` |

  Süre, bitiş eksi başlangıç olarak hesaplanır. Hamle günlüğü sunucuda tutulur.
- **İki kez yazılmaz:**
  - Kayıt kimliği maç oluşurken sabitlenir (`db_id`).
  - `record_match` aynı kimliği ikinci kez görürse hiçbir şey yazmaz.
  - Durable Object önce "bekliyor" durumunu kaydeder, sonra yazar. Hata olursa alarmla yeniden dener: 2 sn, 4 sn … en çok 30 dk; 40 deneme.
  - Böylece kopma, yeniden başlatma ya da yeni sürüm dağıtımında kayıt kaybolmaz ve çift yazılmaz.
- **İstatistik:**
  - `player_stats` aynı işlemde güncellenir: 2P/4P maç ve galibiyet, ayrılma, son maç zamanı.
  - Test maçları (`mode = 'test'`) kaydedilir ama **istatistiğe sayılmaz**.
  - Çevrimdışı (bot/pratik) maçlar sunucuya hiç gitmez; profilde ayrı bölümde, yalnızca bu cihazda gösterilir.
- **4 kişilik:** Motor oyun sonunda bütün sıraları doldurur (üç oyuncu bitirince dördüncü son sıra; ayrılanlar en sona). Kayıt işlevi 1..4 sıranın eksiksiz ve benzersiz olmasını şart koşar.
- **Doğrulama:** Geçersiz sonuç hiçbir şey yazmadan reddedilir: aynı sıra iki kez (`BAD_RANKS`), 2 kişide karşılıklı olmayan renk (`COLOR_INVALID`), bilinmeyen oyuncu (`UNKNOWN_PLAYER`).
- **Eşleşmede adlar:** Sunucu sıra arkadaşının adını istemcinin gönderdiği metinden değil, veritabanındaki profilden alır. Veritabanına ulaşılamazsa eski davranışa düşer.

## 3. Profil (D) ve ekranlar (F)

Ekran görüntüleri: `docs/phase4_screens/`. 43–45 numaralı görüntüler yalnızca ekran turunda enjekte edilen **örnek** satırlarla çekildi; uygulama sahte veri göstermez.

| Ekran | İçerik |
|---|---|
| **Profil** | `ad#etiket`, avatar, hesap durumu çipi; çevrimiçi istatistikler (maç, galibiyet, mağlubiyet, kazanma %, 2P/4P); son 5 maç ve "Tüm maçlar"; ad ve avatar rengi (sunucuya kaydedilir); bu cihazın pratik istatistikleri (ayrı); Hesap ve Güvenlik kartı. Çevrimdışıyken son bilinen veri "Çevrimdışı · son bilinen bilgiler" uyarısıyla gösterilir; düzenleme kapalı. |
| **Maç Geçmişi** | Biten çevrimiçi maçlar, yeniden eskiye, 20'şer sayfa. Yükleniyor / hata / boş ("İlk maçını oyna") durumları. |
| **Maç Ayrıntısı** | Sıralama (oyuncu, renk, "Sen", ayrıldı), süre, bitiş nedeni, hamle sayısı, maç ve sunucu sürümü kimlikleri. |
| **Hesap ve Güvenlik** | Durum, e-postayla koruma, "Kontrol et", parola, Google/Apple (kapalı), başka hesapla giriş, çıkış (yalnızca kalıcı hesapta). |
| **Maç sonu** | Sunucu kaydedince "Maç geçmişine kaydedildi ✓"; profil yeniden yüklenir. Maç akışında başka değişiklik yok. |

- **Ad kuralı:** Veritabanında `update_my_profile` ile denetlenir; istemcide de aynısı var.
  - 3–16 karakter; her dilden harf ve rakam, boşluk, `_ . -`.
  - Harf ya da rakamla başlayıp biter; çift boşluk yok.
  - Türkçe harfler çalışıyor.
  - Aynı `ad#etiket` başka birinde varsa yeni etiket seçilir.
- **Avatar:** `fill:0` … `fill:5` dışında bir değer reddedilir.
- **Başkasını düzenleme:** RLS ve yetkiler doğrudan `PATCH`'i reddeder (403). İşlev yalnızca `auth.uid()` satırını değiştirir.
- **Çevrimdışı oyunla bağlantı:** Sunucudaki ad ve avatar, çevrimdışı maçlar için yerel ayarlara aynalanır. Hesap açılmadan önce seçilmiş yerel ad, sunucudaki ad hâlâ varsayılan "Oyuncu" ise bir kez sunucuya taşınır.

## 4. Misafir → kalıcı hesap (E)

- **E-posta:**
  - `PUT /auth/v1/user {email}` doğrulama bağlantısı gönderir. Bağlantı Worker'daki sabit "doğrulandı" sayfasına döner (`/auth/confirmed`; URL'deki belirteçleri okumaz).
  - Oyuncu uygulamada "Kontrol et"e basar, sonra parola belirler (en az 8 karakter; Supabase ayarı da 8 yapıldı).
  - **Kullanıcı kimliği değişmez** → profil, istatistik ve maç geçmişi aynen kalır.
- **Çakışma:** E-posta başka bir hesaba aitse `EMAIL_TAKEN` → "Bu e-posta başka bir hesaba ait; hesaplar birleştirilmez, aşağıdan giriş yapabilirsin."
- **Yarım kalan bağlama:** Hesap misafir kalır, bekleyen e-posta gösterilir; hiçbir veri kaybolmaz.
- **Başka hesapla giriş:** Yalnızca başarılı girişten sonra oturum değişir. Misafir için "geri dönemezsin" uyarısı var.
- **Oturum reddedilirse:** Hesap sessizce yeni misafirle **değiştirilmez** (`SESSION_EXPIRED`); oyuncu seçer.
- **Uygulama yeniden açılınca:** Yenileme belirteci ve hesap özeti `user://online_session.cfg`'de durur; kısa ömürlü erişim belirteci yalnızca bellekte. Bulut testinde doğrulandı (yeni oturum nesnesi → aynı kullanıcı).
- **Google / Apple:** `OnlineSession.link_id_token()` hazır (`grant_type=id_token` + `link_identity`).
  - Yerel giriş eklentisi ve sağlayıcı ayarları olmadığı için **denenmedi**.
  - Bu REST biçimi supabase-flutter'ın `linkIdentityWithIdToken` uygulamasından alındı ve doğrulanması gerekiyor.
  - Panel adımları: `docs/setup/SUPABASE_SETUP.md` §6.

## 5. Testler

### 5.1 Gerçek bulut (Supabase + Cloudflare)

| Test | Sonuç | Kapsam |
|---|---|---|
| `supabase/tests/phase4_test.sql` (yeni; tek işlem, geri alınır) | **35 / 35** | Profil güncelleme ve ad kuralları, başkasını düzenleyememe, etiket çakışması, anonim erişim yok; istemci kayıt/maç/istatistik yazamaz; `record_match` bir kez yazar, ikinci çağrı yazmaz; istatistik doğru ve bir kez; test maçı sayılmaz; geçersiz sonuçlar yazılmadan reddedilir; 4P + bot; RLS ile yalnızca kendi maçları; `game_server` tablo okuyamaz ve profil düzenleyemez |
| `supabase/tests/rls_economy_test.sql` (Faz 3.2) | **61 / 61** | Gerileme yok |
| `supabase/tests/api_e2e_test.mjs` | **26 / 26** (11 yeni) | Gerçek REST: ad değiştirme (Türkçe), `NAME_INVALID`, başkasının profiline PATCH 403, kendi profiline doğrudan PATCH 403, `record_match` istemciden erişilemez (404), maç ekleme 403, istatistik değiştirme 403, yalnızca kendi istatistikleri ve maçları, sahte imzalı JWT reddi |
| `server/worker/test/local_ws_test.mjs --remote` | **30 / 30** (5 yeni) | Faz 3.4'ün 25 kontrolü (gerçek DO yeniden başlatması dahil) + `match.recorded`, satır `finished`, iki koltuk ve 1/2 sırası, hamle sayısı = sunucu sırası, durum özeti, sunucu sürümü, test maçı istatistiğe sayılmadı |
| `server/worker/test/godot_online_test.mjs --remote` | **Geçti** | İki gerçek Godot istemcisi buluttaki kuyrukta eşleşti, A gerçek maç ekranından oynadı (294 hamle), kopma ve yeniden bağlanma; **ikisi de `match.recorded` aldı**; ikisi için de profil, istatistik ve geçmiş Supabase'ten okundu (1 maç; galibiyet yalnızca kazanana; geçmişteki satır kaydedilen maç; kendi sırası doğru); ad ve avatar sunucuya kaydedildi; uygulama yeniden açılınca aynı hesapla yeniden giriş |

Testlerin açtığı bütün misafir hesaplar ve maç kayıtları test sonunda silindi (bulutta 0 maç kaldı).

### 5.2 Yerel

| Test | Sonuç |
|---|---|
| TS kural motoru (`npm test`) | **85 / 85** |
| Godot birim + sahne (`test_runner.tscn`) | **35 / 35** (3 yeni: profil çevrimdışı durumu, sunucu verisiyle profil/geçmiş/ayrıntı/hesap ekranları, oturumun yeniden okunması + Auth hata eşlemesi) |
| Worker yerel (`wrangler dev`, veritabanısız) | **25 / 25** |
| `tsc --noEmit` | Temiz |

### 5.3 Testte bulunan ve düzeltilen sorunlar

- **Test izolasyonu:**
  - Godot birim/sahne testleri profil ekranını açınca gerçek Supabase'e bağlanıp misafir hesap açabiliyordu ve bilgisayardaki oyun ayar dosyasına yazıyordu.
  - Bir kez oldu; o hesap ve yerel dosyalar silindi.
  - Artık çevrimdışı testler ağa hiç çıkmıyor (`OnlineConfig.force_offline`) ve kendi dosyalarını kullanıyor (`user://test_run/`). Ekran turu da varsayılan olarak çevrimdışı.
- **TLS ve Hyperdrive:** §1.
- **`uuid[]` parametresi:** `fetch_types: false` ile postgres.js boş diziyi `""` olarak gönderiyordu → Postgres dizi biçimiyle gönderiliyor.
- **Arayüz:** Durum kartı simgesi boş kare çiziyordu (TextureRect'e geçildi); maç satırının üçüncü satırı kırpılıyordu.

## 6. Senden gerekenler

1. **E-posta bağlamayı kendi adresinle dene** (APK 0.5.0, telefonda):
   - Profil → Hesap ve Güvenlik → e-posta → bağlantıya dokun → uygulamada "Kontrol et" → parola.
   - Supabase'in yerleşik e-postası yalnızca kuruluş üyelerine gönderiyor ve saatte birkaç e-postayla sınırlı.
2. **Üretim SMTP** (mağazadan önce): sağlayıcı seçimi; ücretli olabilir, onayın gerekir.
3. **Google:**
   - Google Cloud'da OAuth istemcileri: Web ve Android (paket adı + debug/yayın SHA-1);
   - Supabase'te Google sağlayıcısı;
   - Godot için yerel giriş eklentisi seçimi.
4. **Apple / iOS:** Mac + Apple Developer üyeliği (ücretli; onayın olmadan açılmaz). Bkz. `docs/setup/IOS_SETUP.md`.
5. **Gerçek cihaz testi:**
   - 0.5.0'ı iki telefonda: çevrimiçi maç → "kaydedildi" bildirimi → Profil'de istatistik ve geçmiş;
   - uygulamayı kapatıp açınca aynı hesap.
6. **Commit onayı** (§8).

## 7. Açık konular

- **K-65:** Bulutta kaynağı belirsiz 3 misafir hesap var (05:34, 06:19, 09:53 UTC; maç kaydı yok). Telefonun ya da önceki ekran turunun olabilir; dokunulmadı. Eski misafirlerin temizliği kararı yayından önce verilecek.
- **K-67 (yeni):** Uygunsuz ad denetimi. Şimdilik yalnızca biçim kuralı var; mağazadan önce yasaklı kelime listesi öneriliyor.
- **K-68 (yeni):** E-posta doğrulamasından sonra uygulamaya derin bağlantıyla dönüş (App Links).
- **Oturum saklama:** Yenileme belirteci uygulamanın özel klasöründe duruyor; mağazadan önce Android Keystore / iOS Keychain'e taşınmalı.
- Profil istatistiklerinde sıralama puanı ve seviye yok (kapsam dışı).

## 8. Değişen ve yeni dosyalar

**Supabase**
- `supabase/migrations/20261117140000_phase4_match_records_profiles.sql` (bulutta uygulandı)
- `supabase/tests/phase4_test.sql` (yeni)
- `supabase/tests/api_e2e_test.mjs`
- `supabase/config.toml` (doğrulama dönüş adresi, parola ≥ 8; kullanıcı `config push` ile uyguladı)

**Worker**
- `src/db.ts` (yeni), `src/match_room.ts`, `src/matchmaker.ts`, `src/index.ts`
- `wrangler.jsonc`: `nodejs_compat`, sürüm bilgisi, Hyperdrive bağlaması
- `package.json`: `postgres` bağımlılığı
- `scripts/setup_game_server_db.mjs` (yeni)
- `test/local_ws_test.mjs`, `test/godot_online_test.mjs`

**İstemci**
- `scripts/online/`: `online_session.gd`, `online_api.gd` (yeni), `online_profile.gd` (yeni), `online_config.gd`, `online_match_connection.gd`
- `scripts/game/online_match_controller.gd`
- `scripts/app/`: `online.gd`, `main.gd`, `settings.gd`
- `scripts/ui/`: `match_row.gd` (yeni), `status_card.gd` (yeni)
- `scripts/ui/screens/`: `profile_screen.gd` (yeniden yazıldı), `match_history_screen.gd`, `match_detail_screen.gd`, `account_screen.gd` (yeni), `match_screen.gd`, `online_queue_screen.gd`
- `tools/make_translations.py` (+77 anahtar, toplam 248)
- `tests/`: `test_runner.gd`, `scene/test_app_navigation.gd`, `online/test_online_match.gd`, `visual/screenshot_tour.gd`
- `project.godot`, `export_presets.cfg` (0.5.0)

**Belgeler**
- `docs/setup/SUPABASE_SETUP.md`, `docs/setup/IOS_SETUP.md` (yeni)
- `docs/DECISIONS_AND_OPEN_QUESTIONS.md` (K-59 Hyperdrive kesinleşti; K-67, K-68)
- `docs/phase4_screens/`, `README.md`, bu rapor

**Commit:** Faz 3.4 + Faz 4 için ikinci bir commit önerilir. `.gitignore` gizli dosyaları (`.dev.vars`, `supabase/.temp/`) ve APK'ları zaten dışarıda tutuyor. Onay verirsen yapacağım; push yapılmayacak.
