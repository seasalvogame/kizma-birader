# Kızma Birader — Faz 7G Tam Denetim ve Yeniden Tasarım Raporu

**Tarih:** 19 Kasım 2026
**Motor:** Godot 4.7.2, Compatibility renderer
**Kapsam:** Mobil UI/UX, oyun tahtası, kozmetikler, açılış, erişilebilirlik,
test ve statik istemci/backend sınır denetimi.

## 1. Yönetici özeti

Mevcut çalışma ağacındaki Faz 7G yenilemesi korunarak doğrulandı ve aktif
maçtaki eksik canlı kozmetik güncellemesi kapatıldı. Başarılı bir kuşanma
sonrası yerel oyuncunun zarı, tahtası, dört piyonu, avatar çerçevesi/efekti ve
isim süslemesi artık maçı yeniden açmadan güncellenir. Bu yalnızca sunucunun
onayladığı yerel loadout'un sunum katmanına uygulanır; zar değeri, piyon
konumu, dokunma alanı, kurallar ve ağ otoritesi değişmez.

Çalışma ağacında zaten bulunan tasarım sistemi, açılış yüzeyi, cüzdan çubukları,
mağaza/koleksiyon durumları, piyon-küme yerleşimi, oyun hissi ve alt-gezinme
erişilebilirliği gerçek Godot renderer turları ve hedefli testlerle tekrar
denetlendi. Commit, push, deploy, migration veya üretim verisi işlemi
yapılmadı.

## 2. Başlangıçtaki proje durumu

- Dal: `master`; çalışma ağacı başlamadan önce Faz 7/Faz 7G'ye ait
  commit edilmemiş değişiklikler içeriyordu. Hiçbiri geri alınmadı.
- Görsel sistem: Akşam Masası — koyu mürdüm zemin, krem karar yüzeyleri,
  mango ana eylem, Baloo 2/Nunito tipografi.
- `client/project.godot`: 720×1560 referans tuvali, portrait,
  `canvas_items` + `expand`, Compatibility renderer.
- Mevcut güvenli test altyapısı: Godot scene/unit runner, görsel tur,
  TypeScript kural motoru ve Worker tür denetimi.
- Başlangıç ekran görüntüsü: bu denetimde alınan `before` turu, eski tasarımın
  değil, mevcut Faz 7G çalışma ağacının canlı baz çizgisidir. Bu ayrım
  özellikle önemlidir; önceki tasarımın yerine uydurma bir “önce” görseli
  oluşturulmadı.

## 3. Kurulu becerilerin tam envanteri

`C:\KizmaBirader\.agents\skills` altında 35 `SKILL.md` bulundu ve tamamının
içeriği açılarak envanteri çıkarıldı:

`codex-design-audit-skill`, `codex-gamestudio-skill`, `game-feel`,
`game-ui-ux`, `godot-47-migration`, `godot-animation`,
`godot-architecture`, `godot-audio`, `godot-brainstorming`,
`godot-code-review`, `godot-csharp-patterns`, `godot-debugging`,
`godot-dialog-systems`, `godot-gdscript-patterns`,
`godot-headless-workflow`, `godot-i18n`, `godot-input`,
`godot-inventory-economy`, `godot-networking`, `godot-performance`,
`godot-physics`, `godot-project-setup`, `godot-save-systems`,
`godot-shaders-vfx`, `godot-state-management`, `godot-ui-control`,
`godot-ui-integration`, `godot-ui`, `godot`, `impeccable`,
`improve-animations`, `improve-ui`, `kb-visual-design`, `snowe`,
`ui-ux-pro-max`.

`ui-ux-design-auditor` kurulu değildir ve bu raporda kullanılmış gibi
gösterilmemiştir.

## 4. Okunan SKILL.md dosyaları ve güvenlik incelemesi

35 dosyanın tamamı, ilgili boyut/satır sayısı ve SHA-256 özetleriyle
envanterlendi. Yönergelerin çağırdığı araçlar önce kaynak olarak incelendi:

- Godot ve görsel tur komutları proje içindeki güvenli test/renderer yollarını
  kullandı.
- `ui-ux-pro-max` ve `snowe` arama betiklerinin ilk 120 satırı incelendi;
  yalnız yerel CSV/veri okumaktadır. Makinede kullanılabilir bir Python 3
  yorumlayıcısı olmadığından çalıştırılamadılar; bağımlılık yüklenmedi.
