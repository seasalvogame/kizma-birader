# Faz 3 Raporu — Backend ve Online Altyapı

> **Durum:** Devam ediyor. Her alt aşama bitince bu rapor güncellenir.
>
> | Alt aşama | Durum |
> |---|---|
> | 3.1 Teknik hazırlık ve uyumluluk | ✅ Tamamlandı (2026-11-17) |
> | 3.2 Supabase altyapısı | ✅ Tamamlandı (2026-11-17); Google / Apple / SMTP senin bilgilerini bekliyor |
> | 3.3 Cloudflare altyapısı + oynanabilir oyun | 🟡 Yerelde tamam (Worker + DO, 23 test); oyun kabuğu ve APK 0.3.0 hazır; gerçek Cloudflare dağıtımı workers.dev alt alanını bekliyor: [PHASE_3_3_REPORT.md](PHASE_3_3_REPORT.md) |
> | 3.4 Güvenlik | ⏳ (3.2–3.3 ile birlikte) |
> | 3.5 Test ve doğrulama | ⏳ (her aşamada) |
>
> **Gerçek bulut ortamı:** Supabase `dev` projesi kuruldu ve test edildi (§2). Cloudflare'de henüz hiçbir şey yok.

## 1. Faz 3.1 — Teknik hazırlık ve uyumluluk

### 1.1 Yapılanlar

1. **Üçüncü atış kuralı (K-13), iki motorda da:**
   - **Kural:** Üst üste iki 6'dan sonraki atışın üst sınırı **5**. 6 değeri, sıradaki atışta da zaman aşımı atışında da `INVALID_DICE` ile reddedilir ve durumu değiştirmez.
   - **Kural seti:** `classic_v1.third_six_action = "exclude_six"`. Eski "üçüncü 6 → tur biter" davranışı `"forfeit_turn"` değeriyle alternatif kural seti olarak duruyor ve testli.
   - **Yardımcı işlev:** TypeScript'te `maxDiceValue(state)`, GDScript'te `GameEngine.max_dice_value(state)`.
   - **Zar isteme:** `MatchSession` her iki dilde de zar kaynağından değeri bu sınırla ister.
   - **Arayüz:** Kural kurallar ekranında açıklanmaz (K-56, kesin). Arayüz değiştirilmedi.
2. **Cloudflare uyumlu güvenli zar:**
   - `node:crypto` kaldırıldı.
   - `cryptoDice`, Web Crypto `crypto.getRandomValues` ve **reddetme örneklemesiyle** çalışıyor; modulo sapması yok.
   - Aynı API Cloudflare Workers'ta ve Node 19+'da mevcut.
3. **Ortak test vektörleri yeniden üretildi:**
   - 40 senaryo; 4'ü yeni:
     - üçüncü atışta 6'nın reddi (zar ve zaman aşımı);
     - sınırlı atışla yeme ve ardından sayacın sıfırlanması;
     - sınırlı atışta zaman aşımı;
     - alternatif kural seti.
   - 60 rastgele maç (36.079 adım). Rastgele maçlar artık kurala uygun zar çekiyor.
4. **GDScript tarafında:**
   - `DiceSource.next(max)`;
   - yeni `DiceSource.seeded(seed)` (TS'deki `seededDice`'ın eşi);
   - maç akışı testleri, kurala uyan tohumlu zar kaynağına geçirildi.

