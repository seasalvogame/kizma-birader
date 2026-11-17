# GAME_RULES — Oyun Kuralları

> **Durum:** Faz 1 taslağı (2026-11-16). **Faz 2 sonrası güncelleme (2026-11-17):** üçüncü atış kuralı (§6.2) ve 2 kişilikte renk seçimi (§2) kesinleşti.
>
> **Kod durumu:** §6.2 Faz 3.1'de (2026-11-17) TS ve GDScript motorlarına, zar kaynaklarına ve ortak test vektörlerine işlendi.
>
> **Bu belgede ne var:**
> - Kuralların tamamı, sunucunun uygulayacağı kesin biçimde yazıldı.
> - **"Öneri"** etiketli her kural, onay bekleyen bir karardır; karar numarası (K-xx) [DECISIONS_AND_OPEN_QUESTIONS.md](DECISIONS_AND_OPEN_QUESTIONS.md) dosyasındadır.
> - Bölgeye göre değişen kurallar, kural setinde (`ruleset`) bir ayar olarak tanımlandı (§12).
>
> **İlgili belgeler:** tahta geometrisi [MAP_SPECIFICATION.md](MAP_SPECIFICATION.md), sunucu mesajları [NETWORK_PROTOCOL.md](NETWORK_PROTOCOL.md).

## 1. Terimler

| Terim | Anlamı |
|---|---|
| **Bekleme alanı** (yard) | Rengin köşesindeki 6×6 alan; piyonlar oyuna buradan başlar. |
| **Başlangıç karesi** | Piyonun parkura çıktığı, renkli ve oklu kare (adım 0). |
| **Ortak parkur** | Bütün renklerin dolaştığı 52 karelik halka. |
| **Bitiş koridoru** | Rengin kendi kolundaki 5 renkli kare + orta bitiş = 6 adım. |
| **Bitiş** | Orta alan; buraya giren piyon oyunu tamamlamıştır (adım 56). |
| **Adım** | Bir piyonun kendi yolundaki konumu: −1 = bekleme alanı, 0–50 = ortak parkur, 51–55 = koridor, 56 = bitiş. |
| **Güvenli kare** | Üzerindeki piyonun yenemediği kare: başlangıç kareleri ve yıldızlar. |
| **Tur** | Bir oyuncunun zar atma hakkı ve buna bağlı hamle; ek zar hakları aynı tura dahildir. |
| **Otopilot** | Bağlantısı kopan ya da süresi biten oyuncu için sunucunun yaptığı otomatik hamle. |

## 2. Oyuncular, renkler ve sıra

- **4 kişilik:** dört renk de oynar.
- **2 kişilik:** karşılıklı iki renk oynar (K-08, kesin):
  - Oyuncular maç öncesinde **rengini seçer**; dört renk de seçilebilir.
  - İki oyuncu aynı rengi seçemez ve **mutlaka karşılıklı** başlangıç noktalarında oturur. Geçerli çiftler: **kırmızı–sarı** ve **yeşil–mavi**. Bir oyuncunun rengi seçildiğinde diğerinin rengi kendiliğinden belli olur.
  - Renk seçimi oda oluşturma / katılma ve hızlı maç akışına entegredir. Geçersiz ya da çakışan seçimi **sunucu reddeder** (NETWORK_PROTOCOL §4). Çakışma ve sıra ayrıntıları: K-55, K-57.
  - Her oyuncu tahtayı kendi rengi sol altta görür (aşağıda "Görünüm").
- **4 kişilik düzen değişmez:** dört renk, aşağıdaki köşeler.
- **Renk düzeni** (öneri, K-07):

| Köşe | Renk |
|---|---|
| Sol üst | Kırmızı |
| Sağ üst | Yeşil |
| Sağ alt | Sarı |
| Sol alt | Mavi |

- **Hareket ve sıra yönü:** Piyonlar saat yönünde ilerler; sıra da saat yönünde döner: kırmızı → yeşil → sarı → mavi.
- **Görünüm:** Her oyuncu tahtayı kendi rengi **sol altta** olacak biçimde görür (K-09, kesin). Bu yalnızca bir görsel döndürme; sunucudaki mantıksal koordinatlar değişmez.
- **İlk oyuncu:** Sunucu rastgele seçer (güvenli rastgele sayı). İlk oyuncuyu zar atarak belirleme seçeneği daha uzun sürdüğü için önerilmiyor.

