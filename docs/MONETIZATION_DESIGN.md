# MONETIZATION_DESIGN — Reklam, Uygulama İçi Satın Alma ve Kulüp Üyeliği

> **Durum:** Faz 1 taslağı (2026-11-16).
>
> **Onay bekleyen:** Fiyatlar, sıklıklar ve miktarlar öneridir (K-31…K-35). Sayılar uzaktan yapılandırmadan (`app_config`) okunur; yayından sonra A/B testiyle ayarlanır.

## 1. İlkeler

1. **Kazanma şansı satılmaz.** Satın alınabilen her şey görsel (kozmetik) ya da kolaylıktır. Zar, kural, eşleştirme ve süre parayla değişmez.
2. **Maç kutsaldır.** Maç sırasında hiçbir reklam, satış penceresi ya da satın alma önerisi gösterilmez. Zar atma ve hamle hiçbir koşulda bölünmez.
3. **Reklam tercihtir.** Ödüllü reklamın karşılığı önceden açıkça yazılır. Geçiş reklamı sık değildir ve yeni oyuncuya hiç gösterilmez.
4. **Dürüst satış.** Sahte geri sayım, gizli abonelik, kapatma butonunu saklamak gibi karanlık desenler (dark pattern) yoktur. Fiyatlar platformun yerel biçimiyle gösterilir.
5. **Rastgele ücretli içerik yok.** Parayla ya da parayla alınan altınla açılan rastgele kutu (loot box) yoktur (§5).

## 2. Reklamlar

### 2.1 Ağ ve SDK

- **Ağ:** Google AdMob + **UMP** (onay). Ödüllü ve geçiş reklamı biçimleri.
- **Mediation:** v1.1'de değerlendirilir; AdMob mediation ile ek ağlar (ör. AppLovin, Unity Ads). Ek SDK'lar uygulama boyutunu ve gizlilik beyanlarını büyütür.
- **İstemci mimarisi:** `AdsService` autoload (eklenti sarmalayıcısı).
  - **Önceden yükleme:** Ödüllü reklam 1 adet hazır tutulur; ana menüye girişte ve reklam kapandıktan hemen sonra yüklenir. Geçiş reklamı maç sonucu ekranında yüklenir.
  - **Hata yönetimi:** Yükleme başarısız olursa 30 sn → 60 sn → 120 sn bekleyerek yeniden denenir (en fazla 3 kez).
- **Banner reklam:** **Yok.** Hiçbir ekranda kalıcı banner bulunmaz. Gerekçe: görsel kaliteyi bozar, yanlış dokunmaya yol açar, geliri düşüktür.

### 2.2 Ödüllü reklam yerleşimleri (öneri, K-29 / K-33)

| Yerleşim (`placement`) | Nerede | Ödül | Sınır |
|---|---|---|---|
| `double_match_reward` | Maç sonucu | Maçtan kazanılan **altın × 2** (XP hariç) | Maç başına 1, günde 5 |
| `free_coins` | Mağaza > Ücretsiz altın | 50 altın | Günde 5, aralarında 2 dk |
| `quest_reroll` | Görevler | Günlük görevi yenile (ilk yenileme ücretsiz) | Günde 2 |

- **Toplam üst sınır:** Günde 12 ödüllü reklam.
- **Sınır doldu:** Buton "Yarın tekrar · 7 sa 12 dk" olarak pasifleşir.
- **Doğrulama:** Ödül **sunucuda SSV ile doğrulanır** (USER_FLOWS §11, SECURITY §8).

### 2.3 Geçiş reklamı kuralları (öneri, K-32)

Geçiş reklamı **yalnızca** maç sonucu ekranından ayrılırken gösterilir: **Ana menü** ya da **Tekrar oyna** basılınca. Aşağıdaki koşulların **hepsi** sağlanmalıdır:

| Koşul | Değer |
|---|---|
| Oyuncu Kulüp üyesi değil ve "reklamları kaldır" ürününe sahip değil | — |
| Hesabın toplam tamamlanmış maç sayısı | ≥ 5 (yeni oyuncu ilk 5 maçta hiç görmez) |
| Son geçiş reklamından beri tamamlanmış maç | ≥ 3 |
| Son geçiş reklamından beri geçen süre | ≥ 4 dk |
| Son ödüllü reklamdan beri geçen süre | ≥ 2 dk |
| Günlük geçiş reklamı | ≤ 8 |

**Hiç gösterilmez:**
- maç içinde;
- eşleştirme ekranında;
- satın alma akışında;
- uygulama açılışında;
- ana menü gezinmesinde;
- oyuncu maçtan ayrıldığında (ceza gibi algılanır).

