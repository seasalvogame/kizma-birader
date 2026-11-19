# Faz 7 — Yayın Öncesi Kod Denetimi

**Tarih:** 2026-11-18
**Kapsam:** Commit, remote Supabase migration, Worker deploy ve push öncesi salt yerel denetim.
**Uzak işlem:** Yapılmadı. Remote veritabanına yazan test, migration, deploy, commit ve push çalıştırılmadı.

## 1. Çalışma ağacı ve denetlenen dosyalar

Başlangıçta stage edilmiş dosya yoktu. Faz 7 çalışma ağacında 32 değiştirilmiş takipli dosya ile üç yeni dosya vardı:

- Yeni: `supabase/migrations/20261119110000_phase7_2_store.sql`, `client/scripts/ui/screens/store_screen.gd`, ilgili `.uid` dosyası.
- Supabase: Faz 7 testi; Faz 6'nın ödül config kaynakları (`shared/config/*.json`); config sync betiği.
- Worker: `db.ts`, eşleştirici, özel oda, maç odası, protokol ve yerel WebSocket testi.
- Godot: mağaza/detay/çevrimiçi kozmetik API'si, profil-maç görselleri, zar-piyon-tahta/avatar çizimi, çeviriler ve sahne testi.
- Dokümantasyon: ağ protokolü.

`client/project.godot` ayrıca değiştirilmiş durumda; bu Faz 7 davranışının parçası değildir. Godot düzenleyicisinin biçimsel yeniden yazımı `locale/fallback` ve `2d/snap/snap_2d_transforms_to_pixel` satırlarını kaldırmış, başlık yorumlarını değiştirmiştir. Bu dosya geri alınmadı; committen önce ayrı değerlendirilmelidir.

Kullanılmayan/tekrarlanan Faz 7 dosyası bulunmadı. Store placeholder'ı artık gerçek `StoreScreen` ile değiştirilmiş; eski `InfoScreen` mağaza dalı kaldırılmıştır.

Denetim sonundaki tam git envanteri:

```text
staged: yok
modified:
  client/localization/en.po
  client/localization/tr.po
  client/project.godot                         # Faz 7 dışı editor rewrite
  client/scripts/app/main.gd
  client/scripts/board/board_view.gd
  client/scripts/board/dice_view.gd
  client/scripts/board/pawn_sprite.gd
  client/scripts/game/online_match_controller.gd
  client/scripts/online/online_api.gd
  client/scripts/online/online_cosmetics.gd
  client/scripts/online/online_match_connection.gd
  client/scripts/ui/avatar.gd
  client/scripts/ui/player_card.gd
  client/scripts/ui/screens/cosmetic_detail_screen.gd
  client/scripts/ui/screens/info_screen.gd
  client/scripts/ui/screens/match_screen.gd
  client/scripts/ui/screens/profile_screen.gd
  client/tests/scene/test_app_navigation.gd
  client/tools/make_translations.py
  docs/NETWORK_PROTOCOL.md
  server/worker/scripts/progression_config.mjs
  server/worker/src/db.ts
  server/worker/src/match_room.ts
  server/worker/src/matchmaker.ts
  server/worker/src/private_room.ts
  server/worker/src/protocol.ts
  server/worker/test/local_ws_test.mjs
  shared/config/achievements_config.json
  shared/config/leaderboard_config.json
  shared/config/progression_config.json
  shared/config/quests_config.json
  supabase/tests/phase7_test.sql
untracked:
  PHASE_7_PRE_RELEASE_AUDIT.md
  client/scripts/ui/screens/store_screen.gd
  client/scripts/ui/screens/store_screen.gd.uid
  supabase/migrations/20261119110000_phase7_2_store.sql
```

## 2. SQL ve migration güvenliği

`20261119110000_phase7_2_store.sql`, 7.1'in katalog, `player_unlocks`, `player_loadout`, `app_private.cosmetic`, `app_private.owns` ve `game._grant_item` altyapısını yeniden kullanır; yeni cüzdan/ledger/envanter tablosu oluşturmaz.

- Yeni public RPC'ler `SECURITY DEFINER`, boş `search_path` ve `auth.uid()` zorunluluğu kullanır.
- `purchase_cosmetic(text)` ve `equip_cosmetic(text)` için `public` ve `anon` yetkisi kaldırılıp yalnızca `authenticated` rolüne `EXECUTE` verilir.
- Yardımcı katalog/sahiplik fonksiyonları istemci rollerinden kapalıdır.
- `game.player_match_cosmetics(uuid[])` yalnız `game_server` rolüne açıktır; en çok dört kimlik için yalnız sunucu-doğrulanmış, yayınlanmış ve sahip olunan görsel seçimi döndürür.
- `player_loadout` doğrudan yazmaya açık değildir; RLS yalnız sahibinin okumasına izin verir. Kuşanma yalnız RPC üzerinden yapılır.
- 7.1'deki özel `app_config.cosmetics` korunur. Config sync betiği artık bu anahtarı public yapmaz.
- Faz 6 claim ve liderlik fonksiyonlarının `CREATE OR REPLACE` sürümleri mevcut kimlik/ödül/idempotency akışını korur ve yalnız server-owned config içinden opsiyonel kozmetik verir.

