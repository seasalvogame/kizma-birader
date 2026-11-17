# DECISIONS_AND_OPEN_QUESTIONS — Kararlar, Açık Sorular ve Varsayımlar

> **Durum:** Faz 1 taslağı (2026-11-16); Faz 2'de ve **Faz 2 sonrası güncellemede (2026-11-17)** kesinleşen kararlar işlendi.
>
> **Kararların tek kaynağı bu belgedir.** Faz 2 sonrası kesinleşen kararlar ve yeni açık konular **§8**'de toplu olarak da listelenir. Ekonomi açık kararları (E-x) için ayrıntı: [economy/GOLD_AND_DIAMOND_ECONOMY.md](economy/GOLD_AND_DIAMOND_ECONOMY.md) §2.
>
> **Bu belgedeki hiçbir öneri kesin karar değildir.** "Öneri" sütunu benim gerekçeli tavsiyemdir. Senin onayın ya da değişikliğinle "Karar" sütunu dolar; ilgili belge güncellenir.
>
> **Öncelik:**
> - 🔴 **F2'den önce gerekli:** kural motoru, mimari ya da görsel yön buna bağlı.
> - 🟠 İlgili fazın başında.
> - 🟢 Yayından önce.

## 1. Ürün ve kapsam

| No | Öncelik | Soru | Seçenekler | Öneri | Karar |
|---|---|---|---|---|---|
| K-01 | 🟠 | Oyunun adı ve marka | "Kızma Birader Online" çalışma adı; ayırt edici bir marka adı + "Kızma Birader" alt başlığı | Ayırt edici bir ad + alt başlık (mağazada tür adı tek başına ayırt edici değil, tescil riski var). Ad önerileri ayrıca hazırlanabilir. | ⏳ |
| K-02 | 🔴 | Hedef yaş ve mağaza kitlesi | Herkes (çocuklar dahil) / 13+ | **13+**; Families / Kids programları dışında. Yaş beyanı alınıp alınmayacağı ayrıca kararlaştırılır (ön yaş sorusu ve 13 altına kısıtlı mod). | ⏳ |
| K-03 | 🟠 | MVP giriş yöntemleri | Hepsi / e-posta v1.1'e / Android'de Apple ile giriş | **Hepsi** (misafir, Google, Apple, e-posta). Android'de Apple ile giriş **isteğe bağlı**; önerim yok, çünkü ek iş. | ⏳ |
| K-04 | 🔴 | Çevrimdışı pratik (bot) MVP'de mi? | Evet / Hayır | **Evet:** eğitim, internetsiz oyun, mağaza incelemesinde oynanış. Bedeli GDScript kural motoru ve test vektörleri. | ⏳ |
| K-05 | 🟠 | Eşleşme bulunamazsa bot | Hiç / etiketli bot önerisi / gizli bot | **Etiketli bot önerisi:** 2 kişilikte 25 sn, 4 kişilikte 40 sn sonra, ödül × 0,5, sıralamaya sayılmaz. **Gizli bot yok.** | ⏳ |
| K-06 | 🟠 | Maç içi sohbet | Serbest yazı / hazır mesaj + emoji | **Hazır mesaj + emoji** (moderasyon ve yaş riski yok). | ⏳ |
| K-45 | 🟠 | Misafir hesap çevrimiçi oynayabilir mi? | Evet / yalnızca pratik | **Evet**, tam erişim; hesap bağlama teşvik edilir. | ⏳ |
| K-46 | 🟠 | Kullanıcı adı biçimi | Benzersiz ad / ad + #etiket | **Görünen ad (3–16) + 4 haneli etiket** (Ayşe#4821). Ad çakışması sorunu yok, arkadaş kodu olarak da işe yarar. | ⏳ |
| K-47 | 🟠 | Arkadaş ekleme yolları | Kod / davet bağlantısı / son oynananlar / ada göre arama / rehber | **Kod + bağlantı + son oynananlar.** Ada göre genel arama ve rehber yok (gizlilik, spam). | ⏳ |
| K-48 | 🟠 | Hesap silme | Anında / bekleme süreli | **30 gün geri alınabilir** silme; satın alma kayıtları yasal süre boyunca anonim olarak tutulur (hukuki teyit gerekli). | ⏳ |
| K-51 | 🟢 | Sezon / dereceli mod MVP'de mi? | MVP / v1.1 | **v1.1** (oyuncu havuzu oluşsun). | ⏳ |
| K-52 | 🟢 | Haftalık görevler MVP'de mi? | MVP / v1.1 | **v1.1** (MVP'de günlük görevler + başarımlar). | ⏳ |