- `impeccable.cmd context` başarılı biçimde çalıştı; yalnız `PRODUCT.md`,
  `DESIGN.md` ve hedef dosyanın bağlamını okudu. Ağ/deploy/değişiklik yapmadı.
- Godot UI, tasarım denetimi ve Game Studio için gerekli referanslar
  (`rubric`, `engineering-quality`, `economy-liveops`, `ui-ux-audit`,
  `godot`, `minimal-workflow`) açıldı. Eksik veya farklı adla bulunan üçüncü
  taraf referanslar çalıştırılmadı.

## 5. Gerçekten çalıştırılan beceriler ve kullanım amaçları

| Beceri grubu | Uygulama |
|---|---|
| `codex-gamestudio-skill` | Bakım fazı, korunan sözleşmeler, en küçük güvenli dilim, kanıt kapısı ve `CODEX_HANDOFF.md` güncellemesi. |
| `godot`, `godot-headless-workflow`, `godot-debugging` | Godot 4.7.2 sürümü, import/parse davranışı, smoke run, hedefli scene/unit testleri ve gerçek Compatibility-renderer turu. |
| `godot-ui-control`, `godot-ui`, `godot-ui-integration` | Stretch/safe-area/Control hiyerarşisi, merkezi tema, dokunma/focus ve farklı görüntü boyutlarında gerçek ekran denetimi. |
| `godot-gdscript-patterns`, `godot-architecture`, `godot-state-management` | Oyun durumu ile sunum katmanının ayrımını koruyarak canlı kosmetik yenilemesinin doğru sahiplerine yerleştirilmesi. |
| `godot-animation`, `game-feel`, `improve-animations` | Zar, piyon, basma/odak ve Reduce Motion yollarının kuralları bekletmediği denetimi. |
| `godot-i18n`, `godot-input` | TR/EN renderer turları, uzun İngilizce metin ve klavye/gamepad odak yolunun test edilmesi. |
| `godot-performance`, `godot-code-review` | Compatibility renderer, tween/sinyal sahipliği, gereksiz yeniden oluşturma ve düşük maliyetli `queue_redraw` yaklaşımının gözden geçirilmesi. |
| `godot-inventory-economy`, `godot-networking`, `godot-save-systems` | Sunucu onaylı satın alma/loadout, cache'in yalnız görüntü amaçlı olması ve tekrar bağlanma/otorite sınırlarının statik denetimi. |
| `kb-visual-design`, `game-ui-ux`, `impeccable`, `improve-ui`, `snowe`, `ui-ux-pro-max`, `codex-design-audit-skill` | Akşam Masası kimliği, görsel hiyerarşi, mağaza/koleksiyon durumu, dokunma hedefi, metin taşması ve görsel kalite turu. |
| `godot-47-migration` | Projenin zaten Godot 4.7.2 üzerinde olduğu doğrulandı; gereksiz migration yapılmadı. |

## 6. Çalıştırılmayan beceriler ve gerekçeleri

| Beceri | Gerekçe |
|---|---|
| `godot-csharp-patterns` | Proje GDScript; C# yolu yok. |
| `godot-dialog-systems` | Bu turda diyalog/quest konuşma sistemi yok. |
| `godot-physics` | Tahta kuralları saf state/geometri; fizik düğümü kullanılmıyor. |
| `godot-project-setup` | Yeni proje kurulmadı; mevcut proje ayarları korunuyor. |
| `godot-audio`, `godot-shaders-vfx` | Yeni lisanslı ses/efekt varlığı olmadan dekoratif veya maliyetli ekleme yapılmadı; mevcut hafif tween/canvas yolu korundu. |
| `godot-brainstorming` | Mevcut istemci–Worker–Supabase mimarisini değiştirmenin bu bakım diliminde yararı yoktu. |
| `ui-ux-pro-max` / `snowe` CLI aramaları | İncelendi ancak güvenli yerel Python 3 çalışma zamanı yoktu; bağımlılık yüklenmedi. |

## 7. Bulunan UI/UX sorunları

