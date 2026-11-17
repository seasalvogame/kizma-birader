# Faz 3.4 Raporu — İlk Çevrimiçi Maç (2 kişi) ve Cloudflare Hazırlığı

> **Tarih:** 2026-11-17
> **Sürüm:** 0.4.0 (Android versionCode 4)
> **APK:** `build/android/KizmaBirader-0.4.0-debug.apk` (29,3 MB; SHA-256 `b5fea1061b7de63995d9237cdbf537551505ef732a6038cae283e38ed8a3fac9`)
> **Git:** İlk commit `3494652` (Faz 1–3.3). Bu rapordaki değişiklikler **henüz commit edilmedi** (onayını bekliyor). Push yapılmadı.
> **Sunucu:** https://kizmabirader-game-dev.kizmabirader.workers.dev (Cloudflare, ücretsiz plan); gerçek bulutta testli (§1).

## 1. Gerçek Cloudflare test sonuçları

### 1.1 Dağıtım sorunu ve çözümü

- **Belirti:** İlk denemelerde dağıtım `code: 10034` ("You need to verify your email address to use Workers") ile reddedildi.
- **Neden:** Cloudflare hesabındaki e-posta adresi doğrulanmamıştı. Hesap yetkisi ya da workers.dev ayarıyla ilgisi yoktu.
- **Çözüm:**
  - E-posta doğrulandıktan sonra `npx wrangler whoami` ile oturum kontrol edildi:
    - tek hesap;
    - OAuth oturumu açık;
    - `workers (write)`, `workers_scripts (write)` ve `account (read)` yetkileri mevcut.
  - Yeniden giriş gerekmedi.
  - `npx wrangler deploy` başarılı oldu.

| Konu | Değer |
|---|---|
| Adres | https://kizmabirader-game-dev.kizmabirader.workers.dev |
| Alt alan adı | kizmabirader.workers.dev (ücretsiz; ödeme bilgisi istenmedi) |
| Paket | 51 KB (sıkıştırılmış 11,9 KB) |
| Bağlar | MatchRoom ve Matchmaker Durable Objects (SQLite, ücretsiz plan) |

### 1.2 Gerçek bulutta doğrulananlar (2026-11-17)

**Sunucu testi:** `local_ws_test.mjs --remote …` → **25 / 25**

| Konu | Sonuç |
|---|---|
| Worker erişimi ve sağlık kontrolü (HTTPS) | ✅ |
| Durable Object oluşturulması | ✅ Her maç ayrı ve yeni bir nesne |
| WebSocket bağlantısı (`wss://`) | ✅ |
| Kimlik | ✅ JWT'siz istek 401; kurcalanmış JWT reddedildi; maçta olmayan kullanıcı reddedildi; her JWT kendi koltuğuna bağlandı |
| Sunucu otoritesi | ✅ Sırası olmayan reddedildi; istemciden gelen **zar** ve **koltuk** alanı reddedildi |
| Aynı isteğin iki kez işlenmemesi | ✅ Tekrar gönderilen istek kimliğine ilk sonuç döndü, ikinci zar atılmadı |
| Hız sınırı | ✅ 40 mesajlık patlamada 10 mesaj reddedildi |
| Yeniden bağlanma | ✅ 60. hamlede kopan oyuncu tam durumu aynı sıradan aldı |
| Sunucunun yeniden başlatılması ve kalıcılık | ✅ Maçın ortasında yeni sürüm dağıtıldı. Nesne ~10 sn içinde **gerçekten yeniden başladı** (açılış kimliği `44a957df` → `07176a68`). Maç **kayıtlı durumdan** (sıra 120) devam etti. |
| Tam maç | ✅ İki gerçek istemci arasında sunucuda bitti (362 hamle) |
| Zar kuralı | ✅ Bütün zarlar 1–6; iki 6'dan sonraki 4 atışın hiçbiri 6 değil |
| Süre dolması ve otopilot | ✅ Boşta kalanın hamlesini sunucu oynadı; 3 zaman aşımından sonra otopilot açıldı; bot sunucu alarmlarıyla oynamaya devam etti |

