# Faz 7 — Son Regresyon ve Commit Öncesi Kontrol Raporu

**Tarih:** 2026-11-19
**Kapsam:** Geliştirme Supabase entegrasyonundan sonraki eksik Worker/özel oda regresyonları, Godot test ortamı, yapılandırma paritesi ve commit öncesi çalışma ağacı denetimi.
**Yapılmayanlar:** Production projesine işlem, migration'ın yeniden uygulanması, Worker deploy, commit ve push.

## 1. Test ortamı

- Tek uzaktaki hedef, ref ve adla doğrulanan geliştirme projesiydi: `kizmabirader-dev` (`eoujnamlwgbtlwigtjxx`). Supabase CLI'nin hedef satırındaki genel `production` etiketi, proje adı/ref'i değiştirmedi; bu nedenle raporda yalnız proje adı/ref'i hedef kimliği sayılmıştır.
- Yerel Worker koşumları `wrangler dev`, `DB_DISABLED:true`, `BOT_DELAY_MS:20` ile çalıştı. Dolayısıyla bu koşumlar gerçek veritabanı snapshot sorgusunu veya dağıtılmış Worker sürümünü sınamaz.
- Kullanılan hesaplar mevcut üç/beş kişilik yeniden kullanılabilir test havuzudur. Yeni hesap oluşturulmadı.
- Test bitiminde beş hesabın bakiyeleri ve store verisi yeniden salt-okunur doğrulandı: `Faz4 A` 1200 Gold, `Faz4 B` 1170 Gold, `KBTest3/4/5` her biri 1000 Gold; tamamında 0 Gem, 0 unlock ve 0 `store_purchase` transaction bulunuyor.

Tam çıktı kanıtları geçici, yazılabilir test alanında saklandı:

- `C:\Users\Tamer\AppData\Local\Temp\phase7-local-ws-final-clean.log`
- `C:\Users\Tamer\AppData\Local\Temp\phase7-social-room-final-run1.log`
- `C:\Users\Tamer\AppData\Local\Temp\phase7-social-room-final-run2.log`
- `C:\Users\Tamer\AppData\Local\Temp\phase7-godot-final-complete.stdout.log` ve `.stderr.log`
- `C:\Users\Tamer\AppData\Local\Temp\phase7-config-parity-final.stdout.log` ve `.stderr.log`

## 2. `local_ws_test.mjs`: tam sonuç

Test kodu incelendi: dev-route yetkilendirmesi, koltuk ve renk kuralları, JWT doğrulaması, snapshot, emote yetkilendirmesi/idempotency, sunucu otoritesi, rate limit, iki oyunculu tam maç, reconnect, yerel Worker yeniden başlatması sonrası Durable Object kalıcılığı, zar sınırları, timeout, autopilot ve bot-alarm senaryolarını çalıştırıyor.

İzole koşumun sonucu:

```text
LOCAL_WS_PASSED 30
cleanup: local Durable Object state removed
TEST_EXIT_CODE=0
```

Önemli somut kontroller:

- Sahte JWT, koltuk dışı JWT, sıra dışı zar ve istemciden gönderilmiş zar/koltuk alanları reddedildi.
- Yetkili emote kabul edildi; karşı koltuğa authoritative seat ile aktarıldı; tekrar request-id ikinci kez yayınlanmadı; set dışı emote reddedildi.
- 40 istekli burst'te 10 istek rate-limit edildi.
- Tam maç 307 eylem ve 181 zar atışıyla bitti; iki altılıktan sonraki 1 zarın hiçbiri altı değildi.
- 60. eylemde reconnect snapshot'ı, 120. eylemde yerel Worker yeniden başlatmasından sonra Durable Object state'i korundu.
- Timeout/autopilot/bot alarm maçı tamamlandı.

