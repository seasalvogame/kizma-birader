# NETWORK_PROTOCOL — Gerçek Zamanlı Protokol (WSS) ve REST Uçları

> **Durum:** Faz 1 taslağı (2026-11-16). Protokol sürümü: **`1`**.
>
> **Şemaların kaynağı:** Mesaj şemaları `@kb/protocol` paketinde (zod → JSON Schema) tanımlanır. Bu belge onların insan tarafından okunabilir özetidir.
>
> **Temel ilke:** İstemci yalnızca **istek** gönderir. Durumu her zaman sunucu belirler ve yayınlar.
>
> **Faz 2 sonrası güncelleme (2026-11-17):**
> - **Sunucu:** Cloudflare Workers + Durable Objects ([architecture/CLOUDFLARE_ARCHITECTURE.md](architecture/CLOUDFLARE_ARCHITECTURE.md)).
> - **Sosyal mesajlar** (çevrimiçi durumu, davet, bildirim): Supabase Realtime üzerinden (§5.1).
> - **2 kişilikte renk seçimi** eklendi (§4, §5.4).
> - **Zar:** Üçüncü atış kuralı (GAME_RULES §6.2) nedeniyle `turn.forfeit` artık `three_sixes` nedenini taşımaz.
> - **Ping:** Uygulama düzeyinde düzenli `ping` kaldırıldı (maliyet; §1).

## 1. Taşıma

- **Bağlantı:** Cloudflare Worker üzerinden, yalnızca TLS 1.2+ (geliştirmede de WSS; sertifika doğrulaması kapatılmaz):
  - `wss://game.<alan>/v1/queue`: hızlı maç kuyruğu (Matchmaker DO).
  - `wss://game.<alan>/v1/match/{matchId}`: maç (MatchRoom DO).
  - `wss://game.<alan>/v1/room/{kod}`: özel oda (MatchRoom DO, bekleme aşaması).
- **Biçim:** UTF-8 JSON metin çerçeveleri. Tipik mesaj < 2 KB; anlık görüntü (snapshot) < 8 KB.
  - Sıkıştırma: MVP'de `permessage-deflate` kapalı; ölçüme göre açılır.
  - İkili biçim (MessagePack) v1.1'de değerlendirilir.
- **Bağlantı sayısı:** Aynı anda **tek** oyun bağlantısı vardır: kuyruk **ya da** oda **ya da** maç.
  - Eşleşince kuyruk bağlantısı kapanır ve maç bağlantısı açılır.
  - Sosyal kanallar (Supabase Realtime) yalnızca menülerde açıktır; maç sırasında kapatılır (architecture/SUPABASE_ARCHITECTURE §7).
- **Heartbeat:** İstemci 10 sn'de bir WebSocket **protokol** `ping` çerçevesi gönderir.
  - Cloudflare çalışma ortamı otomatik `pong` döner: nesne uyanmaz, faturalanmaz.
  - 20 sn yanıt yoksa istemci bağlantıyı kopmuş sayar ve yeniden bağlanır.
  - Sunucu tarafında kopma, `webSocketClose` olayı ve otomatik yanıt zaman damgasıyla izlenir (**doğrulanacak**, CLOUDFLARE_ARCHITECTURE T-3).
  - Uygulama düzeyinde düzenli `ping` mesajı **yoktur**: her gelen mesaj faturalanır ve nesneyi uyandırır. Saat eşitleme için bağlantı başında en fazla 3 `ping` gönderilir (§9).

## 2. Zarf

```json
{ "v": 1, "t": "action.move", "id": "c-7f3a…", "seq": 42, "ack": 118, "p": { … } }
```