**Yüklenmemişse:** Hiç beklenmez, reklam atlanır.

### 2.4 Reklam yüklenemediğinde davranış

| Durum | Ödüllü | Geçiş |
|---|---|---|
| Henüz yüklenmedi | Buton "Reklam hazırlanıyor…" (en fazla 5 sn), sonra "Şu an reklam yok, birazdan tekrar dene". Hak harcanmaz. | Atlanır |
| Gösterim hatası | Bildirim + hak harcanmaz | Atlanır |
| Kullanıcı yarıda kapattı | "Ödül için sonuna kadar izlenmeli"; hak harcanmaz, niyet geçerli kalır | — |
| SSV gecikti | "Ödülün doğrulanıyor"; gelirse gelen kutusu + bildirim | — |
| Çevrimdışı | Buton gizlenir | Atlanır |

### 2.5 Onay, ATT ve çocuklar

- **Onay (UMP):**
  - Uygulamanın ilk açılışında AB / BK / İsviçre için UMP onay penceresi gösterilir.
  - Ayarlar > Gizlilik'ten yeniden açılabilir.
  - Onay verilmezse kişiselleştirilmemiş ya da sınırlı reklam gösterilir.
- **iOS ATT:** İzin önce kendi açıklama ekranımızla anlatılır, sonra sistem penceresi açılır. Zamanlaması ilk ödüllü reklamdan önce, ilk oturumun sonundadır. Reddedilirse kişiselleştirilmemiş reklam gösterilir.
- **Çocuklar ve aileler:**
  - Uygulama çocuklara yönelik değildir (hedef 13+, K-02); Google Play "Families" ve Apple "Kids" kategorilerine **girmez**.
  - Mağaza hedef kitle ayarı "13+" olarak verilir.
  - Karar K-02 değişip çocuk kitlesi hedeflenirse:
    - yalnızca aile sertifikalı reklam SDK'ları kullanılabilir;
    - kişiselleştirilmiş reklam yasaklanır;
    - satın alma ve sosyal özellikler kısıtlanır.
  - Bu durumda bu belgenin yeniden yazılması gerekir.
- **İçerik filtresi:** AdMob reklam içerik derecelendirmesi **en fazla "T" (Teen)**; kumar, alkol ve flört kategorileri engellenir. Kumar reklamı masa oyunu kitlesinde özellikle risklidir.

## 3. Uygulama içi satın alma (IAP)

### 3.1 Ürün kataloğu (MVP, öneri, K-34)

| Ürün kimliği | Tür | İçerik | Fiyat katmanı (USD karşılığı) |
|---|---|---|---|
| `coins_s` | Tüketilebilir | 1.000 altın | 0,99 |
| `coins_m` | Tüketilebilir | 5.500 altın (+%10) | 4,99 |
| `coins_l` | Tüketilebilir | 12.000 altın (+%20) | 9,99 |
| `coins_xl` | Tüketilebilir | 26.000 altın (+%30) | 19,99 |
| `gems_s` … `gems_xl` | Tüketilebilir | Elmas paketleri (2026-11-17 kararı; miktar ve fiyatlar K-34 ile belirlenecek) | K-34 |
| `starter_pack` | Tüketilmeyen (tek seferlik) | 5.000 altın + Neon Zar (nadir) + Başlangıç çerçevesi | 1,99 · ilk 7 gün, 48 sa vitrin süresi |
| `pack_dice_premium` | Tüketilmeyen | 3 epik zar | 2,99 |
| `pack_board_bazaar` | Tüketilmeyen | "Çarşı" tahta teması + uyumlu piyon seti | 3,99 |
| `remove_ads` | Tüketilmeyen | Geçiş reklamlarını kalıcı kaldırır (ödüllü reklam isteğe bağlı kalır) | 3,99 (K-34: Kulüp ile çakışma) |
| `club_monthly` | Otomatik yenilenen abonelik | Kulüp Üyeliği (§4) | 2,99 / ay |
| `club_yearly` | Otomatik yenilenen abonelik | Kulüp Üyeliği | 19,99 / yıl |

**Fiyat notları:**
- Türk lirası fiyatları her mağazanın **yerel fiyat katmanlarından** seçilir. Türkiye için ayrı bir katman önerilir; satın alma gücüne göre USD karşılığından düşük olabilir (K-34).
- Görünen fiyat her zaman platformdan gelen yerelleştirilmiş metindir.
- Vergi (KDV) platform tarafından eklenir ya da dahil edilir; ödemeyi platformlar tahsil eder.

### 3.2 Neden altın + doğrudan paketler

