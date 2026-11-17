# Faz 5 Kapanış Raporu — Arkadaşlar ve Özel Odalar

> **Tarih:** 2026-11-17 · **Sürüm:** 0.6.1 (versionCode 7) · Ayrıntılar: [PHASE_5_REPORT.md](PHASE_5_REPORT.md)
> **APK:** `build/android/KizmaBirader-0.6.1-debug.apk` (SHA-256 `7c66fadaf1fb0492b11452de2a1a694a775e20f009fffd50b961ae980e5007a5`; izinler INTERNET, VIBRATE)
> **Sunucu:** Cloudflare Worker (son sürüm `42b6bfaa`) + Supabase `kizmabirader-dev` + Hyperdrive, hepsi ücretsiz plan. Ücretli hizmet açılmadı.

## 1. Faz 5'te tamamlanan özellikler

- **Arkadaşlar:**
  - Oyuncu arama (ad / ad#etiket).
  - Arkadaşlık isteği gönderme, kabul, ret ve iptal; çift istek engeli.
  - Arkadaş listesi, oyuncu profili, arkadaş silme, engelleme ve engel kaldırma.
- **Canlı durum:** Çevrimiçi / odada / maçta / çevrimdışı. Yalnızca arkadaşlara gönderilir, sürekli sorgulama yok.
- **Maç davetleri:**
  - Canlı gelir; kabul ve ret var, aynı davet bir kez işlenir.
  - 120 sn süre, oyuncu başına en çok 10 bekleyen davet.
  - Yalnızca arkadaşa; engel varsa davet yok; başka oda ya da maçtaki oyuncu kabul edemez.
- **Özel oda (2 ve 4 kişi):**
  - Tahmin edilmesi zor kod; yanlış kod denemesi sınırı (10 dk'da 8).
  - Kodla ya da davetle katılma.
  - Renkler: 2 kişide karşılıklı, 4 kişide farklı.
  - Hazır durumu; maçı yalnızca oda sahibi başlatır.
  - Ayrılma ve sahiplik devri; boş ya da hareketsiz odanın kapanması.
  - Maç mevcut MatchRoom'da oynanır ve Supabase'e kaydedilir; ardından oda yeniden lobi olur.
- **Ekranlar:**
  - Arkadaşlar, oyuncu arama, istekler (gelen / gönderilen / engellenen), oyuncu profili.
  - Davetler, özel oda, oda lobisi.
  - Yükleniyor / hata / boş / süresi doldu durumları.
- **Kararlar** (`DECISIONS_AND_OPEN_QUESTIONS.md`): K-57, K-71, K-72, K-73 kesinleşti. Uygulama dört kararla zaten aynıydı, bu yüzden kod değişmedi.

## 2. Kapanışta bulunan ve düzeltilen hatalar

| Hata | Nasıl bulundu | Düzeltme |
|---|---|---|
| **Maç sonu ekranında yanlış sıra:** Çevrimiçi maçlarda başlık "0. oldun" gösteriyordu (sıralama sunucudan JSON ile ondalıklı sayılar olarak geliyor, `Array.find` eşleşmiyordu). Faz 3.4'ten beri vardı; alttaki sıralama listesi doğruydu. | Dört Godot istemcisi testi | `MatchScreen.place_of()`; birim testi eklendi. APK 0.6.1. |
| **Kuyrukta bağlantı değişimi:** Aynı oyuncunun iki bağlantısı aynı anda kuyruğa girerse, sunucunun kapattığı eski bağlantının yoldaki mesajı yenisini de düşürüyordu; oyuncu hiç eşleşmiyor, rakibi tek başına bekliyordu. | Bulut güvenlik testi (eşzamanlı katılım) | Değiştirilen bağlantı işaretleniyor, mesajları yok sayılıyor (MatchRoom'da da aynısı). |
| Güvenlik incelemesi (Faz 5 commit'i sonrası): engelden sonra durum sızıntısı, engel ötesine bildirim, odaya katılmada kapasite yarışı | Otomatik inceleme | Önceki mesajda raporlandı; bulutta test edildi (§4). |

## 3. Gerçek bulutta doğrulananlar

| Test | Sonuç |
|---|---|
| `godot_room4_test.mjs --remote` (**dört ayrı Godot süreci**) | **8 / 8**, dört istemcinin hepsi PASS |
| `social_room_test.mjs --remote` | **58 / 58** |
| `security_cloud_test.mjs --remote` (yeni) | **14 / 14** |
| `local_ws_test.mjs --remote` | **31 / 31** |
| `godot_online_test.mjs --remote` | **geçti** (hızlı eşleşme + 2 kişilik özel oda; dört istemcili test burada yapılandırılmadığı için atlandı ve ayrıca çalıştırıldı) |
| `phase5_test.sql` | 31 / 31 (Faz 5'te) |

`social_room_test.mjs --remote` kapsamı: 2 ve 4 kişilik oda, davet, canlı durum, `private` kayıt.

## 4. Güvenlik düzeltmelerinin bulut testleri

**`security_cloud_test.mjs` (14 / 14)**
- **JWT onayı:**
  - B'nin JWT'si olmadan A, B'yi test maçına koyamıyor (403 `SEAT_NOT_CONSENTED`).
  - Sahte belirteç ve başka bir oyuncunun belirteci onay sayılmıyor.
  - B'nin kendi JWT'siyle maç kuruluyor.
- **Eşzamanlı eşleşme:**
  - 4 oyuncu aynı anda kuyruğa girdi, biri iki bağlantıyla; 5 tur tekrarlandı.
  - Her turda her oyuncu tam bir eşleşme aldı; her maçta iki farklı oyuncu vardı.
  - İlk çalıştırmada §2'deki bağlantı değişimi hatası bulundu; düzeltmeden sonra 5 / 5 tur geçti.

**`social_room_test.mjs --remote` (58 / 58)** ve **`local_ws_test.mjs --remote` (31 / 31)**
- Güvenlik incelemesi düzeltmelerinden sonra (engel / bildirim / kapasite) gerileme yok.

**Test hesapları**
- Supabase IP başına saatte 30 misafir hesap sınırı koyuyor. Bu yüzden tekrar kullanılabilen **5 test hesabı** (KBTest1–5) oluşturuldu.
  - Yenileme belirteçleri Git'e girmeyen `server/worker/.test-accounts.json` dosyasında; her çalıştırmada oturum yenileniyor.
  - Bu kapanışta 5 yeni hesap açıldı; bundan sonra Node testleri yeni hesap açmıyor.
  - Testler başlangıçta ve sonda yalnızca bu hesapların maç kayıtlarını, arkadaşlıklarını, isteklerini ve engellerini temizliyor.
- `godot_online_test.mjs` hâlâ her çalıştırmada 4 misafir hesap açıp siliyor.
- Gerçek oyuncu hesaplarına ve verilerine dokunulmadı: kaynağı belirsiz 3 misafir hesap aynen duruyor.
- Testlerin bıraktığı iki geç kayıt (bot maçları, `test` modu, yalnızca test hesapları) silindi.
- Son durum: 8 kullanıcı (3 bilinmeyen + 5 test hesabı), 0 maç, 0 arkadaşlık.

## 5. Dört Godot istemcisiyle test sonucu

**Ortam:** Dört ayrı `godot_console --headless` süreci, aynı bilgisayarda, gerçek Cloudflare ve Supabase'e karşı. Her süreç kendi test hesabının oturumuyla çalıştı. Süreçler yalnızca paylaşılan bir klasördeki küçük dosyalarla (oda kodu, sıra işaretleri) koordine oldu. İstemci kodu uygulamadakiyle aynı (`OnlineSession`, `OnlineApi`, `OnlineRoom`, `OnlineMatchConnection`, `OnlineMatchController`, `OnlineProfile`).

| Adım | Sonuç |
|---|---|
| Oda oluşturma (4 kişilik) | ✅ |
| Dört oyuncunun katılması | ✅ |
| Renk seçimi | ✅ 2. oyuncu maviye geçti; renkler kırmızı / mavi / yeşil / sarı; alınmış renk `COLOR_TAKEN` ile reddedildi |
| Hazır durumu | ✅ Oda sahibinin erken başlatması `NOT_READY`, oda sahibi olmayanın başlatması `NOT_HOST` ile reddedildi |
| Oda sahibinin maçı başlatması | ✅ Dördü aynı maça, lobideki renkleriyle girdi |
| Tam maç | ✅ Her istemci kendi koltuğunu oynadı (172–202 hamle); sunucu durumu sürüm 736'da bitti (üç oyuncu bitirince); toplam ~2 dakika |
| Supabase kaydı | ✅ Bitmiş 4 kişilik `private` maç |
| Doğru sonuç ve sıralama | ✅ Dördü aynı sıralamayı gördü (`[0,3,2,1]`); sıralar 1–4 farklı; her istemcinin maç sonu sırası = geçmiş ekranındaki sıra = Supabase'teki sıra |

Not: İstemciler maç ekranını değil, ekranın kullandığı denetleyiciyi sürdü. Maç sonu ekranının sıra hesabı ayrıca birim testiyle doğrulandı (§2).

## 6. Yerel testler

| Test | Sonuç |
|---|---|
| TS kural motoru | **85 / 85** |
| Godot birim + sahne | **37 / 37** (yeni: sunucu JSON'undan gelen sıralamayla maç sonu sırası) |
| Worker (`local_ws_test.mjs`, test hesaplarıyla) | **26 / 26** |
| Oda testi (`social_room_test.mjs`, veritabanısız) | **32 / 32** |
| `tsc --noEmit` | Temiz |

## 7. Henüz gerçek telefonda denenmeyenler

- APK 0.6.0 / 0.6.1 hiçbir telefonda çalıştırılmadı.
- Arkadaş ekleme, canlı durum, davet ve özel oda: iki ya da dört gerçek cihazla denenmedi.
- Maç sonu ekranındaki sıra düzeltmesi ekranda gözle görülmedi; birim testiyle doğrulandı.
- E-postayla kalıcı hesaba geçiş (Faz 4) kendi adresinle telefonda hâlâ denenmedi.
- iOS: derleme yok (Mac yok).

## 8. Git

| Commit | İçerik |
|---|---|
| `34050a8` | Faz 4 (kalıcı profil ve maç geçmişi) |
| `2da0a38` | Faz 5 (arkadaşlar, durum, davetler, özel odalar). Korundu, değiştirilmedi. |
| Bu raporla oluşturulan düzeltme commit'i | Güvenlik incelemesi düzeltmeleri, kuyruk bağlantı değişimi düzeltmesi, maç sonu sıra düzeltmesi (0.6.1), kararlar, test hesabı havuzu, yeni bulut testleri ve bu rapor. SHA kullanıcıya iletildi. |

- Push yapılmadı.
- Gizli bilgi taraması yapıldı. APK, `.dev.vars`, `.test-accounts.json` (yenileme belirteçleri), token, parola ve imza anahtarı commit'te yok.
