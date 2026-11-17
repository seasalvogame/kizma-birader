# Uyumluluk Raporu — Supabase, Reklam, IAP ve Mobil Eklentiler (Faz 2)

> **Faz 2 sonrası güncelleme (2026-11-17):** Cloudflare Workers / Durable Objects araştırması (limitler, motorun uyumu, maliyet) [architecture/CLOUDFLARE_ARCHITECTURE.md](architecture/CLOUDFLARE_ARCHITECTURE.md) ve [architecture/COST_AND_SCALING.md](architecture/COST_AND_SCALING.md)'de. Supabase plan limitleri [architecture/SUPABASE_ARCHITECTURE.md](architecture/SUPABASE_ARCHITECTURE.md)'de. Bu belgedeki Supabase Auth, reklam, IAP, giriş ve push eklentisi araştırması geçerli.

> **Tarih:** 2026-11-16
>
> **Önemli — iki tür bilgi:**
> - **Doğrudan denendi:** Bu bilgisayarda gerçekten yapılan işler (Android APK dışa aktarma, manifest incelemesi).
> - **Belge araştırması:** Kaynaklardan okunan bilgiler (eklentiler, Supabase). **Hiçbir eklenti projeye kurulmadı, hiçbir cihazda çalıştırılmadı.**
>
> Kaynaklar her bölümün sonunda.

## 1. Bu fazda doğrudan denenenler

| Konu | Sonuç |
|---|---|
| Godot 4.7.2 Android dışa aktarma (Compatibility renderer, arm64) | ✅ `build/android/KizmaBirader-0.2.0-debug.apk`, 29 MB |
| Manifest: yön | ✅ `screenOrientation = 1` (portrait); yatay yok |
| Manifest: SDK | minSdk 24 (Android 7.0), targetSdk 36 |
| İzinler | Yalnızca `VIBRATE` (internet izni yok: çevrimdışı prototip) |
| İmza | Godot debug sertifikası (yayın anahtarı **değil**) |
| Gerçek Android cihazda kurulum ve çalıştırma | ❌ **Yapılmadı:** telefon bağlı değildi (`adb devices` boş) |
| iOS derleme | ❌ **Yapılmadı:** macOS ve Xcode yok |
| Supabase'e bağlantı | ❌ **Yapılmadı:** bir Supabase projesi (URL + anon anahtar) yok |

## 2. Supabase Auth ve Godot

**Godot için resmi bir Supabase SDK'sı yok.**
- **Plan:** Auth (GoTrue) REST uçlarını `HTTPRequest` ile kullanan ince bir GDScript istemcisi (TECHNICAL_ARCHITECTURE §3–4).
- **Gizli anahtar:** Service role anahtarı istemciye **asla** girmez. İstemcide yalnızca proje URL'si ve anon (publishable) anahtar bulunur.

**Misafir hesap (belge araştırması):**
- **Oluşturma:** Supabase anonim girişi destekliyor. Anonim kullanıcı `authenticated` rolünü alıyor ve JWT'sinde `is_anonymous` alanı bulunuyor.
- **RLS etkisi:** Anonim kullanıcı, `authenticated` rolüyle yazılmış bütün politikalardan geçer. Bu yüzden bizim tasarımımızda (istemcinin yazma yetkisi yok) risk düşük, ama misafire özel kısıtlar `is_anonymous` ile yazılmalı.
- **Kötüye kullanım:** Supabase, anonim giriş uç noktasının kötüye kullanılabileceği için görünmez CAPTCHA ya da Cloudflare Turnstile öneriyor. Varsayılan sınır IP başına saatte 30 anonim kayıt.
- **Temizlik:** Kullanılmayan anonim hesaplar otomatik silinmiyor. Bunun için bir zamanlanmış iş (ör. 30 günden eski, bağlanmamış anonim hesaplar) planlanmalı.

**Misafiri Google, Apple ya da e-postaya bağlama:**

| Yöntem | Ne gerekiyor |
|---|---|
| Genel ön koşul | Projede **"Enable Manual Linking"** ayarının açılması |
| E-posta | `updateUser({email})` → doğrulama → `updateUser({password})` |
| OAuth (web akışı) | `linkIdentity({provider})` |
| Yerel kimlik belirteci (Google / Apple / …) | `linkIdentityWithIdToken` (Dart SDK başvurusunda var). Google için `idToken` ile birlikte `accessToken`, Apple için ham `nonce` gerekiyor. |

