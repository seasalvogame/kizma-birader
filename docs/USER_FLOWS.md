# USER_FLOWS — Kullanıcı Akışları ve Menü Hiyerarşisi

> **Durum:** Faz 1 taslağı (2026-11-16).
>
> **Faz 2 sonrası güncelleme (2026-11-17):**
> - Sunucu Cloudflare Workers + Durable Objects: Worker = ağ geçidi, Matchmaker ve MatchRoom = nesneler. Redis yok.
> - Davet ve çevrimiçi durumu Supabase Realtime ile.
> - 2 kişilikte renk seçimi eklendi (§5, §6).
> - Ayrıntı: [architecture/ONLINE_ARCHITECTURE.md](architecture/ONLINE_ARCHITECTURE.md).
>
> **İçerik:** Diyagramlar Mermaid ile çizildi. Ekran ayrıntıları [UI_SCREEN_SPECIFICATIONS.md](UI_SCREEN_SPECIFICATIONS.md) dosyasında, sunucu mesajları [NETWORK_PROTOCOL.md](NETWORK_PROTOCOL.md) dosyasında.

## 1. Menü hiyerarşisi (site haritası)

```mermaid
flowchart TD
  S[Açılış] --> L{Oturum var mı?}
  L -->|Hayır| G[Giriş]
  L -->|Evet| H[Ana Sayfa]
  G --> H
  H --> M2[Maç kur · 2 Kişi] --> MM[Eşleştirme] --> GM[Maç] --> R[Maç sonucu] --> RW[Ödül / Seviye]
  H --> M4[Maç kur · 4 Kişi] --> MM
  H --> PR[Özel Oda] --> PRC[Oluştur / Koda katıl] --> LB[Oda lobisi 2/4] --> GM
  H --> PT[Pratik · Bot] --> GM
  H --> PF[Profil] --> PFE[Düzenle: ad, avatar, çerçeve]
  H --> ST[Ayarlar] --> LNG[Dil]
  ST --> ACC[Hesap: bağla, çıkış, sil]
  H --> INB[Gelen kutusu]
  H -. alt menü .- FR[Arkadaşlar] --> FRA[Arkadaş ekle]
  H -. alt menü .- SH[Mağaza] --> PRM[Kulüp Üyeliği]
  SH --> ITM[Ürün ayrıntısı]
  H -. alt menü .- QS[Görevler / Başarımlar]
  H -. alt menü .- LBD[Sıralama]
```

- **Derinlik:** Bütün ekranlara ana sayfadan en fazla **3 dokunuşla** ulaşılır.
- **Alt menü:** Ana Sayfa, Arkadaşlar, Mağaza, Görevler ve Sıralama'da görünür. Maç, eşleştirme, lobi ve satın alma ekranlarında gizlenir.

## 2. İlk açılış

```mermaid
flowchart TD
  A[Uygulamayı ilk kez aç] --> B[Açılış: config, sürüm kontrolü]
  B -->|Zorunlu güncelleme| U[Mağazaya yönlendir]
  B --> C[Giriş ekranı]
  C -->|Misafir| D[Bilgi alt sayfası: misafir riskleri] --> E[Anonim hesap oluştur]
  C -->|Google / Apple| F[Yerel giriş] --> F2{Profil var mı?}
  C -->|E-posta| EM[E-posta + şifre / doğrulama] --> F2
  F2 -->|Hayır| N[Görünen ad + avatar]
  F2 -->|Evet| H[Ana sayfa]
  E --> N
  N --> T{Eğitim?}
  T -->|Oyna| TU[Pratik eğitim maçı: 2 kişi, bot, ipuçlu, ~3 dk] --> H
  T -->|Atla| H
```

- **Eğitim:** Etkileşimli ve kısa. Kurgulanmış zarlarla "6 at → çık → yıldız güvenli → ye → bitir" adımları gösterilir.
  - Bu kurgulanmış zarlar **yalnızca** çevrimdışı eğitimde kullanılır.
  - Çevrimiçi maçlarda zar daima sunucuda, rastgele üretilir.

## 3. Misafirden kalıcı hesaba geçiş ve çakışma