Bu test **DB-disabled** çalıştığından gerçek `game.player_match_cosmetics` veritabanı snapshot yolunu kapsamaz. Bu yolun SQL/RLS ve katalog denetimi, [bulut entegrasyon raporunda](/C:/KizmaBirader/PHASE_7_CLOUD_INTEGRATION_REPORT.md) geçen 35/35 SQL sonucu ile kapsanmıştır; dağıtılmış yeni Worker sürümüyle E2E test deploy onayı olmadan yapılamaz.

## 3. `social_room_test.mjs`: iki bağımsız temiz koşum

İki koşum da ayrı geçici Durable Object state ile yapıldı. Her ikisinde sonuç aynıdır:

```text
SOCIAL_ROOM_PASSED 32
cleanup: local Durable Object state removed
TEST_EXIT_CODE=0
```

Her iki koşumda geçen yerel oda kontrolleri:

- 2 kişilik oda: geçersiz JWT/oyuncu sayısı/kod, kapasite aşımı, renk seçimi, reconnect, ready/start, host yetkisi, maç başlatma ve tekrar lobiye dönüş.
- 4 kişilik oda: dört benzersiz renk, alınmış rengin reddi, **beşinci oyuncunun reddi**, ready/start kontrolü, ortak maç kimliği, koltuk sırası ve maç sonu.
- Host devri, odadan ayrılma, boş odanın kapanması ve oda kodu rate limit'i.

Yerel Worker `DB_DISABLED:true` olduğunda test kodu arkadaşlık, presence ve davet bölümünü kasıtlı olarak atlar ve bunu `friends, presence and invites are checked with --remote` satırıyla bildirir. Bu nedenle iki temiz yerel koşum oda işlevlerini kesin olarak doğrular; ancak canlı Supabase + dağıtılmış Worker davet/presence E2E'sini doğrulamaz.

## 4. Test izolasyonu için yapılan değişiklikler

Önceki başarısızlığın nedeni, Wrangler'ın varsayılan kalıcı Durable Object deposu olan `server/worker/.wrangler/state` dizininin test koşumları arasında paylaşılmasıydı. Bu nedenle eski oda/oyuncu state'i sonraki koşuma sızıyordu.

Yalnız test altyapısında şu değişiklik yapıldı:

- `local_ws_test.mjs` ve `social_room_test.mjs` her yeni yerel koşum için `mkdtemp` ile benzersiz bir klasör yaratıp Wrangler'a `--persist-to <geçici klasör>` geçirir.
- `local_ws_test.mjs`, kendi restart/persistence kontrolü için aynı geçici dizini koşum içinde korur; finalde siler.
- Her iki test de kapanışta `rmSync` retry ile geçici state'i siler, dizinin gerçekten kaybolduğunu doğrular ve aksi durumda testi hatalı sonlandırır.

İki başarılı koşumdan sonra `kb-wrangler-state-*` geçici test dizini kalmadığı doğrulandı. Uygulama/Worker ürün davranışı değiştirilmedi.

## 5. `client/project.godot` değerlendirmesi

**Karar: B — Faz 7 ile ilgisiz; commit dışında tutulmalı.**

Godot editor rewrite'ı:

- Dosya başlığı yorumlarını standart editor başlığıyla değiştirmiş ve `config/icon` sırasını taşımıştır; bunlar davranışsal değildir.
- `internationalization/locale/fallback="en"` satırını kaldırmıştır. Godot 4 belgelerine göre boş fallback zaten `en` kullanır; bu proje için etkin dil fallback'i değişmez. [Godot Internationalization](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html)
- `rendering/2d/snap/snap_2d_transforms_to_pixel=false` satırını kaldırmıştır. Bu ayarın varsayılanı `false` olduğundan pixel snapping davranışı değişmez. [Godot ProjectSettings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html)

Dolayısıyla mevcut Godot 4.7 testinde davranış değişikliği kanıtı yoktur; yine de değişiklik Faz 7 kapsamının parçası değildir ve Phase 7 commitinden ayrıştırılmalıdır. Dosya geri alınmadı veya stage edilmedi.

## 6. Regresyon sonuçları

