# GOLD_AND_DIAMOND_ECONOMY — Altın ve Elmas Ekonomisi

> **Durum:**
> - Faz 2 sonrası güncelleme (2026-11-17).
> - **Ekonominin tek kaynak belgesi.** Önceki adı `docs/ECONOMY_TWO_CURRENCY_DESIGN.md`; o dosya artık buraya yönlendiriyor.
> - **Bu aşamada ödeme entegrasyonu yapılmadı.** Yalnızca tasarım ve mimari hazırlık.
>
> **Hangi belgelerin yerine geçiyor:**
> - ECONOMY_AND_PROGRESSION §1 (tek para birimi) ve §4'ün "giriş ücreti yok" varsayımı;
> - MONETIZATION_DESIGN §3.7'nin "eksi bakiye" maddesi ve §5'in "giriş ücreti yok" maddesi.
>
> O belgelerin geri kalanı geçerli: XP, görevler, kozmetik nadirlikleri, reklam kuralları, Kulüp.
>
> **Ön koşul:** Altınlı maçlar, hukuki ve mağaza politikası incelemesi tamamlanmadan yayına hazır **sayılmaz**: [../RISK_GOLD_ENTRY_MATCHES.md](../RISK_GOLD_ENTRY_MATCHES.md).

## 1. Kesinleşmiş kararlar (2026-11-17)

| | **Altın** | **Elmas** |
|---|---|---|
| Gerçek parayla satın alma | **Evet** (IAP) | **Evet** (IAP) |
| Maç giriş ücreti | **Evet** | **Hayır, asla** |
| Maç ödülü | **Evet** | Hayır |
| Günlük giriş ödülü | **Evet** | Karar bekliyor (E-2) |
| Görev ve başarım ödülü | **Evet** | Karar bekliyor (E-2) |
| Kozmetik | **Standart** kozmetikler | **Premium** kozmetikler: özel zar, piyon, tahta, avatar, profil efektleri |
| Bahis amaçlı kullanım | Yalnızca maç giriş ücreti modeli (§5) | **Hayır** |
| Oyuncular arası transfer | **Yok** | **Yok** |
| Gerçek paraya çevirme | **Yok** | **Yok** |

**Teknik kurallar** (kesin):
1. **Bakiyeler sunucu otoritesinde:** Altın ve Elmas bakiyeleri yalnızca Supabase Postgres'te tutulur. İstemci bakiyeyi **doğrudan değiştiremez**; yalnızca okur (RLS).
2. **Atomik ve denetlenebilir:** Her bakiye değişikliği tek bir Postgres işleminde, **defter kaydıyla** birlikte yapılır.
3. **Negatif bakiye yok:** `CHECK (coins >= 0)`, `CHECK (gems >= 0)`.
4. **Çift uygulama yok:** Her hareketin benzersiz bir idempotency anahtarı vardır. Aynı satın alma, ödül ya da maç sonucu ikinci kez **uygulanamaz**.
5. **Sabit değer yok:** Giriş bedeli, paylar, kesinti, ücretsiz altın ve telafi yapılandırmadan okunur (§3).

## 2. Karar bekleyen sorular