| Alan | Yön | Anlamı |
|---|---|---|
| `v` | ikisi | Protokol sürümü |
| `t` | ikisi | Mesaj türü (§4, §5) |
| `id` | istemci → | **İstek kimliği** (UUIDv4 ya da `c-` + 96 bit rastgele). Tekrar gönderimde **aynı** kalır (§7). |
| `seq` | sunucu → | Bağlantı bazında değil, **maç bazında** artan olay sıra numarası. Lobi mesajlarında yok. |
| `ack` | istemci → | İstemcinin uyguladığı son `seq` (yeniden bağlanmada ve tanılamada) |
| `re` | sunucu → | Yanıtı olduğu istemci isteğinin `id` değeri |
| `st` | sunucu → | Sunucu saati (ms); saat farkı düzeltmesi için (§9) |
| `p` | ikisi | Yük (payload) |

## 3. Bağlantı ve kimlik doğrulama

```
→ hello   { token: "<Supabase JWT>", clientVersion: "1.0.0", platform: "android", locale: "tr",
            resume: { matchId?: "…", resumeToken?: "…", lastSeq?: 118 } }
← welcome { userId, serverTime: 1763300000123, minClientVersion: "1.0.0",
            activeMatch?: { matchId, endpoint }, rateLimits: { … } }
← error   { code: "AUTH_EXPIRED" | "VERSION_TOO_OLD" | "BANNED" | "MAINTENANCE", … } ve bağlantı kapanır
```

- **Zamanlama:** `hello`, bağlantıdan sonraki **5 sn** içinde gelmezse bağlantı kapatılır.
- **JWT kontrolü:** İmza, `exp`, `aud=authenticated` ve `iss` sunucuda doğrulanır.
  - JWT bağlantı sırasında süresini doldurursa sunucu `auth.refresh_required` gönderir. İstemci yeni belirteci `auth.refresh {token}` ile 60 sn içinde iletir; iletmezse bağlantı kapanır.
- **Tek oturum:** Aynı kullanıcı ikinci bir cihazdan bağlanırsa önceki bağlantıya `error{code:"SESSION_REPLACED"}` gönderilir ve kapatılır. Maç kontrolü yeni bağlantıya geçer.

## 4. İstemci → sunucu mesajları

| Tür | Yük | Not |
|---|---|---|
| `ping` | `{ clientTime }` | `pong {clientTime, serverTime}` ile yanıtlanır. **Yalnızca bağlantı başında, en fazla 3 kez** (§9). |
| `auth.refresh` | `{ token }` | |
| ~~`presence.subscribe`~~ | — | **Kaldırıldı:** çevrimiçi durumu Supabase Realtime Presence ile (§5.1) |
| `queue.join` | `{ mode: "2p"\|"4p", ruleset: "classic_v1", tier: "free"\|"<giriş seviyesi>", preferredColor?: "red"\|"green"\|"yellow"\|"blue" }` | Ceza, sürüm, yasak ve (altınlı seviyede) bakiye / borç kontrolü. `preferredColor` yalnızca 2 kişilikte; tercih garanti değildir (K-55). |
| `queue.leave` | `{}` | İptal önceliklidir |
| `queue.accept_bot` | `{ offerId }` | K-05 |
| `room.create` | `{ players: 2\|4, ruleset, turnSeconds?: 10\|15\|20, color?: "red"\|"green"\|"yellow"\|"blue" }` | Özel oda. 2 kişilikte kurucunun rengi; katılanın rengi karşı renk olur (K-57). |
| `room.join` | `{ code }` ya da `{ roomId }` | |
| `room.leave` / `room.kick` | `{ userId? }` | Kick yalnızca oda sahibi |
| `room.set_seat` | `{ color }` | Renk değiştirme isteği. **2 kişilikte:** yalnızca karşılıklı çiftler (kırmızı–sarı, yeşil–mavi); diğer oyuncunun rengi otomatik karşı renk olur. Sunucu geçersiz ya da çakışan isteği `COLOR_TAKEN` / `COLOR_INVALID` ile reddeder. Maç başladıktan sonra renk değişmez. |
| `room.fill_bot` | `{ seat }` | Yalnızca sahip |
| `room.start` | `{}` | Yalnızca sahip |
| `invite.send` | `{ toUserId, roomId }` | Yalnızca arkadaşa; sınırlar §10 |
| `invite.respond` | `{ inviteId, accept: bool }` | |
| `match.ready` | `{ matchId }` | Maç sahnesi yüklenince |
| `action.roll` | `{ matchId, turnId }` | Yalnızca sırası gelen oyuncu |
| `action.move` | `{ matchId, turnId, pawn: 0..3 }` | `pawn` yalnızca `legalMoves` içinden |
| `action.emote` | `{ matchId, emoteId }` | 10 sn'de 3 |
| `action.claim_win` | `{ matchId }` | 2 kişilikte rakip 90 sn kopuksa (GAME_RULES §11.3) |
| `action.resume_control` | `{ matchId }` | Otopilottan kontrolü geri al |
| `match.leave` | `{ matchId }` | Onaylı ayrılma |
| `match.resync` | `{ matchId }` | Tam durum iste |