```mermaid
flowchart TD
  A[Misafir: Hesabını güvenceye al] --> B{Yöntem}
  B -->|Google / Apple| C[Yerel giriş, kimlik belirteci al]
  B -->|E-posta| D[E-posta + şifre]
  C --> E[Supabase: kimliği anonim kullanıcıya bağla]
  D --> E2[Supabase: anonim kullanıcıya e-posta ve şifre ekle, doğrulama e-postası]
  E -->|Başarılı| OK[Aynı kullanıcı kimliği korunur: ilerleme, altın, satın alımlar yerinde]
  E2 --> OK
  E -->|Kimlik başka hesaba bağlı| X[Çakışma kartı: iki hesabın özeti]
  X -->|O hesaba geç| SW[Onay: misafir ilerlemesi kaybolacak] --> SW2[Oturumu değiştir, platform satın alımlarını geri yükle] --> H[Ana sayfa]
  X -->|Vazgeç| BACK[Misafir olarak devam]
  OK --> RW[+200 altın, tek seferlik] --> H
```

**İlkeler:**
- **Aynı kimlik korunur:** Yükseltme yeni hesap açmaz. Anonim kullanıcının kimliği (`auth.users.id`) aynı kalır; bütün tablolar bu kimliğe bağlı olduğu için hiçbir veri taşınmaz.
- **Satın alımlar platform hesabına bağlıdır:** Hesap değiştirilse de abonelik ve kalıcı ürünler **geri yükleme** ile yeni hesaba atanır (MONETIZATION §3.5).
  - Tüketilen altın paketleri geri yüklenmez. Bu yüzden çakışma kartında misafir hesabında harcanmamış satın alınmış altın varsa ayrıca uyarı gösterilir.
- **Birleştirme yok:** İki hesabın ilerlemesi birleştirilmez (K-54).
  - Gerekçe: hile riski (iki hesapta altın toplayıp birleştirme) ve karmaşık sonuçlar.
  - Alternatif (karar bekliyor): misafir hesaptaki **satın alınmış** kozmetik ve altın, destek ekibi ya da otomatik bir aktarım işlemiyle hedef hesaba taşınır.

## 4. Sonraki açılışlar ve oturum

```mermaid
sequenceDiagram
  participant App as Uygulama
  participant Auth as Supabase Auth
  participant API as Oyun API
  App->>App: Kayıtlı yenileme belirtecini oku (güvenli depolama)
  App->>Auth: Belirteç yenileme
  Auth-->>App: Yeni JWT (1 sa) + yenileme belirteci
  App->>API: GET /me/bootstrap (JWT)
  API-->>App: Profil, cüzdan, görevler, gelen kutusu özeti, süren maç
  alt Süren maç var
    App->>App: "Maçın sürüyor · Dön" kartı
  else
    App->>App: Ana sayfa
  end
```

- **Yenileme hatası:** Belirteç iptal edildiyse ya da hesap silindiyse oturum kapanır ve giriş ekranına dönülür. Misafir için bu, ilerlemenin kaybı demektir; nedeni açıkça anlatılır.

## 5. Hızlı maç

```mermaid
sequenceDiagram
  participant C as İstemci
  participant G as Cloudflare Worker (WSS ağ geçidi)
  participant MM as Matchmaker (Durable Object)
  participant R as MatchRoom (Durable Object)
  C->>G: queue.join {mode: "4p", ruleset: "classic_v1", tier}
  G->>MM: Kuyruğa ekle (nesnenin kendi deposunda)
  MM-->>C: queue.status {position, eta}
  MM->>MM: 4 oyuncu toplandı
  MM->>R: Oda oluştur (oyuncular, renkler; 2 kişilikte renk tercihleri K-55)
  R->>R: Altınlı seviyede giriş bedeli emanete (tek işlem, Supabase)
  R-->>C: match.found {matchId, seat, color, ticket}
  C->>R: match.ready
  R-->>C: match.snapshot (tam durum) + match.started
  loop Turlar
    R-->>C: turn.start {player, deadline}
    C->>R: action.roll {turnId, reqId}
    R-->>C: dice.rolled {value, legalMoves}
    C->>R: action.move {turnId, pawn, reqId}
    R-->>C: pawn.moved {path, captures, nextTurn}
  end
  R-->>C: match.ended {ranks, rewards}
```

- **Vazgeç:** `queue.leave`. Eşleşme bu sırada tamamlandıysa iptal öncelikli olur; oda diğerleri için yeniden kuyruğa döner.
- **Bot önerisi:** Eşleştiricinin süre eşiği aşılınca `queue.offer_bot` gönderilir; istemci kabul ederse oda botla tamamlanır (K-05).

## 6. Özel oda ve davet