## 3. Zar

- **Zarı kim atar:** Çevrimiçi maçta zar sonucunu **yalnızca yetkili oyun sunucusu** (Cloudflare MatchRoom) üretir. Kriptografik rastgele sayı üreteci kullanılır; değer reddetme örneklemesiyle, modulo sapması olmadan çekilir.
  - Normal atış 1–6, eşit olasılıklı.
  - Üst üste iki 6'dan sonraki atış 1–5, eşit olasılıklı (§6.2).
  - İstemci yalnızca "zar at" isteği gönderir. **İstemciden gelen zar değeri hiçbir koşulda kabul edilmez.**
  - Çevrimdışı pratikte zarı cihaz üretir; aynı kurallar geçerlidir, sonuç hiçbir ödüle bağlı değildir.
- **Animasyon:** İstemci zarı sunucudan gelen sonuca göre canlandırır. Animasyon sonucu değiştirmez ve süresi sabittir (~600 ms).
- **Zaman:** Zar, istek anında üretilir; önceden üretilmiş bir dizi yoktur.
- **Ertelenen özellik (v1.1):** Maç başında tohum taahhüdü (commit–reveal) yaparak denetlenebilir zar sunulabilir (TECHNICAL_ARCHITECTURE §6).

## 4. Piyonu oyuna sokma

| # | Kural | Öneri | Ayar |
|---|---|---|---|
| 4.1 | Bekleme alanındaki bir piyonu çıkarmak için gereken zar | **Yalnızca 6** (K-10). Bazı bölgelerde 1 ya da 6. | `enter_on: [6]` |
| 4.2 | Çıkan piyonun konumu | **Başlangıç karesine** konur; o 6 ile ayrıca ilerlemez (K-11). | — |
| 4.3 | Bütün piyonlar bekleme alanında iken | Tek atış hakkı (Ludo). Klasik Kızma Birader'de 3 atış hakkı vardır. | `entry_attempts_when_all_in_yard: 1` |
| 4.4 | Başlangıç karesinde rakip piyon varsa | **Başlangıç karesi güvenlidir:** rakip yenmez, iki piyon aynı karede durur (K-17). | `capture_on_start_cell: false` |

## 5. Hareket

1. **Seçim:** Zar atıldıktan sonra oyuncu, geçerli hamlesi olan piyonlarından birini seçer. Piyon zar değeri kadar adım ilerler.
2. **Geçerli hamle:** Adımın sonucu 56'yı geçmemeli (§8) ve ayarlanmışsa blokaja takılmamalıdır (§7).
3. **Hamle listesi:** Sunucu her zar sonucuyla birlikte **geçerli hamle listesini** gönderir. İstemci yalnızca bu listedeki piyonları seçilebilir gösterir.
4. **Tek geçerli hamle varsa:** Öneri, otomatik oynanması (K-20). Oyuncu ayarlardan kapatabilir. Otomatik oynamada piyonun yolu yaklaşık 400 ms gösterilir, ardından hamle yapılır.
5. **Hiç geçerli hamle yoksa:** Zar sonucu gösterilir. "Oynanabilecek hamle yok" bildirimi ~1 sn görünür ve sıra geçer. Bu zar bir 6 idiyse ek zar hakkı yine geçerlidir (§6).
6. **Aynı yerdeki piyonlar:** Aynı karede birden çok kendi piyonu varsa ve ikisi de aynı hamleyi yapabiliyorsa hamle tek seçenek sayılır; hangi piyonun gittiği önemsizdir.

## 6. Ek zar hakları

| # | Durum | Öneri | Ayar |
|---|---|---|---|
| 6.1 | 6 atmak | Hamleden sonra **bir zar daha** (K-12). | `bonus_roll_on_six: true` |
| 6.2 | Üst üste üçüncü 6 | **Üçüncü 6 gelemez** (K-13, kesin, 2026-11-17): üst üste iki 6'dan sonraki atış yalnızca **1–5** olabilir. Ayrıntı tablonun altında. | `max_consecutive_sixes: 3`, `third_six_action: "exclude_six"` (eski: `"forfeit_turn"`) |
| 6.3 | Rakip piyon yemek | **Bir zar daha** (K-14). | `bonus_roll_on_capture: true` |
| 6.4 | Bir piyonu bitişe sokmak | **Bir zar daha** (K-15). | `bonus_roll_on_finish: true` |