## 5. Sunucu → istemci mesajları

### 5.1 Lobi ve sosyal

> **2026-11-17:** Bu bölümdeki mesajlar oyun soketinden **değil**, Supabase Realtime kanallarından gelir:
> - `user:<id>`: Broadcast; davet, bildirim, cüzdan güncellemesi.
> - `presence:<id>`: Presence; çevrimiçi durumu.
>
> Yük biçimi aynı kalır. Kalıcı iz `notifications` tablosundadır. Ayrıntı: architecture/SUPABASE_ARCHITECTURE §7.

| Tür | Yük |
|---|---|
| `presence.update` | `{ userId, status: "online"\|"in_match"\|"offline", lastSeen? }` (yalnızca arkadaşlar) |
| `invite.received` | `{ inviteId, from: {userId, name, tag, avatar}, roomId, mode, expiresAt }` |
| `invite.updated` | `{ inviteId, status: "accepted"\|"declined"\|"expired" }` |
| `notify` | `{ kind: "friend_request"\|"friend_accepted"\|"reward_ready"\|"system", payloadKey, params }` |
| `wallet.update` | `{ coins, gems, reason }` (sunucuda bir ödül ya da satın alma işlendiğinde; bakiye yalnızca bilgi amaçlı, otorite Postgres) |
| `reward.granted` | `{ intentId?, coins?, items? }` |

### 5.2 Eşleştirme ve oda

