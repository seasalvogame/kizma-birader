# LOCALIZATION_SPECIFICATION — Çok Dilli Destek

> **Durum:** Faz 1 taslağı (2026-11-16).
>
> **Kapsam:** v1.0'da **Türkçe (tr)** ve **İngilizce (en)**. Mimari; yeni Latin dillerini (de, fr, es, pt-BR, ru…) ve **sağdan sola yazılan** dilleri (ar, fa) kod değişikliği olmadan alacak biçimde hazırlanır.

## 1. İlkeler

1. **Kodda sabit metin yok:** Oyuncuya görünen hiçbir metin koda yazılmaz. Her metin bir **anahtardır**; CI'da sabit metin taraması yapılır (TESTING §3).
2. **Kaynak dil:** Kaynak dil **İngilizce** anahtar + Türkçe ve İngilizce çeviriler. Çevirmen araçlarıyla uyum için gettext PO kullanılır.
3. **Birleştirme yok:** Cümleler parça parça birleştirilmez. Değişkenli metinler adlandırılmış yer tutucularla yazılır: `"{name} seni maça davet etti"`.
4. **Çoğul biçimler:** Desteklenir. Türkçe sayıdan sonra çoğul eki almaz ("3 piyon"); İngilizce alır ("3 pawns"). PO çoğul formları kullanılır.
5. **Dil değişikliği anında uygulanır:** Uygulama yeniden başlatılmaz (UI_SCREEN_SPECIFICATIONS §24).

## 2. Dosya ve işlem hattı

- **Godot:** `TranslationServer` + PO dosyaları.

```
client/localization/
  messages.pot          ← anahtarlar ve bağlam (otomatik çıkarılır)
  tr.po  en.po          ← çeviriler
  glossary.csv          ← terim sözlüğü (piyon, zar, Kulüp Üyeliği…)
```

- **Anahtar çıkarma:** `tr("KEY")` çağrılarından ve `.tscn` dosyalarındaki `text` alanlarından betikle yapılır. Godot'un POT oluşturma özelliği de kullanılabilir.
- **Çeviri yönetimi:** Yeni diller için bir yönetim platformu önerilir (Crowdin, Lokalise, Weblate vb.; karar sonra). MVP'de PO dosyaları depoda tutulur.
- **Sunucu metinleri:** Sunucu metin **göndermez**, anahtar + parametre gönderir (§7). Yalnızca push bildirimi ve e-posta metinleri sunucuda çevrilir; bunun için `server/locales/{tr,en}.json` kullanılır.

## 3. Anahtar adlandırma

- **Biçim:** `<ALAN>_<ÖĞE>[_<DURUM>]`, büyük harf ve alt çizgiyle.

| Alan | Örnekler |
|---|---|
| `COMMON_` | `COMMON_OK`, `COMMON_CANCEL`, `COMMON_RETRY` |
| `HOME_` | `HOME_DAILY_REWARD_READY`, `HOME_MODE_2P` |
| `MATCH_` | `MATCH_YOUR_TURN`, `MATCH_TAP_PAWN`, `MATCH_NO_MOVES`, `MATCH_CAPTURED_YOU` |
| `RULE_` | `RULE_ENTER_ON_SIX`, `RULE_SAFE_STARS` |
| `STORE_` | `STORE_BUY_FOR`, `STORE_OWNED`, `STORE_RARITY_EPIC` |
| `ERR_` | `ERR_NOT_YOUR_TURN`, `ERR_ROOM_FULL` (NETWORK §5.4 kodlarıyla eşleşir) |
| `PUSH_` | `PUSH_INVITE`, `PUSH_FRIEND_REQUEST` |
| `EMOTE_` | `EMOTE_GOOD_GAME` |

- **Bağlam:** PO `msgctxt` alanında, ekran ve kullanım yeri. Örneğin "Al" (satın al) ile "Al" (ödülü al) **farklı anahtarlardır**.
- **Kozmetik adları:** `ITEM_<id>_NAME`, `ITEM_<id>_DESC`. Katalog veritabanındaki `id`'ye bağlanır.

## 4. Tarih, saat, sayı ve para biçimleri