- **Altın:** Hem oynayarak kazanılır hem satın alınır. Standart kozmetikler altınla alınır; altın ayrıca maç giriş bedelinde kullanılır (economy/GOLD_AND_DIAMOND_ECONOMY.md). Oynayan oyuncu da standart içeriğe ulaşabilir; satın alma yalnızca hızlandırır.
- **Elmas** (2026-11-17): Gerçek parayla satın alınır. Yalnızca premium kozmetiklerde kullanılır (özel zar, piyon, tahta, avatar, profil efekti). Maç girişinde ve bahiste **kullanılmaz**.
- **Doğrudan paketler:** Bazı paketler yalnızca doğrudan satın alınır; altınla alınamaz. Gerekçe: koleksiyon değeri ve gelir.
- **Pay-to-win yok:** Hiçbir ürün oyun avantajı vermez.

### 3.3 Satın alma akışı (istemci)

1. Ürün listesi platformdan çekilir (fiyat ve yerel metin); başarısız olursa mağazada "Fiyatlar yüklenemedi · Tekrar dene".
2. `POST /iap/intent` → `obfuscatedAccountId` / `appAccountToken` (kullanıcıya bağlı UUID).
3. Platform penceresi açılır.
4. Başarılıysa belirteç `POST /iap/verify` ile gönderilir; istemcide "Ödeme doğrulanıyor…" yazar.
5. Sunucu yanıtı gelince: ödül animasyonu → **ardından** istemci platformda `consume` / `acknowledge` / `finishTransaction` yapar.
   - Sunucu da onaylar (Google `acknowledge` sunucudan yapılabilir); çift onay zararsızdır.
6. Uygulama her açılışta **bekleyen (onaylanmamış) satın almaları** sorgular ve sunucuya yeniden gönderir; yarıda kalan satın almalar kaybolmaz.

### 3.4 Sunucu doğrulaması

- **Google:**
  - Tek seferlik ürünler: `purchases.products.get(packageName, productId, token)`. `purchaseState = 0` (satın alındı) olmalı; `obfuscatedExternalAccountId` eşleşmeli.
  - Abonelikler: `purchases.subscriptionsv2.get` + RTDN (Pub/Sub) bildirimleri.
- **Apple:**
  - İstemcideki StoreKit 2 `Transaction` JWS'i sunucuya iletilir. Sunucu imza zincirini doğrular ve App Store Server API'den `Get Transaction Info` ile teyit eder.
  - Abonelik durumu `Get All Subscription Statuses` ile alınır. App Store Server Notifications V2 dinlenir.
  - `appAccountToken` eşleşmeli.
- **Ödül:** `grant_iap` tek işlemde yapılır (DATABASE_SCHEMA §5); benzersiz `transaction_id` kuralı geçerlidir.

### 3.5 Satın almaları geri yükleme