**Godot istemcisi testi:** `godot_online_test.mjs --remote …` → **geçti**
- Gerçek Godot istemci koduyla iki misafir hesap buluttaki kuyrukta eşleşti.
- A oyuncusu **gerçek maç ekranından** oynadı; maç bitti (312 hamle).
- İki taraf aynı sonucu gördü.
- A'nın bağlantısı koparıldı; kendiliğinden yeniden bağlandı ve tam durumu aldı.

**Testte bulunan ve düzeltilen bir sorun:**
- Cloudflare, uykuya geçebilen WebSocket'lere sahip bir nesneyi yeni dağıtımda **hemen** yeniden başlatmıyor. İlk denemede açılış kimliği aynı kaldı ve test bunu doğru biçimde başarısız saydı.
- Test artık bağlantıları kapatıp nesnenin gerçekten yeniden başladığını yoklayarak doğruluyor.
- Bu bekleme sırasında hamle otomatik oynanmasın diye bu maçta tur süreleri uzun tutuluyor.

**Supabase:**
- Oyun sunucusunun Supabase'e **bağlantısı yok.** Maç sonuçları veritabanına yazılmıyor; altın ve ödül işlemi yok.
- Kullanılan tek Supabase parçası, misafir hesap açma ve JWT doğrulaması (genel anahtarla). Bu parça gerçek Supabase'te çalışıyor.
- Sahte bir Supabase entegrasyonu **yok.**

## 2. Çevrimiçi maç entegrasyonunun durumu

### 2.1 Sunucu (`server/worker`)

- **Yeni `Matchmaker` Durable Object** (`/v1/queue`):
  - 2 kişilik hızlı maç; iki farklı oyuncuyu eşleştiriyor.
  - Renk çiftini (kırmızı–sarı ya da yeşil–mavi) ve koltukları sunucu rastgele atıyor. Renk tercihi K-55 açık kararı nedeniyle henüz yok.
  - MatchRoom'u kuruyor ve iki oyuncuya "maç bulundu" diyor.
  - Bekleyenler WebSocket eklerinde tutuluyor; nesne uykuya geçse de kaybolmuyor.
- **MatchRoom:** Her olay mesajıyla birlikte **tam sunucu durumunu** da gönderiyor; istemci hiçbir şeyi kendi hesaplamıyor.
- **Hata yanıtları:** Şema ve hız sınırı hatalarında istek kimliği yanıta ekleniyor.

### 2.2 İstemci (Godot)

**Yeni dosyalar:**

| Dosya | Görev |
|---|---|
| `scripts/online/online_config.gd` + `data/online_config.json` | Herkese açık yapılandırma: Supabase adresi, **publishable** anahtar (istemcide durması güvenli; gizli anahtar değil), oyun sunucusu adresi |
| `scripts/online/online_session.gd` | Cihazın misafir hesabı: anonim giriş, belirteç yenileme. Kısa ömürlü erişim belirteci yalnızca bellekte tutuluyor. |
| `scripts/online/ws_client.gd` | WebSocket sarmalayıcısı; sunucu saat farkı; protokol ping'i |
| `scripts/online/online_matchmaking.gd` | Kuyruk: `hello` → `queue.join` → `match.found` |
| `scripts/online/online_match_connection.gd` | Maç bağlantısı: kopunca 0,5 / 1 / 2 / 4 / 8 / 15 sn aralıklarla kendiliğinden yeniden bağlanma, tam durum, sıra boşluğunda `resync` |
| `scripts/game/online_match_controller.gd` | **Aynı maç ekranı için** çevrimiçi kontrolcü (aşağıda) |
| `scripts/app/online.gd` | `Online` autoload: oturum ve bağlantı ekran değişimlerinde yaşıyor |
| `scripts/ui/screens/online_queue_screen.gd` | "Çevrimiçi Maç" ekranı: bağlanma, rakip arama (süre), bulundu, hata ve "Tekrar dene" |

