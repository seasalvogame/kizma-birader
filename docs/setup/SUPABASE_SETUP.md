# SUPABASE_SETUP — Supabase Kurulumu, Komutlar ve Giriş Sağlayıcıları

> **Durum:** Faz 3.2 (2026-11-17).
>
> **Proje:** `kizmabirader-dev`
> - referans `eoujnamlwgbtlwigtjxx`;
> - bölge `eu-central-1` (Frankfurt);
> - Postgres 17;
> - **Free** plan.
>
> **İlgili belgeler:**
> - [../architecture/SUPABASE_ARCHITECTURE.md](../architecture/SUPABASE_ARCHITECTURE.md): tasarım;
> - `supabase/migrations/`: gerçek şema.
>
> **Gizli bilgi kuralı:** Veritabanı parolası, gizli (secret / service role) anahtar ve sağlayıcı sırları **bu belgeye, depoya ya da sohbete yazılmaz.**

## 1. Gerçek bulutta kurulu ve doğrulanmış olanlar

| Konu | Durum | Nasıl doğrulandı |
|---|---|---|
| Proje ve CLI bağlantısı | ✅ | `supabase link`. Yerel durum `supabase/.temp/` klasöründe ve `.gitignore`'da. |
| Şema (4 migration) | ✅ Uygulandı | `supabase db push --remote` |
| Anonim (misafir) giriş | ✅ Açık | Uçtan uca test: gerçek misafir hesabı açıldı |
| Manual linking (misafiri kalıcı hesaba bağlama) | ✅ Ayar açık | Ayar okundu (`config pull`). **Bağlama akışı henüz denenmedi** (istemci gerekiyor, §4). |
| E-posta sağlayıcısı | ✅ Açık, doğrulama e-postası zorunlu | Ayar okundu. **E-posta gönderimi denenmedi.** |
| JWT imzalama | ✅ Asimetrik (ES256) | JWKS okundu; misafir JWT'si Web Crypto ile doğrulandı |
| RLS ve yetkiler | ✅ | 61 SQL kontrolü + 15 API kontrolü (§3) |
| Kısıtlı `game_server` rolü | ✅ Oluşturuldu, **NOLOGIN** | SQL testleri. Bağlantı parolası 3.3'te (§5). |
| Google girişi | ❌ Yapılandırılmadı | Sağlayıcı bilgileri gerekli (§6) |
| Apple girişi | ❌ Yapılandırılmadı | Apple Developer hesabı gerekli (§6) |
| Özel SMTP (üretim e-postası) | ❌ | §6.3 |
| Realtime (sosyal) | ❌ | Faz 4 |

## 2. Komutlar

Hepsi `C:\KizmaBirader` klasöründe çalıştırılır. Komutlar `npx supabase login` ile açılmış CLI oturumunu kullanır.

```sh
npx supabase db push --remote --dry-run        # bekleyen migration'ları göster
npx supabase db push --remote --yes            # uygula (dev projesi)
npx supabase db query --remote --yes -f supabase/tests/rls_economy_test.sql   # SQL testleri → "TESTS_PASSED 61"
node supabase/tests/api_e2e_test.mjs eoujnamlwgbtlwigtjxx                     # API testleri → "API_E2E_PASSED 15"
npx supabase db advisors --remote --yes        # güvenlik / performans denetleyicisi
npx supabase config diff                       # yerel config.toml ile uzak ayarların farkı
```

- **Docker gerekmiyor:** Yerel Supabase yığını kurulmadı (C: diskinde ~2,5 GB boş). Geliştirme bulut `dev` projesinde yapılıyor.
- **Veritabanı parolası gerekmiyor:** `db query --remote` ve `db push --remote` CLI'ın yönetim API'si ve geçici oturum rolüyle çalışıyor.

## 3. Şema ve güvenlik modeli (uygulanan)

| Migration | İçerik |
|---|---|
| `20261117120000_foundation_profiles.sql` | `game` ve `app_private` şemaları, `game_server` rolü, varsayılan yetkilerin kapatılması, `app_config` (ekonomi ve özellik bayrakları), `profiles`, `player_stats` |
| `20261117120100_matches.sql` | `matches`, `match_players`; katılımcı RLS yardımcısı |
| `20261117120200_economy.sql` | `wallets` (Altın + Elmas, ≥ 0), `wallet_transactions` (defter, benzersiz idempotency anahtarı), `purchases`, `wallet_debts`, `match_entries`; sunucu işlevleri; yeni kullanıcı tetikleyicisi |
| `20261117120300_social.sql` | `friendships`, `friend_requests`, `blocks`, `notifications`; `get_profile_cards` |

