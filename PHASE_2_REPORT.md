# Faz 2 Raporu — Oyun Motoru, Godot İskeleti ve Oynanabilir Çevrimdışı Oyun

> **Tarih:** 2026-11-16 / 17
> **Sürüm:** 0.2.0 (Android versionCode 2)
> **Testler:** TypeScript **73 / 73**, GDScript **27 / 27**
> **İki motorun eşitliği:** 37 senaryo + 60 rastgele maç (37.121 adım), hepsi birebir.
> **Plan:** [docs/PHASE_2_PLAN.md](docs/PHASE_2_PLAN.md) (inceleme, çelişkiler, alt fazlar)
> **Ekran görüntüleri:** `docs/phase2_screens/` (`overview.png`)
>
> **Sonradan eklenen not (2026-11-17):** Bu rapor Faz 2'nin kaydıdır ve olduğu gibi korunuyor. Sonraki güncellemede bazı kararlar değişti ([PHASE_2_POST_UPDATE_REPORT.md](PHASE_2_POST_UPDATE_REPORT.md)):
> - **Üçüncü 6:** Kural artık "üçüncü atış 1–5" (kod henüz eski kuralda).
> - **Altın:** Gerçek parayla satın alınabilir.
> - **Sunucu:** Cloudflare Workers + Durable Objects.
> - **Faz 3:** Bu raporun §16'daki Faz 3 önerisinin yerine docs/DEVELOPMENT_ROADMAP.md'deki F3 geçerli.

## 1. Yapılan geliştirmeler (alt fazlar)