- **Belirsiz kalan:** JavaScript başvurusunda karşılığını bulamadım. Godot tarafında bunu REST ile yapacağımız için GoTrue'nun ilgili uç noktası **Faz 4'ün ilk işinde, gerçek bir projede denenmeli**. Belgelerde uç nokta adı geçmiyor.

**Veri kaybı riski ve hesap çakışması:**
- **Riskler:**
  - Bağlanmak istenen kimlik başka bir kullanıcıya aitse çağrı **hata verir**; çakışmayı Supabase çözmez, uygulama çözer. Belgedeki örnek, var olan hesaba giriş yapıp anonim verinin "taşınmasını" öneriyor.
  - Misafir oturumu kapatır, uygulama verisini siler ya da cihaz değiştirirse hesabına **erişemez**.
- **Bizim tasarımımız** (USER_FLOWS §3, K-54 önerisi):
  - Bağlama aynı kullanıcı kimliğini korur; veri taşınmaz, bu yüzden kayıp olmaz.
  - Çakışmada **birleştirme yok**, "o hesaba geç" + platform satın alımlarını geri yükleme. Supabase'in davranışı bu tasarımla uyumlu.
- **Öneri:** Misafir yenileme belirteci cihazın güvenli deposunda tutulmalı (Android Keystore / iOS Keychain). Bunun için de yerel bir eklenti gerekiyor (§4).