```mermaid
sequenceDiagram
  participant A as Ayşe (sahip)
  participant S as Sunucu
  participant M as Mehmet
  A->>S: room.create {players: 4}  (2 kişilikte: {players: 2, color})
  S-->>A: room.state {code: "K7Q-4MZ", seats}
  A->>S: invite.send {to: Mehmet, roomId}
  alt Mehmet çevrimiçi (bağlı)
    S-->>M: invite.received (uygulama içi bildirim, 30 sn)
  else Çevrimdışı ya da arka planda
    S->>S: Push bildirimi (FCM / APNs) + gelen kutusu kaydı
  end
  M->>S: room.join {roomId | code}
  S-->>A: room.state (Mehmet koltukta; 2 kişilikte rengi otomatik karşı renk)
  A->>S: room.start
  S-->>A: match.found ... (§5'teki gibi)
  S-->>M: match.found ...
```

- **Davet kuralları:**
  - Yalnızca arkadaşlara davet gönderilir.
  - Engellenmiş kullanıcı davet gönderemez ve alamaz.
  - Davet 30 sn (uygulama içi) / 10 dk (push) geçerlidir.
  - Sınır: aynı kişiye 1 dk'da en fazla 1, toplamda dakikada 10 davet (SECURITY §9).
- **Kodla katılma:** Kod bilen herkes katılabilir (arkadaş olmak gerekmez). Oda sahibi oyuncuyu çıkarabilir.
- **2 kişilikte renk:**
  - Kurucu dört renkten birini seçer; katılan oyuncu karşı rengi alır (K-57).
  - Kurucu maç başlamadan rengini değiştirebilir; katılanın rengi de buna göre değişir.
  - Sunucu karşılıklı olmayan ya da çakışan seçimi reddeder (`COLOR_TAKEN` / `COLOR_INVALID`).
- **İletim:** Davet Supabase Realtime (`user:<id>` kanalı) ve gerekirse push ile iletilir; oda Cloudflare'deki MatchRoom'dadır.

## 7. Arkadaş ekleme, silme ve engelleme

```mermaid
stateDiagram-v2
  [*] --> Yok
  Yok --> Bekliyor: İstek gönder (kod / son oynanan / bağlantı)
  Bekliyor --> Arkadaş: Karşı taraf kabul eder
  Bekliyor --> Yok: Reddet / geri çek / 30 gün yanıtsız
  Arkadaş --> Yok: Sil (iki taraftan da kalkar)
  Yok --> Engelli: Engelle
  Bekliyor --> Engelli: Engelle
  Arkadaş --> Engelli: Engelle (arkadaşlık silinir)
  Engelli --> Yok: Engeli kaldır
```

- **Engellemenin etkisi** (tek yönlü, sessiz):
  - Engellenen kişi istek ve davet gönderemez.
  - Engelleyenin profilini, çevrimiçi durumunu ve odasını göremez.
  - Hızlı maçta mümkünse eşleşmezler (eşleştirici, kuyruktaki engelleme listelerine bakar).
  - Ortak maçta engellenenin hızlı mesajları gizlenir.
- **Şikâyet:** Oyuncu kartında ya da profilde "⋯ → Şikâyet et". Nedenler: uygunsuz ad, uygunsuz avatar / profil, kasıtlı oyun bozma, hile şüphesi, diğer.
  - Son maç kimliği otomatik eklenir.
  - Gönderen "Teşekkürler, inceleyeceğiz" yanıtını alır.
  - İsteğe bağlı olarak aynı ekranda "Bu oyuncuyu engelle" seçeneği sunulur.

## 8. Maç yaşam döngüsü (durum makinesi)

```mermaid
stateDiagram-v2
  [*] --> Bekliyor: Oda oluştu
  Bekliyor --> Başlıyor: Herkes hazır / 10 sn hazır süresi doldu
  Bekliyor --> İptal: Biri bağlanmadı (2 kişilik) ya da yetersiz oyuncu
  Başlıyor --> Oynanıyor: İlk tur
  Oynanıyor --> Oynanıyor: Tur / hamle / zaman aşımı / otopilot
  Oynanıyor --> Bitti: Kazanma koşulu (GAME_RULES §9)
  Oynanıyor --> Bitti: Rakipler ayrıldı / zafer talebi
  Oynanıyor --> Kurtarılıyor: Sunucu süreci düştü
  Kurtarılıyor --> Oynanıyor: Son durum maç nesnesinin deposundan yüklendi
  Kurtarılıyor --> Geçersiz: Durum kurtarılamadı (60 sn)
  Bitti --> [*]: Sonuç DB'ye yazıldı, ödüller verildi
  Geçersiz --> [*]: Ödül/ceza yok, telafi bildirimi
  İptal --> [*]: Oyuncular kuyruğa geri döner
```