**Kurallar:**
- **İstemci** (anon / authenticated) yalnızca **okur**, ve yalnızca kendi satırlarını. Bütün tablolarda RLS açık. İstemcinin hiçbir tabloya yazma yetkisi yok: veritabanı yetkisi düzeyinde de geri alındı.
- **Yazmalar** yalnızca `game` şemasındaki `SECURITY DEFINER` işlevlerle yapılıyor. `game` şeması Data API'de yayınlanmıyor. İşlevleri yalnızca `game_server` çağırabiliyor:

| İşlev | Görev |
|---|---|
| `start_match` | Maç kaydı + giriş bedeli emaneti; ya herkesten alınır ya hiç kimseden |
| `finish_match` | Sonuç + ödül; havuzdan fazla ödeme reddedilir |
| `void_match` | Geçersiz maç → iade |
| `reconcile_stale_matches` | Uzun süredir sonuçlanmamış maçları iade |
| `grant_purchase` | Doğrulanmış satın almayı bakiyeye işler |
| `revoke_purchase` | İade; bakiye 0'da durur, kalanı borç olur |

- **`game_server` rolü** tablolara doğrudan erişemez; iç yardımcıları (`_apply` vb.) da çağıramaz.
- **Altınlı maç kapalı:** `app_config.features.gold_matches_enabled = false` iken giriş bedelli maç veritabanında reddedilir (E-7).
- **Yeni hesap:** Her yeni kullanıcıya (misafir ya da kalıcı) otomatik olarak profil ("Oyuncu" + rastgele etiket), istatistik ve cüzdan açılır. Cüzdana yapılandırmadaki başlangıç altını yazılır (dev: 1.000).

**Denetleyici (advisors) uyarıları** (bilinçli):
1. `get_profile_cards` yetkili hakla çalışıyor ve oturum açmış kullanıcı çağırabiliyor. İşlev yalnızca güvenli sütunları döndürüyor, en fazla 100 kimlik alıyor ve engellemeleri filtreliyor.
2. Anonim giriş açık: politikalar misafirlere de uygulanıyor. Bu, misafirin tam oynayabilmesi kararıyla (K-45) uyumlu.

## 4. Misafirden kalıcı hesaba geçiş ve hesap çakışması

- **Bağlama:** Misafir (anonim) kullanıcı Google, Apple ya da e-posta kimliği ekler.
  - Supabase'te `linkIdentity` (OAuth), `linkIdentityWithIdToken` (yerel belirteç) ya da e-posta için `updateUser`.
  - `auth.users.id` **değişmez**. Profil, cüzdan, defter, maç geçmişi aynı kimliğe bağlı olduğu için **hiçbir veri taşınmaz.** Veritabanında bunun için ek işlem gerekmez; tetikleyici yalnızca yeni kullanıcı **eklenince** çalışır.
- **Çakışma** (eklenmek istenen Google / Apple / e-posta zaten başka bir hesaba bağlı): Supabase hata döndürür.
  - **Birleştirme yok** (K-54, öneri).
  - İstemci "Bu hesap zaten kayıtlı → o hesaba geç" kartını gösterir ve misafir ilerlemesinin kaybolacağını açıkça söyler.
  - Platform satın alımları geri yükleme ile yeni hesaba atanır. **Tüketilmiş altın ve Elmas geri yüklenemez** (USER_FLOWS §3). Bu yüzden satın almadan önce hesap bağlama önerilir (K-63).
- **Doğrulanacak (Faz 4, istemciyle):**
  - gerçek bağlama akışı;
  - çakışma hata kodu;
  - bağlamadan sonra JWT'de `is_anonymous = false` olması.
- **Açık konu:** Hiç bağlanmamış eski misafir hesaplarının temizliği (Supabase otomatik silmiyor). Süre ve yöntem kararı gerekiyor (öneri: 180 gün hareketsiz ve satın alması olmayan misafir).

## 5. Oyun sunucusu bağlantısı (3.3'te)

