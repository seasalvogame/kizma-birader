# @kb/game-engine — Kızma Birader kural motoru (TypeScript)

Saf ve belirleyici bir kural motoru: **durum + eylem (+ zar) → yeni durum + olaylar**.
- **Saflık:** Saat okumaz, rastgele sayı üretmez, ağ ya da veritabanı bilmez.
- **Kimin için:** Otoriter oyun sunucusu bu paketi kullanacak. 2026-11-17 kararı: sunucu **Cloudflare Workers + Durable Objects**. Testler ve araçlar Node'da kalır; motor platformdan bağımsız tutulur (docs/architecture/CLOUDFLARE_ARCHITECTURE.md §5).
- **Eşi:** Godot istemcisindeki GDScript eşi (`client/scripts/game/rules/`) aynı davranmak zorunda; ortak test vektörleriyle denetlenir.

```sh
npm install
npm test            # vitest: kurallar, tahta, oturum, bot, özellik tabanlı testler, vektörler, ekonomi
npm run typecheck   # tsc --noEmit
npm run vectors     # shared/rules_test_vectors/*.json yeniden üretir (kural değişikliğinden sonra; farkı gözden geçir)
```

## Modüller

| Dosya | Sorumluluk |
|---|---|
| `board.ts` | **BoardGeometry:** `docs/design/board/board_map.json`'ı okur (tek kaynak); adım ↔ parkur indeksi ↔ hücre, döndürme |
| `ruleset.ts` | **Ruleset:** `classic_v1`, ayar doğrulaması (desteklenmeyen seçenekler reddedilir) |
| `state.ts` | **GameState / PlayerState / PawnState:** JSON uyumlu düz veri, `createGame` |
| `events.ts` | **GameEvent:** olay türleri (snake_case alanlar) |
| `moves.ts` | **MoveValidator + CaptureResolver:** yasal hamleler, yeme, yol |
| `turn.ts` | **TurnManager + WinCondition:** sıra, ek zar, bitiren oyuncu, sıralama |
| `dice.ts` | **DiceManager:** kriptografik (sunucu), betikli ve tohumlu (test) zar kaynakları |
| `bot.ts` | Bot / otopilot hamle seçimi (belirleyici öncelik listesi) |
| `engine.ts` | **GameEngine:** `apply(state, action, dice?)`; hata kodları; zaman aşımı ve ayrılma |
| `session.ts` | **MatchSession:** istek kimliğiyle tekrar koruması; zar yalnızca kabul edilecek eylemde çekilir |
| `canonical.ts` | Durum metni + FNV-1a 32; iki motorun karşılaştırma sözleşmesi |
| `economy.ts` | Ekonomi hazırlığı: altın giriş seviyesi yapılandırması, ödeme hesabı (tam sayı) |

## Faz 3.1 değişiklikleri (2026-11-17)

1. **Üçüncü atış kuralı (GAME_RULES §6.2):** Üst üste iki 6'dan sonraki atış yalnızca 1–5.
   - `classic_v1`: `third_six_action: "exclude_six"`. Eski davranış alternatif kural seti olarak duruyor (`"forfeit_turn"`).
   - `maxDiceValue(state)` bir sonraki atışın üst sınırını verir (5 ya da 6).
   - `apply` sınırı aşan zarı `INVALID_DICE` ile reddeder; zar sıradaki bir atıştan da, zaman aşımından da gelse aynıdır.
   - `MatchSession` zar kaynağından bu sınırla değer ister.
2. **Zar kaynağı:** `node:crypto` kaldırıldı.
   - `cryptoDice` artık Web Crypto (`crypto.getRandomValues`) ve reddetme örneklemesiyle çalışıyor; modulo sapması yok.
   - `secureRandomInt(min, max)` ayrıca dışa açık.
   - Motorun hiçbir Node'a özgü içe aktarması yok; `test/dice.test.ts` bunu denetliyor.
3. **Testler:** Yeni dosya `test/dice.test.ts`:
   - ki-kare dağılımı;
   - iki 6 sonrası hiç 6 gelmemesi;
   - reddetme örneklemesi;
   - oturumun zarı sınırla istemesi;
   - Workers uyumu.
   - Vektörler yeniden üretildi.

## Eylemler ve hatalar

**Eylemler:**

| Eylem | Alanlar | Zar |
|---|---|---|
| `roll` | `seat`, `turn_id` | Gerekir |
| `move` | `seat`, `turn_id`, `pawn` | — |
| `timeout` | `seat`, `turn_id` | Zar aşamasındaysa gerekir; sonra bot hamlesi de oynanır |
| `leave` | `seat` | — |

**Hata kodları:** `GAME_OVER`, `UNKNOWN_SEAT`, `NOT_ACTIVE`, `NOT_YOUR_TURN`, `STALE_TURN`, `WRONG_PHASE`, `INVALID_DICE`, `DICE_REQUIRED`, `ILLEGAL_MOVE`. Hata durumunda giriş durumu **değişmez**.

## İki motorun eşitliği

- **Vektörler:** `scripts/gen-vectors.ts` iki dosya üretir:
  - `shared/rules_test_vectors/scenarios.json`: elle yazılmış senaryolar; her adımın olayları ve durumu;
  - `traces.json`: tohumlu rastgele maçlar; her adımın durum özeti.
- **GDScript tarafı:** `client/tests/unit/test_vectors.gd` aynı dosyaları koşar.
- **Durum metni biçimi** (`canonical.ts`) **sözleşmedir:** değişirse iki tarafta birlikte değişir.