## 9. Bağlantı kopması ve geri dönüş

```mermaid
sequenceDiagram
  participant C as İstemci
  participant R as Maç odası
  Note over C: Ağ koptu (tünel, Wi-Fi → mobil veri)
  R->>R: Heartbeat yok (20 sn) → oyuncu "kopuk"; turları otopilot
  R-->>R: Diğerlerine player.status {disconnected}
  C->>C: Yeniden bağlanma döngüsü (0,5, 1, 2, 4, 8, 15 sn)
  C->>R: hello {resumeToken, lastSeq}
  alt Son sıradan itibaren olaylar hâlâ bellekte
    R-->>C: Eksik olaylar (seq > lastSeq)
  else
    R-->>C: match.snapshot (tam durum)
  end
  R-->>R: player.status {connected}; kontrol oyuncuya döner
```

- **Arka plana alma:**
  - iOS ve Android uygulamayı arka planda askıya alabilir; sunucu bunu kopukluk olarak görür.
  - Ön plana dönüşte istemci bağlantının ölü olduğunu varsayar ve hemen yeniden bağlanır; heartbeat süresini beklemez.

## 10. Satın alma (IAP)

```mermaid
sequenceDiagram
  participant C as İstemci
  participant P as Google Play / App Store
  participant API as Oyun API
  participant DB as Postgres
  C->>API: POST /iap/intent {productId} (isteğe bağlı: hesap bağlama kimliği)
  API-->>C: {obfuscatedAccountId}
  C->>P: Satın alma penceresi (obfuscatedAccountId / appAccountToken)
  P-->>C: Satın alma belirteci / imzalı işlem
  C->>API: POST /iap/verify {platform, token}
  API->>P: Sunucudan doğrulama (Play Developer API / App Store Server API)
  P-->>API: Geçerli, durum
  API->>DB: purchases (benzersiz transaction id) + cüzdan / envanter (tek transaction)
  API-->>C: {granted, wallet, inventory}
  C->>P: Tüketilebilir ise consume / finishTransaction (sunucu onayından SONRA)
```

- **Hatalar ve yarım kalanlar:** MONETIZATION §3.6 (bekleyen ödeme, iptal, uygulamanın kapanması, ağ hatası, iade).

## 11. Ödüllü reklam

```mermaid
sequenceDiagram
  participant C as İstemci
  participant AD as Reklam SDK (AdMob)
  participant API as Oyun API
  C->>API: POST /ads/reward-intent {placement: "double_match_reward", matchId}
  API-->>C: {intentId} (hak kontrolü: günlük sınır, maç başına 1)
  C->>AD: Ödüllü reklam göster (custom data = intentId)
  AD-->>API: Sunucudan sunucuya doğrulama çağrısı (SSV, imzalı)
  API->>API: İmza doğrula, intentId eşle, tek seferlik
  API-->>C: reward.granted (WSS) / C sorgular: GET /ads/reward-intent/{id}
```

- **SSV gelmezse:** Ödül verilmez. 3 sn içinde gelmezse istemci "Ödül doğrulanıyor" der. SSV geç gelirse ödül gelen kutusuna düşer.

## 12. Hesap silme

```mermaid
flowchart TD
  A[Ayarlar > Hesap > Hesabı sil] --> B[Açıklama: ne silinir, ne kalır, abonelik uyarısı]
  B --> C[SİL yazarak onay]
  C --> D[API: deletion_requested_at = now, oturumlar kapanır]
  D --> E[30 gün bekleme: giriş yapılırsa iptal edilebilir]
  E --> F[Gün 30: kişisel veriler silinir/anonimleştirilir; maç kayıtlarında 'Silinmiş oyuncu']
  F --> G[Yasal saklama gereken satın alma kayıtları anonim olarak tutulur]
```

- **Mağaza kuralları:** Apple ve Google, uygulama içinden hesap silme yolunu zorunlu tutar. Google Play ayrıca web üzerinden silme talebi bağlantısı ister; bu bağlantı Faz 10'da hazırlanır.