Fonksiyonların önceki migration'larla isim veya tablo çakışması bulunmadı. 7.2, 7.1'den sonra sıralandığı için bağımlı fonksiyonlar ve tablolar önce oluşur.

## 3. RLS, RPC ve satın alma güvenliği

Satın alma RPC'si istemciden yalnız ürün kimliği kabul eder. Fiyat ve para birimi katalogdaki rarity tablosundan, hedef kullanıcı `auth.uid()` üzerinden, sahiplik ise server-side inventory fonksiyonundan gelir.

| Senaryo | Sonuç |
|---|---|
| Sahte/bilinmeyen ürün | `ITEM_NOT_FOUND` |
| Yayınlanmamış ürün | `ITEM_NOT_FOUND` |
| Earnable veya ücretsiz ürün | `NOT_FOR_SALE` |
| Sahte fiyat / para birimi | İstemci parametresi yok; sunucu katalogdan seçer |
| Başka kullanıcı için satın alma veya kuşanma | Hedef kullanıcı parametresi yok; `auth.uid()` kullanılır |
| Başka envanteri okuma/yazma | RLS ve owner-scoped RPC engeller |
| Yetersiz bakiye | `game._apply` CHECK ihlalini `INSUFFICIENT_FUNDS` yapar |
| Açık borç | İlgili para biriminde `DEBT_OPEN` |
| Mağaza kapalı | `STORE_CLOSED` |
| Kuşanılmamış / badge öğesi | `NOT_OWNED` / `NOT_EQUIPPABLE` |

Satın alma tek Postgres transaction'ındadır. Cüzdan satırı önce kilitlenir; `_apply` aynı kilit altında bakiye ve benzersiz idempotency anahtarıyla ledger yazar; sonra envanter kaydı eklenir. Hata veya bağlantı kopması transaction'ı geri alır. Aynı oyuncunun paralel isteği ikinci kez kilidi aldıktan sonra sahiplik kontrolüne takılır; tekrar gönderim çift tahsilat yapmaz.

## 4. Eşzamanlılık ve ekonomi

- `wallets ... FOR UPDATE`, eş zamanlı aynı oyuncu satın alımlarını serialize eder.
- `wallet_transactions.idempotency_key` ve `game._apply` yeniden gönderimi ledger'da tekilleştirir.
- Envanter kaydı ve tahsilat aynı transaction'da olduğundan kısmi satın alma bırakılmaz.
- Mevcut borç kontrolü Gold/Gems için ayrı çalışır; bakiye negatifleşmez.
- 7.2 yeni ekonomi kuralı veya gerçek para/IAP/reklam akışı eklemez.

Gerçek paralel bağlantı ve bağlantı-kopması SQL testinde ayrı oturum gerektirir; yerel Supabase/Postgres ortamı yoktur. Kod yolu ve lock/idempotency tasarımı denetlendi; bu iki senaryo geliştirme veritabanı testinden sonra ayrıca doğrulanmalıdır.

## 5. Worker ve maç entegrasyonu

Eşleştirici ile özel oda, maç başlamadan `game.player_match_cosmetics` üzerinden doğrulanmış yüklemeyi alır. `MatchRoom` bunu kalıcı koltuk verisinde saklar; snapshot ve reconnect aynı sabit görsel yüklemeyi döndürür. Maç sonrasında yapılan kuşanma değişikliği mevcut maçı etkilemez.

İstemci rakibin kozmetik kimliğini Worker'a göndermez. İstemcideki bir bellek/UI değişikliği yalnız yerel çizimi etkileyebilir; oyun kuralları, zar sonucu, sahiplik veya diğer oyuncunun snapshot'ı değişmez.

Emote için Worker:

- yalnız match başlangıcında doğrulanmış emote setindeki ifadeyi kabul eder;
- request-id sonucu `seen` içinde saklar, tekrar gönderimi tekrar yayınlamaz;
- zaman damgalarını Durable Object kaydında saklar ve 10 saniyede en çok üç kullanım uygular;
- reconnect sonrası kalıcı rate-limit ve görsel snapshot korunur; geçici emote balonu geçmişi yeniden oynatılmaz.

## 6. Godot istemci denetimi

