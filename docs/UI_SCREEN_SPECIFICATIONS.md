# UI_SCREEN_SPECIFICATIONS — Ekran Spesifikasyonları

> **Durum:** Faz 1 taslağı (2026-11-16).
>
> **Bağlantılar:** Bütün ekranlar [UI_UX_DESIGN_SYSTEM.md](UI_UX_DESIGN_SYSTEM.md) tokenlarını kullanır. Akışlar [USER_FLOWS.md](USER_FLOWS.md) dosyasında.
>
> **Prototip görseller:** `docs/design/screens/NN_*.png`; ekranın başlığında belirtilir.
>
> **Kısaltmalar:** GA = güvenli alan, KK = krem kart, CP = cam panel, PB = primary buton.
>
> **Ekran yönü:** Bütün ekranlar **yalnızca dikey**.

**Her ekran için ortak kurallar:**
- **Yükleme:** 300 ms'den kısa yüklemelerde gösterge yok. 300 ms – 3 sn arası iskelet kartlar. 3 sn'den uzun sürerse metin ("Hâlâ yükleniyor…") ve iptal / tekrar dene.
- **Ağ hatası:** Üst bildirim + "Tekrar dene". Ekran boş kalmaz; varsa son başarılı veri gösterilir.
- **Geri hareketi:** Android'de geri tuşu / hareketi ve iOS'ta kenardan kaydırma bir önceki ekrana döner. Maç ekranında "Maçtan çık" onayı açılır.
- **Küçük ekran (320×568):** Kartlar tek sütuna iner, yatay listeler kaydırılır, ikincil metinler 1 satıra kısaltılır (…).

---

## 1. Açılış / Splash — `01_acilis.png`

- **Amaç:** Marka ilk izlenimi; oturum yenileme, yapılandırma ve sürüm kontrolü.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Boş |
| Orta | Lamba hâlesi; dört piyondan küme; kelime işareti "KIZMA BİRADER" + "ONLINE" |
| Alt | İlerleme çubuğu, durum metni ("Masa hazırlanıyor…"), sürüm |

- **Akış:** Sistem açılış ekranı (tek renk + logo, platform zorunluluğu) → bu ekran. İkisi aynı görünür, geçiş fark edilmez.
- **Yapılan işler (sırayla):**
  1. Yerel ayarlar.
  2. Oturum belirteci (token) yenileme.
  3. `GET /config`: en düşük sürüm, bakım durumu, özellik bayrakları.
  4. Kozmetik katalog önbelleği.
  5. Yönlendirme: giriş ekranına ya da ana menüye.
- **Hedef süre:** 2,5 sn'den kısa. Gerekenden uzun bekletilmez.
- **Durumlar:**

| Durum | Ne olur |
|---|---|
| Çevrimdışı | "İnternet yok" kartı: **Tekrar dene**, **Pratik oyna** (çevrimdışı mod) |
| Zorunlu güncelleme | Mağazaya yönlendiren tam ekran kart; uygulama kullanılamaz |
| Bakım | "Kısa bir bakımdayız · tahmini 20 dk" + Pratik oyna |

- **Animasyon:** Piyonlar sırayla 80 ms arayla zıplayarak belirir; logo `ease_back` ile gelir.

## 2. Giriş ve hesap oluşturma — `02_giris.png`

- **Amaç:** İlk açılışta oyuncuyu en kısa yoldan oyuna sokmak, bunu yaparken kalıcı hesabı teşvik etmek.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Dil seçici hapı (🌐 Türkçe) |
| Orta | Logo + KK: başlık "Masaya hoş geldin!" + tek cümle; **Google ile devam et** (beyaz), **Apple ile devam et** (siyah; yalnızca iOS'ta ve Android'de isteğe bağlı), **E-posta ile devam et** (beyaz çerçeveli), ayraç "veya", PB **Misafir olarak oyna** |
| Alt | Kullanım Koşulları ve Gizlilik Politikası bağlantıları |

- **Kurallar:**
  - Apple ile girişin görsel kurallarına uyulur (siyah buton, logo). Google için marka kurallarına uyulur.
  - iOS'ta Google girişi varsa Apple ile giriş **zorunludur** (App Store Yönergesi 4.8). Android'de Apple ile giriş isteğe bağlıdır (K-03).
- **Etkileşimler:**

| Eylem | Sonuç |
|---|---|
| Google / Apple | Yerel giriş penceresi → sunucuda doğrulama → profil yoksa **Görünen ad** adımı (§2a) |
| E-posta | §2b |
| Misafir | Anonim hesap oluşturulur → otomatik görünen ad ("Oyuncu#4821") → kısa eğitim teklifi |

