# Faz 1 Raporu — Oyun Tasarımı, UI/UX, Teknik Mimari ve Ürün Dokümantasyonu

> **Tarih:** 2026-11-16
> **Durum:** Tamamlandı. Oyun kodu, sahne ya da Godot projesi oluşturulmadı.
> **Onay bekleyen kararlar:** [docs/DECISIONS_AND_OPEN_QUESTIONS.md](docs/DECISIONS_AND_OPEN_QUESTIONS.md)

## 1. İncelenen mevcut proje yapısı

- **Belirtilen klasör yoktu.** Promptta bir proje klasörü belirtilmemişti. `C:\` ve `D:\` kök dizinleri, kullanıcı klasörü ve masaüstü tarandı (Ludo / Kızma Birader adlı klasör araması dahil).
- **Bulunanlar başka projelere ait:**
  - `CoffeeEmpire`, `YeniOyun`, `SeaSalvo` klasörleri.
  - `Klavuz` klasörleri: SeaSalvo ve Deniz Korsanları oyun kılavuzları.
- **Sonuç:** Bu proje için daha önce oluşturulmuş bir Godot projesi ya da belge **yoktu**. Hiçbir mevcut dosya silinmedi ya da değiştirilmedi.
- **Yeni klasör:** `C:\KizmaBirader` oluşturuldu, önceki projelerinle aynı düzende (V2).

```
C:\KizmaBirader\
  README.md, PHASE_1_REPORT.md
  docs\  (16 belge)
  docs\design\board\    board_map.json, board_indices.png
  docs\design\screens\  10 ekran prototipi + overview.png
  docs\design\_src\     prototip kaynakları, fontlar (OFL), betikler