**§6.2 ayrıntısı (üçüncü atış):**
- Üst üste iki 6 atan oyuncunun bir sonraki atışında zar üretici yalnızca **1, 2, 3, 4 ya da 5** üretir (eşit olasılıklı); 6 sonucu hiçbir koşulda üretilmez.
- Bu atış normal oynanır. 6 olmadığı için 6 ek zarı doğmaz; yeme ya da bitiş ek zarı (§6.3, §6.4) geçerlidir.
- Kural **yetkili sunucuda** uygulanır: zar istemciye gönderilmeden önce sunucuda üretilir ve doğrulanır. Motor da savunma olarak bu durumda 6 değerini reddeder (`INVALID_DICE`).
- Eski kural ("üçüncü 6 ile tur biter") yalnızca başka kural setleri için bir ayar değeri olarak kalır (`forfeit_turn`).
- **Bu kural kurallar ekranında açıklanmaz** (K-56, kesin).

- **Birden çok ek hak:** Aynı hamlede birden çok ek hak oluşursa (örneğin 6 atıp rakip yemek) yalnızca **bir** ek zar verilir.
- **Ardışık 6 sayacı:** Yalnızca ardışık 6'lar sayılır. Yeme ya da bitişten gelen ek zarda 6 dışında bir sayı gelirse sayaç sıfırlanır.
  - §6.2'deki sınırlı atış (1–5), sayaç 2 iken yapılan atıştır; bu atış 6 olamadığı için sayaç her zaman sıfırlanır.
  - **Örnek:** 6 → 6 → 4 ve bu 4 rakip yerse yeme ek zarı gelir. Sayaç sıfırlandığı için bu ek zar yeniden 1–6 arasıdır.

## 7. Yeme, güvenli kareler, yığılma ve blokaj

| # | Kural | Öneri | Ayar |
|---|---|---|---|
| 7.1 | Yeme | Hamle, güvenli olmayan bir karede **rakip piyonla** biterse o piyon kendi bekleme alanına döner. Yalnızca hamlenin **bittiği** kare önemlidir; üzerinden geçilen piyonlar yenmez. | — |
| 7.2 | Güvenli kareler | 4 başlangıç karesi + 4 yıldız: parkur indeksleri 0, 8, 13, 21, 26, 34, 39, 47 (K-16). Güvenli karede farklı renkten piyonlar birlikte durabilir. | `safe_cells: "starts_and_stars"` |
| 7.3 | Bitiş koridoru | Yalnızca o rengin piyonları girer; yeme olmaz. | — |
| 7.4 | Kendi piyonlarının aynı karede durması | **Serbest** (K-18). | `stacking: "allowed"` |
| 7.5 | Blokaj | **Yok** (K-18). Aynı karedeki iki kendi piyonu rakibin geçişini engellemez. Ayar `"pair_blocks"` olduğunda: aynı renkten iki piyonun durduğu kare, güvenli olsun olmasın, hiçbir rakip tarafından geçilemez ya da üzerine gelinemez; çift yenemez. | `blockade: "none"` |
| 7.6 | Güvenli olmayan karede rakip yığını | Bir karede aynı renkten 2+ piyon varken (blokaj kapalı), rakip oraya gelirse **hepsi** yenir. Alternatif: yalnızca biri yenir. Karar K-18 ile birlikte verilecek. | `capture_stack: "all"` |

## 8. Bitiş koridoru ve tam sayı

- **Koridora giriş:** Adım 50'deki piyon kendi koridoruna girer (adım 51 = K1). Ortak parkurda ikinci bir tur atmaz.
- **Tam sayı zorunluluğu:** Bitişe (adım 56) ancak **tam sayıyla** girilir (K-19). Sonucu 56'yı geçen hamle o piyon için geçersizdir; başka geçerli hamle yoksa sıra geçer.
  - Ayar: `exact_roll_to_finish: true`. Yanlış ayarlanırsa sapma kuralı (`bounce_back`) uygulanır; MVP'de önerilmiyor.
- **Bitişteki piyonlar:** Hareket etmez ve yenmez.

