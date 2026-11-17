# TESTING_AND_PERFORMANCE — Test Stratejisi ve Performans Hedefleri

> **Durum:** Faz 1 taslağı (2026-11-16).
>
> **Faz 2 sonrası güncelleme (2026-11-17):** Sunucu testleri Cloudflare (workerd) ve Supabase ortamına göre güncellendi (§1, §2.1, §5). Faz 5 hedefleri DEVELOPMENT_ROADMAP F5'te.
>
> **İlke:** Ölçülmemiş bir şey "çalışıyor" diye raporlanmaz. Masaüstü ölçümleri cihaz ölçümüyle karıştırılmaz. Hedefler aşağıda; gerçek değerler fazların raporlarında ölçülerek yazılır.

## 1. Test piramidi

| Katman | Araç | Kapsam | Ne zaman |
|---|---|---|---|
| Birim | Vitest (sunucu), GDScript test koşucusu (istemci) | Kural motoru, ekonomi hesapları, biçimlendiriciler | Her commit |
| Özellik tabanlı | fast-check | Kural motoru değişmezleri (§2.2) | Her commit |
| Ortak vektörler | JSON + iki koşucu | TS ve GDScript motorlarının eşitliği | Her commit |
| Entegrasyon | Vitest + yerel Supabase (CLI) + `wrangler dev` / `@cloudflare/vitest-pool-workers` (workerd) | Worker uçları, Durable Object'ler, RLS, sunucu işlevleri, outbox | Her PR |
| Protokol / maç | Simüle istemciler (Node) | Tam maçlar, kopma, yeniden bağlanma, yarış koşulları | Her PR |
| İstemci sahne | Godot headless | Ekran düzenleri (oran matrisi), akışlar, sahte çeviri, RTL | Her PR |
| Yük | k6 (WebSocket) ya da Artillery | Eşzamanlı maç, eşleştirme kuyruğu | Faz 5, Faz 9, yayın öncesi |
| Cihaz | Gerçek cihazlar (§8) | Performans, dokunma, yaşam döngüsü, ses, bildirim | Faz 3'ten itibaren her sürüm |
| Kapalı beta | Play kapalı test, TestFlight | Gerçek oyuncu, gerçek ağ | Faz 10 |

## 2. Kural motoru testleri

### 2.1 Örnek tabanlı

- **Kural maddeleri:** GAME_RULES §14'teki her örnek ve her kural maddesi için en az bir test.
- **Ayarlar:** Kural seti ayarlarının her değeri (§12) için ayrı test: `blockade` açık / kapalı, `third_six_action` (`exclude_six`, `forfeit_turn`) vb.
- **Üçüncü atış kuralı (GAME_RULES §6.2):**
  - 6, 6 sonrası zar kaynağı yalnızca 1–5 üretir: 100.000 örnekte hiç 6 yok; 1–5 dağılımı ki-kare testinden geçer.
  - Motor, `sixes == 2` iken verilen 6'yı `INVALID_DICE` ile reddeder ve durum değişmez.
  - 6, 6, 5 ile yeme → yeme ek zarı 1–6 arasıdır (sayaç sıfırlandı).
  - 6, 6, 4 ile bitiş → bitiş ek zarı.
  - TS ve GDScript vektörleri yeni kuralla yeniden üretilir; eşitlik %100.
- **Uç durumlar:**
  - adım 50 → 51 geçişi;
  - tam sayı ile bitiş;
  - başlangıç karesinde rakip;
  - aynı karede farklı hamleli piyonlar;
  - 2 kişilik renk çiftleri (kırmızı–sarı, yeşil–mavi; karşılıklı olmayan çiftin reddi);
  - kullanılmayan renklerin yok sayılması;
  - iki 6'dan sonraki sınırlı atışla yeme ek zarının birlikte gelmesi.

### 2.2 Değişmezler (property-based)