**`OnlineMatchController` nasıl çalışıyor:**
- Çevrimdışı `MatchController`'dan türüyor; aynı sinyalleri veriyor. Maç ekranı aynı ekran.
- **Zar üretmiyor:** Zar kaynağı boş; kullanılırsa motor hatası oluşur ve testler bunu yakalar.
- **Kural uygulamıyor, yerel saat başlatmıyor.**
- Dokunuşlar yalnızca istek olarak sunucuya gidiyor. Ekrandaki durum yalnızca sunucudan gelen durumla değişiyor.

**Maç ekranındaki değişiklikler:**
- çevrimiçi kontrolcü seçimi;
- "Yeniden başlat" ve duraklatma çevrimiçide yok;
- "Maçtan çık" sunucuya ayrılma isteği gönderiyor ("Çıkarsan rakibin kazanır" onayı);
- bağlantı koptu / yeniden bağlandı bildirimleri;
- yeniden bağlanınca tam durumla yenileme;
- sonuç notu: "ödüller ve sıralama yakında".

**Menü:**
- Ana menüdeki "Çevrimiçi maç" kartı ve 2 kişilik mod seçimindeki "Çevrimiçi hızlı maç" artık açık ("TEST" etiketi).
- 4 kişilik çevrimiçi ve özel oda hâlâ "Yakında".

## 3. Android tarafındaki değişiklikler

- **İnternet izni açıldı.** Önceki APK'larda kapalıydı; çevrimiçi maç olmazdı. Manifest'te artık `INTERNET` + `VIBRATE` (aapt ile doğrulandı).
- **Sürüm:** 0.4.0 (4).
- **Paket içeriği:** `data/online_config.json` ve `data/board_map.json` APK içinde; test dosyaları değil (doğrulandı).
- **Oyun sunucusu adresi:** `https://kizmabirader-game-dev.kizmabirader.workers.dev`. Sunucu dağıtılınca **APK'yı yeniden derlemek gerekmiyor**.

## 4. Testler

| Test | Sonuç | Ortam |
|---|---|---|
| TypeScript motor | 85 / 85 | Node |
| Worker tip denetimi | Temiz | — |
| Godot birim ve sahne | **33 / 33** | Masaüstü |
| Sunucu uçtan uca (`local_ws_test.mjs`) | **25 / 25** | **Yerel** `wrangler dev` + gerçek Supabase misafir JWT'leri |
| **Godot istemcisi çevrimiçi uçtan uca** (`godot_online_test.mjs`) | **Geçti** | **Yerel** `wrangler dev` + gerçek Supabase |
| Ekran görüntüsü turu | Kuyruk ekranı, hata durumu ve "TEST" kartları gözle kontrol edildi | Masaüstü |

**Godot istemcisi çevrimiçi testinin kapsamı:**
- **Kuyruk:** İki gerçek misafir hesap kuyruğa girdi; sunucu ikisini **aynı maça**, farklı koltuklara ve **karşılıklı renklere** koydu.
- **A oyuncusu:** **Gerçek maç ekranıyla** oynadı; zara ve piyonlara dokunuldu, animasyonlar oynatıldı.
- **B oyuncusu:** Aynı çevrimiçi kontrolcüyle oynadı.
- **Sıra:** Her an yalnızca bir oyuncu eylem yapabildi.
- **Sonuç:** Maç bitti (292 eylem). İki istemci **aynı sıralamayı** ve **aynı son sunucu durumunu** gördü.
- **Kopma:** Maçın ortasında A'nın bağlantısı koparıldı. A kendiliğinden yeniden bağlandı, sunucudan tam durumu aldı ve maça devam etti.
- **Zar:** İstemci hiç zar üretmedi.