| Öncelik | Bulgu | Durum |
|---|---|---|
| P0 | Aktif maçta kuşanma sinyali yalnız zarı yeniliyordu; tahta/piyon/avatar/isim eski kalıyordu. | Düzeltildi ve test edildi. |
| P1 | Uzak/küçük ekran ve klavye/gamepad için alt gezinme odak yolu eksikti. | Çalışma ağacındaki mevcut erişilebilirlik diliminde düzeltildi; 9/9 navigation testinde doğrulandı. |
| P1 | Mağaza ve koleksiyonda sahip/kuşanılmış ayrımı, cüzdan görünürlüğü ve uzun ürün adları incelendi. | Merkezi kart/cüzdan/chip yapılarıyla mevcut sürümde doğrulandı. |
| P1 | Çoklu piyonun aynı hücrede taşması riski. | 2/3/4 piyon için ölçek+simetrik yerleşim, 8/8 layout testinde doğrulandı. |
| P2 | İlk açılışta yarı-hazır ekran gösterme riski. | Mevcut BootScreen gerçek profil/katalog akışına bağlı; yüzde uydurmuyor, hata/tekrar dene/devam et durumları var. |

## 8. Bulunan teknik sorunlar

- `godot --check-only --script` tek başına autoload bağımlı dosyaları derlediğinde
  `Online`/`Settings` bulunamadığını bildirir. Bu, gerçek proje başlatması
  değildir; aynı dosyalar scene testleri, smoke run ve renderer turu sırasında
  autoload ile başarıyla çalıştı. Tek-başına check-only sonucu kabul kanıtı
  olarak kullanılmadı.
- Bu hostta `--import` sırasında Godot kullanıcı ayar dosyası için “Safe save
  failed” uyarısı ve Android build-tools yolu uyarısı görüldü. Kaynak/import
  hatası kanıtlanmadı; bu yüzden bu denetimde yeni Android export başarısı
  iddia edilmez.
- Tam `test_match_flow` işlemi aracın 30 saniyelik canlı çıktı kesiti
  nedeniyle sonuç üretmeden durdu. Başarılı sayılmadı; aşağıda açık risk
  olarak korunur.

## 9. Yapılan gerçek değişiklikler

Bu denetim oturumunda eklenen güvenli düzeltme:

1. `MatchScreen`, `Online.cosmetics.changed` olayında artık tek zar yerine
   yerel loadout'un tüm maç içi sunum sahiplerini yeniler.
2. `BoardView.set_theme_id()` yalnız geçerli kozmetik paletini atayıp yeniden
   çizer; geometri, input ve game state değişmez.
3. `PawnSprite.set_skin()` yalnız texture/ölçeği değiştirir; adım, pozisyon,
   rule state ve hit hedefini değiştirmez.
4. `PlayerCard.apply_cosmetics()` avatar yüzeyini ve isim biçimini idempotent
   şekilde uygular; yıldızlı isimlerin tekrar tekrar öneklenmesini engeller.
5. Regresyon testi zar, tahta, dört piyon, çerçeve, efekt ve isim stilini
   canlı `changed` sinyalinden sonra denetler.
6. Görsel turda aynı davranışı gösteren `05c_match_live_cosmetic_refresh`
   karesi eklendi.

## 10. Değiştirilen dosyalar

Bu oturumda doğrudan değiştirilenler:

- `client/scripts/ui/screens/match_screen.gd`
- `client/scripts/board/board_view.gd`
- `client/scripts/board/pawn_sprite.gd`
- `client/scripts/ui/player_card.gd`
- `client/tests/scene/test_board_view_and_layout.gd`
- `client/tests/visual/screenshot_tour.gd`
- `CODEX_HANDOFF.md`
- Bu rapor.

Önceden var olan Faz 7G ve erişilebilirlik çalışma ağacı değişiklikleri
korundu; bunlar bu raporda yeni oluşturulmuş gibi sunulmamıştır.

## 11. Yeni oluşturulan bileşenler

Yeni bir sahne veya servis oluşturulmadı. Mevcut sahiplerde dar kapsamlı üç
sunum API'si eklendi: `BoardView.set_theme_id`, `PawnSprite.set_skin` ve
`PlayerCard.apply_cosmetics`. Yeni görsel kanıt karesi test turu tarafından
üretilir; dağıtım varlığı değildir.

## 12. Mağaza ve kozmetik iyileştirmeleri

- `WalletBar` gerçek profil cüzdan satırından gelir; değer bilinmiyorsa örnek
  sayı yerine gizlenir.
