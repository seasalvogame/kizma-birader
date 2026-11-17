# SUPABASE_ARCHITECTURE — Kimlik, Veritabanı ve Sosyal Gerçek Zamanlılık

> **Durum:** Faz 2 sonrası güncelleme (2026-11-17).
>
> **Faz 3.2'de uygulandı:**
> - `dev` projesi kuruldu; şema `supabase/migrations/`'ta; bulutta 61 SQL + 15 API testiyle doğrulandı.
> - Kurulum ve komutlar: [../setup/SUPABASE_SETUP.md](../setup/SUPABASE_SETUP.md).
> - Sunucu işlevlerinin güncel adları: `start_match` (emanet dahil), `finish_match`, `void_match`, `reconcile_stale_matches`, `grant_purchase`, `revoke_purchase`.
> - Sunucunun bağlantı yolu (Hyperdrive ya da havuz) 3.3'te kesinleşir.
>
> **İlişkili belgeler:**
> - Tablo taslakları: [../DATABASE_SCHEMA.md](../DATABASE_SCHEMA.md). Bu belge onun Faz 2 sonrası **farklarını** tanımlar.
> - Güvenlik: [SECURITY_ARCHITECTURE.md](SECURITY_ARCHITECTURE.md).
>
> **İşaretler:** (resmi) = resmi belgede yazıyor · (tahmin) · (doğrulanacak).

## 1. Supabase'in görevleri

| Görev | Supabase bileşeni |
|---|---|
| Hesaplar: misafir (anonim), Google, Apple, e-posta | Auth |
| Oyuncu profilleri, istatistikler, envanter | Postgres |
| **Altın ve Elmas bakiyeleri, defter, satın alma geçmişi** | Postgres (tek otorite) |
| Arkadaşlık ve istekleri, engellemeler | Postgres |
| Bildirim kayıtları (gelen kutusu) | Postgres |
| Maç geçmişi, haftalık sıralama | Postgres |
| Arkadaş çevrimiçi durumu, davetler, anlık sosyal bildirimler | **Realtime** (yetkili değil) |

**Supabase'in yapmadıkları:**
- **Maç durumu, zar, kurallar:** Cloudflare MatchRoom'da (ONLINE_ARCHITECTURE §2).
- **Özel oda ve davetin geçici durumu:** Eski planda Redis'teydi. Artık oda MatchRoom'da; davetin kalıcı izi `notifications` tablosunda, anlık iletimi Realtime ile.

## 2. Plan limitleri (resmi, 2026-11-17)

| Ölçü | Ücretsiz | Pro (aylık 25 USD) |
|---|---|---|
| Veritabanı boyutu | 500 MB / proje | 8 GB disk; sonra GB başına 0,125 USD |
| Aylık aktif kullanıcı (MAU) | 50.000 | 100.000; sonra MAU başına 0,00325 USD |
| Çıkış trafiği (egress) | 5 GB (+ 5 GB önbellekli) | 250 GB; sonra GB başına 0,09 USD |
| Dosya depolama | 1 GB | 100 GB |
| Realtime eşzamanlı bağlantı | **200** | 500; sonra 1.000 başına 10 USD |
| Realtime mesaj | 2 milyon / ay | 5 milyon / ay; sonra milyon başına 2,50 USD |
| Edge Function çağrısı | 500.000 | 2 milyon |
| Etkin proje | 2 | — |
| **Duraklatma** | **1 haftalık düşük etkinlikten sonra duraklatılır** | Duraklatılmaz |
| **Yedekleme** | **Otomatik yedek yok** | Günlük, 7 gün saklanır |

**Realtime anlık limitleri** (resmi):

| Limit | Ücretsiz | Pro (harcama sınırı açık) | Pro (harcama sınırı kapalı) |
|---|---|---|---|
| Eşzamanlı bağlantı | 200 | 500 | 10.000 |
| Saniyede mesaj | 100 | 500 | 2.500 |
| Saniyede kanala katılma | 100 | 500 | 2.500 |
| Bağlantı başına kanal | 100 | 100 | 100 |
| Presence: saniyede mesaj | 20 | 50 | — |
| Broadcast yükü | 256 KB | 3.000 KB | — |