`game_server` şu an **giriş yapamaz** (NOLOGIN). Cloudflare bağlanırken parolayı **sen** belirleyeceksin:
- Panelde: SQL Editor → `alter role game_server with login password '<parola>';`
- Parolayı ben görmeyeceğim. Cloudflare tarafına `wrangler` ile terminalden gizli değer olarak gireceksin.

**Doğrulanacak:**
- Supabase'in doğrudan bağlantısı IPv6 kullanıyor; havuz (Supavisor) üzerinden özel rolle bağlanmak gerekebilir.
- Kullanıcı adı biçimi muhtemelen `game_server.<proje-ref>`.
- Hyperdrive ile uyum.

## 6. Dış sağlayıcıların yapılandırılması (senin hesap bilgilerin gerekiyor)

**Henüz hiçbiri yapılandırılmadı ve tamamlanmış gösterilmiyor.**

### 6.1 Google ile giriş

1. **Google Cloud Console** → bir proje → "Google Auth Platform" / OAuth izin ekranı:
   - uygulama adı;
   - destek e-postası;
   - kapsamlar: `openid`, `email`, `profile`.
2. **OAuth istemci kimlikleri:**
   - **Web application** istemcisi: Supabase'in doğrulayacağı istemci (Android Credential Manager da bunu kullanır).
   - **Android** istemcisi: paket adı (`com.kizmabirader…`, K-01'e bağlı) + imza sertifikasının **SHA-1** parmak izi.
     - Debug ve yayın (Play App Signing) için ayrı ayrı.
   - **iOS** istemcisi: bundle ID.
3. **Supabase** → Authentication → Sign In / Providers → **Google**:
   - etkinleştir;
   - "Client IDs" alanına web + Android + iOS istemci kimliklerini virgülle gir;
   - web OAuth akışı kullanılacaksa "Client Secret" alanına web istemcisinin sırrını **sen** gir.
   - Yerel belirteç (`signInWithIdToken`) akışında nonce ayarı istemci eklentisine göre seçilir (doğrulanacak).
4. **Benden gerekenler:** Gizli olmayan istemci kimlikleri ve paket adı / bundle ID. Sırlar panelde kalır.

### 6.2 Apple ile giriş

1. **Apple Developer** (ücretli üyelik): App ID'de "Sign in with Apple" yeteneği.
2. **Android ya da web akışı** istenirse (K-03, isteğe bağlı):
   - Services ID + dönüş adresi (`https://eoujnamlwgbtlwigtjxx.supabase.co/auth/v1/callback`);
   - Sign in with Apple anahtarı (`.p8`).
   - Bu anahtardan üretilen istemci sırrı panelde girilir ve **6 ayda bir yenilenir** (Apple kuralı; doğrulanacak).
3. **Supabase** → Providers → **Apple**:
   - etkinleştir;
   - "Client IDs" alanına iOS bundle ID (+ varsa Services ID).
4. **iOS'ta yerel giriş:** `signInWithIdToken` ile; yalnızca bundle ID yeterli.

### 6.3 E-posta

- **Durum:** Etkin, doğrulama e-postası zorunlu. Supabase'in yerleşik e-posta servisi çok düşük gönderim sınırlıdır ve yalnızca test içindir.
- **Üretim için gerekenler:**
  - Özel SMTP sağlayıcısı: Authentication → SMTP Settings. Ücretli olabilir; senin onayınla seçilir.
  - Gönderen alan adı için SPF / DKIM kayıtları.
- **Doğrulama ve şifre sıfırlama bağlantıları:**
  - Şu an `site_url = http://localhost:3000`.
  - Mobil derin bağlantı (App Links / Universal Links) hazır olunca güncellenecek (Faz 4).
  - "Redirect URLs" listesine uygulamanın şeması eklenecek.

## 7. Plan ve kota notları

| Free plan koşulu | Ne anlama geliyor |
|---|---|
| 500 MB veritabanı, 50.000 MAU, 200 Realtime bağlantısı, 2 M Realtime mesajı / ay | Geliştirme için yeterli |
| **1 hafta düşük etkinlikte duraklatma** | Panelden "Resume" ile geri açılır, veri korunur |
| **Otomatik yedek yok** | Gerçek satın almalardan önce Pro önerisi (K-38) |
| Etkin proje sınırı (2) | Aynı kuruluşta diğer oyunlarına ait iki proje **INACTIVE** durumda görünüyor. Onlara dokunulmadı. |

**Ücretli bir hizmet etkinleştirilmedi.**