## 2. Oyun kuralları (🔴 hepsi F2'den önce)

| No | Soru | Seçenekler | Öneri | Karar |
|---|---|---|---|---|
| K-07 | Renklerin köşeleri, yön, koridor yorumu | Çeşitli | Kırmızı sol üst, yeşil sağ üst, sarı sağ alt, mavi sol alt; piyonlar ve sıra **saat yönünde**. **"6 hücrelik bitiş koridoru" = 5 renkli hücre + orta bitiş** (15×15 geometri; MAP_SPECIFICATION §3). | ⏳ |
| K-08 | 2 kişilik renkler | Sabit karşılıklı çift / oyuncu seçer | Karşılıklı çift (kırmızı–sarı ya da yeşil–mavi). Hızlı maçta sunucu atar; özel odada oyuncu seçebilir. | ✅ 2026-11-17: **Oyuncular rengini seçer**; dört renk seçilebilir; iki oyuncu aynı rengi seçemez ve **mutlaka karşılıklı** oturur (kırmızı–sarı, yeşil–mavi); çakışmayı sunucu engeller; oda kurma / katılma akışına entegre; 4 kişilik düzen değişmez. Açık ayrıntılar: K-55, K-57. |
| K-09 | Tahtanın döndürülmesi | Sabit / yerel oyuncu sol altta | **Yerel oyuncunun rengi sol altta** (yalnızca görsel). | ✅ Faz 2: tahta yerel oyuncu sol altta olacak şekilde döndürülebilmeli |
| K-10 | Piyon çıkarma zarı | Yalnızca 6 / 1 ya da 6 / 5 ya da 6 | **Yalnızca 6** | ✅ Faz 2: yalnızca 6 |
| K-11 | Çıkan piyon | Başlangıç karesine konur / 6 adım ilerler | **Başlangıç karesine konur**; ek zar hakkı 6'dan gelir. | ⏳ |
| K-12 | 6 atınca ek zar | Evet / hayır | **Evet** | ✅ Faz 2: evet |
| K-13 | Üst üste üçüncü 6 | Tur biter / son oynanan piyon eve döner / sınır yok | **Üçüncü 6 hamlesiz, tur biter** | ✅ **2026-11-17 (Faz 2 kararının yerine):** Üst üste iki 6'dan sonraki üçüncü atışta zar **yalnızca 1–5** üretir; 6 hiçbir koşulda gelmez. Yetkili sunucuda uygulanır, istemciden zar kabul edilmez (GAME_RULES §6.2). **Faz 3.1'de iki motora ve vektörlere işlendi** (2026-11-17). Açık ayrıntı: K-56. |
| K-14 | Yeme sonrası ek zar | Evet / hayır | **Evet** | ⏳ |
| K-15 | Bitişe girince ek zar | Evet / hayır | **Evet** | ⏳ |
| K-16 | Güvenli kareler | Başlangıç + yıldızlar / yalnızca yıldızlar / yok | **4 başlangıç + 4 yıldız** (yıldız = başlangıcın 8 ilerisi) | ✅ Faz 2: başlangıç + yıldızlar |
| K-17 | Başlangıç karesinde rakip | Güvenli (yenmez) / çıkan piyon yer | **Güvenli, yenmez** | ✅ Faz 2: güvenli |
| K-18 | Yığılma, blokaj ve yığına yeme | Blokaj yok / çift blokaj; yığında hepsi / biri yenir | **Yığılma serbest, blokaj yok, yığın gelirse hepsi yenir** (ayar olarak diğerleri hazır) | ⏳ |
| K-19 | Bitişte tam sayı | Zorunlu / geri sekme | **Zorunlu** | ✅ Faz 2: zorunlu |
| K-20 | Tek geçerli hamle otomatik mi? | Evet / hayır | **Evet**, ayarla kapatılabilir | ⏳ |
| K-21 | Tur süreleri | 10 + 12 / 15 tek sayaç / farklı | **Zar 10 sn + hamle 12 sn**; özel odada 10 / 15 / 20 sn seçilebilir | ✅ Faz 2: zar 10 sn, seçim 12 sn |
| K-22 | AFK | Kaç zaman aşımında otopilot | **3 ardışık zaman aşımı → otopilot**; dokununca kontrol geri gelir | ⏳ |
| K-23 | Bağlantı kopması | Bekleme / otopilot / atma | **Otopilot hemen oynar;** 2 kişilikte 90 sn sonra rakibe "Zaferi al", 4 kişilikte 5 dk'yı aşan kopukluk "ayrıldı" gibi ödüllendirilir | ⏳ |
| K-24 | Ayrılma ve ceza | Çeşitli | Ödülsüz terk; 24 saatte 3 terk → 5 dk, sonra 15 dk eşleştirme cezası; özel odada ceza yok | ⏳ |
| K-25 | 4 kişilik bitiş | 3 sıra belirlenene kadar / ilk bitiren kazanır | **3 sıra belirlenene kadar** (daha adil sıralama; ama maç uzar; ölçülecek) | ✅ Faz 2: ilk üç belli olana kadar |