**Test sırasında bulunan ve düzeltilen hatalar:**
1. Maç ekranı, çevrimiçi kontrolcünün `fatal` sinyaline bağlantı nesnesi henüz yokken bağlanıyordu; çevrimiçi maç ekranı açılırken çökerdi. Testi gerçek maç ekranıyla genişletince ortaya çıktı.
2. Android'de internet izni kapalıydı (§3).
3. "TEST" etiketi kart sahneye eklendikten sonra atandığı için görünmüyordu.

**Test edilmeyenler:**
- **Gerçek telefon:** Telefon bağlı değildi.
- **Mobil ağda kopma:** Wi-Fi'dan mobil veriye geçiş, arka plana alma.
- **iOS.**

## 5. İki telefonla test adımları

**Ön koşul:** Sunucu dağıtıldı ve gerçek bulutta testli (§1). Ek bir işlem gerekmiyor.

**Adımlar:**
1. **Kurulum:** İki telefona da `KizmaBirader-0.4.0-debug.apk`'yı kur. Eski sürümün üzerine kurulabilir.
2. **Bağlantı:** İki telefon da internete bağlı olsun. Aynı Wi-Fi şart değil.
3. **İsimler:** Her telefonda Profil'den farklı bir ad gir (ör. "Ayşe" ve "Mehmet").
4. **Arama:** İki telefonda da ana menüde **Çevrimiçi maç** kartına dokun. Ya da 2 Kişi → Çevrimiçi hızlı maç. "Rakip aranıyor…" görünür.
5. **Eşleşme:** Birkaç saniye içinde iki telefon eşleşip maça girer. Kontrol et:
   - renkler karşılıklı olmalı;
   - herkes kendi rengini sol altta görmeli;
   - rakibin adı kartında görünmeli.
6. **Sıra:** Sırası gelen zara dokunur; diğer telefonda "… oynuyor" yazmalı ve hamle animasyonla görünmeli.
7. **Kopma testi:** Maçın ortasında bir telefonda Wi-Fi'ı ya da veriyi 10–20 sn kapatıp aç.
   - "Bağlantı koptu · yeniden bağlanılıyor…" ve ardından "Yeniden bağlandı" görünmeli.
   - Tahta doğru duruma gelmeli.
   - Kopukken süre dolarsa o oyuncunun hamlesini sunucu oynar.
8. **Sonuç:** Maçı bitir. İki telefonda da sonuç ekranı ve aynı sıralama görünmeli. "Tekrar oyna" yeniden kuyruğa sokar.
9. **Çıkış:** İkinci bir maçta bir telefonda Menü → Maçtan çık → onay. Diğer telefonda maç o oyuncunun ayrılmasıyla bitmeli.

**Bildirmen yararlı olanlar:**
- eşleşme süresi;
- takılma ya da gecikme;
- yanlış görünen tahta;
- bağlantı sorunları;
- ekran görüntüleri.

## 6. Bilinen eksikler

- **Kapsam:** Yalnızca 2 kişilik çevrimiçi. 4 kişilik çevrimiçi, özel oda ve arkadaş daveti yok.
- **Kuyruk:** Bekleme süresi sınırı ve bot önerisi (K-05) yok. Tek oyuncu varsa kuyrukta beklemeye devam eder; "Vazgeç" ile çıkılır.
- **Supabase:** Maç kaydı, istatistik ve ekonomi yok. Çevrimiçi maçlar yerel pratik istatistiklerine de yazılmıyor.
- **Oturum saklama:** Misafir oturumunun yenileme belirteci uygulamanın özel deposunda; henüz Android Keystore'da değil.
- **Renk tercihi:** Hızlı maçta renk tercihi yok (K-55 açık).

## 7. Senden gerekenler

1. **İki telefonla test:** §5'teki adımlar. Sunucu hazır; APK 0.4.0 yeniden kurulmadan çalışır.
2. **Commit onayı:** Bu rapordaki değişiklikler için ikinci commit'i onaylarsan oluştururum (push yok).
