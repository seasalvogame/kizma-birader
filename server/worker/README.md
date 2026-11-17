# @kb/worker — Cloudflare Worker + Durable Objects oyun sunucusu

Faz 3.3 iskeleti. Tasarım: [docs/architecture/CLOUDFLARE_ARCHITECTURE.md](../../docs/architecture/CLOUDFLARE_ARCHITECTURE.md).

| Dosya | Görev |
|---|---|
| `src/index.ts` | Yönlendirici: `/v1/health`, `/v1/match/:id` (WebSocket), `/v1/dev/matches` (yalnızca geliştirme) |
| `src/match_room.ts` | **MatchRoom** Durable Object: maç başına bir nesne; mevcut TypeScript kural motoru; sunucu zarı; idempotency; her eylemden sonra kalıcı yazma; süre, bot ve otopilot için tek alarm; Hibernation API; yeniden bağlanmada tam durum |
| `src/auth.ts` | Supabase JWT doğrulaması: genel JWKS (ES256), yalnızca Web Crypto; sır yok |
| `src/protocol.ts` | İstemci mesajlarının sıkı doğrulaması: bilinmeyen tür ya da alan reddedilir. İstemci zar ya da koltuk gönderemez. |
| `test/local_ws_test.mjs` | `wrangler dev` ile uçtan uca test (23 kontrol) |

```sh
npm install
npx tsc --noEmit                                   # tip denetimi
node test/local_ws_test.mjs <supabase-proje-ref>   # wrangler dev'i kendisi başlatır; gerçek misafir JWT'leri kullanır, sonra siler
npx wrangler deploy                                # Cloudflare'e dağıtım (workers.dev alt alanı gerekir)
```

**Yapılandırma** (`wrangler.jsonc`):
- `vars` içinde yalnızca gizli olmayan değerler var.
- `ALLOW_DEV_ROUTES`: Eşleştirici (Faz 4) gelene kadar geliştirme amaçlı maç kurma ucu. Bu uç, oturan oyunculardan birinin geçerli Supabase JWT'sini ister. Üretimde `"false"` olmalı.
- Gizli değerler (ileride: `game_server` veritabanı parolası, bilet HMAC anahtarı) yalnızca `npx wrangler secret put <AD>` ile girilir. Yerelde `.dev.vars` kullanılır (`.gitignore`'da).

**Henüz yok:**
- Supabase'e yazma (`start_match` / `finish_match`; `game_server` parolası ve bağlantı yolu gerekli);
- eşleştirici;
- maç bileti;
- 4 kişilik maçta kopan oyuncu için 90 sn "zaferi al" kuralı;
- Godot istemcisinin bu sunucuya bağlanması.