Rastgele 10.000 tam maç simülasyonunda (rastgele zar + rastgele geçerli hamle) şunlar **her zaman** doğru olmalıdır:
- Her rengin piyon sayısı her zaman 4'tür.
- Bir piyonun adımı −1…56 aralığındadır; geri gitmez (yenme hariç).
- Güvenli karede yeme olmaz.
- Farklı renkten iki piyon, güvenli olmayan bir karede birlikte durmaz.
- `legalMoves` boşsa sıra geçer. Boş değilse her öğe `apply` ile geçerli bir durum üretir.
- Maç her zaman biter; tur sınırı 2.000. Kazanan, 4 piyonu da 56'da olan renktir.
- Aynı tohum + aynı hamle dizisi → aynı son durum (belirleyicilik).

### 2.3 Bot / otopilot

- Bot her zaman geçerli hamle seçer.
- 1.000 bot–bot maçında ortalama maç uzunluğu raporlanır. Kural ve süre ayarlarının sonucu olan tahmini maç süresi: 2 kişilik ~8–12 dk, 4 kişilik ~15–22 dk (**ölçülecek**).

## 3. Ortak test vektörleri ve CI denetimleri

- **Test vektörleri:** `shared/rules_test_vectors/*.json`.

```json
{ "name": "exact_roll_blocks_overshoot", "ruleset": "classic_v1",
  "state": { "turn": "red", "pawns": { "red": [53, -1, -1, -1], "green": [-1, -1, -1, -1] } },
  "dice": 4, "expect": { "legalMoves": [], "nextTurn": "green" } }
```

  - TS motoru ve GDScript motoru aynı dosyaları koşar; tek bir fark bile CI'ı **kırar**.
  - Yeni bir kural hatası bulunduğunda önce vektör eklenir, sonra düzeltme yapılır.
- **CI denetimleri:**
  - Protokol şeması anlık görüntüsü.
  - Gizli anahtar taraması.
  - Yerelleştirme: eksik anahtar, yer tutucu tutarlılığı, sabit metin taraması (LOCALIZATION §11).
  - RLS testleri.
  - Supabase güvenlik denetleyicisi.
  - Sunucu lint ve tip denetimi.
  - Godot projesinin headless içe aktarma ve betik denetimi.

## 4. İstemci testleri

- **Düzen matrisi:** Her ekran aşağıdaki tuvallerde taşma, çakışma, güvenli alan ve dokunma boyutu (en az 44 pt) bakımından otomatik denetlenir:

| Tuval | Örnek cihaz |
|---|---|
| 320×568 | En küçük |
| 360×640 | 16:9 |
| 360×780 | Referans |
| 390×844 | iPhone 13 / 14 sınıfı |
| 412×915 | Uzun Android |
| 430×932 | Büyük iPhone |
| 768×1024 | Tablet dikey |

  - Ekran görüntüleri arşivlenir.
- **Tahta:** Her oranda kare kalır, kırpılmaz. Bütün dokunma alanları tahtanın içindedir. Döndürme her renk için doğrudur (yerel renk sol altta).
- **Sahte çeviri (`en-XA`) ve sahte RTL:** Taşma ve aynalama testleri.
- **Akış testleri:** Giriş → ana menü → eşleştirme (sahte sunucu) → maç → sonuç → geçiş reklamı kararı → ana menü.
- **Çift dokunma:** Zar ve hamle butonları istek sürerken ikinci isteği göndermez.
- **Kaydırma:** Listelerde kaydırma başlayınca butonun basma işlemi iptal olur (yanlışlıkla satın alma yok); `cancel_press` deseni.

## 5. Sunucu, bağlantı ve dayanıklılık testleri

- **Tam maç simülasyonu:** 2 ve 4 simüle istemciyle bütün akış: kuyruk → eşleşme → hazır → maç → sonuç → DB kaydı → ödül.
- **İdempotency:**
  - Aynı `reqId` ile 5 kez `action.roll` → tek zar.
  - Ağ kesintisi simülasyonuyla tekrar.
  - Outbox'ın iki kez çalışması → tek ödül.