**Kaynaklar:**
- [Supabase — Anonymous Sign-Ins](https://supabase.com/docs/guides/auth/auth-anonymous)
- [Supabase Dart — linkIdentityWithIdToken](https://supabase.com/docs/reference/dart/auth-linkidentitywithidtoken)
- [Supabase JS — signInWithIdToken](https://supabase.com/docs/reference/javascript/auth-signinwithidtoken)
- [Supabase blog — anonymous sign-ins](https://supabase.com/blog/anonymous-sign-ins)
- [supabase/supabase#25787 (anonim kullanıcıyı OTP ile dönüştürme sorunu)](https://github.com/supabase/supabase/issues/25787)

## 3. Reklam (AdMob) ve uygulama içi satın alma

| İhtiyaç | Aday | Bulunan bilgi | Risk |
|---|---|---|---|
| AdMob (Android + iOS) | **Poing Studios AdMob** (MIT) | Godot 4.2+ için "complete Google Mobile Ads SDK integration", editörde sahte reklamlar, iki platform için tek API; Asset Library'de v5.1.0. Yerel bağımlılıkları kendisi indiriyor. | Son sürüm tarihi doğrulanamadı (GitHub aynasında son itme 2024); UMP onay desteği ve Godot 4.7 uyumu **denenmeli** |
| Google Play Billing | **GodotGooglePlayBilling** (Godot ekibinin SDK entegrasyonları) | Ana dal Godot 4.2+. Kurulum: Releases'tan indir, `addons/`, eklentiyi aç, **Gradle derlemesini aç**. | Kullandığı Billing Library sürümü belgede yazmıyor; Play'in en düşük Billing sürümü şartı kontrol edilmeli. Gradle derlemesi APK sürecimizi değiştirir (şu an Gradle'sız). |
| Google Play Billing (alternatif) | AndroidIAPP (code-with-max) | Billing Library 7, Godot 4.2+ | Topluluk projesi |
| StoreKit (iOS) | Resmi `godot-ios-plugins` InAppStore | Bir 2025 forum gönderisine göre hâlâ **StoreKit 1**; StoreKit 2 güncellemesi için katkıcı yok | Önerilmez (Faz 1 mimarisi StoreKit 2 + App Store Server API varsayıyor) |
| StoreKit 2 (iOS) | **Godot Apple Plugins** (MIT) | Apple ile giriş (AuthenticationServices), GameCenter ve **StoreKit 2** bir arada | **iOS 17.0 ve üstü** gerektiriyor; en düşük iOS sürümü kararını (K-49) doğrudan etkiler |
| StoreKit 2 + Play (alternatif) | **godot-iap** (OpenIAP) | Godot 4.3+, iOS 15+, Xcode 16+; iki platform için tek API | Topluluk projesi; bakım izlenmeli |

**Değerlendirme:**
- **Android:** Resmi Billing eklentisi + Poing AdMob en olası seçenek.
- **iOS:** İki yol var:
  - Godot Apple Plugins (StoreKit 2 + Apple girişi tek pakette, ama iOS 17+).
  - godot-iap (iOS 15+).
- **İkisi de cihazda doğrulanmadı.** Faz 1'deki "eklenti uyumu en büyük istemci riski" tespiti geçerli. Her biri gerçek cihazda "merhaba dünya" ile denenmeli; bunun için telefon, Play Console test hesabı, AdMob hesabı ve Mac gerekiyor.

**Kaynaklar:**
- [Poing Studios godot-admob-plugin](https://www.Github.com/poingstudios/godot-admob-plugin) · [Asset Store sayfası](https://store.godotengine.org/asset/poingstudios/admob/)
- [godot-google-play-billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) · [Godot docs — Android in-app purchases](https://docs.godotengine.org/en/4.4/tutorials/platform/android/android_in_app_purchases.html)
- [AndroidIAPP](https://github.com/code-with-max/godot-google-play-iapp)
- [Godot forum — iOS in-app purchase, Godot 4.4](https://forum.godotengine.org/t/ios-in-app-purchase-godot-4-4/106649)
- [godot-iap](https://hyochan.github.io/godot-iap)
- [Godot Apple Plugins](https://store.godotengine.org/asset/xogot/godot-apple-plugins/) · [AuthenticationServices rehberi](https://migueldeicaza.github.io/GodotApplePlugins/authenticationservices_authenticationservicesguide.html)

## 4. Giriş ve bildirim eklentileri

| İhtiyaç | Aday | Not |
|---|---|---|
| Google girişi (Android) | **Godot Google Sign-In** (topluluk, Credential Manager, Godot 4.2+) | Kimlik belirteci döndürüyor → Supabase `signInWithIdToken` / bağlama. Google'ın kuralı: Credential Manager'a **Web** client ID verilir (Android client ID hata verir); belirtecin `aud` alanı Web client ID'dir, sunucu doğrulamasında buna dikkat edilmeli. SHA-1 parmak izi uyuşmazsa giriş hemen iptal oluyor. |
| Apple ile giriş (iOS) | Godot Apple Plugins (AuthenticationServices) | `com.apple.developer.applesignin` yetkisi ve ücretli Apple Developer üyeliği gerekiyor |
| Push (FCM, Android + iOS) | **godot-x/firebase** (Messaging modülü) | Godot 4.5'te test edildiği yazıyor; Android SDK 24+, iOS 13+. Bir forum gönderisinde `google-services.json` dosyasının bulunamaması sorunu var. |
| Güvenli depolama | Hazır aday bulunmadı | Küçük özel eklenti (Kotlin / Swift) gerekebilir |

**Kaynaklar:**
- [Godot Google Sign-In](https://godotengine.org/asset-library/asset/4578)
- [Android — Sign in with Google (Credential Manager)](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation)
- [Auth0 — Google native (client ID ve aud notları)](https://auth0.com/docs/authenticate/identity-providers/social-identity-providers/google-native)
- [godot-x/firebase](https://github.com/godot-x/firebase) · [Godot forum — google-services.json sorunu](https://forum.godotengine.org/t/godot-4-5-godotx-firebase-fails-to-detect-google-services-json/130559)

## 5. Sonuç ve öneriler

1. **Gradle derlemesi:** Billing, AdMob ve giriş eklentileri büyük olasılıkla **Gradle derlemesi** ister. Faz 3'te dışa aktarma Gradle'a geçirilmeli; bu, Java / Android SDK araç zinciri gerektirir. Makinede mevcut; önceki projede kullanıldı.
2. **En düşük iOS sürümü (K-49):** iOS 17 (Godot Apple Plugins) ya da iOS 15 (godot-iap) seçimi, iPhone kitlesi verisine göre yapılmalı.
3. **Supabase hesap bağlama:** Faz 4'ün ilk işi, gerçek bir Supabase projesinde şu üç akışın uçtan uca denenmesi:
   - anonim giriş;
   - yerel Google belirteciyle bağlama;
   - çakışma.
4. **Eklentilerin tamamı** test edilmedi; bu rapor yalnızca **aday listesi ve bilinen kısıtlar**dır.