- Store yalnız sunucudan gelen yayınlanmış/satılabilir/sahip olunmayan öğeleri listeler.
- Detay ekranı satın alma veya kuşanma sırasında `_busy` ile çift dokunmayı engeller.
- İstemci RPC'ye yalnız ürün kimliği yollar; hata kodları yetersiz bakiye, sahiplik, borç ve mağaza kapalı durumlarına çevrilir.
- Başarılı işlemden sonra envanter sunucudan yenilenir. Yenileme başarısızsa cache yalnız görsel kolaylık olarak güncellenir; sonraki RPC yine sunucu kontrolünden geçer.
- Cache uygulama yeniden açıldığında yüklenir; sahiplik/fiyat otoritesi değildir.
- Profil, kendi tahta/zar/piyon görünümü, oyuncu kartları, rakip snapshot'ı ve emote seçimi incelendi. Rakip görselleri server snapshot'tan gelir.

`user://logs` hata bulgusu ürün kodu değildir. Kısıtlı çalışma ortamında Godot zaman zaman AppData altındaki log dizinine yazamaz; bu, oturum-kalıcılığı testini aralıklı etkileyebilir. Bu denetimdeki son doğrudan sahne testi tamamen geçti; önceki sandbox çalıştırmalarında görülen izin sorunu için ürün kodunda değişiklik yapılmadı.

## 7. Eklenen test kapsamı

`supabase/tests/phase7_test.sql` şu kontrollerle genişletildi:

- ikinci satın alma/idempotency ve tek ledger kaydı;
- earnable ürünün satın alınamaması;
- sahte ve yayınlanmamış ürün;
- yetersiz Gold sonrası envanter/ledger'da kısmi kayıt kalmaması;
- sunucunun Gems para birimi ve fiyatını seçmesi;
- mağaza kapalıyken red;
- sahip olunmayan veya badge öğesinin kuşanılamaması;
- match snapshot'ının çapraz kategori veya sahip olunmayan loadout'ı classic'e düşürmesi.

Godot sahne testi ayrıca mağaza hata metinlerinin yetersiz bakiye ve sahiplik için eyleme geçirilebilir olduğunu doğrular.

## 8. Yerel test sonuçları

| Komut | Sonuç |
|---|---|
| `server/game-engine: npm test -- --run` | **8 dosya, 85/85 geçti** |
| `server/worker: npx tsc --noEmit` | **Geçti** |
| `server/worker: node --check test/local_ws_test.mjs` | **Geçti** |
| `server/worker: node --check scripts/progression_config.mjs` | **Geçti** |
| `godot_console --headless --path client res://tests/test_runner.tscn` | **Tüm listelenen testler geçti** |
| Faz 7 config/parite PowerShell denetimi | **`PHASE7_CONFIG_PARITY_OK`** |
| `git diff --check` | Hata yok; yalnız CRLF uyarıları |

SQL test paketi çalıştırılmadı: migration henüz uygulanmış değil ve bu denetimin kuralı remote veritabanına yazmayı yasaklıyor. Worker E2E testi de gerçek Supabase test hesapları/veritabanı temizliği kullandığından çalıştırılmadı.

## 9. Tespit edilen ve düzeltilenler

- Eksik satın alma saldırı senaryoları ve istemci hata metni kontrolleri testlere eklendi.
- Godot düzenleyicisinin Faz 7 dışı `client/project.godot` yeniden yazımı tespit edildi; geri alma yapılmadı.
- Ürün davranışında bu denetimde düzeltilmesi gereken kritik kod kusuru bulunmadı.

## 10. Çözülemeyenler / yayın öncesi riskler

1. SQL migration ve SQL testi yerel veya uzak gerçek PostgreSQL üzerinde bu turda çalıştırılmadı. Uygulama öncesi en yüksek kalan risk budur.
2. Gerçek paralel RPC ve bağlantı-kopması testi iki SQL oturumu gerektirir; geliştirici Supabase testinden sonra yürütülmelidir.
3. Worker E2E emote testi kod olarak güncellendi, ancak gerçek JWT/test hesabı kullandığı için çalıştırılmadı.
4. `client/project.godot` Faz 7 dışı değişikliği commit kapsamından ayrıştırılmalıdır.
5. Godot log dizini izin sorunu CI/yerel test ortamında düzeltilmelidir; ürün çalışma koduna müdahale gerekmez.

## 11. Karar

**Koşullu olarak geliştirme Supabase ortamına uygulanmaya hazırdır.** Kod güvenlik ve yerel test denetimini geçti; ancak uygulamadan önce `client/project.godot` değişikliği hakkında karar verilmelidir. Migration uygulandıktan hemen sonra `supabase/tests/phase7_test.sql`, özellikle satın alma/kuşanma ve snapshot testleri, geliştirme ortamında çalıştırılmalı; ardından Worker E2E emote testi yapılmalıdır.