```

## 2. Oluşturulan belgeler

16 belge [README.md](README.md) içinde tek tek listelendi.

**Ek tasarım çıktıları:**
- **Tahta geometrisi:** `board_map.json`; kural motoru ve istemci bu tek kaynağı kullanacak.
- **İndeksli tahta şeması.**
- **10 ekran prototipi** (1080×2340): açılış, giriş, ana menü, maç kurma, eşleştirme, 4 kişilik maç, 2 kişilik maç, maç sonucu, mağaza, arkadaşlar.

## 3. Oyunun baştan sona nasıl çalışacağı

1. **İlk açılış:** Oyuncu açılış ekranından giriş ekranına gelir. Misafir olarak tek dokunuşla başlar ya da Google / Apple / e-posta ile giriş yapar. Görünen ad ve avatar seçer; isterse 3 dakikalık eğitim maçını oynar.
2. **Ana menü:** 2 Kişi, 4 Kişi, Özel Oda ve Pratik; günlük ödül, günlük görevler, arkadaş etkinliği. Alt menüde Arkadaşlar, Mağaza, Görevler ve Sıralama.
3. **Hızlı maç:**
   - Mod seçilir ve eşleştirmeye geçilir; hedef bekleme 15–30 sn. Uzarsa etiketli bot önerilir.
   - Sunucu odayı kurar. Tahta, oyuncunun rengi sol altta olacak biçimde döndürülür.
   - Sırası gelen oyuncu zarı atar; zarı **sunucu** üretir.
   - Geçerli piyonlar parlar; oyuncu dokunur, piyon ilerler.
   - Yeme, güvenli yıldızlar, 6 ile ek zar ve bitiş koridoru klasik kurallarla işler.
4. **Kopma:** Bağlantı koparsa maç durmaz, otopilot oynar; oyuncu geri dönünce tam durumu alır.
5. **Maç sonu:** Sıralama ve ödül (altın + XP) gösterilir. İsteğe bağlı ödüllü reklamla altın ikiye katlanır. Ana menüye ya da tekrar oynamaya geçerken, kurallar uygunsa, geçiş reklamı gösterilir.
6. **Uzun vade:** Seviye, görev, başarım, haftalık sıralama ve kozmetik koleksiyonu. Altınla ya da satın almayla kozmetik alınır; Kulüp Üyeliği reklamsız deneyim ve özel görünüm sağlar.
7. **Arkadaşlar:** Kodla eklenir; çevrimiçi durumları görülür; özel odaya davet edilir (uygulama içi ya da push).

## 4. UI/UX tasarım sisteminin özeti

- **Konsept "Akşam Masası"** (K-41):
  - koyu mürdüm ve gece mavisi zemin, soluk yıldız dokusu (yıldız = marka motifi = güvenli kare);
  - tahtanın arkasında sıcak lamba hâlesi;
  - krem kartlar ve koyu cam paneller.
- **Renk rolleri:**
  - Eylem renkleri oyuncu renklerinden ayrık: mango (ana eylem), böğürtlen (reklam ve ödül), nane (sosyal), altın (para).
  - Oyuncu renkleri (kırmızı, yeşil, sarı, mavi) **yalnızca** tahta ve oyuncu öğelerinde kullanılır.
  - Renk körlüğü için semboller: ▲ ● ■ ◆.
- **Tipografi:** Baloo 2 (başlık ve sayı) + Nunito (gövde); ikisi de SIL OFL lisanslı ve Türkçe karakterler doğrulandı.
- **Butonlar:** Kalın alt kenarlı, basınca gömülen "oyun butonları". Dokunma alanı en az 44 pt; ekran başına tek ana eylem.
- **Tasarım tokenları:** boşluk, köşe, boyut, gölge, hareket süreleri.
- **Hareket:** Bir turun zorunlu animasyonları en fazla 1,6 sn. "Hızlı animasyon" ve "azaltılmış hareket" seçenekleri var.
- **Ekran:** Yalnızca dikey; güvenli alan (çentik, Dynamic Island, hareket çubuğu) hesaba katıldı. Tahta her zaman kare kalır; en küçük taban 320 pt genişlik. Kısa ekran (16:9) ve tablet düzenleri tanımlandı.
- **Ekranlar ve akışlar:** 26 ekran amaç, yerleşim, etkileşim, boş / yükleniyor / hata durumları, küçük ekran davranışı ve animasyonlarıyla tanımlandı. Menü hiyerarşisi ve akışlar Mermaid diyagramlarıyla çizildi.

## 5. Önerilen teknik mimari

| Katman | Teknoloji |
|---|---|
| İstemci | Godot 4 (GDScript), 2D, Compatibility renderer; yerel eklentiler: Billing, StoreKit, AdMob + UMP, Google ve Apple girişi, FCM |
| Kimlik ve veri | Supabase Auth (anonim, Google, Apple, e-posta) + Postgres; RLS her tabloda açık, istemci **yazamaz** |
| Oyun sunucusu | Node.js / TypeScript: `api` (REST), `realtime` (WSS: lobi, eşleştirme, otoriter maç odaları), `worker` (zamanlı işler, mağaza bildirimleri, push) |
| Redis | Eşleştirme kuyrukları, maç anlık görüntüleri (çökmede devam), çevrimiçi durumu, hız sınırları, idempotency |

**Temel ilkeler:**
- Zar sunucuda `crypto.randomInt` ile üretilir; kurallar sunucuda doğrulanır; istemci yalnızca istek gönderir.
- İstek kimliği, tur kimliği ve durum sürümü ile tekrar ve yarış koşulları önlenir.
- Maç sonucu outbox deseniyle tek işlemde yazılır.
- Service role anahtarı yalnızca sunucuda bulunur.

**Önerinden iki sapma** (onayına sunuldu):
1. **Redis eklendi.**
2. **Supabase Realtime MVP'de kullanılmıyor** (K-53): çevrimiçi durumu ve davetler oyun soketinden yürüyor, böylece telefonda tek kalıcı bağlantı oluyor.

**Değerlendirilen alternatifler:** Nakama (hazır sosyal ve eşleştirme sistemleri, resmi Godot istemcisi) ve Colyseus. Gerekçeler TECHNICAL_ARCHITECTURE §2'de.

## 6. Gelir modelinin özeti

- **Reklam:**
  - Banner yok.
  - Ödüllü reklam yalnızca isteğe bağlı: maç altınını ikiye katlama, ücretsiz altın, görev yenileme. Günlük sınırlar var; ödül sunucuda SSV ile doğrulanır.
  - Geçiş reklamı yalnızca maç sonucundan **ayrılırken**: 3 maçta ve 4 dakikada en fazla bir; ilk 5 maçta hiç; maç içinde **asla**.
  - UMP onayı, iOS ATT ve reklam içerik filtresi (kumar yok) var.
- **Uygulama içi satın alma:**
  - Altın paketleri, tek seferlik başlangıç paketi ve kozmetik paketler.
  - Sunucu doğrulaması (Play Developer API, App Store Server API), mağaza bildirimleri, bekleyen ödeme, geri yükleme ve iade sonrası geri alma tanımlandı.
- **Kulüp Üyeliği (aylık / yıllık):**
  - Reklamsız deneyim, ödüllerin reklamsız alınması, günlük 100 altın, aylık kalıcı kozmetik, kulüp görünümü.
  - Kazanma şansını hiçbir biçimde etkilemez.
- **Kesin sınırlar:** Pay-to-win yok, bahis / giriş ücreti yok, rastgele ücretli kutu yok, karanlık desen yok.

## 7. Kesinleştirilmesi gereken oyun kuralları

| No | Konu | Öneri |
|---|---|---|
| K-07 | Renk düzeni, yön ve koridor yorumu | Kırmızı sol üst, saat yönü; "6 hücrelik koridor" = 5 renkli hücre + orta bitiş |
| K-08 | 2 kişilik renkler | Karşılıklı çift |
| K-09 | Tahta döndürme | Yerel oyuncu sol altta |
| K-10 | Piyon çıkarma zarı | Yalnızca 6 |
| K-11 | Çıkan piyonun yeri | Başlangıç karesi |
| K-12 | 6 atınca ek zar | Evet |
| K-13 | Üçüncü 6 | Tur biter |
| K-14 | Yeme sonrası ek zar | Evet |
| K-15 | Bitişe girince ek zar | Evet |
| K-16 | Güvenli kareler | Başlangıçlar + yıldızlar |
| K-17 | Başlangıç karesinde rakip | Yenmez |
| K-18 | Yığılma / blokaj | Yığılma serbest, blokaj yok |
| K-19 | Bitişte tam sayı | Zorunlu |
| K-20 | Tek geçerli hamle | Otomatik |
| K-21 | Tur süreleri | Zar 10 sn + hamle 12 sn |
| K-22 | AFK | 3 zaman aşımı → otopilot |
| K-23 | Bağlantı kopması | Otopilot; 2 kişilikte 90 sn sonra "Zaferi al" |
| K-24 | Terk | Ödülsüz; kademeli eşleştirme cezası |
| K-25 | 4 kişilik bitiş | İlk 3 sıra belirlenene kadar |

Hepsi kural setinde ayar olarak tanımlandı; farklı bölgesel kurallar kod değişmeden açılabilir.

## 8. Teknik riskler

1. **Godot yerel eklentileri:** IAP, AdMob, giriş ve push eklentilerinin olgunluğu ve Godot sürümüyle uyumu. Faz 2'de cihazda denenecek; gerekirse özel ince eklenti yazılacak.
2. **Supabase'de kimlik bağlama:** Anonim hesaba yerel kimlik belirteciyle kimlik bağlamanın davranışı **doğrulanmadı**. Faz 2'de denenecek; alternatif yollar belirlendi.
3. **Oyuncu yoğunluğu:** İlk aylarda düşük olursa eşleştirme süreleri uzar. Önlem: etiketli bot önerisi ve tek bölge.
4. **Cihaz erişimi:** Yalnızca bir Android telefon biliniyor. iOS için Mac, Xcode ve Apple Developer hesabı gerekiyor; cihaz çiftliği ya da ek cihaz kararı gerekli.
5. **İki kural motorunun tutarlılığı:** Sunucu (TypeScript) ve çevrimdışı mod (GDScript) ortak test vektörleriyle sürekli denetlenecek.
6. **Mağaza politikaları:** Giriş seçenekleri, abonelik metinleri, hesap silme, gizlilik beyanları, yaş hedefi.
7. **Görsel ve ses üretim kaynağı belirsiz** (K-42, K-43).

## 9. MVP kapsamı (v1.0)

| Alan | İçerik |
|---|---|
| Oyun | 2 ve 4 kişilik hızlı maç, özel oda (kod, davet, bot doldurma, rövanş), çevrimdışı pratik ve eğitim |
| Hesap | Dört giriş yöntemi, misafir yükseltme, hesap silme |
| Sosyal | Arkadaşlar, çevrimiçi durumu, davet ve push, gelen kutusu, engelleme, şikâyet, hazır mesaj + emoji |
| İlerleme | XP / seviye, 7 günlük giriş ödülü, 3 günlük görev, ~20 başarım, haftalık galibiyet sıralaması |
| Ekonomi | Tek para birimi (altın), kozmetik mağazası (avatar, çerçeve, zar, piyon, tahta, emoji) |
| Gelir | Ödüllü ve geçiş reklamı, IAP, Kulüp Üyeliği |
| Dil | TR / EN |

**MVP dışı:** Dereceli mod ve sezonlar, haftalık görevler, etkinlikler, maç izleme, kulüpler, turnuvalar, serbest sohbet, yeni diller. Bunlar v1.1 ve sonrasına bırakıldı.

## 10. Faz 2'de yapılacak işler

1. **🔴 Kararlar:** Önce bu kararlar onaylanmalı: K-02, K-04, K-07…K-25, K-27, K-28, K-36, K-41, K-50, K-53.
2. **Depo yapısı ve CI:** lint, gizli anahtar taraması, testler.
3. **TypeScript kural motoru** (`@kb/rules`): kural seti şeması, `legalMoves`, `apply`, `botMove`. ≥ 150 test ve 10.000 maçlık değişmez testi.
4. **GDScript kural motoru:** Ortak JSON test vektörleriyle %100 eşitlik.
5. **Godot proje iskeleti:** yalnızca dikey yön, ölçekleme, güvenli alan servisi, tema tokenları, Compatibility renderer denemesi.
6. **Gerçek cihazda eklenti denemeleri:** Billing, StoreKit, AdMob + UMP, Google ve Apple girişi, FCM, güvenli depolama, derin bağlantı. Uyumluluk raporu hazırlanacak.
7. **Supabase yerel yığını:** ilk migration; anonim giriş ve kimlik bağlamanın doğrulanması.
8. **Rapor:** `PHASE_2_REPORT.md`.