**Sayılar:**

| Dil | Binlik / ondalık | Örnek |
|---|---|---|
| tr | `.` / `,` | 12.450 · 3,5 |
| en | `,` / `.` | 12,450 · 3.5 |

- **Uygulama:** Godot tam ICU biçimlendirme sunmadığı için küçük bir `NumberFormat` yardımcısı yazılır; dil tablosundan binlik, ondalık ve yüzde düzeni okunur.
- **Yüzde:** tr "%62", en "62%".

**Süreler:**

| Dil | Örnek |
|---|---|
| tr | "6 sa 12 dk", "3 g 4 sa", "45 sn" |
| en | "6h 12m", "3d 4h", "45s" |

- Sayaç biçimi (`00:12`) her dilde aynıdır; sayılar Batı Arap rakamlarıyla yazılır (§6).

**Tarih ve saat:**
- Göreli ifadeler: "3 sa önce", "Dün", "3 h ago", "Yesterday".
- Mutlak tarih: tr `16 Kas 2026`, en `Nov 16, 2026`.
- Saat dilimi: Cihazın yerel saati gösterilir.
- **Sıfırlama saatleri:** Oyun günü sıfırlamaları **TR 00:00 (UTC+3)** sabittir (DATABASE_SCHEMA §1). Oyuncuya her zaman "kalan süre" olarak gösterilir, böylece saat dilimi karışıklığı olmaz.
  - Çok bölgeli yayında bölge başına sıfırlama saati yeniden değerlendirilir (açık konu).

**Para:** Mağaza fiyatları **platformun** yerelleştirilmiş metniyle gösterilir (`₺49,99`, `$1.99`). Uygulama para birimini kendisi biçimlendirmez.

## 5. Türkçe'ye özgü noktalar

- **Büyük ve küçük harf:** i ↔ İ, ı ↔ I. Godot'un `to_upper()` ve `to_lower()` işlevleri dile duyarlı değildir.
  - Büyük harf görünecek metinler (`micro` stil, rozetler) çeviri dosyasında **zaten büyük harfle** yazılır: `"SIRA SENDE"`.
  - Ya da dile duyarlı bir `UiText.upper(text, locale)` yardımcısı kullanılır.
- **Arama ve eşleştirme:** Arkadaş kodu araması Türkçe katlamayla yapılır (`name_key`; DATABASE_SCHEMA §3.1).
- **Ek uyumu:** Değişkene ek gelen cümleler kurulmaz. Örneğin `"{name}'in piyonu"` yerine `"Piyonu yenen: {name}"` gibi eksiz yapılar kullanılır.
  - Kaçınılmazsa ünlü uyumuna göre ek seçen küçük bir yardımcı (`tr_suffix(name, "genitive")`) eklenir; bu karar bekleyen bir tasarım detayıdır.
- **Görünen ad:** Türkçe karakterlere izin verilir. Fontlar tam destekli (UI_UX_DESIGN_SYSTEM §4).

## 6. Sağdan sola yazılan diller (RTL) için hazırlık

- **Godot desteği:** `Control.layout_direction`, `TextServer` (çift yönlü metin ve şekillendirme) sağdan sola düzeni destekler.
- **Arayüz kuralları:**
  - Kenar boşlukları "sol / sağ" değil, **"başlangıç / bitiş"** anlamında kullanılır. Kapsayıcılar (HBox, Grid) yöne göre otomatik aynalanır.
  - Ok, geri ve "›" ikonları aynalanır. Zar, piyon, tahta, sayılar ve logolar **aynalanmaz**.
  - **Tahta aynalanmaz:** Oyun tahtası mantıksal ve görsel olarak aynı kalır, saat yönü korunur. Yalnızca çevresindeki arayüz aynalanır.
  - **Sayılar:** Saf sayılar ve sayaçlar soldan sağa yazılır (`TEXT_DIRECTION_LTR`). Arapça yerel rakamlar mı Batı rakamları mı kullanılacağı dil eklenirken karar verilir.