- Satın alma dönüşündeki sunucu `currency`/`balance` değeri cüzdana yansır;
  istemci fiyat düşmez veya bakiye üretmez.
- Mağaza, sahip olunan/kuşanılan ürünü kart üstünde ayırt eder; koleksiyon
  sahiplik ve kuşanılmış chip'lerini gösterir.
- Bu denetimin düzeltmesi, başarılı kuşanmanın aktif maçta anlık etkisini tüm
  yerel maç kozmetiklerine genişletir.

## 13. Piyon ve zar düzeltmeleri

- Aynı hücrede 2/3/4 piyon için hücre içinde kalan simetrik ofset ve ölçek
  doğrulandı; kural motoru, path indeksi ve sunucu konumu dokunulmaz kaldı.
- Zar animasyonu yalnız controller/server'ın verdiği sonucu gösterir; ara
  yüzler sonuç üretmez. Reduce Motion durumunda anında son yüze geçer.
- Yeni kozmetik yenilemesi, mevcut anlık zar değişikliğini yerel piyon ve
  tahta görünümüne taşır.

## 14. Bakiye ve yüklenme ekranı iyileştirmeleri

- Uygulama açılışında BootScreen, gerçek profil ve katalog hazırlığına bağlı
  belirsiz ilerleme/güncel durum metni sunar; sahte yüzde yoktur.
- Bağlantı başarısızsa tekrar dene ve önbellekli/çevrimdışı devam et yolu
  görünürdür.
- Cüzdan pill'leri ana menü, mağaza, koleksiyon ve kozmetik detay başlıklarında
  gözlemlendi. Test turundaki örnek bakiye yalnız screenshot fixture'ının
  sunucu-şekilli verisidir; uygulama kodu sabit örnek bakiye üretmez.

## 15. Animasyon ve game-feel iyileştirmeleri

- Mevcut tactile button, zar hazırlık/tumble/yerleşme, piyon hop/pop ve popup
  geçişleri incelendi.
- Tüm ortak hareketler `reduced_motion` yolunu kontrol eder; kuralları,
  sunucu tur süresini veya ağ mesajını bekletmez.
- Yeni canlı kozmetik akışı tween eklemeden texture/palet/çizim sahiplerini
  günceller; düşük donanımlı cihazda pahalı efekt oluşturmaz.

## 16. Mobil uyumluluk

- `test_board_view_and_layout`: kare tahta, farklı oranlar, küçük setup,
  dokunma, seçili hedef ve piyon kümeleri geçti.
- Gerçek 540×1170 portrait turda 47 TR ve 47 EN kare alındı. İngilizce mağaza,
  koleksiyon, oda ve canlı maç karesi görsel olarak incelendi; metin kutu
  taşması görülmedi.
- Safe area ve fiziksel çentik/IME/büyük yazı tipi, cihaz gerektirdiği için
  manuel test listesinde kalır.

## 17. Güvenlik ve backend incelemesi

Statik denetimde:

- `wallets` için RLS açık; authenticated kullanıcı yalnız kendi cüzdanını
  okuyabilir. Doğrudan cüzdan yazımı geri alınmış testlerle sınırlandırılmıştır.
- `purchase_cosmetic` ve `equip_cosmetic` SECURITY DEFINER RPC'leridir;
  katalog yayınlanma/kategori/sahiplik/fiyat/bakiye doğrulaması sunucudadır.
- Worker protokolü `action.roll` için yalnız `turnId` kabul eder; istemciden
  zar değeri kabul edilmez. Durable Object zar değerini Web Crypto tabanlı
  `cryptoDice` ile üretir.
- İstemcinin yeni değişikliği yalnız sunucu onayından sonra yenilenen local
  loadout olayını dinler; ekonomi veya match state yazmaz.

Canlı Supabase/Worker/RLS testi bu oturumda çalıştırılmadı: üretim veya uzak
ortam yetkisi kullanılmadı.

## 18. Test sonuçları