| Alt faz | Sonuç | Testler |
|---|---|---|
| 2.0 İnceleme ve plan | Faz 1 belgeleri kontrol edildi; 5 çelişki raporlandı (plan §3); kararlar karar listesine işlendi | — |
| 2.1 TS oyun motoru | `server/game-engine/` modüler, saf, belirleyici motor | 63 test (o anda) |
| 2.2 Ortak test vektörleri | `shared/rules_test_vectors/` (TS'nin ürettiği beklenen sonuçlar) | Vektörler güncel mi testi |
| 2.3 GDScript motoru + Godot iskeleti | `client/` (dikey, güvenli alan, Compatibility); motorun GDScript eşi; hata yakalayan test koşucusu | 17 test; eşitlik %100 |
| 2.4 Tahta, piyon, zar görselleri | `BoardView` (`board_map.json`'dan), döndürme; SVG piyon, zar, ikon, buton; tema | Döndürme ve konum testleri |
| 2.5 Oynanabilir çevrimdışı maç | Kurulum ekranı, maç ekranı, animasyonlar, menü, sonuç; bot ve aynı cihazda sırayla oynama | Akış, düzen ve dokunma testleri |
| 2.6 Ekonomi ve mimari hazırlığı | İki para birimi tasarımı, yapılandırma, ödeme hesabı, risk notu, Realtime ve Redis güncellemesi | Ekonomi testleri (+10) |
| 2.7 Uyumluluk ve APK | Kaynaklı araştırma raporu; debug APK | Manifest denetimi |

## 2. Oluşturulan dosyalar (özet)

**Sunucu ve paylaşılan dosyalar:**

| Yol | İçerik |
|---|---|
| `server/game-engine/` | `src/` 12 modül, `test/` 8 dosya, `scripts/gen-vectors.ts`, `README.md` |
| `shared/rules_test_vectors/` | `scenarios.json`, `traces.json` |
| `shared/config/economy_config.example.json` | Örnek ekonomi yapılandırması |

**İstemci (`client/`):**
- `project.godot`, `export_presets.cfg`, `icon.svg` (placeholder), `README.md`.
- `data/board_map.json` (tek kaynağın birebir kopyası).
- Kod:
  - `scripts/game/rules/` (9 dosya, kural motoru);
  - `scripts/game/match_controller.gd`;
  - `scripts/board/` (3);
  - `scripts/ui/` (8);
  - `scripts/ui/screens/` (2);
  - `scripts/app/` (2).
- Varlıklar: `assets/` (fontlar, SVG'ler, `ASSETS.md`), `localization/tr.po`, `en.po` (64 anahtar).
- Testler ve araçlar: `tests/` (koşucu, 5 test dosyası, ekran görüntüsü turu), `tools/` (3 Python betiği).

**Belgeler (`docs/`):**
- Yeni: `PHASE_2_PLAN.md`, `COMPATIBILITY_REPORT.md`, `ECONOMY_TWO_CURRENCY_DESIGN.md`, `RISK_GOLD_ENTRY_MATCHES.md`, `phase2_screens/`.
- Güncellenen: `DECISIONS_AND_OPEN_QUESTIONS.md` (15 karar işlendi), ECONOMY / MONETIZATION / TECHNICAL_ARCHITECTURE / DATABASE_SCHEMA belgelerine "Faz 2 güncellemesi" notları.

**Kök klasör:** `.gitignore`, `build/android/KizmaBirader-0.2.0-debug.apk`.

**Faz 1 dosyaları:** Hiçbiri silinmedi ya da taşınmadı.

## 3. Godot proje yapısı

- **Konum:** Godot projesi `client/` altında. Proje köke kurulsaydı Godot, `docs/`, `server/` ve `node_modules` klasörlerini de içe aktarmaya çalışırdı (plan Ç4).
- **Klasörler:** Talimatta önerilen klasörler `client/` içinde. `scripts/animation/` ve `themes/` şimdilik boş:
  - Animasyonlar görsellerin kendi içinde (`PawnSprite`, `DiceView`, `MatchScreen`).
  - Tema kodla kuruluyor (`UiTheme`).
- **Ayarlar:**

| Ayar | Değer |
|---|---|
| Ekran yönü | `window/handheld/orientation = 1` (portrait); Android manifest'te `screenOrientation = 1` doğrulandı |
| Ölçekleme | 720×1560 referans, `canvas_items`, `expand` |
| Renderer | `gl_compatibility` (2D, en geniş cihaz desteği) |
| Güvenli alan | `SafeArea`: Android / iOS'ta `DisplayServer.get_display_safe_area()`; test ve görüntüler için `--safe-insets`. Üst çubuk, kartlar, zar ve alt boşluk bu alanın içinde. |

- **Ayrıntı:** `client/README.md`.

## 4. Oyun motoru mimarisi

- **Çekirdek:** `GameEngine.apply(state, action, dice?) → {state, events}` ya da `{error}`; hata durumunda durum değişmez.
  - Durum düz JSON'dur (Redis anlık görüntüsü ve ağ için hazır).
  - Zar dışarıdan verilir: sunucuda kriptografik kaynak, testlerde betikli ya da tohumlu kaynak.
- **Modüller:**
  - `BoardGeometry`, `Ruleset`, `GameState / PlayerState / PawnState`, `MoveValidator + CaptureResolver`, `TurnManager + WinCondition`, `DiceManager`;
  - `Bot` (belirleyici öncelik: bitir > ye > çık > tehlikeden kaç > en gerideki);
  - `MatchSession` (istek kimliğiyle tekrar koruması);
  - `canonical` (eşitlik sözleşmesi).
- **Bağlantıdan bağımsızlık:** Motor bağlantı durumunu bilmez. Yalnızca `active / finished / left` ve otopilot durumlarını tutar; kopma ve yeniden bağlanma sunucu katmanının işi.
- **Godot tarafı:** Aynı yapı GDScript'te (`client/scripts/game/rules/`). Arayüz kuralları bilmez:
  - `MatchController` süreleri ve botları yönetir;
  - `MatchScreen` yalnızca olayları canlandırır.
- **Kural seti:**

| Durum | Kurallar |
|---|---|
| Onaylanmış | 6 ile çıkış; 6 → ek zar; üçüncü 6 turu bitirir; yıldızlar ve başlangıçlar güvenli; bitişte tam sayı; 2 kişilikte ilk bitiren kazanır; 4 kişilikte 3 sıra belli olana kadar; zar 10 sn, seçim 12 sn |
| Hâlâ öneri (ayar olarak değiştirilebilir) | Yeme ve bitişte ek zar (K-14, K-15); yığılma serbest, blokaj yok (K-18); tek hamle otomatik (K-20, ayarlanabilir); 3 zaman aşımında otopilot (K-22) |

## 5. Tahta geometrisi doğrulama sonuçları

**`board_map.json` testleri (TS ve GDScript):**
- 15×15 ızgara; 52 benzersiz parkur hücresi; kapalı halka.
- Başlangıçlar 0 / 13 / 26 / 39; yıldızlar 8 / 21 / 34 / 47; güvenli kareler 8 hücre.
- Koridor girişi adım 50'nin yanında; K1–K5 bitişik; K5 merkeze komşu.
- 3×3 orta bitiş; 4 bekleme alanı (6×6, köşelerde).
- Parkur, koridor, bitiş ve bekleme alanları **çakışmıyor**; toplam 225 hücre tam karşılanıyor.
- Renk yolları parkurla tutarlı; 90° döndürme simetrisi var.
- Her renk döndürüldüğünde sol altta.
- İstemci kopyası kaynağın **bayt bayt aynısı**.

**Testin düzelttiği bir varsayım:** İlk testim her parkur adımının yan yana iki hücre arasında olduğunu varsayıyordu. Klasik Ludo tahtasında haçın 4 iç köşesinde parkur **çapraz** geçer (adım 4→5, 17→18, 30→31, 43→44). Bu bir veri hatası değil, testteki yanlış varsayımdı; test doğru geometriye göre düzeltildi ve köşe geçişlerini açıkça denetliyor.

## 6. Otomatik test sonuçları

- **TypeScript (`npm test`): 73 / 73.**

| Dosya | Test | Kapsam |
|---|---|---|
| `rules.test.ts` | 37 | Talimattaki 18 senaryo + ek kurallar |
| `board.test.ts` | 11 | Tahta geometrisi |
| `bot.test.ts` | 7 | Bot öncelikleri |
| `economy.test.ts` | 7 | Ekonomi yapılandırması ve ödeme |
| `session.test.ts` | 4 | Tekrar koruması |
| `property.test.ts` | 4 | 300 iki kişilik + 200 dört kişilik rastgele maçta değişmezler; 200 bot maçının bitmesi; belirleyicilik |
| `vectors.test.ts` | 3 | Vektörlerin güncelliği |

- **GDScript (headless): 27 / 27.**
  - Tahta: 5.
  - Kurallar: 10.
  - Eşitlik: 2.
  - Tahta görünümü ve düzen: 6. Kapsam: 6 ekran oranı × 2 / 4 kişi; kurulum ekranının küçük ekranlarda sığması; gerçek dokunuşla zar ve piyon seçimi.
  - Maç akışı: 4. Kapsam:
    - bot maçlarının sonuna kadar oynanması;
    - zaman aşımı ve otopilot;
    - tek hamlenin otomatik oynanması;
    - gerçek oyun ekranında ve animasyonlarla, hızlandırılmış zamanda baştan sona 4 kişilik maç.
- **Test koşucusu:** Test sırasında oluşan her betik ya da motor hatasını yakalayıp testi başarısız sayıyor. Bu, kasıtlı bir hatayla doğrulandı.

## 7. TypeScript / GDScript tutarlılık sonuçları

- **Senaryolar:** 37 senaryonun her adımında **olay listesi, hata kodu, durum metni ve özeti** birebir aynı.
- **Rastgele maçlar:** 60 tohumlu rastgele maçta (30 iki kişilik, 30 dört kişilik; zaman aşımları dahil) **37.121 adımın her biri** aynı durum özetini üretti.
- **Kural değişirse:** `npm run vectors` ile vektörler yeniden üretilir; GDScript tarafı aynı anda güncellenmezse CI kırılır.

## 8. Çevrimdışı oynanabilir özellikler

- **Kurulum:** 2 / 4 kişi seçimi.
  - İlk koltuk "Sen"; tahta bu renge göre döner (yerel oyuncu sol altta).
  - Diğer koltuklar **Bot** ya da **Oyuncu** (aynı cihazda sırayla oynama).
  - TR / EN dil seçimi.
- **Maç:**
  - Zar atma: dokunarak; animasyonlu; en az ~0,35 sn.
  - Piyon seçme: geçerli piyonlar hâle ile, hedef kareler kesikli halkayla; dokunma alanı 44 pt; en yakın geçerli piyon seçilir.
  - Hareket: kare kare zıplama.
  - Yeme: yayla eve uçuş ve tahta sarsıntısı. Bitiş: piyon küçülerek bitişe yerleşir.
  - Süre: oyuncu kartında halka (zar 10 sn, hamle 12 sn); son 3 sn kırmızı. Süre dolunca otomatik oynanır; 3 kez üst üste dolarsa otopilot devreye girer.
  - Bilgi: sıra göstergesi; bitiş noktaları; durum (sırada, otopilot, ayrıldı, N. oldu); kısa bildirimler (6 → tekrar at, yeme, üç 6, hamle yok).
- **Menü:**
  - Devam et.
  - Ayarlar: hızlı animasyon, tek hamleyi otomatik oyna, renk sembolleri.
  - Yeniden başlat ve Maçtan çık (ikisi de onaylı).
  - Menü açıkken saat durur.
- **Sonuç ekranı:** Sıralama (botlar BOT etiketli), "Pratik maç · ödül ve sıralama yok" notu, Ana menü / Tekrar oyna.
- **Botlar:** Her yerde açıkça "BOT" etiketli ve robot avatarlı. Yalnızca geçerli hamle yaparlar, insanın hamlesini beklerler, gecikmeleri 0,7–1,3 sn.

## 9. UI/UX uygulama durumu

**Uygulanan (Akşam Masası):**
- koyu mor radyal zemin, soluk yıldız dokusu, lamba hâlesi;
- krem kartlar (alt kenarlı), koyu cam paneller;
- 9 parçalı (9-slice) degradeli oyun butonları, basılınca gömülen;
- Baloo 2 + Nunito, Faz 1 tokenları (pt × 2);
- oyuncu renkleri ve renk sembolleri;
- tahta, piyon ve zar tasarımı, Faz 1 prototipine uygun.

**Ekran oranları:** 19,5:9, 16:9 (sıkışık düzen), 20:9 ve tablet (4:3) görüntülerde ve otomatik düzen testinde denendi.

**Henüz yok** (sonraki fazlar):
- ana menü, profil, mağaza, giriş ekranları;
- ses ve müzik, titreşim (ayar var, kullanılmıyor);
- hızlı mesaj ve emoji;
- "Seç ve onayla" dokunma modu (ayar anahtarı var, arayüzde yok);
- maç girişi ve açılış animasyonu cilası;
- erişilebilirlik (azaltılmış hareket ayarı kodda var, arayüzde yok).

**Placeholder olanlar:** avatarlar (harf + gradyan), uygulama ikonu, logo yazısı. Liste: `client/assets/ASSETS.md`. Faz 1 prototiplerindeki emoji ikonları oyunda **kullanılmadı**.

## 10. Android / iOS uyumluluk durumu

| Platform | Durum |
|---|---|
| Android derleme | ✅ `build/android/KizmaBirader-0.2.0-debug.apk` (29 MB, arm64, minSdk 24, targetSdk 36, yalnızca dikey, debug sertifikası). SHA-256: `d06c8635692067a65e755d2ff0a046363602b2985b8df51846c9f5e9cd5ca05d` |
| **Android cihaz testi** | ❌ **Yapılmadı:** telefon bu faz boyunca bağlı değildi. Performans, dokunma hissi ve güvenli alan cihazda **doğrulanmadı**. |
| iOS | ❌ Derleme ve test **yapılmadı** (Mac, Xcode, Apple hesabı yok). Kod, iOS güvenli alanını da okuyor. |
| Masaüstü (Windows) | ✅ Oyun açılıyor, oynanıyor; ekran görüntüleri buradan |

## 11. Supabase entegrasyon araştırması

Ayrıntı ve kaynaklar: `docs/COMPATIBILITY_REPORT.md` §2.

- **SDK:** Godot için resmi Supabase SDK'sı yok; plan, REST ile ince bir GDScript istemcisi.
- **Misafir hesap:** Anonim giriş var; JWT'de `is_anonymous` alanı bulunuyor. Kötüye kullanıma karşı CAPTCHA öneriliyor; varsayılan sınır IP başına saatte 30. Eski anonim hesaplar otomatik silinmiyor.
- **Hesap bağlama:**
  - Önce "manual linking" açılmalı.
  - E-posta için `updateUser`, OAuth için `linkIdentity`, yerel belirteç için `linkIdentityWithIdToken` (Dart başvurusunda).
  - Kimlik başka bir hesaba aitse hata döner; çakışma uygulamada çözülmeli. "Birleştirme yok" tasarımıyla uyumlu.
- **Canlı doğrulama yapılmadı** (Supabase projesi yok). Faz 4'ün ilk işi.
- **Güvenlik:** Service role anahtarı istemciye **eklenmedi**. İstemcide hiçbir Supabase anahtarı yok.

## 12. Reklam ve IAP eklenti araştırması

Ayrıntı ve kaynaklar: `docs/COMPATIBILITY_REPORT.md` §3–4.

| İhtiyaç | Aday | Bilinen kısıt |
|---|---|---|
| AdMob | Poing Studios (Godot 4.2+, iki platform) | Son sürümün tarihi doğrulanamadı |
| Google Play Billing | Resmi GodotGooglePlayBilling (4.2+) | **Gradle derlemesi** gerektiriyor |
| iOS IAP | Resmi `godot-ios-plugins` | Hâlâ StoreKit 1 |
| iOS StoreKit 2 + Apple girişi | Godot Apple Plugins | **iOS 17+** gerektiriyor |
| iOS StoreKit 2 (alternatif) | godot-iap | iOS 15+ |
| Google girişi | Credential Manager eklentisi | Web client ID gerekiyor |
| Push | godot-x/firebase | Godot 4.5'te test edilmiş |

**Hiçbir eklenti kurulmadı ya da cihazda denenmedi.**

## 13. Bilinen hatalar ve kısıtlar

1. **Cihazda doğrulanmadı:** Dokunma, kaydırma hissi, güvenli alan ve performans gerçek telefonda denenmedi.
2. **Aynı cihazda sırayla oynama:** Tahta yalnızca "Sen" koltuğuna göre döner. Diğer insan oyuncular tahtayı kendi açılarından görmez; bilinçli bir sadeleştirme.
3. **Animasyonlar zamanla değiştirilebilir değil:** Maç ekranı olay kuyruğunu sırayla oynatıyor. Çok hızlı art arda gelen bot hamleleri arasında küçük bekleme boşlukları olabilir; cila Faz 3'te.
4. **Ayar ekranı eksik:** Tam ayarlar Faz 3'te. Azaltılmış hareket ve "seç ve onayla" ayarlarının arayüzü yok.
5. **Masaüstü uyarısı:** Godot, Compatibility renderer'da 2D MSAA'yı desteklemiyor; ayar kaldırıldı. Kenar yumuşatma çizimlerin kendi `antialiased` seçenekleriyle yapılıyor.
6. **Git deposu yok:** Proje bir git deposu değil. Sürüm geçmişi için `git init` önerilir; senin onayına bırakıldı.

## 14. Eksik kalan işler (bu fazın talimatına göre)

- [ ] **Android cihaz testi** (telefon gerekli).
- [ ] **iOS derleme ve test** (Mac gerekli).
- [ ] **Supabase'in canlı doğrulaması** (proje URL'si ve anon anahtar gerekli).
- [ ] **Eklentilerin cihazda denenmesi** (hesaplar ve cihaz gerekli).
- [ ] **Ekonomi kararları:** E-1 (altın satın alınabilir mi), E-2 (Elmas edinimi), E-3 (kesinti), giriş seviyeleri. Bunlar senin kararın.
- [ ] **Hâlâ öneri olan kurallar:** K-11, K-14, K-15, K-18, K-20, K-22–K-24.

## 15. Teknik riskler

1. **Eklenti ve Gradle geçişi:** IAP, reklam ve giriş eklentileri Gradle derlemesi istiyor; iOS'ta eklenti seçimi en düşük iOS sürümünü belirliyor (iOS 15 / 17).
2. **İki kalıcı bağlantı:** Supabase Realtime + oyun soketi telefonda pil ve yeniden bağlanma karmaşıklığı getiriyor (TECHNICAL_ARCHITECTURE §9 notu).
3. **Altınlı maçların mevzuat ve mağaza uygunluğu** doğrulanmadı (`docs/RISK_GOLD_ENTRY_MATCHES.md`).
4. **İki motor bakımı:** Kural değişikliklerinin iki dilde yapılması gerekiyor. Vektör testleri bunu yakalıyor, ama iş yükü iki katı.
5. **Tek test cihazı:** Giriş seviyesi Android ve iOS kapsamı yok.

## 16. Faz 3 önerisi

**Faz 3 — Oyun hissi, tasarım sistemi tamamlama ve cihaz doğrulaması:**

1. **Cihaz testi:** Telefon bağlanınca APK kurulumu; dokunma, güvenli alan, performans ölçümü (FPS, bellek, açılış süresi); sonuçların rapora eklenmesi.
2. **Gradle tabanlı dışa aktarma:** Eklentilere hazırlık. Bir eklentinin (önce AdMob test reklamı ya da Billing) cihazda "merhaba dünya" denemesi.
3. **Ana menü ve ekranlar:** Faz 1 tasarımına göre ana menü iskeleti, ayarlar ekranı (azaltılmış hareket, dokunma modu, dil, titreşim) ve eğitim maçı.
4. **His:** Ses ve titreşim (K-43 kararı sonrası), maç girişi ve kutlama animasyonları, hızlı mesajlar (arayüz).
5. **Kuralların kesinleşmesi:** Kalan kural kararlarının (K-11, K-14, K-15, K-18, K-20, K-22–K-24) kesinleşmesi ve vektörlerin yenilenmesi.
6. **Ekonomi kararları:** E-1…E-4 kararları ve DATABASE_SCHEMA güncellemesi (uygulama Faz 7'de).
7. **Sürüm kontrolü:** Git deposunun açılması (onayınla).