- **Limit aşılırsa:** Bağlantı, kanal ya da katılma limitinde yeni katılım **reddedilir**. Mesaj hızı limitinde bağlantılar **koparılır** (resmi).
- **Belgelerde netleşmeyenler:**
  - Anonim kullanıcıların MAU'ya sayılıp sayılmadığı fiyat sayfasında yazmıyor (**doğrulanacak**).
  - Duraklatılmış ücretsiz projenin ne kadar süre geri yüklenebildiği: 2024 değişiklik notunda 90 gün, güncel belgede 1 yıl yazıyor (**doğrulanacak**).
  - Pro planın bilgi işlem (compute) boyutu ve yük altında yeterliliği **ölçülecek** (Faz 5).

## 3. Kimlik doğrulama (Auth)

- **Misafir:**
  - Anonim giriş; JWT'de `is_anonymous` alanı bulunur.
  - Kötüye kullanıma karşı CAPTCHA önerilir.
  - Varsayılan sınır IP başına saatte 30 anonim kayıt.
  - Kaynak: COMPATIBILITY_REPORT §2.
- **Google ve Apple:** Yerel kimlik belirteciyle `signInWithIdToken`.
- **E-posta:** E-posta + şifre. Doğrulama ve şifre sıfırlama e-postaları için üretimde özel bir SMTP sağlayıcısı gerekir (**doğrulanacak**).
- **Misafiri kalıcı hesaba yükseltme:**
  - "Manual linking" açılır.
  - E-posta için `updateUser`; Google / Apple için `linkIdentity` / `linkIdentityWithIdToken`.
  - Kullanıcı kimliği (`auth.users.id`) değişmez.
  - Canlı doğrulama Faz 3'ün işi.
- **JWT imzalama:** Supabase'in **asimetrik imzalama anahtarları** açılır.
  - Cloudflare yalnızca **genel anahtarı** JWKS uç noktasından alır: `https://<proje>.supabase.co/auth/v1/.well-known/jwks.json`. Belgelerde bir sayfada farklı bir yol geçiyor (**doğrulanacak**).
  - Böylece Cloudflare'de hiçbir JWT gizli anahtarı tutulmaz.
  - Anahtar döndürme JWKS üzerinden otomatik yayılır (resmi).

## 4. Veri modeli farkları (DATABASE_SCHEMA'ya göre)

DATABASE_SCHEMA'daki tabloların çoğu geçerli. Faz 2 sonrası kararlarla gelen farklar şunlar. Ekonomi ayrıntısı: GOLD_AND_DIAMOND_ECONOMY §4.

| Konu | Değişiklik |
|---|---|
| `wallets` | `coins` (Altın) ve `gems` (Elmas); ikisi de `CHECK (>= 0)`. **Negatif bakiye yok.** Eski "iade için −1.000.000'a kadar" kısıtı kaldırıldı. |
| `wallet_transactions` | `currency` (`gold` / `gems`), yeni nedenler (`match_entry`, `match_payout`, `match_refund`, `daily_free_gold`, `bailout`, `iap_gold`, `iap_gems`, `refund_clawback`); `idempotency_key` benzersiz |
| `match_entries` (yeni) | Maç girişi emanet kaydı: `(match_id, user_id)` birincil anahtar, `amount`, `status` (`held` / `paid_out` / `refunded`) |
| `wallet_debts` (yeni) | İade sonrası harcanmış bakiye için borç kaydı (E-6) |
| `purchases` | Ürün türüne `gold` ve `gems` paketleri eklenir; `(platform, transaction_id)` benzersiz (mevcut) |
| Özel oda / davet | Redis yerine: oda MatchRoom'da, davet `notifications` + Realtime |
| Canlı sıralama | Redis sıralı kümesi yerine `weekly_wins` tablosu ve indeksi. MVP ölçeğinde Postgres sorgusu yeterli (tahmin); sıralama ekranı önbellekli okunur. |
| `matches` | `economy_tier`, `economy_config_version`, `status` (`finished` / `void`) alanları |
| `match_events` | Olay listesi yerine **kompakt eylem dizisi**: zar ve piyon seçimi. Motor belirleyici olduğu için maç birebir yeniden oynatılabilir (COST_AND_SCALING §4). |

