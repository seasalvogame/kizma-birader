# Faz 7 — Geliştirme Supabase Entegrasyonu ve Bulut Test Raporu

**Tarih:** 2026-11-18
**Kapsam:** Faz 7.2 migration'ının geliştirme projesine uygulanması; SQL/RPC, eşzamanlı satın alma, katalog paritesi ve dağıtım yapılmadan Worker regresyon doğrulaması.
**Yapılmayanlar:** Worker deploy, production projesine işlem, commit, push ve gerçek oyuncu verisine işlem.

## 1. Kullanılan ortam

- Doğrulanan proje: `kizmabirader-dev` (`eoujnamlwgbtlwigtjxx`), durum `ACTIVE_HEALTHY`, bölge `eu-central-1`.
- Supabase CLI çıktısı hedef satırında `· production` etiketi gösterdi. İşlemden önce ve sonra proje adı ile ref açıkça doğrulandı; erişilen ve değiştirilen tek proje `kizmabirader-dev` oldu. Bu CLI etiketi nedeniyle sonraki operatör de proje ref'ini ayrıca kontrol etmelidir.
- Kullanılan yeniden kullanılabilir test hesapları: beş mevcut test hesabı. Yeni hesap oluşturulmadı; token veya başka gizli bilgi rapora yazılmadı.

## 2. Migration uygulanması

Önce `supabase db push --linked --dry-run` yalnız şu migration'ı gösterdi:

```text
20261119110000_phase7_2_store.sql
```

Ardından aynı bağlı geliştirme projesine `supabase db push --linked --yes` çalıştırıldı. Çıktı `Applying migration 20261119110000_phase7_2_store.sql... Finished` oldu. Sonraki migration geçmişi, hem local hem remote için `20261119110000` kaydını gösterdi. Önceki tüm migration kayıtları da eşleşiyordu.

Migration yeni cüzdan, ledger veya envanter tablosu yaratmadan mevcut `wallets`, `wallet_transactions`, `player_unlocks` ve `player_loadout` altyapısını kullanır.

## 3. SQL test sonuçları

`supabase/tests/phase7_test.sql` geliştirme projesinde çalıştırıldı. Test paketi transaction sonunda bilerek hata yükselterek rollback yaptığı için CLI'nin görünen son çıktısı `ERROR: TESTS_PASSED 35` ve çıkış kodu `1` oldu; bu paket için başarı işaretidir. Tüm **35** kontrol geçti ve testin kendi verisi rollback edildi.

Kapsanan temel durumlar: sahte/yayınlanmamış ürün, earnable ürün, server-side fiyat ve para birimi seçimi, yetersiz bakiye/kısmi kayıt bırakmama, mağaza kapalıyken red, sahiplik, kuşanma ve maç snapshot'ında geçersiz yüklemenin classic'e düşmesi.

İlk çalıştırmada 4.3 kontrolü yanlışlıkla daha önce test içinde grant edilmiş `dice_master` ürününü "sahip olunmayan" sayıyordu. Bu ürün kodu hatası değil, test fixture hatasıydı. Test `dice_mango` kullanacak şekilde düzeltildi; ikinci çalıştırmada 35/35 geçti.

## 4. RLS, RPC ve katalog gizliliği

Uzak şema/izin sorgusunda:

| Kontrol | Sonuç |
|---|---|
| `anon` için `purchase_cosmetic` / `equip_cosmetic` | Yok |
| `authenticated` için iki RPC | Var |
| authenticated için doğrudan loadout güncelleme | Yok |
| authenticated için match snapshot fonksiyonu | Yok |
| `game_server` için match snapshot fonksiyonu | Var |
| `player_loadout` RLS | Etkin |

Katalog paritesi ayrıca doğrulandı: yerel `cosmetics_catalog.json` ile buluttaki `app_config.cosmetics` sürüm `1`, ürün sayısı `43` ve sıralı ürün kimlikleri bakımından aynı. Bulut katalog satırı `is_public=false`; istemci özel fiyat/katalog kaynağını doğrudan okuyamaz.

## 5. Satın alma güvenliği ve gerçek eşzamanlılık testi

İki ayrı gerçek SQL bağlantısı ile, aynı geliştirme test hesapları üzerinde aşağıdaki kontroller yapıldı:

