# Faz 6 Kapanış Raporu — Oyuncu İlerlemesi, Görevler ve Ödül Sistemleri

> **Tarih:** 2026-11-17 · **Sürüm:** 0.7.0 (versionCode 8)
> **APK:** `build/android/KizmaBirader-0.7.0-debug.apk` (29,4 MB; SHA-256 `404de29081bda3741967e9aeeff877f0fdc80f362fbb3432fbbe1c5c83ca55bc`; izinler INTERNET, VIBRATE)
> **Sunucu:** Cloudflare Worker (zamanlanmış tetikleyici `7 * * * *`) + Supabase `kizmabirader-dev` + Hyperdrive — hepsi ücretsiz plan; ücretli hizmet açılmadı.
> **Kurallar ve sayılar:** [docs/economy/PROGRESSION_SYSTEMS.md](docs/economy/PROGRESSION_SYSTEMS.md) (sıralama puanının nasıl kazanıldığı §5'te).
> **Gerçek cihaz:** 0.7.0 telefonda **denenmedi**.

## 0. Başlangıçtaki altyapı ve plan (A)

**Zaten vardı ve kullanıldı:**
- `profiles.level` ve `profiles.xp` sütunları (o ana kadar kullanılmıyordu).
- Cüzdan defteri `game._apply`:
  - idempotent;
  - negatif bakiyeye izin vermiyor;
  - gerekçe listesinde `daily_login`, `quest`, `achievement` ve `level_up` hazırdı.
- Maç kayıt işlevi `game.record_match`.
- Faz 1 tasarımı `ECONOMY_AND_PROGRESSION.md`: XP eğrisi, maç XP'si, 7 günlük giriş, görevler, başarımlar, sıralama önerisi.

**Eksikti, eklendi:**
- XP defteri, kilitler / rozetler, görev, giriş, başarım ve sıralama tabloları.
- Merkezi yapılandırma dosyaları.
- Maç sonucunu ilerlemeye bağlayan kanca.
- Ekranlar.

**Mimari kararı:** Bütün ilerleme, sunucunun maç sonucunu yazdığı **aynı Postgres işleminde** (`record_match` → `_after_match`) ve maç başına bir kez işlenir.
- Hamle ya da zar başına veritabanı sorgusu yok.
- Yeni sunucu ya da servis yok; mevcut Worker, DO ve Hyperdrive korunuyor.

## 1. Alt fazlar

| Alt faz | Commit | Yapılanlar |
|---|---|---|
| 6.1 XP ve seviye | `c8637f3` | Sıraya göre XP; seviye eğrisi ve sınırı; seviye ödülü (Altın + rozet); maç sonunda XP, seviye atlama kutlaması; profil ilerleme kartı; ana sayfada seviye çipi |
| 6.2 Görevler | `982faaa` | 3 günlük + 4 haftalık görev; sunucu ilerletir; tek seferlik toplama; eski dönemlerin toplanmamış ödülleri; görevler sekmesi; ödül kutlaması; sekme noktası |
| (güvenlik) | `982faaa`, `8b3e0ba` | Ödül kasma önlemleri (K-75); günlük XP sınırının eşzamanlılık kilidi |
| 6.3 Günlük giriş | `8b3e0ba` | 7 günlük döngü; sunucu saati; gün başına tek talep; gün kaçırma kuralı (K-74); 7. gün rozeti; açılışta panel |
| 6.4 Başarımlar | `ec31ffd` | 12 başarım; oyuncu sayaçları (eski maçlardan dolduruldu); tek seferlik ödül; rozetler ve profil rozeti seçimi |
| 6.5 Haftalık sıralama | `fdc04f0` | Sıraya göre puan; ilk 100 (sayfalı); kendi sıram; geçen hafta; otomatik ve idempotent hafta kapanışı ve ödüller (cron) |
| Kapanış | bu rapordaki commit | Bütün testler, belgeler, APK 0.7.0, test izolasyonu düzeltmesi |

**Değişen başlıca dosyalar:**
- **Migration'lar** (`supabase/migrations/`):
  - `20261118100000_phase6_1_xp_levels`
  - `…110000_phase6_2_quests`
  - `…120000_phase6_reward_guards`
  - `…130000_phase6_3_daily_login`
  - `…131000_phase6_cap_lock`
  - `…140000_phase6_4_achievements`
  - `…150000_phase6_5_leaderboard`
- **Yapılandırma:** `shared/config/{progression,quests,daily_login,achievements,leaderboard}_config.json`; araç `server/worker/scripts/progression_config.mjs`.
- **Worker:**
  - `src/match_room.ts`: koltuk sayaçları; XP ve puan sonucu `match.recorded`'a eklendi.
  - `src/db.ts`, `src/index.ts`: cron ve geliştirme rotası.
  - `wrangler.jsonc`: tetikleyici.
- **Godot:**
  - Servis: `online/online_progress.gd`.
  - Ekranlar: `quests_screen`, `achievements_screen`, `leaderboard_screen`.
  - Bileşenler: `celebration`, `xp_bar`, `daily_login_panel`.
  - Güncellenen ekranlar: profil, maç, ana sayfa, maç ayrıntısı, sekme çubuğu.
- **Testler:** `supabase/tests/phase6_test.sql`, `server/worker/test/progress_cloud_test.mjs`, test hesabı sıfırlaması (`test_accounts.mjs`).

**Veritabanı değişiklikleri:**
- Yeni tablolar:
  - `xp_events`, `player_unlocks`;
  - `player_quests`;
  - `player_login`, `login_claims`;
  - `player_counters`, `player_achievements`;
  - `leaderboard_weeks`, `leaderboard_scores`, `leaderboard_daily`, `leaderboard_rewards`.
- Yeni sütunlar:
  - `match_players`: `rolls`, `sixes`, `captures`, `finished`, `xp_gained`, `level_after`;
  - `profiles.badge_id`.
- Defter gerekçesine `leaderboard` eklendi.
- Bütün tablolarda RLS açık. İstemci yalnızca kendi satırlarını okur; yazma yetkisi yok.

## 2. Güvenlik

- **İstemci hiçbir ilerleme değerini değiştiremez:** XP, seviye, görev, giriş günü, başarım, sayaç ve sıralama puanı. Bu bulutta REST ile denendi (401 / 403).
- **İstemci sunucu işlevlerini çağıramaz:** `_grant_xp`, `_quest_add`, `leaderboard_maintenance` ve diğerleri.
- **Ödüller:**
  - Tek satır güncellemesi ve tekil anahtarla verilir; eşzamanlı isteklerde de bir kez.
  - Altın defterden ve idempotency anahtarıyla ödenir.
  - Bakiye negatife düşemez (defter kısıtı).
- **Sahte JWT ve başka oyuncunun JWT'si:** reddedildi (bulut testi).
- **Kısıtlı roller:** `game_server` yalnızca kayıt ve hafta kapanışı işlevlerini çalıştırır. Service Role anahtarı hiçbir yerde kullanılmıyor.
- **Faz sırasında otomatik güvenlik incelemesinin bulduğu iki sorun düzeltildi:**
  - Ödül kasma: biri hemen ayrılan iki hesap XP toplayabiliyordu → kısa maç kuralı ve günlük sınır.
  - Günlük XP sınırında yarış koşulu → oyuncu kilidi.
- **Bilinçli olarak kapalı kalanlar:** Altınlı maçlar, gerçek para satın alımı, Billing / IAP, reklam ve premium üyelik.

## 3. Test sonuçları (kapanış zinciri, 2026-11-17)

### 3.1 Gerçek bulut (Supabase + Cloudflare)

| Test | Sonuç | Kapsam |
|---|---|---|
| `phase6_test.sql` | **93 / 93** | Ayrıntılar aşağıda |
| `progress_cloud_test.mjs --remote` | **37 / 37** | Ayrıntılar aşağıda |
| `godot_online_test.mjs --remote` | **geçti** | Hızlı maç (XP 40 / 15, profil XP'si), özel oda (kısa maçın sayılmaması), test hesaplarıyla |
| `godot_room4_test.mjs --remote` | **8 / 8** | Dört ayrı Godot süreciyle tam 4 kişilik özel oda maçı; ilerleme kancası 4 kişiyle |
| `social_room_test.mjs --remote` | **58 / 58** | Gerileme yok |
| `local_ws_test.mjs --remote` | **31 / 31** | Gerileme yok |
| `security_cloud_test.mjs --remote` | **14 / 14** | Gerileme yok |
| `phase5_test.sql` / `phase4_test.sql` / `rls_economy_test.sql` | **31 / 35 / 61** | Gerileme yok |
| `api_e2e_test.mjs` | **26 / 26** | Gerileme yok |
| `progression_config.mjs --check` | **5 / 5 aynı** | Dosyalar ↔ veritabanı |

`phase6_test.sql` kapsamı:
- seviye eğrisi;
- maç XP'si (2P, 4P, özel oda, terk, test maçı, iki kez kayıt);
- seviye atlama ödülü ve rozeti; istemcinin yazamaması;
- TR gün ve hafta sınırları; görev ataması ve ilerlemesi; özel oda ve terk kuralları; görev ödülü bir kez; geçmiş dönem ödülü;
- kısa maç ve günlük XP sınırı;
- günlük giriş: seri, gün kaçırma, 7. gün, giriş görevi;
- başarımlar: seri, sosyal sayaç, tek seferlik toplama, rozet seçimi;
- sıralama: puanlar, özel oda / kısa maç, günlük sınır, sıra ve eşitlik, hafta kapanışı bir kez, ödül ve rozet, yetkisiz erişim.

`progress_cloud_test.mjs` kapsamı:
- iki test hesabı arasında **gerçek bir hızlı maç**: sunucuda oynandı, XP / görev / başarım / puan sunucuda hesaplandı;
- 5 eşzamanlı talep (görev, giriş, başarım) → her birinde yalnızca bir ödeme;
- sahte ve başka oyuncunun JWT'si;
- doğrudan yazma girişimleri;
- hafta kapanışının paralel ve tekrar çalıştırılması.

### 3.2 Yerel

| Test | Sonuç |
|---|---|
| TS kural motoru | **85 / 85** |
| Godot birim + sahne | **37 / 37** |
| Worker yerel | **26 / 26** |
| Oda testi yerel | **32 / 32** |
| `tsc --noEmit` | Temiz |

### 3.3 Test hesapları ve veriler

- Bütün Node ve Godot bulut testleri 5 kalıcı test hesabını (KBTest1–5) kullandı.
  - Bu fazda **yeni misafir hesap açılmadı**; yalnızca `api_e2e_test` 2 geçici hesap açıp sildi.
  - Testler yalnızca bu hesapların verisini sıfırlıyor.
- Kapanış zincirinde bir sızıntı bulundu ve düzeltildi:
  - Godot testinde gerçek maç ekranı, görevleri yenilerken uygulamanın genel oturumunu kullandı ve **1 misafir hesap açtı**.
  - O hesap silindi. Test artık genel oturumu test hesabına bağlıyor; düzeltmeden sonra yeniden çalıştırıldı ve hesap açılmadı.
- Gerçek oyuncu verisine dokunulmadı.
- Son durum:
  - 8 kullanıcı (3 dokunulmayan misafir + 5 test hesabı);
  - 0 maç, 0 sıralama puanı;
  - bir açık hafta kaydı (bu hafta).

## 4. Henüz yapılmayan ya da sınırlı olanlar

- **Gerçek cihaz:** 0.7.0'ın ekranları (görevler, giriş paneli, başarımlar, sıralama, kutlamalar) telefonda görülmedi.
  - Ekran turunda örnek verilerle görüldü: `docs/phase6_screens/`. 60–66 numaralı görüntüler örnek veridir; uygulama sahte veri göstermez.
  - Düşük seviye Android cihazda animasyon performansı ölçülmedi. Kutlamada tek bir tween ve 12 çizilen nokta var; "azaltılmış hareket" ayarına uyuyor.
- **Hafta kapanışı:** Gerçek bir pazartesi geçişi beklenmedi.
  - Geçmiş bir hafta üzerinde SQL testinde doğrulandı.
  - Bulutta kapanış işlevi Worker → Hyperdrive → `game_server` yoluyla çalıştırıldı (rota). Saatlik cron tetikleyicisi dağıtıldı ama ilk çalıştırması gözlenmedi.
- **Sıralama:** İlk 100 için hile / işbirliği denetimi ve ödül bekletme yok (K-76, mağaza öncesi).
- **Kozmetikler:** Seviye ödüllerinde yalnızca rozetler var. Avatar, çerçeve ve zar içerikleri yok; sahte mağaza ya da satın alma da eklenmedi.
- **Elmas:** Hiçbir ödülde kullanılmadı (E-2 kararı açık).
- **Onay bekleyen kararlar:**
  - K-74: gün kaçırma kuralı;
  - K-75: kasma sınırları;
  - K-76: sıralama puanı ve ödülleri;
  - K-77: özel odanın ödüllere etkisi.
  Hepsi belge önerileriyle uygulandı.

## 5. Git

| Commit | İçerik |
|---|---|
| `c8637f3` | 6.1 XP ve seviye |
| `982faaa` | 6.2 görevler + kasma önlemleri |
| `8b3e0ba` | 6.3 günlük giriş + sınır kilidi |
| `ec31ffd` | 6.4 başarımlar ve rozetler |
| `fdc04f0` | 6.5 haftalık sıralama |
| (bu rapor) | Faz 6 kapanışı |

- `eeafcde` ve önceki commit'ler korundu.
- Push yapılmadı.
- APK, `.dev.vars`, `.test-accounts.json`, token ve parola commit'lerde yok; her commit öncesi tarandı.