## 9. Kazanma ve sıralama

- **2 kişilik:** Dört piyonunu da bitişe ilk sokan **kazanır** ve maç biter.
- **4 kişilik** (öneri, K-25): Dört piyonunu da ilk bitiren 1., sonraki 2., ondan sonraki 3. olur; kalan oyuncu 4. olur ve maç biter.
  - Alternatif: "ilk bitiren kazanır" ayarı. Maçlar daha kısa sürer.
  - Ayar: `four_player_end: "until_three_finish" | "first_finisher"`.
- **Aynı sırada bitirme:** Mümkün değil; sıralama bitirme anına göredir.
- **Ödüller:** Sıraya göre verilir; miktarlar [ECONOMY_AND_PROGRESSION.md](ECONOMY_AND_PROGRESSION.md) §4'te.

## 10. Süre, zaman aşımı ve otopilot

| # | Kural | Öneri | Ayar |
|---|---|---|---|
| 10.1 | Tur süresi | Zar için **10 sn**, zardan sonra hamle için **12 sn** (K-21). Sayaç avatarın çevresinde halka olarak görünür; son 3 sn'de titreşim ve renk değişimi olur. | `turn_roll_seconds: 10`, `turn_move_seconds: 12` |
| 10.2 | Süre dolunca | Sunucu zarı atar ya da **otomatik hamleyi** yapar (§10.4). | — |
| 10.3 | Ardışık zaman aşımı | Öneri: **3 ardışık** zaman aşımında oyuncu "uzakta" sayılır ve turları otopilotla, sayaç beklenmeden (~1,5 sn gecikmeyle) oynanır (K-22). Oyuncu ekrana dokunduğunda kontrolü geri alır. | `afk_timeouts_to_autopilot: 3` |
| 10.4 | Otopilot hamle seçimi | Öncelik sırası: (1) bitişe sokan hamle, (2) rakip yiyen hamle, (3) piyon çıkarma, (4) yenme tehlikesindeki piyonu güvenli kareye kaçırma, (5) en geride kalan piyonu ilerletme. Belirleyicidir: aynı durumda aynı hamleyi seçer. | — |

## 11. Bağlantı kopması, ayrılma ve yeniden bağlanma

| # | Durum | Öneri |
|---|---|---|
| 11.1 | Bağlantı koptu | Maç **durmaz**. Kopan oyuncunun turları otopilotla oynanır (K-23). Diğer oyuncular avatarda "Bağlantı yok · mm:ss" görür. |
| 11.2 | Yeniden bağlanma | Oyuncu maç bitene kadar geri dönebilir. Sunucu ona tam durumu (snapshot) gönderir ve kontrolü hemen geri verir (NETWORK_PROTOCOL §6). |
| 11.3 | Uzun kopukluk, 2 kişilik | Rakip **90 sn** boyunca kopuk kalırsa diğer oyuncuya **"Zaferi al"** butonu çıkar. Basılırsa maç biter, kopan oyuncu "ayrıldı" sayılır. Basılmazsa maç otopilotla sürer. |
| 11.4 | Uzun kopukluk, 4 kişilik | Otopilot maç sonuna kadar oynar. Kopan oyuncu bulunduğu sırayı alır. Toplam kopukluk 5 dakikayı geçerse ödülü "ayrıldı" gibi hesaplanır (K-23). |
| 11.5 | Oyundan ayrılma (onaylı çıkış) | **2 kişilik:** rakip kazanır. **4 kişilik:** ayrılanın piyonları tahtadan kalkar, son sıraya yerleşir, maç diğerleriyle sürer. Ayrılan oyuncu ödül ve XP almaz, istatistiğine "terk" yazılır (K-24). |
| 11.6 | Terk cezası | 24 saatte 3 terk → 5 dk hızlı maç bekleme cezası; tekrarında 15 dk. Özel odalarda ceza yok (K-24). |
| 11.7 | Hep birlikte ayrılma | 4 kişilik maçta tek oyuncu kalırsa o oyuncu kalan sıralar için kazanan sayılır ve maç biter. |
| 11.8 | Sunucu çökmesi | Maçın durumu her eylemden sonra maç nesnesinin kendi kalıcı deposuna yazılır (Cloudflare Durable Object). Nesne yeniden başlarsa maç son kaydedilen durumdan sürer. Kurtarılamazsa maç **geçersiz** sayılır: giriş bedelleri iade edilir, ödül yok, ceza yok, oyunculara özür bildirimi ve küçük bir telafi verilir (architecture/CLOUDFLARE_ARCHITECTURE §6). |