| Tür | Yük |
|---|---|
| `queue.status` | `{ state: "searching", position?, etaSeconds?, elapsed }` |
| `queue.offer_bot` | `{ offerId, seatsToFill, rewardMultiplier: 0.5 }` |
| `queue.cancelled` | `{ reason: "user"\|"penalty"\|"server" }` |
| `room.state` | `{ roomId, code, ownerId, players: 2\|4, seats: [{seat, color, user?, isBot, ready}], ruleset, turnSeconds, expiresAt }` |
| `match.found` | `{ matchId, seat, color, ticket, resumeToken, players: [ … ], ruleset, entryFee? }` (`ticket`: MatchRoom'a giriş için imzalı, kısa ömürlü bilet) |

### 5.3 Maç

| Tür | Yük | Not |
|---|---|---|
| `match.snapshot` | Tam durum: `{ matchId, stateVersion, seq, ruleset, players: [{seat, color, userId?, name, avatar, level, isBot, status, finishedRank?}], pawns: {color: [step × 4]}, turn: {turnId, seat, phase: "roll"\|"move", dice?, legalMoves?, deadline, consecutiveSixes}, startedAt, serverTime }` | Bağlanma, geri dönüş ve `resync` |
| `match.started` | `{ firstSeat }` | |
| `turn.start` | `{ turnId, seat, phase: "roll", deadline }` | |
| `dice.rolled` | `{ turnId, seat, value, legalMoves: [{pawn, from, to, captures: [{color, pawn}], finishes}], deadline }` | `legalMoves` boşsa sıra kısa bir gecikmeyle geçer |
| `pawn.moved` | `{ turnId, seat, pawn, from, to, path: [step…], captures: [{color, pawn, from}], finished: bool, auto: "timeout"\|"autopilot"\|"single"\|null }` | |
| `turn.bonus` | `{ seat, reason: "six"\|"capture"\|"finish" }` | Ek zar |
| `turn.forfeit` | `{ seat, reason: "no_moves" }` | `three_sixes` nedeni kaldırıldı: üçüncü atış 1–5 (GAME_RULES §6.2) |
| `player.status` | `{ seat, status: "connected"\|"disconnected"\|"autopilot"\|"left"\|"finished", since, rank? }` | |
| `emote` | `{ seat, emoteId }` | Engellenen göndericininki gönderilmez |
| `match.ended` | `{ matchId, reason: "finished"\|"opponents_left"\|"claimed"\|"void", ranks: [{seat, rank, result}], rewards: {coins, xp, levelUp?, questsProgressed: [ … ], achievements: [ … ]}, adDoubleAvailable: bool }` | Ödüller **yalnızca alıcının kendisi** için |

- **`legalMoves[].to`:** Adım numarasıdır (GAME_RULES §1). İstemci bunu `board_map.json` ile hücreye çevirir.

### 5.4 Yanıtlar ve hatalar

```json
{ "v":1, "t":"ok",    "re":"c-7f3a…", "p": { } }
{ "v":1, "t":"error", "re":"c-7f3a…", "p": { "code":"NOT_YOUR_TURN", "message":"…", "retryAfterMs":0 } }
```

| Kod | Anlamı | İstemcinin yapacağı |
|---|---|---|
| `AUTH_INVALID` / `AUTH_EXPIRED` | Belirteç geçersiz / süresi geçmiş | Yenile, yeniden bağlan |
| `VERSION_TOO_OLD` | İstemci eski | Zorunlu güncelleme ekranı |
| `MAINTENANCE` | Bakım | Bakım kartı |
| `BANNED` | Yasaklı | Yasak açıklaması (süre) |
| `SESSION_REPLACED` | Başka cihazda açıldı | "Başka bir cihazda oturum açıldı" |
| `RATE_LIMITED` | Çok sık istek | `retryAfterMs` bekle |
| `INVALID_MESSAGE` | Şema hatası | Günlüğe yaz (hata) |
| `NOT_IN_MATCH` / `MATCH_NOT_FOUND` | Maç yok | Ana menü |
| `NOT_YOUR_TURN` / `STALE_TURN` | Eski tur | `resync` |
| `ILLEGAL_MOVE` | Hamle geçersiz | `resync` (istemci hatası) |
| `QUEUE_PENALTY` | Terk cezası | Kalan süreyi göster |
| `ROOM_FULL` / `ROOM_NOT_FOUND` / `ROOM_FORBIDDEN` | Oda sorunları | İlgili mesaj |
| `COLOR_TAKEN` / `COLOR_INVALID` | Renk başka oyuncuda / karşılıklı çift kuralına aykırı | Renk seçimini güncelle |
| `INSUFFICIENT_FUNDS` / `DEBT_OUTSTANDING` | Altınlı seviye için bakiye yetersiz / ödenmemiş iade borcu var | Bakiye ya da borç bilgisini göster |
| `NOT_FRIENDS` / `BLOCKED` | Davet edilemez | Genel ifade ("Davet gönderilemedi") |
| `TRY_AGAIN` | Geçici sunucu hatası | Üstel geri çekilme |

## 6. Yeniden bağlanma ve devam

1. İstemci bağlantının koptuğunu fark eder (soket hatası, ping zaman aşımı, ağ değişimi, uygulamanın ön plana dönmesi).
2. **Üstel geri çekilmeyle** yeniden bağlanır: 0.5, 1, 2, 4, 8, 15, 15… sn. Ağ değişince hemen dener.
3. `hello { resume: { matchId, resumeToken, lastSeq } }` gönderir.
4. Sunucu cevabı:
   - `lastSeq`'ten sonraki olaylar halka tamponunda (son 200 olay) varsa **eksik olayları** sırayla gönderir.
   - Yoksa `match.snapshot` gönderir.
5. Oyuncu otopilottaysa ve kendi sırasıysa sunucu kontrolü geri verir ve `player.status{connected}` yayınlar.
   - Kopukluk sırasında yapılan otomatik hamleler `pawn.moved{auto:"autopilot"}` olarak oyuncuya da gider.

**Güvenlik:** `resumeToken`, maç ve koltuğa bağlı, 2 saat geçerli, imzalı (HMAC) bir belirteçtir. JWT ile **birlikte** gönderilir; tek başına yeterli değildir.

## 7. İdempotency, sıra ve yarış koşulları

- **İstek kimliği:** MatchRoom her koltuğun son isteklerini ve yanıtlarını kendi kalıcı durumunda saklar; hibernation ve yeniden başlatmada kaybolmaz (architecture/CLOUDFLARE_ARCHITECTURE §3.3).
  - Aynı `id` tekrar gelirse işlem **yeniden yapılmaz**; ilk yanıt (`ok`, olay ya da `error`) tekrar gönderilir.
  - Böylece ağ yüzünden tekrarlanan "zar at" ikinci bir zar üretmez.
- **Tur kimliği:** Her tur ve ek zar yeni bir `turnId` alır. Eski `turnId`'li istekler `STALE_TURN` ile reddedilir.
- **Durum sürümü:** `stateVersion` her değişiklikte artar. İstemci olayları `seq` sırasıyla uygular; boşluk görürse (`seq` atlarsa) `match.resync` ister.
- **Zaman aşımı yarışı:** Süre dolarken istemci hamlesi gelirse sunucunun saatine göre karar verilir: hamle `deadline`'dan önce işlendiyse geçerlidir, sonra geldiyse `STALE_TURN`.
  - 150 ms'lik **tolerans** tanınır (ağ gecikmesi için); tolerans süresince otomatik hamle bekletilir.
- **Ayrılma ve hamle yarışı:** `match.leave` gelince oyuncunun bekleyen istekleri iptal edilir.

## 8. Maç akışı örneği (2 kişilik, kısaltılmış)

```text
→ queue.join {mode:"2p"}                         ← ok
← queue.status {state:"searching", etaSeconds:12}
← match.found {matchId:"m1", seat:0, color:"red", resumeToken:"…"}
→ match.ready {matchId:"m1"}
← match.snapshot {stateVersion:1, seq:1, …}
← match.started {firstSeat:1}                     (seq 2)
← turn.start {turnId:"t1", seat:1, deadline:…}   (seq 3)
← dice.rolled {turnId:"t1", seat:1, value:4, legalMoves:[]}          (seq 4)
← turn.start {turnId:"t2", seat:0, phase:"roll", deadline:…}         (seq 5)
→ action.roll {matchId:"m1", turnId:"t2"}  id:"c-1"
← dice.rolled {turnId:"t2", seat:0, value:6, legalMoves:[{pawn:0, from:-1, to:0, captures:[], finishes:false}, …]} re:"c-1" (seq 6)
→ action.move {matchId:"m1", turnId:"t2", pawn:0}  id:"c-2"
← pawn.moved {turnId:"t2", seat:0, pawn:0, from:-1, to:0, path:[0]}  (seq 7)
← turn.bonus {seat:0, reason:"six"}                                  (seq 8)
← turn.start {turnId:"t3", seat:0, phase:"roll", deadline:…}         (seq 9)
…
← match.ended {reason:"finished", ranks:[…], rewards:{coins:60, xp:40}, adDoubleAvailable:true}
```

## 9. Saat eşitleme

- **Fark hesabı:** Bağlantı başındaki en fazla 3 `ping` / `pong { clientTime, serverTime }` ölçümüyle istemci gidiş-dönüş süresini (RTT) ve saat farkını hesaplar: `offset = serverTime − (clientTime + RTT/2)`.
  - Ölçümlerin ortancası kullanılır.
  - Sunucunun her zarf mesajında taşıdığı `st` (sunucu saati) alanıyla fark düzeltilir; ek ping gerekmez.
- **Kullanım:** Sayaçlar `deadline − (now + offset)` ile çizilir. İstemci saati değiştirilse de sayaç doğru kalır; otorite yine sunucudadır.

## 10. Hız sınırları (sunucu, kullanıcı başına)

| Mesaj | Sınır |
|---|---|
| Bütün mesajlar | 30 / sn patlama, 10 / sn sürekli (aşılırsa `RATE_LIMITED`, sürerse bağlantı kapanır) |
| `queue.join` | 6 / dk |
| `room.create` | 10 / saat |
| `room.join` (kodla) | 20 / dk (kod tahmini engeli) |
| `invite.send` | Aynı kişiye 1 / dk, toplam 10 / dk, 100 / gün |
| `action.emote` | 3 / 10 sn |
| `hello` | IP başına 30 / dk |

## 11. REST uçları (Cloudflare Worker, `https://game.<alan>/v1`, `Authorization: Bearer <JWT>`)

> Yalnızca okuma amaçlı veriler (profil, envanter, gelen kutusu) istemci tarafından doğrudan Supabase'den, RLS ile okunabilir. **Yazan** her uç Worker'dadır ve Postgres'te sınırlı yetkili sunucu işlevlerini çağırır (architecture/SUPABASE_ARCHITECTURE §5).

| Yöntem ve yol | Amaç |
|---|---|
| `GET /config` | Sürüm, bakım, özellik bayrakları, katalog sürümü (kimlik gerekmez) |
| `GET /me/bootstrap` | Profil, cüzdan, envanter, görevler, gelen kutusu özeti, süren maç |
| `POST /profile/create` | İlk profil (ad, avatar) |
| `PATCH /profile` | Ad / avatar / çerçeve değişikliği (filtre, sıklık) |
| `POST /profile/equip` | `{type, itemId}`: kuşanma |
| `POST /friends/request` | `{code}` ya da `{userId}` |
| `POST /friends/respond` | `{userId, accept}` |
| `DELETE /friends/{userId}` | Arkadaşlıktan çıkar |
| `POST /blocks` / `DELETE /blocks/{userId}` | Engelle / kaldır |
| `POST /reports` | Şikâyet |
| `POST /store/buy` | `{itemId, idempotencyKey}`: altınla satın alma |
| `POST /iap/intent` | Hesap bağlama kimliği (obfuscatedAccountId / appAccountToken) |
| `POST /iap/verify` | `{platform, productId, token / signedTransaction}` |
| `POST /iap/restore` | Geri yükleme listesi |
| `POST /ads/reward-intent` | `{placement, refId}` |
| `GET /ads/reward-intent/{id}` | Durum |
| `POST /ads/ssv` | AdMob sunucudan sunucuya geri çağrı (imza doğrulamalı, kimlik yok) |
| `POST /daily-login/claim` | Günlük giriş ödülü |
| `POST /quests/claim` / `POST /quests/reroll` | Görev ödülü / yenileme |
| `POST /achievements/claim` | Başarım ödülü |
| `POST /devices` / `DELETE /devices/{token}` | Push belirteci |
| `POST /account/delete` / `POST /account/delete/cancel` | Hesap silme |
| `POST /webhooks/google-rtdn` | Pub/Sub push (imza / JWT doğrulamalı) |
| `POST /webhooks/apple-asn` | App Store Server Notifications V2 (JWS doğrulamalı) |

**Kurallar:**
- Bütün `POST` istekleri `Idempotency-Key` başlığını kabul eder. Ekonomi uçlarında bu başlık **zorunludur**.
- Hata gövdesi WSS ile aynıdır: `{ code, message, retryAfterMs? }`.

## 12. Sürümleme

- **Geriye uyumlu değişiklikler:** Yeni bir alan ya da yeni bir mesaj türü eklemek. İstemci bilmediği alanları ve türleri **yok sayar**.
- **Kırıcı değişiklikler:** `v` artırılır. Sunucu bir süre iki sürümü birlikte destekler; `minClientVersion` ile zorunlu güncelleme yapılır.
- **Test:** Şema değişiklikleri CI'da `@kb/protocol` anlık görüntü testleriyle yakalanır.