- **Ne geri yüklenir:** Tüketilmeyen ürünler ve abonelikler.
- **Nasıl:** "Satın alımları geri yükle" (iOS zorunlu; Android'de de var) → platformdan sahip olunan ürünler sorgulanır → sunucuya gönderilir → sunucu, işlem kaydını **mevcut kullanıcıya** bağlar ve envanteri verir.
- **Başka bir hesaba bağlı işlem:** İşlem başka bir oyun hesabına bağlıysa (aynı mağaza hesabı, farklı oyun hesabı):
  - **Abonelik:** Yalnızca **bir** oyun hesabına bağlı olur. Öneri: en son geri yükleyen hesaba taşınır, önceki hesapta pasifleşir (K-35 ile birlikte karar).
  - **Tüketilmeyen ürünler:** Mağaza hesabına bağlı sayılır, her iki oyun hesabında da kullanılabilir. Kötüye kullanım sınırlıdır.
- **Geri yüklenmeyenler:** Tüketilebilir ürünler (altın).

### 3.6 Hata ve özel durumlar

| Durum | Davranış |
|---|---|
| Kullanıcı iptal etti | Sessiz kapanış; hata bildirimi yok |
| Bekleyen ödeme (Google "pending", ör. nakit / kart onayı) | "Ödemen onay bekliyor; tamamlanınca ürünün otomatik eklenecek." Ödül verilmez; RTDN ya da sonraki açılış kontrolüyle verilir. |
| Ask to Buy (Apple aile onayı) | Aynı: bekliyor |
| Ağ hatası (ödeme sonrası, doğrulama öncesi) | Belirteç cihazda saklanır; açılışta ve 30 sn'de bir yeniden doğrulanır. Kullanıcıya "Ürünün hazırlanıyor" gösterilir. |
| Doğrulama reddedildi (sahte / geçersiz) | "Satın alma doğrulanamadı · Destek" + günlük kaydı; ödül yok |
| Ürün zaten var (tüketilmeyen) | "Bu ürün zaten sende" + geri yükleme önerisi |
| Mağaza kullanılamıyor (ödeme kısıtı, bölge) | Mağaza ekranında "Satın alma bu cihazda kullanılamıyor" |
| Sunucu bakımı | Satın alma butonları pasif; bekleyen işlemler sonra işlenir |

### 3.7 İade, iptal ve geri alma

- **Bildirim kaynakları:** Google RTDN + Voided Purchases API (günlük tarama) ve Apple `REFUND` / `REVOKE` / `CONSUMPTION_REQUEST` bildirimleri işçiye düşer.
- **Tüketilebilir altın / Elmas iadesi:** İlgili miktar `refund_clawback` olarak düşülür.
  - **Bakiye asla eksiye düşmez** (2026-11-17 kesin kuralı). Bakiye yetmezse kalan, `wallet_debts` kaydına **borç** olarak yazılır. Borç varken altınlı maç ve mağaza kapanır, kazançlar önce borcu kapatır (E-6, açık karar).
  - **Öneri:** Satın alınan altınla alınmış kozmetikler geri alınmaz; borç yeterlidir. Bu daha basit ve oyuncuya daha az cezalandırıcıdır.
- **Tüketilmeyen ürün iadesi:** Öğe envanterden kaldırılır (`revoked_at`); kuşanılmışsa varsayılana dönülür.
- **Abonelik iadesi ve iptali:** İptal (`auto_renew = false`) dönem sonuna kadar avantajları korur. İade ya da geri alma (`revoke`) avantajları hemen bitirir.
- **İade istismarı:** 90 günde 3 iade → hesap işaretlenir, IAP geçici kapatılır (inceleme). Apple'ın `CONSUMPTION_REQUEST` bildirimine tüketim bilgisiyle yanıt verilir (ör. "ürün kullanıldı").

### 3.8 Platform farkları

| Konu | Google Play | App Store |
|---|---|---|
| Doğrulama | Play Developer API (servis hesabı) | App Store Server API (JWT, özel anahtar) |
| Gerçek zamanlı bildirim | RTDN (Pub/Sub → HTTPS push) | Server Notifications V2 (HTTPS, JWS) |
| Onay | `acknowledge` (3 gün içinde, yoksa otomatik iade) | `finishTransaction` |
| Bekleyen ödeme | Var (pending) | Ask to Buy |
| Geri yükleme butonu | İsteğe bağlı (yine de var) | Zorunlu |
| Aile paylaşımı | Yok | Abonelik ve tüketilmeyenler için açılabilir (K-31) |
| Abonelik ek süreleri | Grace period, account hold, pause | Billing grace period, billing retry |
| Teklifler | Base plan + offers (deneme, giriş fiyatı) | Introductory / promotional / offer codes |

### 3.9 Altyapı seçeneği (K-35)

| Seçenek | Artısı | Eksisi |
|---|---|---|
| **Doğrudan platform API'leri** (önerilen başlangıç) | Ek maliyet yok, tam kontrol | Abonelik durum makinesi ve bildirim işleme bizde (~2–3 hafta iş) |
| **RevenueCat** | Abonelik durumu, webhook'lar, gelir panosu hazır | Gelir payı ücreti; Godot için resmi SDK yok (doğrulanacak), istemci tarafı yine yerel eklenti + RevenueCat REST ile çalışır |

Öneri: MVP'de doğrudan API'ler. Abonelik karmaşıklığı ağır gelirse RevenueCat'e geçiş, veri modeli (`purchases` / `subscriptions`) korunarak yapılabilir.

## 4. Kulüp Üyeliği (premium)

**Avantajlar** (öneri, K-31 / K-33):

| Avantaj | Açıklama | Oyun dengesine etkisi |
|---|---|---|
| Reklamsız | Geçiş reklamı hiç yok | Yok |
| Reklamsız ödüller | Ödüllü reklam yerleşimlerinin ödülü reklam izlemeden alınır; **günlük sınırlar aynı** | Altın kazanımı biraz hızlanır; yalnızca kozmetiğe gider |
| Günlük kulüp hediyesi | Her gün 100 altın (giriş yapınca) | Aynı |
| Aylık özel kozmetik | Her ay bir kulübe özel zar ya da çerçeve; **kalıcı** (üyelik bitse de kalır) | Yok |
| Kulüp görünümü | Kulüp çerçevesi, ad yanında 👑, profil arka planı | Yok |
| Ek özelleştirme | Görünen adı her 7 günde bir ücretsiz değiştirme; 2 ek emoji seti | Yok |

**Üyelik dışı kalanlar:**
- Zar, eşleştirme, süre, kural ve sıralama puanı **etkilenmez**.
- Kulüp üyeleri ayrı bir kuyruğa alınmaz.

**Fiyatlandırma ve deneme:**
- Aylık 2,99, yıllık 19,99 USD karşılığı; TR katmanı ayrı (K-31).
- İsteğe bağlı **7 gün ücretsiz deneme**, yalnızca ilk abonelikte.
- Deneme bitmeden 2 gün önce uygulama içi hatırlatma; platformlar da hatırlatır.

**Yaşam döngüsü:**

| Durum | Avantajlar |
|---|---|
| Aktif | Hepsi |
| Ödeme sorunu (grace) | Devam; "Ödeme yöntemini güncelle" şeridi |
| Account hold / billing retry | Kapalı; kozmetikler (aylık ödüller) kalır |
| İptal edildi (dönem sonu) | Dönem sonuna kadar devam |
| Süresi doldu | Kulüp çerçevesi ve 👑 kalkar; kuşanılmış kulübe özel **görünüm** öğeleri varsayılana döner; aylık ödül olarak kazanılan kozmetikler kalır |

**`remove_ads` ile çakışma:** Kulüp, reklamsızlığı zaten içerir. `remove_ads` sahibine Kulüp sayfasında "Reklamsızlık zaten sende" bilgisi gösterilir. `remove_ads` ürününün MVP'de olup olmayacağı K-34 ile kararlaştırılır.

## 5. Politika sınırları

> **Faz 2 ve sonrası güncelleme (2026-11-17):**
> - Altınlı maç giriş bedeli **var**.
> - **Altın ve Elmas gerçek parayla satın alınabilir;** altın paketleri artık askıda değil.
> - Elmas maçta ve bahiste kullanılmaz; nakit ve transfer yok.
> - Aşağıdaki "giriş ücreti yok" maddesinin yerine [economy/GOLD_AND_DIAMOND_ECONOMY.md](economy/GOLD_AND_DIAMOND_ECONOMY.md) ve [RISK_GOLD_ENTRY_MATCHES.md](RISK_GOLD_ENTRY_MATCHES.md) geçerli.
> - Altınlı maçlar, hukuki ve mağaza politikası incelemesi tamamlanmadan yayına hazır sayılmaz.


- **Rastgele ücretli kutu yok.** Günlük giriş, görev bonusu ve seviye ödülleri **sabit ve önceden gösterilen** içeriklerdir.
  - Gerekçe: birçok ülkede düzenleme ve mağaza açıklama zorunlulukları; çocuk koruma riski; marka güveni.
- **Altınlı maç giriş bedeli** (K-28, kesin karar; Faz 1 önerisinin yerine):
  - Model ve kurallar economy/GOLD_AND_DIAMOND_ECONOMY.md §5'te.
  - Satın alınabilen bir para birimiyle şansa dayalı kazanç bazı ülkelerde **kumar** sayılabilir ve mağaza politikalarında risklidir. Önlemler ve yayın öncesi kontrol listesi RISK_GOLD_ENTRY_MATCHES.md'de.
  - Altınsız ücretsiz modlar her zaman açık kalır.
- **Oyuncular arası alım satım ya da transfer yok.**
- **Mağaza yönergeleri:** Fiyatlar, abonelik koşulları, otomatik yenileme açıklaması, iptal yolu, geri yükleme, gizlilik ve koşul bağlantıları.

## 6. Ölçüm ve deneyler

- **Olaylar** (analitik; onaylı kullanıcılarda): `store_view`, `product_view`, `purchase_start`, `purchase_success` / `fail{reason}`, `ad_offer_shown`, `ad_start`, `ad_reward`, `ad_fail{reason}`, `interstitial_shown`, `club_view`, `club_start_trial`, `club_convert`, `club_cancel`.
- **Temel ölçütler:** ARPDAU, ödeme yapan oranı, ilk satın alma süresi, ödüllü reklam katılımı (gösterilen → izlenen), geçiş reklamının geri dönüşe etkisi (kontrol grubuyla), deneme → ücretli dönüşüm.
- **Uzaktan yapılandırma** (`app_config.ad_policy`, `store_offers`): Sıklıklar, ödül miktarları ve vitrin içeriği uygulama güncellemesi gerektirmeden değişir. Bütün değişiklikler sürümlü olarak kaydedilir.