## 3. Ekonomi ve gelir

| No | Öncelik | Soru | Öneri | Karar |
|---|---|---|---|---|
| K-26 | 🟠 | Sıralama sistemi (MVP) | **Haftalık galibiyet listesi**; kupa puanı ve dereceli mod v1.1 (prototipte görünen 🏆 kupa bu alternatif içindir) | ⏳ |
| K-27 | 🔴 | Para birimi sayısı | **Tek para birimi: Altın** | ✅ Faz 2: **Altın + Elmas** (öneriden farklı). ✅ 2026-11-17: **Altın da Elmas da gerçek parayla satın alınabilir**; Altın: maç girişi, maç ödülü, günlük giriş, görev / başarım, standart kozmetik; Elmas: yalnızca premium kozmetik, maç girişi ve bahiste **asla**; transfer ve nakde çevirme yok (economy/GOLD_AND_DIAMOND_ECONOMY.md §1) |
| K-28 | 🔴 | Giriş ücreti / ödül havuzu (bahis) | **Yok** (kumar algısı ve politika riski) | ✅ Faz 2: **altınlı maç giriş bedeli var**, Elmas maç girişinde/bahiste kullanılmaz (öneriden farklı; risk notu: RISK_GOLD_ENTRY_MATCHES.md) |
| K-29 | 🟠 | Ödül miktarları, reklam ödülleri, görev yenileme | ECONOMY_AND_PROGRESSION §4–§7 ve MONETIZATION §2.2 tabloları | ⏳ |
| K-30 | 🟠 | MVP kozmetik kataloğu ve fiyatları | ECONOMY §9: 24 avatar, 6 çerçeve, 6 zar, 4 piyon seti, 3 tahta, 2 emoji seti; fiyatlar 400 / 1.200 / 2.500 / 5.000 | ⏳ |
| K-31 | 🟠 | Kulüp fiyatı, dönemleri, deneme, aile paylaşımı | Aylık 2,99 / yıllık 19,99 USD karşılığı; TR'ye ayrı katman; 7 gün deneme (yalnızca ilk abonelik); aile paylaşımı kapalı | ⏳ |
| K-32 | 🟠 | Geçiş reklamı sıklığı | Ana menüye / tekrar oynaya dönerken; ≥ 3 maç ve ≥ 4 dk arayla; ilk 5 maçta yok; günde ≤ 8 | ⏳ |
| K-33 | 🟠 | Kulüp üyesi ödüllü reklam ödülünü reklamsız alır mı? | **Evet**, aynı günlük sınırlarla | ⏳ |
| K-34 | 🟠 | IAP ürünleri ve fiyatlar; `remove_ads` ürünü olacak mı? | MONETIZATION §3.1; `remove_ads` **isteğe bağlı** (Kulüp'le çakışır; önerim MVP'de olmaması) | ⏳ |
| K-35 | 🟠 | IAP altyapısı | **Doğrudan platform API'leri**; abonelik yükü ağırsa RevenueCat. Doğrulamanın çalışacağı yer: K-61. | ⏳ |

## 4. Teknik