- **§2a Görünen ad:** Tek alan (3–16 karakter), önerilen ad, avatar seçimi (24 avatar, 4×6 ızgara). Ad uygunluğu canlı denetlenir; argo ve yasaklı sözcük filtresi var. Etiket (#4821) otomatik verilir.
- **§2b E-posta:**
  1. E-posta alanı → **Devam**.
  2. Hesap varsa şifre alanı ve "Şifremi unuttum".
  3. Yoksa şifre oluştur (en az 8 karakter, güç göstergesi) → doğrulama e-postası.
  - Doğrulama beklenirken oyuna geçilebilir; kalıcı özellikler (satın alma geri yükleme dışında) doğrulama sonrasında açılır.
- **Hatalar** (satır içi, alanın altında kırmızı `caption`):
  - "Bu e-posta başka bir hesapta kullanılıyor"
  - "Şifre yanlış · 3 deneme hakkın kaldı"
  - "Giriş iptal edildi"
  - "Google hesabına ulaşılamadı, tekrar dene"
- **Yükleniyor:** Basılan buton yükleniyor durumuna geçer, diğerleri pasifleşir.
- **Küçük ekran:** Logo 28 pt'ye iner, alt metin 2 satır olur.

## 3. Misafir olarak devam etme

- **Amaç:** Hiç bilgi istemeden oyna; riskleri dürüstçe anlat.
- **Akış:** Misafir butonu → tek seferlik bilgi alt sayfası (KK):
  - "Misafir hesabın bu cihazda saklanır. Uygulamayı silersen ya da telefon değiştirirsen ilerlemen kaybolabilir. İstediğin zaman Google, Apple ya da e-posta ile güvenceye alabilirsin."
  - **Anladım, oyna** (PB) · **Hesap bağla** (ghost).
- **Sonradan hatırlatmalar** (en fazla 1 / gün):

| Ne zaman | Nasıl |
|---|---|
| İlk satın alma öncesinde | Zorunlu değil, güçlü öneri |
| 5. seviyede | Hatırlatma kartı |
| 3. arkadaş eklenince | Hatırlatma kartı |
| Hesap ekranında | Sürekli "Hesabını güvenceye al" şeridi |

## 4. Ana menü — `03_ana_menu.png`

- **Amaç:** Tek dokunuşla maça girmek; günlük döngüyü (ödül, görev, arkadaş) görünür kılmak.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst (GA + 56) | Avatar (46) + ad + XP çubuğu (dokununca profil), altın hapı (+ → mağaza Altın sekmesi), ayarlar ikonu. Premium üyede avatarın çevresinde premium çerçeve ve ad yanında 👑. |
| Orta, sırayla | Günlük ödül şeridi (CP, hazırsa "Al"); **2 Kişi** ve **4 Kişi** mod kartları (2 sütun, 150 pt; dokununca §6); **Özel Oda** ve **Pratik** kutuları; günlük görevler KK (ilk 2 görev, kalan süre); arkadaş etkinlik şeridi ("Mehmet çevrimiçi · Davet et") |
| Alt | Alt menü: Ana Sayfa · Arkadaşlar (rozet: istek sayısı) · Mağaza · Görevler (rozet: alınmamış ödül) · Sıralama |

- **Etkileşimler:**
  - Mod kartına dokununca §6 Maç kur açılır. "Hızlı başlat" ayarı açıksa doğrudan eşleştirmeye geçilir.
  - Uzun basınca son kullanılan ayarlarla hemen eşleştirme başlar (ipucu ilk seferde gösterilir).
- **Boş durumlar:**
  - Arkadaş yoksa şerit "Arkadaşlarını davet et · Kodunu paylaş" olur.
  - Görevlerin hepsi bittiyse "Yarın yeni görevler · 6 sa 12 dk".
- **Yükleniyor:** Görev ve arkadaş kartları iskelet hâlde; mod kartları **her zaman** hemen kullanılabilir.
- **Hata:** Sunucuya ulaşılamıyorsa mod kartları pasifleşir ve üstte "Bağlantı yok · Tekrar dene" şeridi çıkar. Pratik açık kalır.
- **Animasyon:**
  - Girişte kartlar 40 ms arayla aşağıdan kayar.
  - Altın değişince sayı 600 ms boyunca sayarak artar ve hap bir kez zıplar.
- **Küçük ekran:** Mod kartları 128 pt'ye iner; arkadaş şeridi gizlenir (Arkadaşlar sekmesinde zaten var).

## 5. Oyuncu profili

- **Amaç:** Kimlik, ilerleme ve koleksiyonu göstermek; sosyal eylemlere kapı açmak.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Geri, başlık, (kendi profilinde) düzenle ikonu |
| Orta | KK başlık: büyük avatar (88) ve çerçeve, ad#etiket (dokununca kopyalanır), seviye ve XP çubuğu, üyelik rozeti. İstatistik ızgarası 2×3: Maç · Galibiyet · Galibiyet % · Yenen piyon · En uzun seri · Favori mod. Vitrin: kuşanılmış zar, piyon, tahta, çerçeve. Başarımlar: son 6 rozet + "Tümü" |
| Alt | Başkasının profilinde: **Arkadaş ekle** / **Davet et** (çevrimiçiyse), "⋯" menüsü (Engelle, Şikâyet et) |

- **Düzenleme:** Ad değiştirme (ilk değişiklik ücretsiz, sonrası 30 günde bir), avatar ve çerçeve seçimi (alt sayfa, sahip olunanlar önce, kilitliler soluk ve kilit ikonlu).
- **Boş durum:** 0 maçta istatistik yerine "İlk maçını oyna!" ve buton.
- **Gizlilik:** Engellenen kullanıcı profili göremez ("Profil kullanılamıyor").

## 6. Oyun modu seçimi — `04_mac_kur.png`

- **Amaç:** Modu ve kuralları netleştirip tek dokunuşla eşleştirmeye geçmek.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Geri, "Hızlı Maç", altın hapı |
| Orta | Sekme: **2 Kişi / 4 Kişi**; mini tahta önizlemesi (210 pt; 2 kişilikte kullanılmayan alanlar soluk); KK "Klasik kurallar": kural etiketleri (6 ile çık, Yıldızlar güvenli, 6 = tekrar at, 10+12 sn) + "Kurallar ⓘ" (alt sayfada tam kurallar, görselli); ödül önizlemesi (sıraya göre altın ve XP); CP kuşanılmış zar ve piyon + "Değiştir ›" |
| Alt | PB XL **OYNA** |

- **Hata:** Terk cezası sürüyorsa OYNA pasifleşir ve "4:12 sonra tekrar deneyebilirsin" yazar. Neden bilgisi ⓘ ile açılır.
- **Küçük ekran:** Mini tahta 150 pt; kural etiketleri yatay kaydırılır.

## 7. 2 kişilik oyun lobisi

> **Not:** "Lobi" burada iki şey demektir:
> - Hızlı maçta eşleştirme ekranı (§9).
> - Özel odada bekleme odası (§13).
>
> Bu bölüm özel odanın **2 kişilik** bekleme düzenini tanımlar.

- **Amaç:** Davet edilen arkadaşı beklemek, hazır olunca başlatmak.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Geri (odayı kapatma onayı), "Özel Oda · 2 Kişi", oda kodu hapı **K7Q-4MZ** (dokununca kopyalanır) |
| Orta | İki büyük koltuk kartı (yukarıda rakip, aşağıda sen), her biri renk halkalı avatar + ad + "Hazır ✓ / Bekleniyor…"; renk seçici (2026-11-17, K-08 kesin: dört renkten biri seçilir; rakibin rengi otomatik karşı renk olur; yalnızca kırmızı–sarı ve yeşil–mavi; kurucu değiştirir, katılan görür, K-57); kural özeti KK (özel odada kural seti değiştirilebilir — v1.1) |
| Alt | **Arkadaş davet et** (mint; alt sayfada çevrimiçi arkadaşlar), **Kodu paylaş** (sistem paylaşım penceresi, derin bağlantı), PB **Başlat** (yalnızca oda sahibi ve ikisi de hazırsa) |

- **Durumlar:**
  - Davet gönderildi → koltukta "Davet edildi · 0:45" geri sayımı.
  - Reddedildi → "Ayşe daveti reddetti" bildirimi.
  - Rakip ayrıldı → koltuk boşalır.
- **Zaman aşımı:** Boş oda 10 dk sonra kapanır (uyarı 1 dk önce).

## 8. 4 kişilik oyun lobisi

- §7 ile aynı. Farklar:
  - 2×2 koltuk ızgarası; sol üst kırmızı, sağ üst yeşil, sağ alt sarı, sol alt mavi (tahtaya göre).
  - Boş koltukta "+ Davet et".
- **Oda sahibi seçenekleri:**
  - Boş koltuğu **bot** ile doldurmak ("Bot" etiketli; özel odada ödül yok, ECONOMY §4.3).
  - Oyuncuyu çıkarmak (onaylı).
- **Başlatma koşulu:** En az 2 insan oyuncu varsa ve boş koltuk kalmadıysa (bot dahil) başlatılabilir. 3 kişilik oyun **yoktur**.

## 9. Eşleştirme — `05_eslestirme.png`

- **Amaç:** Beklemeyi kısa ve keyifli hissettirmek; iptal her zaman mümkün olsun.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Başlık "Rakipler aranıyor" + mod |
| Orta | Koltuk kartları (2 ya da 4). Bulunan oyuncu kartı çevrilerek açılır (avatar, ad, seviye); arananlar kesikli ve "?" ile nabız atar. Sayaç "00:12" ve "Ortalama bekleme ~20 sn". İpucu kartı (CP, kurallardan dönen ipuçları) |
| Alt | Ghost **Vazgeç** |

- **Durumlar:**

| Durum | Ne olur |
|---|---|
| Eşleşti | 600 ms'lik "Maç bulundu!" kutlaması; tahta yakınlaşarak maç ekranına geçilir |
| 25 sn (2 kişilik) / 40 sn (4 kişilik) | "Bot ile oyna" önerisi kartı (K-05): **Bekle** / **Botla oyna** |
| Bağlantı koptu | "Yeniden bağlanılıyor…", ardından kuyruğa otomatik dönüş |
| Sunucu dolu | "Yoğunluk var, sıradasın" ve sıra numarası |

- **Kurallar:**
  - Vazgeç anında bir eşleşme tamamlanırsa sunucu oyuncuyu maça almaz (yarış koşulu: iptal önceliklidir).
  - Arka plana alınınca kuyruk korunur. 60 sn içinde dönülmezse oyuncu kuyruktan çıkarılır.

## 10. Arkadaşlar — `10_arkadaslar.png`

- **Amaç:** Arkadaşları görmek, davet etmek, istekleri yönetmek.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Başlık + "＋ Ekle" |
| Orta | Sekme **Arkadaşlar / İstekler (rozet) / Son oynanan**; KK arkadaş kodu (AYSE#4821, Kopyala, Paylaş); listeler (her satır: avatar ve durum noktası, ad, durum metni, eylem) |
| Alt | Alt menü |

- **Listeler:**
  - **Arkadaşlar:** Çevrimiçi (yeşil nokta) → Maçta (altın nokta, "Maçta · 4 Kişi") → Çevrimdışı (gri nokta, "3 sa önce"). Davet butonu yalnızca çevrimiçi olanlarda.
  - **İstekler:** Gelen istekler (Kabul ✓ / Reddet ✕), gönderilenler ("Bekliyor · Geri çek").
  - **Son oynanan:** Son 20 maçtaki rakipler ("Ekle" butonu; engellenenler hariç).
- **Satır eylemleri:** Satıra dokununca profil; sola kaydırınca **Sil** (onaylı); "⋯" ile Engelle / Şikâyet et.
- **Boş durum:** "Henüz arkadaşın yok" + illüstrasyon + **Kodunu paylaş**.
- **Sınırlar:** En fazla 200 arkadaş, en fazla 50 bekleyen giden istek (SECURITY §9).

## 11. Arkadaş ekleme

- **Amaç:** Arkadaşı kod, bağlantı ya da yakın zamanda oynanan oyuncular üzerinden eklemek (K-47).
- **Yerleşim** (alt sayfa):
  - Alan "Arkadaş kodu (ör. MEHMET#2231)"; kod biçimi canlı denetlenir.
  - **Ara** → sonuç kartı: avatar, ad, seviye, **İstek gönder**.
  - Alt bölüm: "Bağlantıyla davet et" (paylaşım) ve "Son oynananlar" kısayolu.
- **Durumlar:**

| Durum | Ne olur |
|---|---|
| Bulunamadı | Satır içi "Bu kodla oyuncu bulunamadı" |
| Kendi kodu | "Bu senin kodun 🙂" |
| Zaten arkadaş | Buton yerine "Arkadaşsınız" |
| Engellenmiş | "Bu oyuncuya istek gönderilemiyor" |
| Sınır aşıldı | "Çok fazla istek gönderdin, biraz sonra dene" |

- **Gizlilik:** Ada göre genel arama **yok**; kötüye kullanımı ve rahatsız etmeyi azaltır.

## 12. Davet ve bildirim ekranları

- **Uygulama içi davet** (uygulama açıkken):
  - Üstten kayan büyük bildirim: avatar + "Mehmet seni 4 Kişilik maça davet ediyor".
  - **Katıl** (mint) / **Reddet** ve 30 sn geri sayım çubuğu.
  - Maç içindeyken davetler **gösterilmez**; gelen kutusuna düşer ve maç sonunda özet olarak gösterilir.
- **Push bildirimi** (uygulama kapalıyken): "Mehmet seni maça davet etti 🎲". Dokununca uygulama açılır ve doğrudan odaya katılma onayına gider (derin bağlantı). Davet süresi dolduysa "Davetin süresi doldu" ve odaya katılma isteği gönderme seçeneği.
- **Gelen kutusu** (zil ikonu, ana menü üst barında; v1.0):

| Bildirim türü | Eylem |
|---|---|
| Arkadaş isteği | Kabul / Reddet |
| Davet | Katıl |
| Ödül hazır | Al |
| Sistem duyurusu | Oku |

  - Okunmamışlar kalın ve sol tarafında nokta. 30 günden eski bildirimler silinir.
- **Bildirim izni:** İlk arkadaş eklemede ya da ilk davet gönderiminde **bağlam içinde** sorulur. Önce uygulamanın kendi açıklama kartı ("Davetleri kaçırma"), sonra sistem izni. İlk açılışta istenmez.

## 13. Özel oda oluşturma

- **Amaç:** Arkadaşlarla kurallı ve kodlu oda kurmak.
- **Yerleşim** (KK, alt sayfa):
  - Oyuncu sayısı 2 / 4.
  - Kural seti (MVP: yalnızca Klasik; diğerleri "yakında").
  - Tur süresi: 10 / 15 / 20 sn (yalnızca özel oda; K-21).
  - **2 kişilikte renk** (2026-11-17): dört renk seçeneği; seçilen rengin karşısı rakibe ayrılır, önizlemede gösterilir.
  - **Oda oluştur** → §7 / §8 lobi.
- **Odaya katılma:** "Koda katıl" alanı (6 karakter, `XXX-XXX`, karışabilecek karakterler — 0/O, 1/I — hariç) ya da derin bağlantı.
- **Hatalar:** "Oda bulunamadı", "Oda dolu", "Oda sahibi seni engellemiş" (genel ifade: "Bu odaya katılamazsın").

## 14. Oyun tahtası / aktif maç ekranı — `06_mac_4_kisi.png`, `07_mac_2_kisi.png`

- **Amaç:** Tahtayı odakta tutarak sırayı, durumu ve hamleyi hiç düşündürmeden göstermek.

### 14.1 Düzen — 4 kişi (360×780)

```
┌──────────────────────────────────────┐  ← GA üst
│ [≡]        4 Kişi · Klasik       [💬] │  56 pt üst bar (menü, mod etiketi, hızlı mesaj)
│ (K)Kerem ●○○○        Deniz ●Bağlantı yok (D)│  52 pt: rakip kartları (sol üst = kırmızı, sağ üst = yeşil)
│ ┌──────────────────────────────────┐ │
│ │                                  │ │
│ │        TAHTA 336×336 (kare)      │ │  Yerel oyuncunun rengi sol altta (döndürme, K-09)
│ │                                  │ │
│ └──────────────────────────────────┘ │
│ (A)Sen ○○○○ ·9sn [SIRA SENDE]  Selin ●●○○ (S)│  60 pt: alt kartlar (sol alt = sen, sağ alt = sarı)
│              ┌────────┐              │
│              │  ZAR   │ 92 pt        │  Zar alanı: yerel oyuncunun sırasında parlar
│              └────────┘              │
│   ( Oynatmak istediğin piyona dokun ) │  İpucu hapı (bağlama göre)
└──────────────────────────────────────┘  ← GA alt
```

- **Oyuncu kartları:** Tahtanın dört köşesine, kendi alanlarının yanına yerleşir; renkle konum eşleşir.
  - **İçerik:** Avatar (renk halkası, seviye rozeti), ad, bitiş noktaları (4 küçük daire, biten dolu), durum.
  - **Durumlar:**

| Durum | Görünüm |
|---|---|
| Sırada | Avatarda sayaç halkası, kartta hafif parlama, "SIRA SENDE" (yerel) ya da avatarın büyümesi (rakip) |
| Bağlantı yok | Kırmızı nokta + "Bağlantı yok · mm:ss"; avatar soluk |
| Otopilot | 🤖 rozeti |
| Ayrıldı | Kart soluk + "Ayrıldı"; piyonlar tahtadan kalkar |
| Bitirdi | Altın taç + sıra numarası |

  - **Rakip zarı:** Rakip zar attığında kartın yanında küçük zar (36 pt) görünür.
- **Üst bar:**
  - **≡ menü** (alt sayfa): Kurallar, Ses / Müzik anahtarı, "Maçtan ayrıl" (kırmızı, onaylı ve ceza uyarılı).
  - **💬 hızlı mesaj** (§15.4).
- **Bilgi akışı:** Önemli olaylar üstte kısa bildirim olarak görünür ("Mehmet senin piyonunu yedi! 😈", "Selin 2. piyonunu bitirdi"). Aynı anda en fazla 1 bildirim; sıradakiler kuyruğa girer.

### 14.2 Düzen — 2 kişi

- **Rakip** üstte, tam genişlikte CP kartında: avatar, ad, bitiş noktaları, kupa / seviye, zarı.
- **Yerel oyuncu** altta, tam genişlikte kartta: zar alanı kartın sağında; yerel sırada büyüyüp ortaya çıkar.
- **Tahta** iki kartın arasında; dikeyde ortalanır.
- **Altta** hızlı mesaj kısayolları (3 emoji + "İyi oyun!").

### 14.3 Kısa ekran (16:9, 360×640)

```
┌──────────────────────────────────────┐
│ [≡] (K)Kerem ●○  (D)Deniz ●○     [💬] │  Üst bar ve rakip kartları birleşir (44 pt)
│ ┌──────────────────────────────────┐ │
│ │          TAHTA 336×336           │ │
│ └──────────────────────────────────┘ │
│ (A)Sen ○○○○ [ZAR 76] (S)Selin ●●○○   │  Alt kartlar ve zar tek satırda (84 pt)
└──────────────────────────────────────┘
```

### 14.4 Uzun ve geniş ekranlar

- **20:9 ve üstü:** Fazla yükseklik tahtanın üstüne ve altına eşit dağıtılır. Zar alanı alt güvenli alana yakın kalır; başparmak erişimi için tahtanın altında olması önemlidir.
- **Tablet:** Tahta en fazla 560 pt; kartlar tahtanın köşelerine hizalanır.

### 14.5 Maç ekranındaki durumlar

| Durum | Ne olur |
|---|---|
| Yükleniyor | Maç ekranı, sunucudan ilk tam durum (snapshot) gelene kadar tahta ve kartları iskelet hâlinde gösterir (en fazla ~1 sn). |
| Yerel bağlantı koptu | §25 katmanı tahtanın üstünde. Tahta son durumda donar; yeniden bağlanınca tam durum gelir ve fark animasyonsuz uygulanır. |
| Sunucu hatası, maç iptal | "Maç sunucusu bir sorunla karşılaştı. Maç sayılmadı." + telafi bilgisi + Ana menü. |

## 15. Zar atma ve piyon seçme kontrolleri

### 15.1 Zar

- **Sıra yerel oyuncudaysa:**
  - Zar alanı mango hâleyle nabız atar.
  - **Zara dokunmak** ya da zar alanında **yukarı fırlatma hareketi** zarı atar.
  - Çift dokunma koruması: istek gönderilince buton 1,2 sn kilitlenir; yanıt gelince açılır.
- **Gecikmeli yanıt:** Zar dönmeye başlar. Sunucu yanıtı 1,5 sn'den uzun sürerse "Bağlantı yavaş…" ibaresi çıkar. Yanıt gelmezse istek **aynı istek kimliğiyle** yeniden gönderilir (NETWORK §7); çift zar oluşmaz.
- **Otomatik zar** (ayar, varsayılan kapalı): Sıra gelince 0,8 sn sonra zar kendiliğinden atılır.

### 15.2 Piyon seçimi

- **Gösterim:** Geçerli piyonlar parlar; seçilemeyen piyonlar normal kalır.
- **Önizleme:** Bir piyona dokununca (ya da üzerinde parmak tutulunca) hedef kare ve yol önizlenir.
- **Hamle yöntemi** (ayar "Dokun ve oyna", varsayılan): **Tek dokunuşla** hamle yapılır.
  - Alternatif ayar "Seç ve onayla": ilk dokunuş seçer, ikinci dokunuş oynar. Yeni oyuncular ve yanlış dokunmaya hassas kullanıcılar için.
- **Dokunma alanı:** 44 pt; en yakın geçerli piyon seçilir (MAP_SPECIFICATION §7).
- **Aynı karede farklı hamleli piyonlar:** Küçük bir seçim balonu açılır.
- **Yönlendirme:**
  - Yeni oyuncunun ilk 3 maçında ipucu hapı çıkar: "Piyon çıkarmak için 6 at", "Yıldızlar güvenli".
  - Sonrasında ipucu yalnızca 6 sn hareketsizlikte görünür.

### 15.3 Süre

- Sayaç halkası avatarda döner.
- Son 3 sn'de halka kırmızıya döner, tik-tak sesi ve hafif titreşim olur.
- Süre dolunca sunucu hamle yapar ve "Süre doldu · otomatik oynandı" bildirimi çıkar (GAME_RULES §10).

### 15.4 Hızlı mesajlar

- **İçerik:** 💬 ile açılan alt sayfa: 8 emoji + 8 hazır cümle ("İyi oyun!", "Bol şans!", "Tebrikler!", "Ups!", "Hadi ama 😄", "Teşekkürler", "Tekrar?", "Bekle beni").
  - Hazır cümleler her oyuncunun kendi dilinde görünür (anahtar tabanlı).
- **Görünüm:** Mesaj, gönderenin avatarından konuşma balonu olarak 2,5 sn çıkar.
- **Sınır:** 10 sn'de en fazla 3 mesaj.
- **Susturma:** Oyuncu kartından tek oyuncu ya da herkes susturulabilir.

## 16. Maç sonucu — `08_mac_sonucu.png`

- **Amaç:** Sonucu kutlamak ya da teselli etmek, ödülü göstermek ve oyuncuyu bir sonraki maça yönlendirmek.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Kupa / madalya illüstrasyonu; "1. oldun!" / "2. oldun" / "Bu sefer olmadı"; mod + süre |
| Orta | KK sıralama: sıra, avatar, ad, altın; ayrılanlar "Maçtan ayrıldı · ödül yok"; diğer oyuncular için **＋ Arkadaş ekle**. CP ödüller: altın, XP, (v1.1) kupa ve seviye çubuğu. Seviye atlanırsa §17 araya girer |
| Alt | Berry **▶ İzle · Altını 2 katına çıkar** (yalnızca kazanılan altın > 0 ise; günlük sınırda değilse); **Ana menü** (secondary) + **Tekrar oyna** (PB; aynı mod, yeni eşleştirme) |

- **Özel odada:** "Tekrar oyna" aynı odada **rövanş** önerir. Herkes kabul ederse yeni maç başlar.
- **Geçiş reklamı:** Yalnızca **Ana menü** ya da **Tekrar oyna** basıldıktan sonra ve sıklık kurallarına uyuyorsa gösterilir (MONETIZATION §2.3). Kutlama ve ödül ekranı asla bölünmez.
- **Animasyon:** Sıralama satırları 120 ms arayla gelir; altın ve XP sayarak artar; 1.'likte konfeti var (dokununca atlanır).

## 17. Ödül ve ilerleme ekranı

- **Amaç:** Seviye atlama, görev ve başarım tamamlama anlarını ödüllendirmek.
- **Görünüm:** Tam ekran kutlama katmanı, gece perdesi + ışık hüzmesi.
  - "Seviye 13!" + açılan ödüller kart kart çevrilir (altın, kozmetik).
  - **Topla** (PB).
- **Birden çok ödül:** Sıraya girer; "1/3" sayacı ve **Hepsini topla** seçeneği.
- **Kurallar:** Maç içinde gösterilmez; maç sonucundan sonra ya da ana menüde gösterilir.

## 18. Sıralama tablosu

- **Amaç:** Rekabet hissi (MVP: haftalık galibiyet sıralaması, K-26).
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Başlık; sekme **Genel / Arkadaşlar**; "Sıfırlanmaya 3 g 4 sa" |
| Orta | İlk 3 için podyum kartı (büyük avatarlar, altın / gümüş / bronz); liste (sıra, avatar, ad, galibiyet). Kendi satırı listenin altında yapışkan kart olarak her zaman görünür ("Sen · 1.284. · 23 galibiyet") |
| Alt | Alt menü |

- **Boş durum:** Arkadaş sekmesinde arkadaş yoksa davet çağrısı.
- **Yükleniyor:** İlk 50 satır gelir, kaydırdıkça sayfalanır.
- **Ödül:** Haftalık ilk 100'e kozmetik rozet (öneri; ECONOMY §8).

## 19. Görevler ve başarımlar

- **Yerleşim:**
  - Sekme **Günlük / Başarımlar** (v1.1'de Haftalık).
  - **Günlük:** 3 görev kartı (ikon, metin, ilerleme, ödül). Tamamlanınca kart parlar ve **Al** butonu çıkar.
    - "Yenile" (günde 1 ücretsiz, sonra ödüllü reklamla; K-29).
    - Üstte sıfırlanma sayacı. Hepsi bitince bonus sandığı (sabit içerik: 100 altın).
  - **Başarımlar:** Kategori başlıkları (Maç, Sosyal, Koleksiyon), rozet ızgarası. Kilitliler gri ve ilerleme yüzdesi gösterir. Dokununca açıklama alt sayfası.
- **Boş durum:** Yok; her zaman görev vardır.

## 20. Mağaza — `09_magaza.png`

- **Amaç:** Kozmetik ve altın satışı; premium tanıtımı. Rahatsız etmeyen, vitrin gibi bir mağaza.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Başlık + altın hapı |
| Orta | Sekmeler (yatay kaydırma): **Öne çıkan · Zarlar · Piyonlar · Tahtalar · Çerçeveler · Avatarlar · Altın**. Öne çıkan: Kulüp Üyeliği bandı, başlangıç paketi (zamanlı, tek seferlik), günlük vitrin (3 ürün, her gün değişir), ücretsiz altın (ödüllü reklam, kalan hak). Ürün kartı: nadirlik etiketi, önizleme, ad, fiyat (altın ya da yerel para birimi). Sahip olunanlar "Sende ✓", kuşanılan "Kullanılıyor" |
| Alt | Alt menü |

- **Ürün ayrıntısı** (alt sayfa): Büyük önizleme (zar dönerek, piyon tahtada, tahta tam görünüm), açıklama, **Satın al / Kuşan**.
- **Satın alma akışı:**
  - **Altınla:** Onay penceresi ("1.200 altın harcanacak") → animasyon → "Kuşan" önerisi. Yetersiz altında "Eksik 300 altın · Altın al" yönlendirmesi.
  - **Gerçek parayla:** Platform ödeme penceresi → "Ödeme doğrulanıyor…" (sunucu doğrulaması) → ödül animasyonu. Hatalar MONETIZATION §3.6'da.
- **Fiyat gösterimi:** Platformdan gelen yerelleştirilmiş fiyat metni (₺49,99) kullanılır; elle biçimlendirme yapılmaz.
- **Yasal metinler:**
  - Altın paketlerinde altının kullanım alanları dürüstçe yazılır: kozmetik ve maç girişi. **Nakde çevrilemez, transfer edilemez.** Metin hukuki incelemeyle kesinleşir (RISK_GOLD_ENTRY_MATCHES.md).
  - Elmas paketlerinde: "Elmas yalnızca premium kozmetiklerde kullanılır; maçlarda kullanılmaz."
  - Gerekli bölgelerde fiyat ve KDV bilgisi platform penceresinde.
- **Sandık yok:** Rastgele içerikli ücretli kutu (loot box) yoktur (MONETIZATION §5).

## 21. Reklam karşılığı ödül ekranı

- **Amaç:** Reklamı izlemeden önce ne kazanılacağını açıkça göstermek.
- **Akış:** Ödüllü eylem (ör. "Altını 2 katına çıkar") → küçük onay kartı:
  - "30 saniyelik bir reklam izleyerek **+80 altın** kazan" · **İzle** (berry) / **Vazgeç**.
  - Kalan hak: "Bugün 3/5".
- **Sonrasında:** Reklam → dönüşte "Ödül doğrulanıyor…" (sunucu tarafı doğrulama, en fazla 3 sn) → ödül animasyonu.
- **Hatalar:**

| Durum | Ne olur |
|---|---|
| Reklam yüklenemedi | "Şu an reklam yok, birazdan tekrar dene" |
| Yarıda kapatıldı | "Ödül için reklamın sonuna kadar izlenmesi gerekiyor" |
| Doğrulama gecikti | Ödül gelen kutusuna düşer: "Ödülün hazır" |

- **Premium üyede:** Aynı kart "Kulüp üyesi olarak reklamsız al" (berry yerine mint) (K-33).

## 22. Premium üyelik ekranı

- **Amaç:** Kulüp Üyeliği'ni dürüst ve net biçimde satmak.
- **Yerleşim:**

| Bölge | İçerik |
|---|---|
| Üst | Kapat (X; her zaman görünür, gizlenmez) |
| Orta | Premium degrade başlık "Kulüp Üyeliği 👑"; avantaj listesi (ikon + tek satır): Reklamsız maçlar · Aylık özel kozmetik · Kulüp çerçevesi ve rozeti · Her gün +100 altın · Reklamsız ödüller; plan kartları **Aylık** / **Yıllık** ("%40 tasarruf" etiketi; fiyatlar platformdan); varsa deneme ("7 gün ücretsiz, sonra ₺…/ay") |
| Alt | PB **Üye ol**; küçük yazıyla otomatik yenileme açıklaması ("Abonelik, iptal edilmezse dönem sonunda otomatik yenilenir. Ayarlar > Abonelikler'den iptal edebilirsin."); **Satın alımları geri yükle** (iOS zorunlu, Android'de de var); Koşullar · Gizlilik bağlantıları |

- **Üye olunca:** Yerleşim "Üyeliğin aktif · yenilenme tarihi …" ve "Aboneliği yönet" (platform sayfasına bağlantı) olur.
- **Mağaza kuralları:** Fiyat ve dönem satın alma butonundan daha belirgin olmamalı ama açıkça okunmalıdır. Yanıltıcı geri sayım yok (MONETIZATION §4).

## 23. Ayarlar

- **Gruplar** (KK'lar alt alta):

| Grup | İçerik |
|---|---|
| **Hesap** | Hesap türü (Misafir / Google / Apple / E-posta), **Hesabını güvenceye al** (misafirde), bağlı hesaplar, çıkış yap, **Hesabı sil** |
| **Oyun** | Tek hamleyi otomatik oyna, Dokun ve oyna / Seç ve onayla, Otomatik zar, Hızlı animasyon, Rakip kozmetiklerini basit göster |
| **Ses** | Müzik, efektler, titreşim (kaydırıcı ve anahtar) |
| **Bildirimler** | Davetler, arkadaş istekleri, günlük ödül hatırlatması, etkinlikler (her biri ayrı anahtar) |
| **Erişilebilirlik** | Renk sembolleri, azaltılmış hareket |
| **Dil** | §24 |
| **Gizlilik** | Reklam tercihleri (onay penceresini yeniden aç), veri indirme talebi, gizlilik politikası |
| **Destek** | SSS, sorun bildir (otomatik cihaz bilgisi + oturum kimliği), sürüm |

- **Hesap silme:** İki adım: açıklama → "SİL" yazarak onay. 30 gün içinde giriş yapılarak geri alınabilir (K-48). Aktif abonelik varsa önce platformdan iptal edilmesi gerektiği anlatılır.
- **Kaydetme:** Değişiklikler anında kaydedilir; "Kaydet" butonu yok.

## 24. Dil seçimi

- **Liste:** Dil adları **kendi dilinde** yazılır: "Türkçe", "English" (ileride "العربية"). Seçili dilde ✓.
- **Etki:** Seçim anında uygulanır; ekran yeniden kurulur, yeniden başlatma gerekmez. Sağdan sola diller seçildiğinde arayüz aynalanır (LOCALIZATION §6).
- **Varsayılan:** Cihaz dili desteklenmiyorsa İngilizce.

## 25. Bağlantı kesildi / yeniden bağlanma

- **Katman:** Ekranın üstünde, gece perdesi (%55) + ortada CP kartı:
  - dönen bağlantı ikonu, "Yeniden bağlanılıyor…", deneme sayacı "2. deneme".
  - **Maçta:** "Maçın devam ediyor · Senin yerine otopilot oynuyor" (GAME_RULES §11).
- **Akış:**
  1. **Yeniden bağlanma:** Üstel geri çekilme (0,5, 1, 2, 4, 8, 15 sn; sonra 15 sn aralıkla). Ağ değişince (Wi-Fi ↔ mobil veri) hemen denenir.
  2. **15 sn sonra:** **Ana menüye dön** seçeneği eklenir. Maçtaysan: "Maç sürüyor; döndüğünde kaldığın yerden devam edersin."
  3. **Bağlantı gelince:** Kart 300 ms'de kaybolur, "Tekrar bağlandın" bildirimi çıkar, tam durum uygulanır.
- **Maç bitmiş olabilir:** Bağlantı geldiğinde maç bitmişse doğrudan maç sonucu gösterilir.
- **Uygulama yeniden açıldığında:** Süren bir maç varsa ana menü yerine "Maçın sürüyor · Dön" kartı çıkar.

## 26. Hesap bağlama ve hesap yükseltme

- **Giriş noktaları:** Ayarlar > Hesap, misafir hatırlatma kartları, profil.
- **Yerleşim:**
  - KK "Hesabını güvenceye al":
    - avantajlar: telefon değiştirsen de ilerlemen kalsın · satın alımların korunsun · arkadaşların seni bulsun;
    - Google / Apple / E-posta butonları.
  - Bağlı hesaplar listesi; her biri "Bağlı ✓" ve (birden çok bağlıysa) "Bağlantıyı kaldır".
- **Çakışma:** Bağlanmak istenen hesap başka bir oyun hesabına aitse (K-54), karşılaştırma kartı açılır:

| Bu cihazdaki hesap | Google hesabındaki |
|---|---|
| Sv. 7 · 3.200 altın | Sv. 21 · 12.000 altın |

  - Seçenekler:
    - **O hesaba geç:** Bu cihazdaki misafir ilerlemesi kaybolur. Satın alımlar platformdan geri yüklenir. Onay için "Anladım" kutusu işaretlenir.
    - **Vazgeç**.
  - Otomatik birleştirme **yoktur**. Ayrıntılar USER_FLOWS §3.
- **Başarı:** "Hesabın güvende! 🎉" + küçük ödül (öneri: 200 altın, tek seferlik; ECONOMY §5).