- **Yarış koşulları:**
  - Zaman aşımı ile hamlenin aynı anda gelmesi (NETWORK_PROTOCOL §7 toleransı).
  - Kuyruktan çıkma ile eşleşmenin aynı anda olması.
  - Odaya aynı anda iki katılma.
  - Aynı ürünü iki cihazdan aynı anda satın alma.
- **Kopma:** Rastgele anlarda bağlantı kesme. Geri dönüşte eksik olaylar ya da tam durum; durum sağlaması (hash) her iki tarafta aynı olmalı.
- **Sunucu yeniden başlaması:** Maç ortasında MatchRoom nesnesini yeniden başlat (yerelde workerd, staging'de dağıtım) → durum nesnenin deposundan yüklenir, alarm sürer, istemciler yeniden bağlanır → maç sürer. Durum bozulursa maç geçersiz sayılır, emanet iade edilir, telafi verilir.
- **Renk seçimi:** Aynı anda iki oyuncunun aynı rengi istemesi → biri `COLOR_TAKEN` alır; karşılıklı olmayan çift isteği → `COLOR_INVALID`.
- **Kota testleri (Faz 5):** Cloudflare ve Supabase kullanım ölçümleri. Maç-saati başına DO isteği, yazılan satır, süre (GB-sn), Realtime bağlantı ve mesaj sayısı ölçülür; architecture/COST_AND_SCALING.md tahminleriyle karşılaştırılır.
- **DB kesintisi:** Postgres 5 dk kapalıyken maçlar sürer, outbox birikir, açılınca boşalır, ödüller doğrudur.
- **Kaos:** Toxiproxy ile gecikme (300 ms), titreşim (±150 ms), %5 paket kaybı ve bant sınırı. Maçın oynanabilir kalması ve olay sırasının bozulmaması beklenir.
- **Yük testi hedefleri** (ölçülecek; Cloudflare'de maç başına ayrı nesne olduğu için "süreç kapasitesi" yerine gecikme ve kota ölçülür):

| Ölçüt | Hedef |
|---|---|
| Eşzamanlı maç | ≥ 2.000 (8.000 bağlantı) |
| Eylem işleme gecikmesi p95 | < 50 ms (sunucu içi) |
| Uçtan uca p95 (TR'den, ölçüm noktası İstanbul) | < 150 ms |
| Kuyruktan eşleşmeye ek gecikme | < 1 sn |
| Bellek | Maç başına < 50 KB; sızıntı yok (1 sa yük) |

## 6. Performans hedefleri (istemci)

**Hedef cihaz sınıfları:**

| Sınıf | Örnek | Hedef |
|---|---|---|
| Giriş seviyesi Android | 3–4 GB RAM, Mali-G52 / Adreno 610 sınıfı | Menü ve maç **60 FPS** (2D); en kötü durumda 30 FPS sabit, kare süresi < 33 ms |
| Orta ve üst Android | 6 GB+ | 60 FPS (120 Hz ekranda 60 sabit; v1.1'de 120 Hz değerlendirilir) |
| iPhone | iPhone 11 ve üstü (iOS sürüm tabanı K-49) | 60 FPS |

**Bütçeler:**

| Ölçüt | Bütçe |
|---|---|
| Soğuk açılış → ana menü | < 3 sn (orta seviye), < 5 sn (giriş seviyesi) |
| Ana menü → eşleştirme ekranı | < 300 ms |
| Maç sahnesi yüklenmesi | < 800 ms |
| Kare süresi p95 (maç) | < 16,7 ms (orta), < 25 ms (giriş seviyesi) |
| Bellek (PSS, Android) | < 250 MB (orta), < 200 MB (giriş seviyesi) |
| İndirme boyutu (AAB / App Store) | < 80 MB (öneri; ilk sürüm) |
| Çizim çağrısı | Menü < 120, maç < 80 |
| Pil (maçta, 30 dk, ekran %50 parlaklık) | < %6 (orta seviye; **ölçülecek**) |
| Ağ (maç başına) | < 1 MB (4 kişilik, 20 dk) |

**Animasyon süre bütçeleri** (UI_UX_DESIGN_SYSTEM §6):
- Bir turun zorunlu animasyonları en fazla **1,6 sn**.
- Zar en az 350 ms, en fazla 850 ms (yanıt beklemesi dahil).
- Piyon adımı kare başına 90 ms.
- Ekran geçişi 240 ms.

**Boşta kare hızı:** Menüde ve maçta oyuncu dokunmuyorsa ve animasyon yoksa **30 FPS**'e düşülür; dokununca 60'a çıkılır (pil ve ısı).

**Ölçüm araçları:**
- Godot `Performance` izleyicileri ve uygulama içi geliştirici paneli.
- Android `dumpsys gfxinfo` / `meminfo`, Perfetto.
- Xcode Instruments.
- Her faz raporunda aynı senaryo ve aynı cihazla tablo.

## 7. Ağ koşulları

| Senaryo | Beklenen |
|---|---|
| Zayıf 3G (400 ms RTT, 1 Mbps) | Maç oynanabilir; zar yanıtı yavaşsa "Bağlantı yavaş" ibaresi; olaylar sırayla |
| %10 paket kaybı | TCP yeniden iletim; sayaçlar sunucu zamanına göre doğru |
| Wi-Fi ↔ mobil veri geçişi | 3 sn içinde yeniden bağlanma; maç durumu doğru |
| Uçak modu 30 sn | "Yeniden bağlanılıyor"; dönüşte devam; otopilot hamleleri gösterilir |
| Tünel / asansör (60 sn+) | 4 kişilikte otopilot sürer; 2 kişilikte rakibe 90 sn sonra "Zaferi al" |
| Çok yüksek gecikme (1.500 ms) | Sayaç doğru; hamle süreleri yetmezse otomatik hamle — **bilinçli kabul** |

## 8. Cihaz matrisi (öneri; erişime göre güncellenir)

| Sınıf | Android | iOS |
|---|---|---|
| Giriş seviyesi | Samsung Galaxy A1x / A0x sınıfı, Xiaomi Redmi sınıfı (3–4 GB) | iPhone SE (2. / 3. nesil) |
| Orta | Samsung Galaxy A5x, Honor / Xiaomi orta sınıf (6–8 GB) | iPhone 12 / 13 |
| Üst | Samsung Galaxy S serisi, Pixel | iPhone 15 / 16 Pro |
| Özel | Çentikli, delikli, katlanabilir (dış ekran), 20:9+ uzun ekran | Dynamic Island |
| Tablet | 10" Android tablet (dikey) | iPad (dikey) |

- **Mevcut cihaz:** Projenin şu an erişebildiği tek bilinen cihaz kullanıcının Android telefonu (Honor, orta sınıf; önceki projelerden). Diğer sınıflar için cihaz temini ya da bulut cihaz çiftliği (Firebase Test Lab, BrowserStack vb.) gerekir. Bu bir **risk ve karar konusudur**.

## 9. Yaşam döngüsü ve izinler

- **Uygulama durumları:**
  - Arka plana alma ve geri dönme: maçta, eşleştirmede, satın alma penceresi açıkken, reklam oynarken.
  - Ekran kilidi.
  - Gelen arama.
  - İşletim sisteminin uygulamayı öldürmesi; yeniden açılışta "Maçın sürüyor" kartı.
- **Bildirim izni:**
  - Android 13+ `POST_NOTIFICATIONS` ve iOS izni: bağlamlı isteme, reddetme, ayarlardan sonradan açma.
  - Push'a dokununca doğru ekrana derin bağlantı.
- **Ayarlar ve sistem değişiklikleri:**
  - Dil değişimi.
  - Sistem yazı boyutu (%85–%130).
  - Karanlık mod. Uygulama kendi karanlık temasında; sistem açık moddayken de bozulma olmamalı.
  - Azaltılmış hareket.

## 10. Satın alma testleri

- **Google:**
  - Lisans test hesapları, test kartları ("her zaman onayla", "her zaman reddet", "yavaş").
  - Kapalı test kanalı.
  - RTDN test bildirimi.
  - İade ve geri alma (Play Console).
- **Apple:**
  - StoreKit Configuration dosyası ile yerel test.
  - Sandbox hesapları; hızlandırılmış abonelik yenileme.
  - Ask to Buy.
  - App Store Server Notifications sandbox uç noktası.
- **Senaryolar:**
  - Başarılı satın alma.
  - İptal.
  - Bekleyen ödeme.
  - Ödeme sonrası uygulamanın kapanması (açılışta tamamlanmalı).
  - Doğrulama sırasında ağ kopması.
  - Aynı belirteci iki kez gönderme.
  - Abonelik: deneme → yenileme → ödeme sorunu (grace) → iptal → süre dolumu.
  - Geri yükleme (yeni cihaz, farklı oyun hesabı).
  - İade sonrası altın düşümü ve öğe geri alımı.
- **Gerçek para kullanılmaz:** Bütün testler sandbox ve test hesaplarıyla yapılır.

## 11. Reklam testleri

- **Test reklamları:** Geliştirme ve staging'de Google test reklam birimleri ve test cihazı kimlikleri kullanılır. Gerçek reklama tıklamak politika ihlalidir ve **yasaktır**.
- **Senaryolar:**
  - Yükleme hatası.
  - Yarıda kapatma.
  - SSV'nin gecikmesi ya da hiç gelmemesi.
  - Günlük sınır.
  - Geçiş reklamı kurallarının (MONETIZATION §2.3) birim testleri: sayaçlar, süreler, Kulüp, yeni oyuncu.
  - UMP onay akışı (AB test coğrafyası).
  - ATT (reddet ve izin ver).

## 12. Güvenlik testleri

- **RLS:** Otomatik testler (DATABASE_SCHEMA §4).
- **Protokol bulanıklaştırma (fuzz):** Geçersiz ve aşırı büyük mesajlar, sırası dışında eylemler, başka maçın kimliği, başka oyuncunun piyonu. Hepsi reddedilmeli ve günlüğe yazılmalı.
- **Sahte makbuz:** Sahte ya da değiştirilmiş makbuzlar reddedilmeli.
- **SSV:** İmzasız ya da değiştirilmiş SSV geri çağrısı reddedilmeli.
- **Hız sınırları:** Her sınırın aşılması test edilir.
- **Yayın öncesi:** Bağımsız bir güvenlik gözden geçirmesi (en azından iç denetim: OWASP MASVS ve ASVS kontrol listesi), Faz 9.

## 13. Kapalı beta ve yayın ölçütleri

**Kapalı beta** (Faz 10):
- 50–200 oyuncu, 2 hafta.
- Ölçülenler: çökme oranı, eşleştirme süresi, terk oranı, maç süresi, ödeme akışı hataları, oyuncu geri bildirimi (uygulama içi form).

**Yayın kapısı:** Aşağıdakilerin hepsi sağlanmalı:

| Ölçüt | Hedef |
|---|---|
| Çökmesiz oturum | ≥ %99,5 |
| ANR (Android) | < %0,47 (Play'in "kötü davranış" eşiğinin altında) |
| Açık P1 hata | 0 |
| Açık güvenlik bulgusu | 0 (yüksek / kritik) |
| Kural vektörleri | %100 geçti |
| Hedef sınıflarda ölçülmüş performans | Bütçe içinde |
| Mağaza politikası kontrol listesi | Tamam |

## 14. Yayın sonrası izleme

- **Paneller:** CCU, eşleştirme süresi, maç tamamlama ve terk, hata oranları, gelir, reklam doldurma oranı.
- **Uyarılar:** TECHNICAL_ARCHITECTURE §12.
- **Haftalık:** Ekonomi raporu (kaynak / harcama dengesi, altın enflasyonu).
- **Sürüm takibi:** Kademeli açılış (%5 → %20 → %50 → %100) ve geri çekme ölçütleri.