| Kontrol | Sonuç |
|---|---|
| Godot board/layout | 8/8 geçti |
| Godot app navigation | 9/9 geçti |
| Godot board geometry | 5/5 geçti |
| Godot rules | 12/12 geçti |
| Godot engine parity vectors | 2/2 geçti; 36.079 trace adımı |
| Godot smoke run | geçti (`--quit-after 180`) |
| Gerçek TR renderer turu | 46 before, 47 after PNG |
| Gerçek EN renderer turu | 47 PNG |
| TypeScript game engine | 85/85 geçti |
| Game-engine typecheck | geçti |
| Worker typecheck | geçti |
| `git diff --check` | geçti (yalnız CRLF dönüştürme uyarıları) |
| Tam Godot match-flow paketi | **Sonuç alınamadı; başarılı sayılmadı** |

## 19. Önce/sonra ekran görüntüleri

- `artifacts/full-audit/before/`: 46 gerçek Godot renderer karesi.
- `artifacts/full-audit/after/`: 47 gerçek Godot renderer karesi.
- `artifacts/full-audit/en/`: 47 gerçek İngilizce renderer karesi.
- `artifacts/full-audit/comparisons/05_live_cosmetic_refresh_before_after.png`:
  kuşanma sinyalinden önceki klasik görünüm ile anlık canlı kozmetik
  yenilemesinin yan yana kanıtı.

Önemli canlı kanıt: `artifacts/full-audit/after/05c_match_live_cosmetic_refresh.png`.
Turlar uygulamanın gerçek Godot viewport'undan alınmıştır; katalog/profil
satırları gerekiyorsa `screenshot_tour.gd` içindeki açıkça işaretlenmiş,
yalnız test için kullanılan sunucu-şekilli fixture'lardır. Gerçek hesap,
satın alma veya üretim verisi kullanılmadı.

## 20. Kalan sorunlar

- Tam offline `test_match_flow` paketi bu aracın zaman sınırında sonuç
  vermedi; yerel/CI ortamında tamamlanmalıdır.
- Godot UI'larının çoğu çalışma zamanında kodla kuruluyor. Mevcut projede
  çalışır bir mimari olsa da, `godot-ui-integration`ın editörde doğrudan
  görünür `.tscn` ekran önerisi gelecekte bakım/önizleme maliyetini azaltır.
- Yeni ses varlığı olmadan ses geri bildirimi eklenmedi.

## 21. Manuel cihaz testi gereken maddeler

1. Android ve iOS'ta APK/IPA kurulumu, ilk açılış ve geri dönüş.
2. Çentik/safe area, 320 pt dar genişlik, çok uzun ad/bakiye ve sistem klavyesi.
3. 130%+ yazı ölçeği, TalkBack/VoiceOver ve erişilebilirlik odak sırası.
4. Fiziksel Bluetooth gamepad ile alt navigasyon, modal, mağaza ve maç menüsü.
5. Düşük seviye Android GPU/termal profil, ağ kesilmesi ve yeniden bağlanma.
6. Sunucu onaylı gerçek satın alma/kuşanma ile aktif çevrimiçi maçta anlık
   kozmetik güncellemesi.

## 22. Son kalite değerlendirmesi

| Alan | Değerlendirme | Kanıt / sınır |
|---|---:|---|
| Görsel hiyerarşi ve tutarlılık | 4/5 | 47 karelik gerçek tur; Akşam Masası tokenları tutarlı. |
| Mağaza/koleksiyon kullanılabilirliği | 4/5 | Cüzdan, sahip/kuşanılmış durum ve ayrıntı ekranı; canlı backend işlemi test edilmedi. |
| Tahta okunabilirliği ve game feel | 4/5 | Kümelenmiş piyon testi, sonuç-odaklı zar ve renderer kanıtı. |
| Erişilebilirlik | 3/5 | Sembol, reduce motion, 44 pt+ hedef ve klavye/gamepad testleri; cihaz screen-reader testi bekliyor. |
| Performans/mobil dayanıklılık | 3/5 | Compatibility renderer ve hafif güncelleme yolu; cihaz profil/termal ölçüm yok. |
| Güvenlik/otorite sınırı | 4/5 | Statik RLS/RPC/protokol denetimi ve 85 motor testi; uzak üretim doğrulaması yapılmadı. |

Sonuç: P0 canlı kozmetik yenileme açığı kapatılmış, tasarım ve işlevsel
regresyon sınırı doğrulanmıştır. Yayın kabulü için kalan koşullar fiziksel
cihaz/erişilebilirlik testi, tamamlanan match-flow koşusu ve yetkili bir test
ortamında backend uçtan uca geçişidir.
