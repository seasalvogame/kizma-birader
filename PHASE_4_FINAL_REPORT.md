# Faz 4 Kapanış Raporu

> **Tarih:** 2026-11-17 · **Sürüm:** 0.5.0 (versionCode 5) · Ayrıntılar: [PHASE_4_REPORT.md](PHASE_4_REPORT.md)
> **Commit:** `34050a8` (feat: complete persistent player profiles and match history). Push yapılmadı.

## Tamamlanan özellikler

- **Maç kayıtları:** Biten her çevrimiçi maçı oyun sunucusu Supabase'e kaydeder.
  - Kısıtlı `game_server` rolüyle, Cloudflare Hyperdrive üzerinden.
  - Aynı maç bir kez kaydedilir; hata olursa yeniden denenir.
  - İstemci sonuç yazamaz.
- **İstatistikler:** 2P/4P maç, galibiyet ve ayrılma aynı işlemde ve bir kez artar. Test maçları sayılmaz, çevrimdışı maçlar karışmaz.
- **Profil:** Sunucu tarafından doğrulanan ad ve avatar, `ad#etiket`. Kimse başkasının profilini değiştiremez.
- **Ekranlar:**
  - Profil, Maç Geçmişi, Maç Ayrıntısı, Hesap ve Güvenlik.
  - Yükleniyor, hata, çevrimdışı ve boş durumları var.
  - Maç sonunda "kaydedildi" bildirimi gösterilir.
- **Hesap:**
  - Misafir hesap uygulama yeniden açılınca korunur.
  - E-postayla kalıcı hesaba geçiş, parola, başka hesapla giriş ve çıkış.
  - Çakışma hataları güvenli biçimde ele alınır; oturum reddedilince hesap sessizce değiştirilmez.

## Gerçek bulutta doğrulananlar (Supabase + Cloudflare)

| Test | Sonuç |
|---|---|
| `phase4_test.sql` | 35 / 35 |
| `rls_economy_test.sql` | 61 / 61 |
| `api_e2e_test.mjs` (REST, gerçek misafir hesaplar) | 26 / 26 |
| `local_ws_test.mjs --remote` | 30 / 30 (DO yeniden başlatması + Supabase kaydı dahil) |
| `godot_online_test.mjs --remote` | Geçti |
| `/v1/health?db=1` | Worker → Hyperdrive → Postgres ~95 ms |

`godot_online_test.mjs --remote` kapsamı: iki Godot istemcisi, gerçek maç ekranı, kopma ve yeniden bağlanma, kayıt bildirimi, istatistik ve geçmiş, ad ve avatar kaydı, uygulama yeniden açılınca aynı hesap.

## Yerelde doğrulananlar

| Test | Sonuç |
|---|---|
| TS kural motoru | 85 / 85 |
| Godot birim + sahne | 35 / 35 (ağa çıkmaz, izole dosyalar) |
| Worker (`wrangler dev`, veritabanısız) | 25 / 25 |
| `tsc --noEmit` | Temiz |

## Gerçek cihazda henüz denenmeyenler

- APK 0.5.0 telefonda hiç çalıştırılmadı.
- **E-postayla kalıcı hesaba geçiş kullanıcının kendi adresiyle gerçek cihazda denenmedi.**
  - Supabase'in yerleşik e-postası yalnızca kuruluş üyelerine gönderiyor.
  - Kod ve sunucu ayarları hazır; uçtan uca sonuç bilinmiyor.
- Google ve Apple ile bağlama: Kod ve belgeler korundu, gerçek sağlayıcı bilgileri yok. **Tamamlanmış sayılmaz** (K-70).
- iOS: Derleme yapılmadı (Mac yok). Bkz. `docs/setup/IOS_SETUP.md`.

## Mağaza öncesine bırakılan işler (zorunlu)

| Karar | İş |
|---|---|
| K-67 | Uygunsuz oyuncu adı denetimi |
| K-68 | Android App Links + iOS Universal Links ile e-posta doğrulamasından uygulamaya dönüş |
| K-69 | Yenileme belirtecinin Android Keystore ve iOS Keychain'e taşınması |
| K-70 | Google / Apple sağlayıcılarının gerçek bilgilerle kurulması ve denenmesi |
| — | Üretim e-posta servisi (SMTP; ücretli olabilir, onay gerekir) |
| K-65 | Kaynağı belirsiz üç misafir hesaba dokunulmadı. Genel misafir temizliği yayından önce değerlendirilecek. |

Faz 4 bu noktada kapatıldı. Telefon testleri beklenmeden Faz 5'e geçildi.