| Kontrol | Sonuç |
|---|---|
| Worker TypeScript (`npm run typecheck`) | Geçti |
| `local_ws_test.mjs` | **30/30, kesin başarı işareti ve temiz state** |
| `social_room_test.mjs`, temiz koşum 1 | **32/32, kesin başarı işareti ve temiz state** |
| `social_room_test.mjs`, temiz koşum 2 | **32/32, kesin başarı işareti ve temiz state** |
| Game engine (`npm test -- --run`) | **8 dosya, 85/85 geçti** |
| Game engine TypeScript | Geçti |
| Godot unit/scene | **38 test, 0 başarısızlık, 89.0 s** |
| Faz 6/7 config parity (`progression_config.mjs --check`) | Progression, quests, daily login, achievements, leaderboard ve cosmetics: **tamamı same** |
| Faz 7 SQL/RLS/satın alma | Önceki 35/35 bulut sonucu korundu; bu turda ekonomi testi tekrar yazılmadı |
| `git diff --check` | Hata yok; yalnız CRLF dönüşüm uyarıları |

İlk Godot koşumu, kısıtlı varsayılan `user://logs` konumuna yazamadığı için oturum kalıcılığı testinde yanlış negatif verdi. Aynı test, `APPDATA`/`LOCALAPPDATA` yazılabilir geçici test dizinine yönlendirilip `--log-file` kullanıldığında 38/38 geçti. Bu test ortamı çözümüdür; ürün dosyasına değişiklik yapılmadı.

## 7. Değiştirilen dosyalar ve çalışma ağacı

Bu turun kaynak değişiklikleri yalnız test izolasyonundadır:

- `server/worker/test/local_ws_test.mjs`
- `server/worker/test/social_room_test.mjs`
- `PHASE_7_FINAL_REGRESSION_REPORT.md`

Önceden var olan Faz 7 dosyaları (Godot kozmetik ekranları, Worker snapshot/emote kaynakları, shared config, Phase 7 migration, SQL testleri ve önceki iki denetim raporu) korunmuştur. Stage edilmiş dosya yoktur. `client/project.godot` yukarıdaki B kararıyla ayrı tutulmalıdır.

## 8. Çözülmeyen riskler

1. Yerel DB-disabled Worker testi gerçek Supabase snapshot yolunu test etmez; SQL/RLS denetimi geçti, fakat dağıtılmış yeni Worker ile E2E için deploy izni gerekir.
2. Yerel özel oda testinin arkadaşlık, presence ve davet bölümü tasarım gereği DB-disabled modda çalışmaz. Dağıtılmış dev Worker üzerinde sosyal/davet E2E'si, Worker sürümünün güncelliği de doğrulanarak ayrıca koşulmalıdır.
3. Supabase CLI, `kizmabirader-dev` proje adı/ref'i için hedef satırında `production` etiketi gösteriyor. Sonraki uzaktan işlemden önce ref doğrulaması zorunludur.
4. Varsayılan Windows AppData log konumu kısıtlı test ortamında yazılamıyor; Godot testleri yazılabilir geçici kullanıcı veri diziniyle çalıştırılmalıdır.

## 9. Kapanış kararı

Yerel Worker, özel oda kapasite/host/reconnect/start akışı, oyun motoru, Godot ve Faz 6/7 config kontrolleri geçmiştir. Önceki SQL, RLS, satın alma, ledger ve katalog paritesi sonuçları korunmaktadır; açık bir kritik ekonomi veya veri tutarlılığı kusuru bulunmadı.

**Faz 7 teknik kapanışa henüz koşulsuz hazır ilan edilmemelidir.** Bunun tek kalan nedeni, bu talimatta istenen arkadaşlık/presence/davet E2E kontrollerinin iki temiz koşumda gerçekleştirilmemiş olmasıdır: yerel test modu bunları bilerek atlar, dağıtılmış güncel Worker ise deploy edilmeden doğrulanamaz. Bu kontrol tamamlanıp dağıtılmış Worker'ın Faz 7 kaynak sürümü teyit edildiğinde, mevcut yerel ve veri katmanı kanıtları kapanış için yeterlidir.