## 5. Oyun sunucusunun Supabase'e erişimi

**İlke:** Cloudflare tarafı Supabase'e **yalnızca belirli işlevleri çağırma** yetkisiyle erişir. Genel yazma yetkisi yoktur.

| Seçenek | Nasıl | Yetki | Not |
|---|---|---|---|
| **A (önerilen, K-59)** | Hyperdrive üzerinden doğrudan Postgres bağlantısı, **özel bir rol** (`game_server`) | Yalnızca ekonomi ve maç işlevlerinde `EXECUTE`; tablolara doğrudan yetki yok | En az yetki ilkesi tam uygulanır. Cloudflare'in Supabase için resmi Hyperdrive örneği var. Ücretsiz planda günde 100.000 sorgu. |
| B | PostgREST üzerinden `rpc/*` çağrıları, **gizli API anahtarı** (`sb_secret_…` / service role) | Anahtar RLS'i **atlar**; yetki geniş | Kurulumu basit; anahtar sızarsa etkisi büyük |

- **Her iki seçenekte:** Kimlik bilgisi yalnızca Cloudflare gizli anahtarı olarak durur; **asla** istemcide değildir.
- **Karar:** Faz 3'teki denemeyle (T-7). Önerim A.

**Sunucu işlevleri** (hepsi tek işlem, idempotent, `security definer`, sabit `search_path`):

| İşlev | Çağıran | Görev |
|---|---|---|
| `escrow_match_entry(match_id, entries[])` | MatchRoom | Bütün oyunculardan giriş bedelini **birlikte** alır (biri yetersizse hiçbiri alınmaz) |
| `settle_match(match_id, result)` | MatchRoom | Emanetleri dağıtır, `matches` / `match_players` / istatistik / sıralama / görev ilerlemesi |
| `refund_match(match_id, reason)` | MatchRoom / mutabakat | Geçersiz maçta emanet iadesi |
| `grant_purchase(purchase)` | Worker (`/iap/verify`, webhook) | Doğrulanmış satın almayı bakiyeye işler |
| `revoke_purchase(purchase)` | Worker (iade bildirimi) | İade: bakiyeden düşer, yetmezse borç (E-6) |
| `claim_reward(user, kind, key)` | Worker | Günlük giriş, ücretsiz altın, telafi, görev, reklam ödülü |
| `buy_item(user, item, currency, key)` | Worker | Altın ya da Elmasla kozmetik |

- **Yetkiler:** `REVOKE EXECUTE ... FROM anon, authenticated` → `GRANT EXECUTE ... TO game_server`.
- **İstemcinin çağırabildiği RPC'ler:** Yalnızca okuma amaçlı olanlar (ör. `get_profile_cards`).

## 6. RLS (özet)

- Bütün tablolarda RLS açık; `anon` ve `authenticated` rollerinin tablo yetkileri geri alınmış.
- İstemci yalnızca **kendi** satırlarını **okur**: cüzdan, defter, envanter, satın almalar, bildirimler, katıldığı maçlar.
- **Hiçbir ekonomi, maç ya da satın alma tablosunda istemci yazma politikası yoktur.**
- Başkasının verisi yalnızca güvenli sütunlu ve engelleme filtreli `security definer` RPC'lerle gelir.
- **Testler:** Her migration sonrası iki test kullanıcısıyla otomatik okuma / yazma reddi testleri (DATABASE_SCHEMA §4).