## 12. Kural seti şeması (`ruleset`)

Sunucuda ve maç kayıtlarında (`matches.ruleset` JSONB) aynı yapı kullanılır. MVP'de tek bir hazır set olur: `classic_v1`.

```json
{
  "id": "classic_v1",
  "enter_on": [6],
  "entry_attempts_when_all_in_yard": 1,
  "bonus_roll_on_six": true,
  "max_consecutive_sixes": 3,
  "third_six_action": "exclude_six",
  "bonus_roll_on_capture": true,
  "bonus_roll_on_finish": true,
  "safe_cells": "starts_and_stars",
  "capture_on_start_cell": false,
  "stacking": "allowed",
  "blockade": "none",
  "capture_stack": "all",
  "exact_roll_to_finish": true,
  "auto_move_single_option": true,
  "turn_roll_seconds": 10,
  "turn_move_seconds": 12,
  "afk_timeouts_to_autopilot": 3,
  "two_player_claim_win_seconds": 90,
  "four_player_disconnect_leave_seconds": 300,
  "four_player_end": "until_three_finish"
}
```

**Sonraki sürüm için kural seti adayları:**
- **`kizma_birader_klasik`:** 3 atış hakkı, güvenli kare yok, başlangıç karesinde yeme. Tahta yıldızları bu sette yalnızca süs olur.
- **`hizli`:** her oyuncu 2 piyonla başlar ve ilk bitiren kazanır.

## 13. Kural motorunun ilkeleri

- **Saf ve belirleyici:** Kural motoru, durum + zar → yeni durum biçiminde çalışır. Rastgelelik motorun dışında üretilir ve motora girdi olarak verilir. Böylece testler tekrarlanabilir.
- **İki uygulama:** Sunucu sürümü TypeScript'te yazılır ve tek otoritedir. Çevrimdışı pratik modu için GDScript'te ikinci bir uygulama yazılır.
- **Aynı davranışın garantisi:** İki uygulama, ortak JSON test vektörleriyle aynı sonucu vermek zorundadır (TESTING_AND_PERFORMANCE §3).
- **Geçerli hamle listesi:** `legalMoves(state, dice)` her zaman sıralı ve benzersiz bir liste döndürür. İstemci yalnızca bu listeden seçim yapabilir.

## 14. Kurallara bağlı örnekler (test vektörlerinin özeti)

| # | Durum | Beklenen |
|---|---|---|
| 1 | Bütün piyonlar bekleme alanında, zar 5 | Geçerli hamle yok, sıra geçer. |
| 2 | Bütün piyonlar bekleme alanında, zar 6 | Tek hamle: piyon çıkar (adım 0); ek zar. |
| 3 | Mavi piyon adım 3'te (parkur 42), kırmızı piyon parkur 43'te (kırmızının adım 43'ü); mavi 1 atıyor | Mavi parkur 43'e gelir; bu kare güvenli değil. Kırmızı bekleme alanına döner, mavi ek zar alır. |
| 4 | Piyon adım 53, zar 4 | 57 > 56: geçersiz. Başka hamle yoksa sıra geçer. |
| 5 | Piyon adım 53, zar 3 | Bitiş; ek zar (§6.4). |
| 6 | 6, 6, sonra üçüncü atış | İlk iki 6'nın hamlesi yapılır. Üçüncü atış yalnızca 1–5 olabilir; normal hamle yapılır. 6 ek zarı yok; yeme ya da bitiş varsa onların ek zarı var. |
| 6a | Sunucu üçüncü atışta 6 değeri üretmeye çalışırsa (hata) | Motor `INVALID_DICE` ile reddeder; durum değişmez. |
| 7 | Yeşil piyon yıldız karesinde (parkur 21), kırmızı oraya geliyor | Yeme yok; iki piyon birlikte durur. |
| 8 | Kırmızı başlangıç karesinde (parkur 0) bir yeşil piyon var, kırmızı 6 atıp piyon çıkarıyor | Yeme yok (K-17); ikisi birlikte durur. |