| No | Soru | Öneri ve gerekçe |
|---|---|---|
| E-2 | Elmas yalnızca satın alınarak mı edinilecek, yoksa nadir ödüllerle de (sezon, başarım) mi? | Satın alma + **az sayıda** nadir ödül. Oynamayan oyuncuya da premium içeriği tatma şansı verir. |
| E-3 | Maç havuzundan kesinti (rake) olacak mı, oranı ne? | Örnek yapılandırmada %10. Kesinti ekonomiden altın çeker (enflasyona karşı), ama "ev payı" algısını güçlendirir. Altın artık satın alınabildiği için risk notu §3 kesintiyi **düşük ya da sıfır** tutmayı öneriyor. |
| E-4 | Giriş seviyeleri ve ödül payları; özel odada altınlı maç olacak mı? | Örnek 100 / 500 / 2.500 altın. 2 kişilikte kazanan alır; 4 kişilikte %60 / %30 / %10 / %0. Özel odada altınlı maç **olmasın** (işbirliği riski, SECURITY_ARCHITECTURE §8). |
| E-5 | Elmas ↔ Altın dönüşümü olacak mı? | **Başlangıçta yok.** İki para biriminin ayrımını (Elmas maça girmez) korur. |
| E-6 | İade edilen bir satın almanın bakiyesi harcanmışsa ne olacak? | Bakiye sıfıra kadar düşülür, kalanı **borç** (`wallet_debts`) olur. Borç varken altınlı maç ve mağaza kapalı; yeni kazançlar önce borcu kapatır. Bakiye **asla** eksiye düşmez. |
| E-7 | Altınlı maç modu hangi ülkelerde ve hangi yaş için açık olacak? | **Hukuki görüş gelene kadar kapalı** (özellik bayrağı, ülke bazında). Yaş sınırı hukuki görüşle belirlenir; K-02 (13+) yeniden değerlendirilebilir. |

## 3. Yapılandırma (sabit kod yok)