- **Font zinciri:** Arapça için Noto Sans Arabic yedeği yalnızca o dil seçildiğinde eklenir (satır yüksekliği diğer dilleri etkilemesin diye).
- **Test:** Sahte sağdan sola mod: geliştirici ayarında İngilizce metinle `layout_direction = RTL`. Faz 3'ten itibaren düzen testlerine eklenir.

## 7. Sunucudan gelen metinler

- **Biçim:** Bildirimler, hata kodları, sistem duyuruları ve gelen kutusu kayıtları `{ key, params }` olarak gönderilir.

```json
{ "kind": "friend_request", "payloadKey": "NOTIF_FRIEND_REQUEST", "params": { "name": "Mehmet", "tag": 2231 } }
```

- **Çeviri yeri:** İstemci, oyuncunun **o anki** dilinde çevirir.
- **Push bildirimleri:** Uygulama kapalıyken gösterildiği için sunucuda çevrilir. Dil kaynağı `device_tokens.locale` alanıdır; uygulama dili değişince güncellenir.
  - Alternatif: Android `title_loc_key` / iOS `loc-key` ile cihaz içi çeviri; bu durumda metinler uygulama paketinde olur. Öneri bu yöntemdir, çünkü dil değişikliğine anında uyar (doğrulanacak).
- **Sistem duyuruları:** Yönetim panelinden girilen duyuru metinleri her dil için ayrı girilir (`{tr, en}`). Eksik dilde İngilizce gösterilir.

## 8. Metin uzunluğu ve düzen

- **Bütçe:** Her UI metninin bir **uzunluk bütçesi** vardır (karakter ya da piksel). Çevirmen notunda yazılır: `#. max 18 chars (button)`.
- **Taşma stratejisi** (sırayla):
  1. Esnek düzen (satır kaydırma, iki satır).
  2. Tanımlı en küçük yazı boyutuna küçültme (`UiKit.fit_label`, en fazla −%15).
  3. "…" ile kesme. Yalnızca ikincil metinlerde; butonlarda **asla**.
- **Sahte çeviri testi:** `en-XA` sahte dili; metinler %40 uzatılır ve aksanlanır (`[Ŝîřâ šéñðé ~~~~]`). Bütün ekranlar 320 pt genişlikte taşma testinden geçer (TESTING §4).
- **Bilinen uzun metinler:** "Satın alımları geri yükle" ve İngilizcesi "Restore purchases" gibi metinler tasarımda iki satıra izin verecek yükseklikle ele alınır.

## 9. Dil seçimi

- **İlk açılış:** Cihaz dili desteklenen dillerdense o dil, değilse **İngilizce**.
- **Ayarlar > Dil:** Diller kendi adlarıyla listelenir (UI_SCREEN_SPECIFICATIONS §24). Giriş ekranında da hap olarak bulunur.
- **Kayıt yeri:** Seçim yerel ayarlarda ve `profiles.locale` alanında tutulur; push dili için gerekir.

## 10. Mağaza ve yasal metinler

- **Mağaza:** Mağaza sayfası (başlık, kısa / uzun açıklama, ekran görüntüsü metinleri) TR ve EN hazırlanır.
  - Ekran görüntüleri her dil için ayrı oluşturulur; prototip altyapısı bunun için kullanılabilir.
- **Yasal metinler:** Gizlilik politikası, kullanım koşulları ve KVKK aydınlatma metni TR ve EN olarak hazırlanır; hukuki gözden geçirme gerekir (K-02 / Faz 10).

## 11. Yerelleştirme kalite kontrolü

| Kontrol | Ne zaman |
|---|---|
| Eksik anahtar | CI: her anahtarın tr ve en karşılığı var mı |
| Kullanılmayan anahtar | Haftalık rapor |
| Yer tutucu tutarlılığı | CI: `{name}` iki dilde de var mı |
| Sabit metin taraması | CI: `.gd` ve `.tscn` içinde anahtar olmayan görünür metin |
| Sahte çeviri ve 320 pt taşma testi | Her sürümde |
| Dil uzmanı gözden geçirmesi | Her yayın öncesinde (TR ana dili konuşan, oyun bilen) |
| RTL düzen testi | Faz 3'ten itibaren otomatik (sahte RTL) |