| No | Öncelik | Soru | Öneri | Karar |
|---|---|---|---|---|
| K-36 | 🔴 | Oyun sunucusu teknolojisi | **Supabase + özel Node.js / TypeScript + Redis** (önerdiğin yapı + Redis). Alternatif: Nakama. | ~~Faz 2: Supabase + Node.js + WSS + Redis~~ → ✅ **2026-11-17: Cloudflare Workers + Durable Objects** (yetkili oyun sunucusu, WebSocket) **+ Supabase** (Auth, Postgres, Realtime sosyal). Redis başlangıçta **yok** (gerçek ihtiyaç doğarsa). VPS / VDS + Node.js başlangıç hedefi değil; Node.js test / araç ortamı ve gelecekte alternatif olarak korunur (architecture/ONLINE_ARCHITECTURE.md). |
| K-37 | 🟠 | Barındırma sağlayıcısı ve bölge; debug APK dağıtımı | Avrupa merkezli bölge (ör. Frankfurt) ya da Türkiye'ye yakın bir bölge; sağlayıcı maliyet ve gecikme ölçümüyle seçilir. Debug APK önceki projelerdeki gibi özel bir GitHub release'iyle dağıtılır. | ✅ 2026-11-17 (kısmen): **VPS / VDS kiralanmayacak**; yönetilen servisler (Cloudflare + Supabase). ⏳ Açık: Supabase bölgesi (öneri `eu-central-1` Frankfurt), DO yerleşimi (K-62), debug APK dağıtımı. |
| K-38 | 🟠 | Supabase planı ve bölgesi | Geliştirmede ücretsiz; **prod için Pro** (ücretsiz planda otomatik yedek yok ve 1 hafta hareketsizlikte duraklatma var; gerçek parayla alınan bakiyeler için yedek şart); gerçek satın almalar başlamadan Pro'ya geçiş; PITR yayın öncesi değerlendirilir (architecture/COST_AND_SCALING.md) | ⏳ |
| K-39 | 🟠 | Push servisi | **FCM** (Android + iOS, APNs anahtarıyla) | ⏳ |
| K-40 | 🟠 | Analitik ve çökme raporlama; Play Integrity / App Attest | Çökme için Sentry (Godot SDK) ya da Crashlytics; analitik için Firebase Analytics, GameAnalytics ya da PostHog. Seçim gizlilik ve SDK yüküne göre. Integrity / Attest v1.1. | ⏳ |
| K-49 | 🟠 | En düşük işletim sistemi sürümleri; test cihazları | Godot sürümünün desteklediği en düşük Android / iOS (doğrulanacak; tipik olarak Android 7–8+, iOS 13–15+). Cihaz çiftliği hizmeti ya da 2–3 ek test cihazı. | ⏳ |
| K-50 | 🔴 | Godot sürümü | **Godot 4.x'in güncel kararlı sürümü** (makinede 4.7.2 var); eklenti uyumu F2'de doğrulanır | ✅ Faz 2: Godot 4 (4.7.2) |
| K-53 | 🔴 | Supabase Realtime kullanımı | **MVP'de kullanılmaz;** çevrimiçi durumu ve davetler oyun soketinden yürür (tek bağlantı). Senin önerinden sapma; onayın gerekli. | ✅ Faz 2: **Supabase Realtime kullanılacak** (çevrimiçi durumu, davetler, sosyal bildirimler; öneriden farklı). 2026-11-17: Realtime **yetkili oyun motorunun yerine kullanılmaz**; maç durumu ve kurallar yalnızca Cloudflare'de. |
| K-54 | 🟠 | Hesap çakışmasında birleştirme | **Birleştirme yok;** "o hesaba geç" + platform satın alımlarını geri yükleme. Alternatif: satın alınmış öğe ve altının aktarılması. | ⏳ |

## 5. Görsel, ses ve erişilebilirlik

| No | Öncelik | Soru | Öneri | Karar |
|---|---|---|---|---|
| K-41 | 🔴 | Görsel konsept | **"Akşam Masası"** (prototipler: `docs/design/screens/`). Alternatifler: B "Kahvehane Ahşap", C "Neşeli Pastel". İstersen F2'nin başında prototiplenir. | ✅ Faz 2: Akşam Masası |
| K-42 | 🟠 | Avatar ve kozmetik görsel üretimi | Seçenekler: dışarıdan illüstratör (önerilen, tutarlı stil); lisanslı paket; kendi üretimimiz (vektör, geometrik). Bütçe ve lisans durumuna göre. | ⏳ |
| K-43 | 🟠 | Ses ve müzik kaynağı | Lisanslı ses paketi + 2 özel müzik parçası (ya da telifsiz kütüphane); lisanslar belgelenir | ⏳ |
| K-44 | 🟠 | Renk körlüğü desteği | **Renk sembolleri varsayılan açık** (▲ ● ■ ◆), ayarla kapatılabilir | ⏳ |

## 6. Varsayımlar