### 1.2 Değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `server/game-engine/src/ruleset.ts` | `third_six_action: "exclude_six" \| "forfeit_turn"`; varsayılan `exclude_six` |
| `server/game-engine/src/engine.ts` | `maxDiceValue`; sınır denetimi; tur kaybı yalnızca `forfeit_turn`'de |
| `server/game-engine/src/session.ts` | Zarı sınırla ister |
| `server/game-engine/src/dice.ts` | Web Crypto + reddetme örneklemesi; `secureRandomInt`; bütün kaynaklar sınır alır |
| `server/game-engine/scripts/gen-vectors.ts` | Yeni senaryolar; rastgele maçlarda kurala uygun zar |
| `server/game-engine/test/rules.test.ts` | Test 6 yeni kurala göre; 6b, 6c, 6d ve kural seti testleri |
| `server/game-engine/test/dice.test.ts` (**yeni**) | Zar güvenliği ve Workers uyumu (8 test) |
| `server/game-engine/test/property.test.ts` | Rastgele maçlarda kurala uygun zar |
| `shared/rules_test_vectors/scenarios.json`, `traces.json` | Yeniden üretildi |
| `client/scripts/game/rules/ruleset.gd`, `game_engine.gd`, `match_session.gd`, `dice_source.gd` | TS ile aynı değişiklikler |
| `client/tests/unit/test_rules.gd` | Test 06, 06b, 06c |
| `client/tests/scene/test_match_flow.gd` | Tohumlu zar kaynağı |
| Belgeler | DECISIONS (K-13 uygulandı, K-56 ve K-59 kesin), GAME_RULES, motor README'si, ONLINE_ARCHITECTURE |

**Değiştirilmeyenler:** Arayüz ve tasarım, tahta, ekonomi modülü, Faz 2 testlerinin kapsamı.
- Değişen tek test **beklentisi**, eski kurala ait test 6. Bu test silinmedi; alternatif kural seti testi olarak korundu.
- Faz 2'deki bütün diğer testler aynen geçiyor.

### 1.3 Test sonuçları