| Senaryo | Gözlenen sonuç |
|---|---|
| Aynı kullanıcı, aynı ürün, paralel iki istek | Bir istek `dice_night` için 400 Gold düşerek başarılı; diğeri `ALREADY_OWNED`. Tek transaction/tek unlock oluştu. |
| Aynı kullanıcı, farklı iki ürün, paralel istek | `dice_night` ve `name_mango` başarılı; bakiye `1000 → 600 → 200`. |
| İki farklı kullanıcı, aynı ürün | Her kullanıcıda ayrı ayrı başarı ve `1000 → 600`; çapraz hesap etkisi yok. |

Her senaryodan sonra yalnız ilgili test kullanıcıları ve ürünleri için ledger transaction'ları/unlock kayıtları silinip bakiyeler başlangıç değerlerine geri getirildi. Satın alma RPC'si istemciden fiyat, para birimi veya hedef kullanıcı kabul etmez; SQL paketi de sahte ürün, free/earnable ürün, yetersiz bakiye ve mağaza kapalı saldırı yollarını reddetti.

İstemcinin ayrı bir idempotency anahtarı yoktur: satın alma için deterministik server-side anahtar ve item sahiplik kontrolü kullanılır. Aynı item'in paralel isteği bu nedenle ikinci tahsilat yerine `ALREADY_OWNED` döndürdü.

## 6. Ledger, bakiye ve test hesabı temizliği

Son salt-okunur denetimde beş test hesabında başlangıç durumu korundu:

- `Faz4 A`: 1200 Gold, 0 Gem, boş unlock/loadout, 0 store transaction.
- `KBTest3`, `KBTest4`, `KBTest5`: her biri 1000 Gold, 0 Gem, boş unlock/loadout, 0 store transaction.
- `Faz4 B`: 1170 Gold, 0 Gem, boş unlock/loadout, 0 store transaction.

Dolayısıyla eşzamanlı satın alma ve yerel Worker testlerinin kalıcı ekonomi/envanter artığı yoktur.

## 7. Kuşanma ve maç snapshot sonucu

SQL paketi sahip olunmayan, yanlış kategori ve kuşanılamayan öğeleri reddetti; sahip olunan uygun kozmetik için `equip_cosmetic` akışı doğrulandı. `game.player_match_cosmetics` yalnız `game_server` rolüne açık olduğundan rakiplerin loadout'u istemciden sağlanamaz. Snapshot, yayınlanmamış/sahip olunmayan veya kategoriyle uyumsuz öğeleri varsayılan görünüme indirger.

Worker kaynak incelemesinde matchmaking/özel oda başlangıçta doğrulanmış kozmetik snapshot'ını koltuk verisine kopyalar; reconnect aynı koltuk snapshot'ını kullanır. Maç başladıktan sonra yapılan yeni kuşanma mevcut maçın görüntüsünü değiştirmez.

## 8. Worker ve emote doğrulaması

`node test/local_ws_test.mjs eoujnamlwgbtlwigtjxx` yerel `wrangler dev` ile (`DB_DISABLED:true`) çalıştırıldı ve çıkış kodu `0` verdi. Görünen test çıktısında şunlar geçti:

- gerçek geliştirme JWT'leriyle auth/koltuk bağlama;
- kuşanılmış emote'un kabulü ve yetkili koltuğa relay;
- tekrar edilen request id'nin ikinci kez relay edilmemesi;
- kuşanılmış set dışındaki emote'un reddi;
- 40'lık burst içinde 10 isteğin rate-limit ile reddi;
- iki gerçek istemciyle tam maç aşamasına giriş.

Aracın yakalanan çıktısında son `LOCAL_WS_PASSED` işareti görünmediğinden, bu koşumun tüm senaryolarını tamamlandı diye değil, **çıkış kodu başarılı fakat çıktı kanıtı kısmi** olarak kaydediyorum. Ayrıca `DB_DISABLED:true` nedeniyle bu koşum 7.2'nin gerçek veritabanı snapshot sorgusunu değil, Worker'ın yerel protokol/emote yolunu doğrular.

Dağıtılmış Worker'a istek atılmadı ve Worker deploy edilmedi. Bu nedenle gerçek Cloudflare Worker ile yeni snapshot kodunun uçtan uca doğrulaması sonraki deploy onayına bırakılmıştır.

## 9. Özel oda regresyonu

`node test/social_room_test.mjs eoujnamlwgbtlwigtjxx` yerel `wrangler dev` ile iki kez çalıştırıldı; ikisi de başarılı kabul edilmedi:

1. İlk koşum 4 kişilik odada beşinci girişin `ROOM_FULL` doğrulamasında başarısız oldu.
2. Hemen sonraki koşum, 2 kişilik oda oluşturma kontrolünde başarısız oldu; önceki yerel Durable Object oda durumunun yeniden kullanıldığına işaret ediyor.

Bu, ürün kodu için kanıtlanmış bir kapasite ihlali değildir: ikinci, erken başarısızlık lokal Durable Object test izolasyonunun kalıcı oda durumu taşıdığını gösterir. Ancak test altyapısı temiz/izole başlangıç sağlamadığı için özel oda regresyonu bu turda güvenilir şekilde geçmemiş sayılır. Kaynak kodu değiştirilmedi. Bu testin izole edilmiş Wrangler state ile tekrar çalıştırılması gerekir.

Testin `finally` temizliği, ilgili beş test hesabının match/sosyal kayıtlarını silmeyi denedi; bölüm 6'daki son kontrol ekonomi ve kozmetik verisi artığı olmadığını doğrular.

## 10. Yerel regresyon sonuçları

| Komut | Sonuç |
|---|---|
| `server/game-engine: npm test -- --run` | **8 dosya, 85/85 geçti** |
| `server/game-engine: npm run typecheck` | Geçti |
| `server/worker: npm run typecheck` | Geçti |
| `server/worker: node --check test/local_ws_test.mjs` | Geçti |
| `server/worker: node --check scripts/progression_config.mjs` | Geçti |
| `godot_console --headless --path client res://tests/test_runner.tscn` | Çıkış kodu 0; görünen çıktıda tüm listelenen unit/scene testleri PASS |
| Katalog paritesi (yerel/bulut) | Sürüm, 43 kimlik ve gizlilik eşleşti |

Godot test ortamındaki aralıklı `user://logs` yazma izni sorunu bu koşumda görünmedi. Ürün koduna bu ortam sorunu için değişiklik yapılmadı.

## 11. Çalışma ağacı ve dosya değişiklikleri

Bu tur başlangıcı ve sonrasında stage edilmiş dosya yoktur. Faz 7 kaynak değişiklikleri (Godot mağaza/kozmetik ekranları, Worker snapshot/emote akışı, shared config, migration ve SQL testleri) korunmuştur. Bu turda yalnızca:

- `supabase/tests/phase7_test.sql` içindeki test fixture seçimi `dice_master` yerine `dice_mango` olarak düzeltildi;
- bu rapor oluşturuldu.

Önceden tespit edilmiş Faz 7 dışı `client/project.godot` editor rewrite'ı korunmuştur; commit kapsamına alınmadan önce ayrıca değerlendirilmelidir. Hiçbir mevcut değişiklik silinmedi veya geri alınmadı.

## 12. Açık riskler ve çözülmeyenler

1. CLI hedef satırındaki `production` etiketi ile proje adındaki `kizmabirader-dev` farklı görünüyor. Bu turda yalnız ref/name ile doğrulanan dev proje kullanıldı; yine de sonraki operatör hedef ref'ini mutlak surette kontrol etmelidir.
2. Worker deploy yasak olduğu için dağıtılmış Worker'ın 7.2 snapshot ve emote kodu ile gerçek bulut E2E testi yapılmadı.
3. `social_room_test.mjs` local Durable Object durum izolasyonu nedeniyle güvenilir geçiş üretmedi. Bu, özel oda regresyonu için yayın öncesi giderilmesi gereken test ortamı belirsizliğidir.
4. `local_ws_test.mjs` başarı exit code'u verdi fakat yakalanan çıktı son başarı işaretini içermedi; eksiksiz log ile yeniden koşturulması önerilir.
5. `client/project.godot` Faz 7 dışı değişikliği hâlâ commit kapsamı kararı bekliyor.

## 13. Karar

**Faz 7.2 veritabanı migration'ı geliştirme Supabase projesine başarıyla uygulanmış; SQL güvenlik, RLS/RPC, katalog gizliliği ve gerçek paralel satın alma denetimleri geçmiştir.**

**Faz 7'nin tüm bulut entegrasyonu henüz koşulsuz tamamlanmış sayılmaz.** Worker deploy edilmediğinden gerçek dağıtılmış snapshot/emote E2E kapsamı doğal olarak kapalıdır; ayrıca özel oda regresyon testinin Durable Object state izolasyonu düzeltilip tekrar çalıştırılmalıdır. Bu iki konu çözülmeden production'a ilerlenmesi önerilmez.