| No | Varsayım | Doğrulama |
|---|---|---|
| V1 | Birincil pazar Türkiye; yumuşak çıkış Türkiye'de | Senin onayın |
| V2 | Bu klasör (`C:\KizmaBirader`) projenin kök klasörü; önceden bir proje yoktu (inceleme: Faz 1 raporu) | — |
| V3 | Godot GDScript (C# değil) kullanılacak | Önceki projelerinle aynı; onayın |
| V4 | Sunucu tarafı TypeScript ile yazılacak; Cloudflare Workers çalışma ortamında (K-36) | K-36 |
| V5 | Ekip küçük (sen + yapay zekâ destekli geliştirme); fazlar buna göre küçük tutuldu | Senin bilgin |
| V6 | Mağaza geliştirici hesapları (Google Play Console, Apple Developer) alınacak; iOS derlemesi için macOS ve Xcode erişimi sağlanacak | Senin bilgin; iOS için şart |
| V7 | Supabase anonim giriş, yerel kimlik belirteciyle giriş ve kimlik bağlama özelliklerinin beklenen biçimde çalıştığı | F2'de doğrulanacak |
| V8 | Godot için gereken yerel eklentilerin (IAP, AdMob, giriş, FCM) kullanılabilir olduğu | F2'de doğrulanacak |
| V9 | Prototipteki logo, avatar harfleri ve emoji ikonları **yer tutucudur**; son görseller üretilecek | K-01, K-42 |
| V10 | Fiyatlar USD karşılığı yazıldı; TL fiyatları mağaza fiyat katmanlarından seçilecek | K-31, K-34 |

## 7. Açık sorular (bilgi gerekiyor)

1. **Ekip:** Grafik, ses ve hukuki destek için dış kaynak bütçesi var mı? (K-42, K-43, gizlilik metinleri)
2. **Cihaz ve araçlar:** iOS için Mac erişimi ve Apple Developer hesabı ne zaman sağlanabilir? (V6)
3. **Hesaplar:** Google Play Console hesabı mevcut mu? (Önceki projelerde vardı; bu proje için aynı hesap mı?)
4. **Hedef pazar:** Yalnızca Türkiye mi, yoksa ilk günden İngilizce pazarlar da mı? (Sunucu bölgesi ve sıfırlama saati etkilenir.)
5. **Gelir önceliği:** Reklam ağırlıklı mı, Kulüp ağırlıklı mı? (Geçiş reklamı sıklığı ve Kulüp tanıtım sıklığı buna göre ayarlanır.)

## 8. Faz 2 sonrası güncelleme (2026-11-17)

### 8.1 Kesinleşen kararlar (kullanıcı; tekrar sorulmaz)

| Konu | Karar | Ayrıntı |
|---|---|---|
| Üst üste üçüncü 6 (K-13) | İki ardışık 6'dan sonraki atışta zar yalnızca **1–5**; sunucuda uygulanır; istemciden zar kabul edilmez | GAME_RULES §6.2 |
| 2 kişilikte renk (K-08) | Oyuncu rengini seçer; aynı renk yok; yalnızca karşılıklı çiftler (kırmızı–sarı, yeşil–mavi); sunucu çakışmayı engeller; 4 kişilik düzen değişmez | GAME_RULES §2, NETWORK_PROTOCOL §4 |
| Para birimleri (K-27, eski E-1) | Altın ve Elmas **gerçek parayla satın alınabilir**; Elmas maç girişinde ve bahiste kullanılmaz; transfer ve nakde çevirme yok; bakiyeler sunucuda, defterli, negatifsiz, idempotent | economy/GOLD_AND_DIAMOND_ECONOMY.md |
| Satın alma altyapısı | Google Play Billing ve Apple IAP ileride; doğrulama **sunucuda**; idempotency; iade / iptal yönetimi; satın alma geçmişi. Bu aşamada entegrasyon yok. | GOLD_AND_DIAMOND_ECONOMY §6 |
| Online altyapı (K-36) | Cloudflare Workers + Durable Objects (her maç bir nesne); Supabase (Auth, Postgres, Realtime sosyal) | architecture/ONLINE_ARCHITECTURE.md |
| Redis | Başlangıçta yok; yalnızca gerçek bir teknik ihtiyaç ölçülürse | ONLINE_ARCHITECTURE §1 |
| Barındırma (K-37, kısmen) | VPS / VDS kiralanmayacak; yönetilen servisler | — |
| Maliyet önceliği | Ücretsiz planlarla geliştirme ve test; mümkünse ilk yayın; güvenlik, tutarlılık ve performanstan ödün yok | architecture/COST_AND_SCALING.md |
| Supabase Realtime (K-53) | Yalnızca sosyal; yetkili oyun motorunun yerine geçmez | SUPABASE_ARCHITECTURE §7 |

### 8.2 Yeni açık kararlar

| No | Öncelik | Soru | Seçenekler | Öneri | Karar |
|---|---|---|---|---|---|
| K-55 | 🟠 Faz 4 | Hızlı maçta iki oyuncunun renk tercihi çakışırsa (ör. ikisi de kırmızı, ya da biri kırmızı diğeri yeşil) | (a) Yalnızca uyumlu tercihleri eşleştir (bekleme uzar); (b) önce kuyruğa gireninki korunur, diğeri karşı rengi alır ve maç başında bilgilendirilir; (c) rastgele | **(b)**, uyumlu eşleşme birkaç saniye önce denenir. Arayüzde "tercih, garanti değil" yazar. | ⏳ |
| K-56 | 🟠 Faz 3 | Üçüncü atış kuralı (1–5) oyuncuya açıklanacak mı? | Kurallar ekranında açıkça / açıklanmaz | **Açıklansın** (kurallar ve yardım ekranında tek cümle): güven ve şeffaflık; gizli kural fark edilince "hileli zar" şikâyetine dönüşebilir | ✅ 2026-11-17 (Faz 3): **Açıklanmayacak**; kurallar ekranında yer almaz (öneriden farklı). |
| K-57 | 🟠 Faz 5 | Özel odada renk seçim sırası (2 kişi) | (a) Oda kurucusu seçer, katılan otomatik karşı rengi alır; (b) ilk seçen kazanır; (c) ikisi de çift seçer | Katılan, kurucunun karşı rengini otomatik alır | ✅ 2026-11-17 (kullanıcı): İki kişilik özel odada **iki oyuncu da renk seçebilir**; seçilen renk diğer oyuncuyu otomatik olarak **karşı renge** geçirir (K-08 karşılıklılığı korunur). Faz 5 uygulamasıyla aynı. |
| K-58 | 🔴 kapalı betadan önce | Cloudflare planı ve geçiş zamanı | Ücretsiz kal / Workers Paid (aylık 5 USD) | Geliştirme ve iç testte **ücretsiz**; herkese açık testten önce **Paid**. Ücretsiz planda günlük limit aşımı maçları yarıda bırakır (COST_AND_SCALING §5). | ⏳ |
| K-59 | 🔴 Faz 3 | Oyun sunucusunun Supabase'e erişimi | (A) Hyperdrive + yalnızca işlev çağırabilen `game_server` rolü; (B) gizli API anahtarı + RPC | **A** (en az yetki); Faz 3 denemesiyle doğrulanır | ✅ 2026-11-17 (Faz 3): Oyun sunucusu Supabase'e **kısıtlı yetkili ayrı bir veritabanı hesabıyla** erişir; ana yetkili (service role) anahtar kullanılmaz; en az yetki. Bağlantı yolu (Hyperdrive ya da başka) Faz 3.2–3.3 denemesiyle kesinleşir. **Faz 4 (2026-11-17): Hyperdrive kesinleşti** — Supabase veritabanı sertifikası özel CA'lı olduğu için Worker TCP soketiyle doğrudan bağlantı TLS'te reddediliyor; Hyperdrive (ücretsiz, önbellek kapalı) bulutta doğrulandı. |
| K-60 | 🟠 Faz 3–5 | Maç durumunun kalıcı yazma sıklığı | A: her eylem + alarm; B: her eylem, alarm yedek; C: tur sonu | **B** (kurtarma güvencesi tam, yazmalar ~yarıya iner); ölçümle kesinleşir | ⏳ |
| K-61 | 🟠 Faz 7–8 | Satın alma doğrulamasının çalışacağı yer | Cloudflare Worker / Supabase Edge Functions / RevenueCat (K-35) | **Cloudflare Worker** (tek dil, gizli anahtarlar tek yerde) | ⏳ |
| K-62 | 🟢 Faz 5 | Durable Object yerleşimi | Varsayılan (ilk isteğe yakın) / ipucu `eeur` / `weur` | Faz 5'te TR'den gecikme ölçümüyle seçilir | ⏳ |
| K-63 | 🟠 Faz 7 | Misafir hesap satın alma yapabilir mi? | Evet / önce hesap bağlama zorunlu | **Evet, ama satın almadan önce hesap bağlama güçlü biçimde önerilir.** Misafir hesap cihazla kaybolursa tüketilen altın ve Elmas geri yüklenemez. | ⏳ |
| K-64 | 🟢 Faz 5 | Arkadaş çevrimiçi durumunun tasarımı | Supabase Realtime kanalları / oyun sunucusunda tek "sosyal merkez" | **Faz 5'te uygulanan:** Cloudflare'de tek `SocialHub` Durable Object (WebSocket, hibernation): durum yalnızca **arkadaşlara** itilir (arkadaş listesi veritabanından, `game_server`), sürekli sorgulama yok; davetler de buradan. Supabase Realtime kullanılmadı (Godot için ayrı Phoenix istemcisi gerekmedi; JWT doğrulaması ve hız sınırı oyun sunucusuyla aynı). | ✅ 2026-11-17 (Faz 5 uygulaması). Ölçeklenme yolu: kullanıcı kimliğine göre birden çok hub (ONLINE_ARCHITECTURE). |
| K-65 | 🟢 yayından önce | Hiç kalıcı hesaba bağlanmamış eski misafir hesaplarının temizliği (Supabase otomatik silmiyor) | Süre / yöntem | 180 gün hareketsiz ve satın alması olmayan misafirlerin silinmesi önerildi | ✅ 2026-11-17 (kullanıcı): Bulutta kaynağı belirsiz **üç misafir hesaba dokunulmaz**; silme ya da temizlik yapılmaz. Genel temizlik politikası **yayından önce** ayrıca değerlendirilecek. |
| K-66 | 🟠 Faz 4 | Altınlı maçta bot koltuğu olabilir mi? (K-05 bot önerisiyle ilişkili) | Hayır / evet (botun payı ne olur?) | Şimdilik **hayır**: veritabanı `BOTS_IN_GOLD_MATCH` ile reddediyor (en güvenli varsayılan) | ⏳ |
| K-67 | 🔴 mağaza öncesi | Oyuncu adlarında uygunsuz ad denetimi | Yalnızca biçim kuralı / yasaklı kelime listesi / bildirim + moderasyon | Faz 4: biçim kuralı + `ad#etiket` benzersizliği uygulandı | ✅ 2026-11-17 (kullanıcı): Uygunsuz ad denetimi **mağaza sürümünden önce zorunlu**. Yöntem (liste, TR + EN) o aşamada seçilecek. |
| K-68 | 🔴 mağaza öncesi | E-posta doğrulamasından uygulamaya güvenli dönüş | Şimdiki: Worker'daki "doğrulandı" sayfası + "Kontrol et" / App Links + Universal Links | — | ✅ 2026-11-17 (kullanıcı): Android **App Links** ve iOS **Universal Links** desteği **mağaza öncesi zorunlu**. Geliştirmede mevcut sayfa + "Kontrol et" akışı kalır. |
| K-69 | 🔴 mağaza öncesi | Oturum (yenileme belirteci) saklama | Uygulamanın özel klasörü (şimdiki) / Android Keystore + iOS Keychain | — | ✅ 2026-11-17 (kullanıcı): Geliştirme sürümlerinde mevcut yöntem kalabilir; **mağaza sürümünden önce Android Keystore ve iOS Keychain'e taşınması zorunlu**. |
| K-70 | 🟠 mağaza öncesi | Google ve Apple ile giriş | — | Kod (`OnlineSession.link_id_token`) ve kurulum belgeleri (SUPABASE_SETUP §6, IOS_SETUP) korunur | ⏳ Gerçek sağlayıcı bilgileri (OAuth istemcileri, Apple Developer) gelmeden **tamamlanmış sayılmaz**. E-postayla kalıcı hesaba geçiş de kullanıcının kendi adresiyle gerçek cihazda henüz denenmedi. |
| K-71 | 🟠 Faz 5 | Özel odada oda sahibi ayrılırsa | (a) ilk katılan kalan oyuncu; (b) oda kapanır; (c) rastgele | — | ✅ 2026-11-17 (kullanıcı): Oda sahibi ayrılırsa **ilk katılan kalan oyuncu** yeni oda sahibi olur. Odada kimse kalmazsa oda kapanır (Faz 5 uygulamasıyla aynı). |
| K-72 | 🟢 Faz 5 | Maç davetinin süresi ve sınırları | — | — | ✅ 2026-11-17 (kullanıcı): Davet süresi **120 saniye**; oyuncu başına en fazla **10 bekleyen** davet. Ayrıca: yalnızca arkadaşa, engel varsa hiçbir yönde davet yok, aynı kişiye aynı oda için ikinci davet oluşmaz (Faz 5 uygulaması). |
| K-73 | 🟢 Faz 5 | Oda kodu ve deneme sınırı | — | 6 karakter, karışabilen harf/rakam yok (31 karakter → ~8,9×10⁸ kod) | ✅ 2026-11-17 (kullanıcı): **10 dakikada 8 yanlış** oda kodu denemesinden sonra bu süre boyunca **doğru kod da reddedilir** (Faz 5 uygulamasıyla aynı). |
| K-74 | 🟢 Faz 6 | Günlük girişte gün kaçırılırsa | Döngü sıfırlanır / döngü kaldığı yerden sürer | **Döngü sürer, yalnızca ardışık gün serisi 1'e döner** (ECONOMY_AND_PROGRESSION §6 önerisi; yumuşak tasarım). Gün sınırı sunucu saatiyle TR 00:00; cihaz saati kullanılmaz. | ⏳ Faz 6.3'te bu şekilde uygulandı; onay bekliyor |
| K-75 | 🟠 Faz 6 | Ödül kasmaya karşı sınırlar | — | Oyuncu ayrıldığı için 30 hamleden önce biten maç kimseye XP / görev ilerlemesi vermez; maçlardan günlük en çok 1500 XP; özel odada XP yarım ve yalnızca arkadaş görevleri ilerler (ECONOMY_AND_PROGRESSION §4.3) | ⏳ Faz 6'da uygulandı (güvenlik incelemesi); onay bekliyor |
| K-76 | 🟠 Faz 6 | Haftalık sıralama puanı ve ödülleri | Yalnızca galibiyet sayısı (ECONOMY §8 önerisi) / sıraya göre puan | **Sıraya göre puan** uygulandı (kullanıcı: yalnızca maç sayısına dayanmasın, sıra ve galibiyet sayılsın): 2P 10/2, 4P 15/8/4/1; günlük 300 sınırı; ödüller 1: 2.000 Altın + rozet, 2–10: 1.000 + rozet, 11–100: 500 Altın (docs/economy/PROGRESSION_SYSTEMS.md §5). Mağaza öncesi: ilk 100 için hile / işbirliği denetimi ve ödül bekletme | ⏳ Değerler onay bekliyor |
| K-77 | 🟢 Faz 6 | Özel odanın ödüllere etkisi | — | Özel odada XP yarım; yalnızca "arkadaşla oyna" görevi ve sosyal başarım ilerler; sıralamaya sayılmaz (ECONOMY §4.3) | ⏳ Faz 6'da uygulandı |
| E-2…E-7 | 🟠 | Ekonomi ayrıntıları: Elmas ödülleri, kesinti, giriş seviyeleri ve özel odada altınlı maç, Elmas ↔ Altın dönüşümü, iade sonrası borç, altınlı maçın ülke / yaş kapsamı | — | economy/GOLD_AND_DIAMOND_ECONOMY.md §2 | ⏳ |

### 8.3 Geçersiz hale gelen eski kararlar ve öneriler

| Eski | Durum |
|---|---|
| K-13 "üçüncü 6 → tur biter" (Faz 2 kararı) | Yerine 8.1'deki kural geçti |
| K-36 "Supabase + Node.js + WSS + Redis" (Faz 2 kararı) | Yerine Cloudflare + Supabase geçti. Node.js ve Redis yalnızca alternatif ya da ölçek seçeneği. |
| E-1 önerisi "altın satın alınamasın" | Kararla geçersiz; risk notu güncellendi |
| MONETIZATION §5 "altın paketleri askıda" (Faz 2 notu) | Kaldırıldı; altın paketleri yeniden katalogda (K-34 fiyatları açık) |
| MONETIZATION §3.7 / DATABASE_SCHEMA "iade için −1.000.000'a kadar eksi bakiye" | Kaldırıldı; bakiye asla eksi olmaz, borç kaydı (E-6) |
| TECHNICAL_ARCHITECTURE §5–§8, §10, §13–§15: Node süreçleri, Redis kuyruk, anlık görüntü, outbox ve devralma | Yerine architecture/ belgeleri geçti |