| Takım | Sonuç |
|---|---|
| TypeScript (`npm test`) | **85 / 85** (Faz 2'de 73). `tsc --noEmit` temiz. |
| GDScript (headless) | **29 / 29** (Faz 2'de 27). İki motorun eşitliği: 40 senaryo + 60 maç (36.079 adım) birebir aynı. |

**Zar güvenliği testleri:**
- 1–6 dağılımı, 120.000 atış, ki-kare: geçti.
- 1–5 dağılımı, 100.000 atış: **hiç 6 yok**, ki-kare geçti.
- Reddetme örneklemesi: sapmalı bölgedeki 32 bitlik değer atılıp yeniden çekiliyor (sahte rastgele sayı üreteciyle doğrulandı).
- Oturum, iki 6'dan sonra zar kaynağından **1–5** istiyor.
- Gerçek güvenli kaynakla 2.000 sınırlı atış: hepsi ≤ 5.
- GDScript: cihaz zarı (çevrimdışı) 5.000 atışta sınır 5 iken hiç 6 vermiyor; oturum sınırla istiyor.

**Cloudflare uyumluluğu:**
- **Statik denetim (test):** Motor kaynaklarında yalnızca göreli içe aktarmalar var; `node:*` yok.
- **Paketleme:** esbuild `--platform=neutral`, dış modül yok: **16.909 bayt**, `node:` atfı **0**.
- **Paketle çalıştırma:** 300 tam maç (2 ve 4 kişilik, 270.361 eylem), güvenli zar kaynağıyla. 3.289 sınırlı atışın **hiçbirinde 6 yok**.
- **Henüz doğrulanmadı:** Kodun gerçek Cloudflare çalışma ortamında (workerd) koşması. Bunun için `wrangler` gerekiyor; 3.3'te kurulup Workers testleriyle doğrulanacak.

### 1.4 Notlar

- **APK:** Depodaki debug APK (0.2.0) eski kuralla derlenmişti; **yeniden derlenmedi**. Çevrimdışı oyunun kaynak kodu artık yeni kuralı kullanıyor.
- **Docker:** C: diskinde **2,8 GB** boş yer var. Yerel Supabase yığını (Docker) kurulmayacak; 3.2'de **bulut `dev` projesi** kullanılacak.

## 2. Faz 3.2 — Supabase altyapısı

**Proje:**
- `kizmabirader-dev` (`eoujnamlwgbtlwigtjxx`, Frankfurt, Postgres 17, **Free**);
- CLI ile bağlandı (`supabase/config.toml`; yerel durum `.gitignore`'da).

**Ayrıntı:** [docs/setup/SUPABASE_SETUP.md](docs/setup/SUPABASE_SETUP.md).

### 2.1 Yapılanlar

- **Auth ayarları** (uzaktan okunup doğrulandı):
  - anonim giriş açık;
  - manual linking açık;
  - e-posta açık, doğrulama zorunlu;
  - JWT imzalama **ES256**.
- **Şema** (4 migration, `supabase/migrations/`):
  - yapılandırma; profiller ve istatistikler;
  - maçlar;
  - Altın + Elmas cüzdanı, defter, satın almalar, borç, giriş emaneti;
  - arkadaşlık, istek, engelleme, bildirim tabloları.
- **Güvenlik:**
  - **RLS:** her tabloda; istemci yalnızca kendi satırını okur.
  - **Yetkiler:** İstemcinin yazma yetkisi veritabanı yetkisi düzeyinde de yok. Supabase'in yeni tablolara varsayılan olarak verdiği istemci yetkileri de kapatıldı.
  - **Kısıtlı rol (K-59):** `game_server` yalnızca `game` şemasındaki sunucu işlevlerini çağırabilir. Tablolara erişemez; **NOLOGIN** (parola 3.3'te, senin tarafından).
  - **Ana anahtar:** Service role ya da gizli anahtar hiçbir yerde kullanılmıyor.
- **Ekonomi işlevleri** (tek işlem, idempotent): `start_match`, `finish_match`, `void_match`, `reconcile_stale_matches`, `grant_purchase`, `revoke_purchase`.
  - Bakiye asla eksiye düşmüyor; iade edilen satın almanın harcanmış kısmı borç oluyor ve sonraki kazançtan ödeniyor.
  - Borçlu oyuncu altınlı maça giremiyor.
  - Elmas maça hiç girmiyor.
  - Altınlı maç, `features.gold_matches_enabled = false` iken **veritabanında reddediliyor** (E-7).
- **Yeni hesap tetikleyicisi:** Profil ("Oyuncu" + etiket), istatistik, cüzdan ve yapılandırmadaki başlangıç altını.
- **Varsayılan olarak seçtiğim ama kararı açık iki kural:**
  1. Altınlı maçta bot koltuğu reddediliyor (`BOTS_IN_GOLD_MATCH`, K-66; en güvenli seçenek).
  2. 2 kişilikte karşılıklı olmayan renk veritabanında da reddediliyor (K-08, kesin karar).

### 2.2 Testler (gerçek bulutta)

| Test | Sonuç |
|---|---|
| `supabase/tests/rls_economy_test.sql` | **61 / 61** |
| `supabase/tests/api_e2e_test.mjs` | **15 / 15** |
| Supabase güvenlik denetleyicisi | Hata yok; 2 tür bilinçli uyarı (SUPABASE_SETUP §3) |

**SQL test takımı** (61 kontrol) tek işlemde koşar ve sonunda geri alınır. Kapsamı:
- **Yeni hesap:** Başlangıç altını ve defter kaydı.
- **RLS:** Oyuncu yalnızca kendini görür.
- **Yazma girişimleri:** Cüzdan, defter, profil, maç, sunucu işlevi ve iç yardımcı → hepsi reddedildi.
- **Oturumsuz erişim:** Hiçbir oyuncu verisi okunamadı.
- **`game_server` sınırları:** Tablolara ve iç yardımcılara erişemedi.
- **Altınlı maç kapalıyken:** Ret.
- **Renk ve bot kuralları:** Karşılıklı olmayan renk reddedildi; altınlı maçta bot reddedildi.
- **Emanet:** Tekrar çağrıda yeniden alınmadı; yetersiz bakiyede kimseden alınmadı.
- **Ödeme:** Havuzu aşan ödeme reddedildi; çift ödeme yapılmadı.
- **İptal ve iade:** Biten maç iptal edilemedi; geçersiz maç tek seferde iade edildi.
- **Satın alma:** Çift satın alma işlenmedi; başka kullanıcıya ait makbuz kullanılamadı.
- **İade ve borç:** İade sonrası bakiye 0'da durdu ve kalan borç oldu. Borçlu oyuncu maça alınmadı ve kimseden bedel alınmadı. Sonraki kazanç önce borcu kapattı.
- **Defter:** Defter toplamı her bakiyeye eşit.
- **Maç ve sosyal RLS:** Maç kayıtlarını yalnızca katılımcılar görüyor; engelleme profil kartını gizliyor.
- **Testin testi:** Kasıtlı yanlış bir beklentiyle çalıştırıldığında takım doğru kontrolde ("FAIL 4.13") durdu. Test sonrası veritabanında hiçbir test kaydı kalmadı.

**API testi** (15 kontrol), oyunun kullanacağı genel API'ler üzerinden. Kapsamı:
- **Hesaplar:** Gerçek iki misafir hesabı açıldı.
- **JWT:** İmza, Supabase'in genel JWKS anahtarıyla, Web Crypto'yla doğrulandı (Cloudflare'in kullanacağı yöntem). Kurcalanmış JWT reddedildi.
- **Okuma:** Oyuncu yalnızca kendi cüzdanını ve profilini okudu. Gerçek kayıtta tetikleyici çalıştı (1.000 başlangıç altını).
- **Yazma girişimleri:** Bakiye değiştirme ve deftere yazma reddedildi (HTTP 403). Sunucu işlevleri istemciden görünmüyor (HTTP 404). Denemelerden sonra bakiye değişmedi.
- **Oturumsuz erişim:** Cüzdan okunamadı (HTTP 401); genel yapılandırma okunabildi.
- **Temizlik:** Test kullanıcıları silindi (doğrulandı: 0 kullanıcı).

### 2.3 Yapılandırılmamış olanlar (bilgin gerekiyor)

- **Google girişi:** Google Cloud OAuth istemcileri ve Android SHA-1.
- **Apple girişi:** Apple Developer hesabı.
- **Üretim e-postası:** Özel SMTP, gerekirse ücretli; onayınla.
- **Derin bağlantılar** (e-posta doğrulama ve şifre sıfırlama dönüşü).
- **Misafiri kalıcı hesaba bağlama akışı:** Ayar açık, ama istemciyle denenmedi (Faz 4).
- **Sosyal yazma işlevleri ve Realtime kanalları:** Faz 4.
- **Eski misafir hesaplarının temizliği:** Karar gerekiyor (K-65).

## 3. Gerçek bulut ortamında doğrulanmış özellikler

- Supabase:
  - misafir hesap açma;
  - JWT'nin genel anahtarla doğrulanması;
  - yeni hesap tetikleyicisi;
  - RLS ve yetki sınırları;
  - ekonomi işlevleri (§2.2).
- Cloudflare: henüz yok.

## 4. Kullanıcıdan beklenen işlemler

**3.2 için tamamlananlar:**
- Supabase hesabı;
- `kizmabirader-dev` projesi;
- CLI girişi;
- Auth ayarları.

**3.3 (Cloudflare) öncesi:**
1. **Cloudflare hesabı** (ücretsiz): https://dash.cloudflare.com/sign-up ve e-posta doğrulaması. Ödeme yöntemi istenirse durup haber ver; ücretli bir şey açılmayacak.
2. **Wrangler girişi**, ayrı bir PowerShell penceresinde:
   ```
   cd C:\KizmaBirader
   npx wrangler login
   ```
   - Tarayıcıda Cloudflare yetkilendirmesi açar.
   - Oturum bilgisi yalnızca senin kullanıcı profilinde tutulur.
3. **İsteğe bağlı:** Git deposu onayı.

**Daha sonra** (3.3'ün veritabanı bağlantısı adımında):
- `game_server` rolüne panelin SQL Editor'ünde senin belirleyeceğin parolayla giriş izni vermek (SUPABASE_SETUP §5).
- Aynı parolayı Cloudflare'e terminalden gizli değer olarak girmek.

**Giriş sağlayıcıları için** (acil değil; SUPABASE_SETUP §6):
- Google Cloud OAuth istemci kimlikleri;
- Apple Developer hesabı;
- üretim SMTP kararı.