## 7. Realtime tasarımı (sosyal)

| Kanal | Tür | İçerik | Yetki |
|---|---|---|---|
| `user:<id>` (özel kanal) | Broadcast | Davet, arkadaş isteği, "ödül hazır", sistem bildirimi | Yalnızca o kullanıcı katılabilir |
| `presence:<id>` (özel kanal) | Presence | Kullanıcının durumu (`online` / `in_match`) | Yalnızca kullanıcının arkadaşları katılabilir |

- **Yetkilendirme:** Özel kanallar ve `realtime.messages` üzerinde RLS politikalarıyla. Özelliğin ayrıntısı **doğrulanacak** (Faz 3).
- **Davet akışı:**
  1. Worker `notifications` satırını yazar (kalıcı iz).
  2. Davet Realtime Broadcast ile gönderilir.
  3. Uygulama kapalıysa push ile iletilir (K-39).
  4. İstemci açılışta gelen kutusunu okur; kaçan davet kaybolmaz.
- **Bağlantı politikası:**
  - Realtime bağlantısı **yalnızca menülerde** açık tutulur; maç sırasında kapatılır, durum "maçta" olarak yazılır.
  - Böylece eşzamanlı Realtime bağlantısı, çevrimiçi oyuncu sayısının yalnızca menüde olan kısmı kadar olur.
  - Telefonda iki kalıcı bağlantı (Realtime + oyun soketi) da aynı anda açık kalmaz (TECHNICAL_ARCHITECTURE §9 riski).
- **Bağlantı başına 100 kanal limiti:** Arkadaş sayısı sınırı (200, K-47) bu limitin üstünde.
  - Seçenekler:
    - yalnızca çevrimiçi ya da yakın zamanda etkin arkadaşlara abone olmak;
    - arkadaş durumlarını açılışta Postgres'ten okuyup yalnızca değişiklikleri dinlemek.
  - Faz 4 tasarım kararı (K-64).

## 8. Zamanlanmış işler

| İş | Yer |
|---|---|
| Haftalık sıralama kapanışı | Supabase `pg_cron` (**doğrulanacak**) ya da Cloudflare Cron Trigger |
| Günlük sıfırlamalar | Aynı |
| **Mutabakat:** belirli süreyi aşmış `held` emanetleri iade et, defter–bakiye denetimi | Aynı |
| Eski kayıtların temizliği (`match_events` 90 gün, `notifications` 30 gün) | Aynı |
| Hesap silme (gün 30) | Aynı |

## 9. Ortamlar ve geçişler

- **Projeler:** `dev`, `staging` ve `prod` ayrı Supabase projeleridir.
  - Ücretsiz planda en fazla 2 etkin proje var. `staging` ya da `prod` için Pro gerekir (K-38).
- **Şema:** `supabase/migrations/` (SQL) ve RLS politikaları sürüm kontrolünde.
- **Duraklatma:** Ücretsiz `dev` projesi bir hafta düşük etkinlikten sonra duraklatılır. Elle yeniden başlatılır; veri korunur (resmi). Geliştirmede kabul edilebilir.

## 10. Kaynaklar (erişim: 2026-11-17)

- Fiyatlandırma ve plan limitleri: https://supabase.com/pricing
- Realtime limitleri: https://supabase.com/docs/guides/realtime/limits
- Ücretsiz projenin duraklatılması: https://supabase.com/docs/guides/platform/free-project-pausing
- JWT imzalama anahtarları: https://supabase.com/docs/guides/auth/signing-keys
- JWT ve JWKS: https://supabase.com/docs/guides/auth/jwts
- Anonim giriş ve kimlik bağlama: COMPATIBILITY_REPORT.md §2 kaynakları
- Hyperdrive ile Supabase (Cloudflare): https://developers.cloudflare.com/hyperdrive/examples/connect-to-postgres/postgres-database-providers/supabase/