- **Yapılandırılanlar:** Giriş bedeli, ödül havuzu, sıralama payları, kesinti, günlük ücretsiz altın ve telafi. Hepsi sunucunun yönettiği yapılandırmadan okunur.
- **Biçim örneği:** `shared/config/economy_config.example.json` (yalnızca geliştirme değerleri).
- **Doğrulama ve hesap:** `server/game-engine/src/economy.ts` (Faz 2'de testli):
  - `validateEconomyConfig`;
  - `computePayout`;
  - `canEnter`;
  - `bailoutAmount`.
- **Saklama:** `app_config` tablosunda sürümlü. Her maç kaydına o anki sürüm numarası yazılır.
- **Hesap kuralları** (`test/economy.test.ts` ile doğrulandı):
  - havuz = giriş × oyuncu sayısı;
  - kesinti = ⌊havuz × oran / 100⌋;
  - pay = ⌊dağıtılacak × baz puan / 10.000⌋.
  - Yuvarlama her zaman aşağı; ödenen + kesinti + kalan = havuz. **Havuzdan fazla ödeme matematiksel olarak imkânsız.**
  - Paylar toplam 10.000 baz puan ve azalmayan sırada (1. ≥ 2. ≥ …).

## 4. Defter ve veritabanı

DATABASE_SCHEMA §3.4'ün güncellenmiş hali (SQL taslağı; migration'a Faz 3'te dönüşür):

```sql
-- Bakiyeler: ikisi de negatife düşemez
create table wallets (
  user_id    uuid primary key references profiles(user_id) on delete cascade,
  coins      bigint not null default 0 check (coins >= 0),   -- Altın
  gems       bigint not null default 0 check (gems  >= 0),   -- Elmas
  updated_at timestamptz not null default now()
);

-- Defter: her hareket bir satır
-- wallet_transactions: + currency ('gold' | 'gems'), idempotency_key UNIQUE (mevcut)
-- yeni nedenler: 'match_entry','match_payout','match_refund','daily_free_gold','bailout',
--                'iap_gold','iap_gems','refund_clawback','debt_settlement'

-- Maç girişi emaneti
create table match_entries (
  match_id   uuid not null,
  user_id    uuid not null references profiles(user_id),
  amount     bigint not null check (amount > 0),
  status     text not null check (status in ('held','paid_out','refunded')),
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  primary key (match_id, user_id)
);

-- İade sonrası borç (E-6)
create table wallet_debts (
  user_id     uuid not null references profiles(user_id),
  currency    text not null check (currency in ('gold','gems')),
  amount      bigint not null check (amount > 0),
  purchase_id uuid references purchases(id),
  created_at  timestamptz not null default now(),
  settled_at  timestamptz
);
```

**Kurallar:**
1. **Tek işlem:** Defter satırı + bakiye + (varsa) envanter / emanet aynı Postgres işleminde yazılır. Cüzdan `SELECT … FOR UPDATE` ile kilitlenir.
2. **İdempotency anahtarları:**

| Hareket | Anahtar |
|---|---|
| Maç girişi | `entry:<maç>:<kullanıcı>` |
| Maç ödülü | `payout:<maç>:<kullanıcı>` |
| Maç iadesi | `refund:<maç>:<kullanıcı>` |
| Satın alma | `iap:<platform>:<transaction_id>` |
| İade düşümü | `revoke:<platform>:<transaction_id>` |
| Günlük ücretsiz altın | `daily:<kullanıcı>:<TR günü>` |
| Telafi | `bailout:<kullanıcı>:<gün>:<n>` |

3. **Denetim:** Gece işi, bakiyenin defter toplamına eşit olduğunu denetler. Sapma P1 olaydır.
4. **Sunucu işlevleri** (SUPABASE_ARCHITECTURE §5):
   - `escrow_match_entry`, `settle_match`, `refund_match`;
   - `grant_purchase`, `revoke_purchase`;
   - `claim_reward`, `buy_item`.

## 5. Maç giriş ücreti ve ödül akışı

1. **Eşleşme:** Matchmaker oyuncuları giriş seviyesine göre eşleştirir. Kuyruğa girerken `canEnter` ön kontrolü yapılır (borç varsa giriş yok).
2. **Emanet:** Maç başlamadan MatchRoom, `escrow_match_entry` işlevini **bütün oyuncular için birlikte** çağırır.
   - Biri yetersizse **hiç kimseden** alınmaz; maç kurulmaz.
   - Bedel `match_entries.status = 'held'` olarak durur.
3. **Maç:** Ekonomi maç sırasında hiçbir şeyi etkilemez.
4. **Sonuç:** MatchRoom sıralamayı hesaplar; `settle_match` payları `computePayout` kurallarıyla dağıtır (idempotent).
   - Ayrılan oyuncu bulunduğu sıranın payını alır (genelde 0).
5. **Geçersiz maç:** Sunucu hatası durumunda `refund_match` çağrılır: herkese tam iade.
6. **Mutabakat:** Belirli süreyi (öneri 6 saat) aşmış `held` kayıtlar otomatik iade edilir.
7. **Şeffaflık:** Giriş bedeli, kesinti ve paylar maç öncesinde gösterilir (risk notu §3).

**Altınsız modlar** (risk notunun temel önlemi): Ücretsiz hızlı maç (sabit ödüllü), özel oda ve pratik **her zaman** açık kalır. Altınlı maç isteğe bağlı bir moddur.

## 6. Satın alma altyapısı (hazırlık; bu aşamada entegrasyon yok)

### 6.1 Ürünler

- **Paketler:** Altın paketleri (`gold_*`) ve Elmas paketleri (`gems_*`), tüketilebilir ürünler.
- **Diğer ürünler:** Kozmetik paketleri ve Kulüp aboneliği MONETIZATION §3.1'de.
- **Fiyatlar ve miktarlar:** K-34 ile kararlaştırılır.
- **Apple kuralı:** IAP ile satın alınan oyun içi para birimlerinin **süresi dolamaz** (App Store Review Guidelines 3.1.1). Altın ve Elmas için süre sınırı konmaz.

### 6.2 Akış

```mermaid
sequenceDiagram
  participant C as İstemci
  participant P as Google Play / App Store
  participant W as Cloudflare Worker
  participant DB as Supabase Postgres
  C->>W: POST /v1/iap/intent (JWT)
  W-->>C: hesap bağlama kimliği (obfuscatedAccountId / appAccountToken)
  C->>P: satın alma penceresi
  P-->>C: purchaseToken / imzalı işlem (JWS)
  C->>W: POST /v1/iap/verify {platform, productId, token} + Idempotency-Key
  W->>P: Google Play Developer API / App Store Server API ile doğrula
  P-->>W: doğrulanmış işlem (durum, ürün, hesap kimliği)
  W->>DB: grant_purchase(...)  [tek işlem; (platform, transaction_id) benzersiz]
  DB-->>W: yeni bakiye (ya da "zaten işlendi" → önceki sonuç)
  W-->>C: ok {coins, gems}
  C->>P: consume / acknowledge (Google) · finishTransaction (Apple)
```

**Kurallar:**
- **İstemcinin "başarılı" bildirimi tek başına yeterli değildir.** Yalnızca mağazanın sunucu API'siyle doğrulanmış işlem bakiye üretir.
- **Hesap bağlama:** Doğrulanan işlemdeki hesap kimliği, isteği yapan kullanıcıyla eşleşmelidir. Başka hesabın makbuzu kullanılamaz.
- **Tüketme / onay sırası:** Bakiye **Postgres'e yazıldıktan sonra** yapılır. Arada uygulama kapanırsa açılışta bekleyen işlemler yeniden doğrulanır; idempotency sayesinde çift bakiye oluşmaz.
- **Tekrarlanan bildirimler:** Mağaza bildirimleri ve aynı belirtecin tekrar gönderilmesi idempotent işlenir.
- **Satın alma geçmişi:** `purchases` tablosu, yasal saklama süresi boyunca (K-48).

### 6.3 İade ve iptal

- **Kaynaklar:**
  - Google: RTDN + Voided Purchases API (günlük tarama).
  - Apple: App Store Server Notifications V2 (`REFUND`, `REVOKE`, `CONSUMPTION_REQUEST`).
  - Hepsi imza doğrulamasıyla.
- **İşleme:** `revoke_purchase`:
  - İlgili miktar bakiyeden düşülür.
  - Bakiye yetmezse kalan **borç** olur (E-6); bakiye eksiye düşmez.
  - Tüketilmeyen ürün iadesinde öğe envanterden kaldırılır.
- **İstismar:** 90 günde 3 iade → hesap işaretlenir, IAP geçici kapatılır (MONETIZATION §3.7).

### 6.4 Doğrulamanın yeri

- **Önerim:** Cloudflare Worker (K-61): sunucu kodu tek dilde (TypeScript), gizli anahtarlar tek yerde.
- **Alternatif:** Supabase Edge Functions.
- **Abonelik yükü:** Ağır gelirse RevenueCat değerlendirilir (K-35).

## 7. Altına erişim (para harcamadan oynanabilirlik)

| Kaynak | Örnek değer |
|---|---|
| Başlangıç altını | 1.000 |
| Günlük ücretsiz altın | 300. Günlük giriş ödülüyle birleştirilebilir (ECONOMY §6). |
| Telafi (bailout) | Bakiye en ucuz girişin altına düşerse günde en fazla 2 kez 200 altın |

**Amaç:** Oyuncunun oynayabilmek için **asla** para harcamak zorunda kalmaması. Altın satın alınabilir olduğu için bu önlem risk notunda daha da önemli hale geldi.

**Enflasyon izleme:** Kesinti, kozmetik harcamaları, ad değiştirme ücretleri; haftalık ekonomi raporu.

## 8. Sonraki fazlarda yapılacaklar

| Faz | İş |
|---|---|
| Faz 3 | Cüzdan, defter, emanet, borç ve satın alma tabloları + RLS + sunucu işlevleri (migration'lar; test altınıyla) |
| Faz 4 | Emanet ve sonuç akışının MatchRoom'a bağlanması (yalnızca test bakiyesiyle) |
| Faz 5 | Altın muhasebe testleri: eşzamanlılık, çift istek, kesinti, mutabakat |
| Faz 7–8 | Mağaza ekranları, gerçek IAP entegrasyonu (sandbox), iade akışı |
