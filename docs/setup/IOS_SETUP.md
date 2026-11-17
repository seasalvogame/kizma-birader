# IOS_SETUP — iOS derlemesi için gerekenler (Faz 4 notu)

**Durum:** iOS derlemesi yapılmadı ve test edilmedi. Bu ortamda Mac yok. Aşağıdakiler hazırlık listesidir.

## Gerekenler

| Gereksinim | Not |
|---|---|
| macOS + Xcode (güncel) | Godot iOS dışa aktarımı Xcode projesi üretir; derleme ve imza Mac'te yapılır. |
| Apple Developer Program üyeliği | Ücretli (yıllık). **Senin onayın olmadan açılmaz.** TestFlight ve App Store için şart. |
| Bundle ID | Örn. `com.kizmabirader.app` (K-01: kesin paket adı kararı). Android paket adıyla aynı olması önerilir. |
| Godot iOS export templates (4.7.2) | Godot → Editor → Manage Export Templates. |
| "Sign in with Apple" yeteneği | App ID'de açılır. Apple kuralı: Google ile giriş sunan iOS uygulaması Apple ile girişi de sunmalı. |

## Uygulamanın iOS'ta kullandıkları

- **Ağ:** Supabase (HTTPS) ve oyun sunucusu (WSS). İkisi de TLS kullandığı için App Transport Security istisnası gerekmez.
- **Oturum:** `user://online_session.cfg` (uygulamanın özel klasörü). Mağaza sürümünden önce Keychain'e taşınması önerilir (TECHNICAL_ARCHITECTURE §4).
- **Titreşim:** `Input.vibrate_handheld`; iOS'ta süre ayarı yok, kısa dokunsal geri bildirim olur.
- **Yön:** yalnızca dikey. Export ayarında `Portrait` seçilir.

## Apple ile giriş (hazırlanan kod, denenmedi)

1. Yerel bir Godot eklentisi `ASAuthorizationAppleIDProvider` ile bir **ID belirteci** ve nonce alır. Eklenti henüz seçilmedi.
2. İstemci `Online.session.link_id_token("apple", id_token, nonce)` çağırır.
   - Misafir hesaba Apple kimliği eklenir; kullanıcı kimliği değişmez.
3. Supabase → Authentication → Providers → Apple: etkinleştir, "Client IDs" alanına bundle ID.

Google için iOS istemci kimliği de gerekir (SUPABASE_SETUP §6.1).

## Senden gerekenler (Mac'e erişim olduğunda)

- Apple Developer üyeliği ve bundle ID kararı.
- Mac'te Godot ile iOS dışa aktarımı ve Xcode'da imzalama.
- Gerçek cihazda: misafir giriş, çevrimiçi maç, profil, maç geçmişi ve hesap ekranlarının denenmesi.
