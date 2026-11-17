# @kb/worker — Cloudflare Worker + Durable Objects oyun sunucusu

Faz 3.3 iskeleti. Tasarım: [docs/architecture/CLOUDFLARE_ARCHITECTURE.md](../../docs/architecture/CLOUDFLARE_ARCHITECTURE.md).

| Dosya | Görev |
|---|---|
| `src/index.ts` | Yönlendirici: `/v1/health`, `/v1/queue` (WebSocket, eşleştirme), `/v1/match/:id` (WebSocket), `/v1/dev/matches` (yalnızca geliştirme ve testler) |
| `src/matchmaker.ts` | **Matchmaker** Durable Object: 2 kişilik hızlı maç kuyruğu. İki farklı oyuncuyu eşleştirir, karşılıklı renk çiftini ve koltukları rastgele atar, MatchRoom'u kurar. |
| `src/match_room.ts` | **MatchRoom** Durable Object: maç başına bir nesne; mevcut TypeScript kural motoru; sunucu zarı; idempotency; her eylemden sonra kalıcı yazma; süre, bot ve otopilot için tek alarm; Hibernation API; yeniden bağlanmada tam durum |
| `src/auth.ts` | Supabase JWT doğrulaması: genel JWKS (ES256), yalnızca Web Crypto; sır yok |
| `src/protocol.ts` | İstemci mesajlarının sıkı doğrulaması: bilinmeyen tür ya da alan reddedilir. İstemci zar ya da koltuk gönderemez. |
| `test/local_ws_test.mjs` | Sunucu uçtan uca testi (25 kontrol): yerelde `wrangler dev`, `--remote <url>` ile Cloudflare'de |
| `test/godot_online_test.mjs` | **Godot istemcisinin** çevrimiçi testi: iki misafir hesap kuyrukta eşleşir, A gerçek maç ekranından oynar, maç biter; kopma ve yeniden bağlanma dahil |

```sh
npm install
npx tsc --noEmit                                   # tip denetimi
node test/local_ws_test.mjs <supabase-proje-ref>   # wrangler dev'i kendisi başlatır; gerçek misafir JWT'leri kullanır, sonra siler
node test/local_ws_test.mjs <ref> --remote https://kizmabirader-game-dev.kizmabirader.workers.dev
node test/godot_online_test.mjs [--remote <url>]  # Godot istemcisiyle iki oyunculu çevrimiçi maç
npx wrangler deploy                                # Cloudflare'e dağıtım (workers.dev alt alanı gerekir)
```

**Yapılandırma** (`wrangler.jsonc`):
- `vars` içinde yalnızca gizli olmayan değerler var.
- `ALLOW_DEV_ROUTES`: Testler ve araçlar için maç kurma ucu (oyuncular `/v1/queue` kullanır). Bu uç, oturan oyunculardan birinin geçerli Supabase JWT'sini ister. Üretimde `"false"` olmalı.
- Gizli değerler (ileride: `game_server` veritabanı parolası, bilet HMAC anahtarı) yalnızca `npx wrangler secret put <AD>` ile girilir. Yerelde `.dev.vars` kullanılır (`.gitignore`'da).

**Henüz yok:**
- Supabase'e yazma (`start_match` / `finish_match`; `game_server` parolası ve bağlantı yolu gerekli);
- maç bileti;
- 4 kişilik maçta kopan oyuncu için 90 sn "zaferi al" kuralı;
- 4 kişilik çevrimiçi maç; hızlı maçta renk tercihi (K-55 açık karar);
- kuyrukta bekleme süresi sınırı ve bot önerisi (K-05).
