# Faz 7G — Görsel Yenileme ve Ortam Doğrulama Raporu

**Tarih:** 19 Kasım 2026
**Kapsam:** Akşam Masası mobil görsel sistemi, gerçek Godot görsel turu ve regresyon doğrulaması.
**Commit:** İlk Faz 7/Faz 7G teslimi yerelde commit'lendi (`feat: deliver phase 7 social, cosmetics, and visual refresh`). Bu raporun sonundaki radikal geçiş iyileştirmeleri kullanıcının son talimatı uyarınca **bilerek commit'siz** bırakıldı.
**Push:** Yapılmadı; depoda tanımlı Git remote yok ve son talimat commit/push yapılmamasıdır.
**Deploy / remote migration:** Yapılmadı.

## Sonuç

Faz 7G görsel katmanı uygulandı ve gerçek, **headless olmayan** Godot Compatibility renderer turuyla doğrulandı. Koyu mürdüm gece zemini, krem karar kartları, mango ana eylemler, yıldız dili ile Baloo 2 / Nunito hiyerarşisi korunarak daha tutarlı dokunma hedefleri, derinlik, rozet ritmi ve aktif gezinme durumu eklendi.

Önceden var olan Faz 7 çalışma ağacı değişiklikleri korunmuştur. Özellikle tahta, piyon ve zar kozmetiklerini bağlayan mevcut kirli Faz 7 dosyaları değiştirilmedi; kurallar, sunucu otoritesi, kimlik doğrulama, ekonomi, görev/XP mantığı, oda/arkadaş sistemi ve veri şemaları yeniden yazılmadı.

## Ortam doğrulaması

| Kontrol | Sonuç |
|---|---|
| Terminal komutu | Çalışıyor |
| `godot_console --version` | `4.7.2.stable.official.ed1daf0bf` |
| Godot Compatibility renderer | OpenGL 3.3, Intel UHD 620 ile gerçek render üretildi |
| Windows UI otomasyonu | Godot Proje Yöneticisi açılıp görüntülendi |
| Oyun penceresi masaüstü yakalama | Bağlanamadı: `window is not a usable app window` |

Computer Use, Proje Yöneticisini hedefleyebildi; ancak `Çalıştır` sonrası Godot oyun penceresi için kullanılabilir bir pencere bağlamı vermedi. Bu yüzden burada masaüstü yakalaması gibi sunulan yapay bir görsel yoktur. Görsel kanıtlar, non-headless Godot uygulamasının kendi viewport'undan kaydedilen gerçek renderer çıktılarıdır.

## Uygulanan görsel iyileştirmeler

- Ortak krem kartlara ince üst/yan rim, sıcak alt kenar ve daha yumuşak gölge eklendi; profil, mağaza, görev, başarımlar, liderlik tablosu, sonuç, hesap ve tüm diğer `CreamCard` kullanan ekranlar aynı dilde güncellendi.
- Cam panellere hafif derinlik gölgesi uygulandı. Hata, çevrimdışı, kuyruk, arkadaş, davet ve oda durumları daha belirgin katmanlara kavuştu.
- Küçük butonlar artık 44 pt minimum dokunma alanını karşılıyor; metin ölçeği kompakt kalıyor.
- Ödül, nadirlik, durum ve bot rozetleri için ortak yükseklik, yuvarlaklık ve düşük kontrastlı çerçeve kuralları eklendi.
- Ana menüdeki 2/4 kişi oyun kartları hafif üst çerçeveyle, sosyal kişi satırları krem rim ile güçlendirildi.
- Cam menü kartlarında görünür alt kenar ve basılıyken 4 pt'lik içerik gömülmesi eklendi; ekranın dekoratif yükünü artıran ilk ışık halkası denemesi görsel kontrolden sonra kaldırıldı.
- Alt gezinmede seçili hedef artık mango çizgisiyle renk dışında da ayırt ediliyor.

Değiştirilen ortak görsel dosyalar:

- `client/scripts/ui/ui_palette.gd`
- `client/scripts/ui/ui_tokens.gd`
- `client/scripts/ui/ui_theme.gd`
- `client/scripts/ui/ui_kit.gd`
- `client/scripts/ui/menu_card.gd`
- `client/scripts/ui/nav_bar.gd`
- `client/scripts/ui/play_card.gd`
- `client/scripts/ui/person_row.gd`

## Gerçek ekran görüntüleri ve karşılaştırmalar

Tur, 540×1170 çözünürlükte non-headless Godot ile alındı. Tur varsayılan olarak çevrimdışıdır; yalnızca ekranı doldurmak için betikte enjekte edilen örnek verileri kullanır, gerçek oyuncu verisine veya çevrimiçi servislere dokunmaz.

- `artifacts/phase7g/before/`: 42 başlangıç PNG'si
- `artifacts/phase7g/after/`: 42 güncellenmiş PNG'si
- `artifacts/phase7g/comparisons/`: Başlıkları **ÖNCE / SONRA** olan 42 yan yana karşılaştırma

Temsilî karşılaştırmalar:

| Alan | Karşılaştırma |
|---|---|
| Ana menü ve hızlı oyun | [comparison_00a_home.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_00a_home.png) |
| Mağaza ve kozmetik | [comparison_00g_store.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_00g_store.png) |
| Arkadaşlar ve çevrimdışı hata | [comparison_53_friends_sample.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_53_friends_sample.png) |
| Günlük / haftalık görevler | [comparison_62_quests_sample.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_62_quests_sample.png) |
| Başarımlar | [comparison_65_achievements_sample.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_65_achievements_sample.png) |
| Haftalık sıralama | [comparison_66_leaderboard_sample.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_66_leaderboard_sample.png) |
| 4 kişilik maç tahtası, piyonlar ve zar | [comparison_03_match_4p_start.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_03_match_4p_start.png) |
| Maç sonucu | [comparison_07_result.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_07_result.png) |
| Kozmetik detay | [comparison_71_cosmetic_detail_sample.png](/C:/KizmaBirader/artifacts/phase7g/comparisons/comparison_71_cosmetic_detail_sample.png) |

Tur ayrıca giriş/hesap, profil, ayarlar, kurallar, hızlı maç kurulumu, özel oda, davetler, lobi, çevrimiçi kuyruk, maç ortası/menüsü, günlük giriş ödülü, başarımlar, liderlik tablosu, koleksiyon ve ürün detay ekranlarını kapsar.

## Test sonuçları

| Kontrol | Sonuç |
|---|---|
| Godot birim + sahne paketi | **38/38 geçti, 0 hata** |
| Godot gezinme/UI testi | **9/9 geçti**, 9,1 sn |
| Godot maç akışı alt kümesi | **4/4 geçti**, 66,7 sn |
| Gerçek Godot görsel turu | **42/42 önce** ve **42/42 sonra** PNG üretildi |
| TypeScript oyun motoru: `npm test` | **8 dosya, 85 test geçti** |
| TypeScript oyun motoru: `npm run typecheck` | Geçti |
| Worker: `npm run typecheck` | Geçti |
| `git diff --check` | Geçti |

Godot tam paketinin ilk 34 başarılı testi hostun 30 sn canlı çıktı sınırında görüldü; kalan dört `test_match_flow` testi ayrı koşuda tamamlanıp 4/4 geçti. Böylece paket toplamı 38/38 olarak doğrulandı.

## Kalan ortam notları

- Android Debug export preset'i var; ancak bu ortamda `ANDROID_HOME` ve `ANDROID_SDK_ROOT` yok. Bu nedenle Android debug APK oluşturulmadı.
- Computer Use katmanı, Godot Proje Yöneticisini yakalayabildiği halde çalışan oyun penceresine bağlanamadı. Bu masaüstü otomasyon sınırlamasıdır; Godot renderer ve görsel tur çalışmaktadır.

## Ek uygulama — PNG piyonlar ve tahta yüzeyi

Kullanıcı geri bildirimiyle piyon ve oyun tahtası katmanı ayrıca yenilendi.

- Varsayılan `pawns_classic` görünümü artık dört ayrı şeffaf, yüksek çözünürlüklü PNG kullanır: `client/assets/pawns/atelier_png/pawn_{red,green,yellow,blue}_atelier.png`.
- PNG seti yerleşik Image Generation aracıyla oluşturuldu; eski SVG varsayılanı ve tüm diğer kozmetik SVG setleri silinmedi. PNG bulunamazsa kod güvenli biçimde eski SVG'ye döner.
- PNG ve SVG kaynaklarının piksel boyutu farklı olsa bile, `PawnSprite` ikisini aynı görsel ayak izinde ölçekler. Hücre koordinatları, piyon konumları, tap yarıçapı, zar sonucu ve kural motoru değişmedi.
- Her piyonun üstünde artık krem madalyon içindeki üçgen / daire / kare / baklava sembolü yer alır; böylece renk bilgi için tek araç değildir.
- Tahtanın dışına yalnızca sıcak masa üstü kenarı ve katmanlı derinlik eklendi. `board_map.json` geometrisi, parkur, güvenli yıldızlar, koridorlar ve bitiş alanı korunmuştur.

PNG piyon karşılaştırması: [comparison_svg_to_png_pawns.png](/C:/KizmaBirader/artifacts/phase7g/pawn-refresh/comparison_svg_to_png_pawns.png)

Bu ek için gerçek Godot turu yeniden çalıştırıldı (42 PNG). İlgili doğrulamalar:

| Kontrol | Sonuç |
|---|---|
| `test_board_view_and_layout` | **6/6 geçti**, 2,6 sn |
| `test_app_navigation` | **9/9 geçti**, 4,5 sn |
| Non-headless Godot görsel turu | 42 PNG üretildi; başlangıç, hareket, seçim, sonuç ve 2 kişilik maç ekranları gözden geçirildi |

## Impeccable ve UI becerileriyle final tasarım geçişi

Bu geçişte görsel kararlar, ayrı bir ürün/tasarım kaydı ve iki salt-okunur denetimle doğrulandı; ardından uygulama değişiklikleri ana çalışma kapsamında yapıldı. Kullanıcının koruma sınırları nedeniyle denetim becerileri kaynak kodu değiştirmedi.

- [PRODUCT.md](/C:/KizmaBirader/PRODUCT.md) ürün amacı, platform, kullanıcı bağlamı, erişilebilirlik ve değişmeyecek sistem sınırlarını kaydeder.
- [DESIGN.md](/C:/KizmaBirader/DESIGN.md), artık uygulanan tasarım sisteminin makine-okunur tokenlarını ve **“The Lacquered Evening Table”** yaratıcı yönünü kaydeder.
- `.impeccable/design.json`, DESIGN.md’nin yanındaki araç tarafı genişletmesidir.
- [design-plans/](/C:/KizmaBirader/design-plans/) UI denetiminden çıkan iki deterministik düzeltmeyi; [animation-plans/](/C:/KizmaBirader/animation-plans/) ise hareket planlarını, kapsam sınırlarını ve doğrulama ölçütlerini saklar. Planların her biri bu çalışma ağacında uygulanmıştır.

Impeccable bağlam yüklemesi bir kez başarıyla çalıştı. Bu ortamda hesap bağlı değildi; `impeccable.cmd init` ise doğrudan bir CLI alt komutu olmadığını ve sohbet içi `/impeccable init` akışını beklediğini bildirdi. Bu nedenle ürün/tasarım kayıtları, kullanıcı isteği ve mevcut çalışır Godot kanıtından türetilerek elle oluşturuldu; doğrulanmamış ürün bilgileri PRODUCT.md içinde açıkça **inferred** olarak işaretlendi. Hook özellikle etkinleştirilmedi.

### Görsel yön ve tüm yüzeylere etkisi

Akşam Masası korunurken tasarım dili, rastgele parıltılarla dolu bir oyun yüzeyi yerine **cilalı akşam oyun masası** olarak netleştirildi:

- Gece arka planındaki yıldız alanı seyrekleştirildi; içerik, tahta ve karar kartlarının hiyerarşisi öne çıktı. Bu değişim ortak `NightBackground` üzerinden ana menü, giriş/hesap, profil, mağaza, görevler, sıralama, arkadaşlar/davetler/oda, kuyruk, ayarlar, hata/boş durumlar ve sonuç akışlarına yayılır.
- Krem kart / koyu cam / mango eylem / Baloo 2 + Nunito sistemi korunarak, ortak kart rimleri, 44 pt dokunma hedefleri, rozet ritmi, aktif alt gezinme işareti ve basılma derinliği önceki 7G geçişindeki bütün ekranlara taşındı.
- Tahta, PNG piyon seti, erişilebilir sembol madalyonu ve sıcak masa çerçevesi korunup final tura dahil edildi. PNG kaynak çözünürlüğü oyun koordinatlarını değiştirmez.
- Pasif zar artık küçülmüş, loş bir bağlam nesnesidir; yalnızca yerel oyuncunun zar atma anı parlak krem yüz, mango alan ve nabızla ana eylem olur.
- Bitiş koridoru hedefi / hareket izi, artık `pawn` kimliğini taşır. Bu, görsel hedefin gerçek seçilen piyonun slotuyla çelişmesini engeller; oyun kuralı veya ağ mesajı değişmedi.

### UI denetimi — uygulanmış bulgular

| Öncelik | Denetimdeki kanıt | Uygulanan düzeltme |
|---|---|---|
| Yüksek | `MatchScreen._sync()` hedef listesinde piyon kimliği atılıyordu; `BoardView` bitiş slotunu daima piyon 0 için çiziyordu. | Hedef ve iz sözlüğüne `pawn` eklendi; `BoardView` onu `pawn_position()`a iletiyor. Eski fixture’lar için `0` geri dönüşü korunuyor. |
| Orta | Rakip/bot sırasındaki zar, dokunulamaz olsa da parlak ve ana eylem kadar güçlüydü. | `DiceView` pasif yüzde 0.62 ölçek / loş tint kullanıyor; etkin yüzde eski parlak 0.72 yüz korunuyor. |

### Hareket denetimi — uygulanmış bulgular

| Öncelik | Uygulanan koruma |
|---|---|
| Yüksek | Reduce Motion açıkken zar dönüşü, piyon zıplaması/uçuşu/pop ve uzun süreli arama/yükleme döngüleri artık anında son durum veya statik durumla sonuçlanır. Metinle durum bildirimi korunur. |
| Orta | Yeni `UiTokens.duration()` köprüsü, mevcut `fast_animations` tercihini ekran geçişi, toast, sheet, sonuç, kutlama ve avatar dönüşü gibi ortak UI hareketlerine taşır. Sunucu/turn süreleri ve mesaj okuma beklemeleri kısaltılmaz. |
| Orta | Kutlama kartı 0.60’tan büyümek yerine 0.94’ten yerleşir; aktif oyuncu avatarı yalnız sıra değiştiğinde 1.04’e geçer ve tween kesilebilir. |
| Orta | XP çubuğu önceki tween’i iptal eder; hızlı veri güncellemesinde eski değer geri yazılamaz. |

## Final gerçek ekran görüntüleri

Final tur, değişikliklerden sonra yine **non-headless Godot Compatibility renderer** ile 540×1170’de çalıştırıldı. Bu görüntüler gerçek uygulama viewport çıktısıdır; masaüstü ekran görüntüsü olduğu iddia edilmez.

- [Final tur klasörü — 43 PNG](/C:/KizmaBirader/artifacts/phase7g/final/)
- [Önce/sonra karşılaştırmaları — 42 PNG](/C:/KizmaBirader/artifacts/phase7g/comparisons-final/)
- [Bitiş koridoru hedef kanıtı](/C:/KizmaBirader/artifacts/phase7g/final/05b_finish_target.png)

Karşılaştırma klasöründe her görselde **sol**, PNG piyon yenilemesinden sonraki önceki render; **sağ**, bu final Impeccable/UI geçişinin renderıdır. Bunlar yan yana incelenen karşılaştırma varlıklarıdır; uygulama ekran görüntüsü olarak tek başına sunulmaz.

| Alan | Final kanıt |
|---|---|
| Ana menü — daha sakin gece alanı | [comparison_00a_home.png](/C:/KizmaBirader/artifacts/phase7g/comparisons-final/comparison_00a_home.png) |
| 4 kişilik tahta, PNG piyonlar, aktif zar | [comparison_03_match_4p_start.png](/C:/KizmaBirader/artifacts/phase7g/comparisons-final/comparison_03_match_4p_start.png) |
| Pasif zar hiyerarşisi | [comparison_08_match_2p.png](/C:/KizmaBirader/artifacts/phase7g/comparisons-final/comparison_08_match_2p.png) |
| Koleksiyon ve kozmetik yüzeyi | [comparison_70_collection_sample.png](/C:/KizmaBirader/artifacts/phase7g/comparisons-final/comparison_70_collection_sample.png) |
| Bitiş koridoru seçili piyon hedefi | [05b_finish_target.png](/C:/KizmaBirader/artifacts/phase7g/final/05b_finish_target.png) |

## Final test geçişi

| Kontrol | Bu geçişte sonuç |
|---|---|
| Non-headless Godot visual tour | **43/43 PNG** üretildi; OpenGL 3.3 Compatibility / Intel UHD 620 |
| Godot `test_board_view_and_layout` | **7/7 geçti**, 2,0 sn (bitiş-slot regresyon testi dahil) |
| Godot `test_app_navigation` | **9/9 geçti**, 4,2 sn |
| TypeScript oyun motoru `npm test` | **8 dosya, 85/85 geçti**, 10,23 sn |
| TypeScript oyun motoru `npm run typecheck` | Geçti |
| Worker `npm run typecheck` | Geçti |
| `git diff --check` | Geçti; yalnız önceden var olan CRLF dönüştürme uyarıları görüldü |
| Android Debug export | Başarılı; `KizmaBirader-0.7.0-phase7g-debug.apk` (v2/v3 debug imzası doğrulandı) |

Tam Godot runner, ortamın tek komut için 30 sn canlı çıktı sınırında önceki geçişteki gibi uzun `test_match_flow` bölümünde kesiliyor. Önceki doğrulanmış tam koşu **38/38, 0 hata** idi; bu final geçişte değişen görsel yol için yukarıdaki 16/16 hedefli Godot test ve gerçek 43 karelik tur yeniden çalıştırıldı. Kesilmiş tam koşu başarılı olarak gösterilmemiştir. Yeni regresyon testinin ilk taslağı mevcut `TestCase` API’sinde olmayan `assert_ne()` kullandığı için bir parse hatası verdi; test hemen `assert_true(a != b)` ile düzeltildi ve yukarıdaki 7/7 sonuçta yeniden geçti.

## Kalan işler / çözülemeyen ortam konuları

- Android Debug APK export edildi ve imzası doğrulandı. Bu bilgisayarda bağlı cihaz/emülatör olmadığı için APK kurulum, TalkBack, koyu mod ve font ölçeği denemesi henüz fiziksel Android üzerinde yapılmadı.
- Windows Computer Use, Godot Project Manager’ı açabildi ancak çalışan Godot oyun penceresine güvenilir biçimde bağlanamadı (`window is not a usable app window`). Bu nedenle masaüstü otomasyon görüntüsü yoktur; görsel kanıtlar gerçek non-headless renderer turudur.
- TalkBack/cihaz titreşimi ve düşük uç Android GPU profil testi bu bilgisayarda yoktur. Sembol medalyonu, 44 pt hedefler ve Reduce Motion kod yolu mevcuttur; fiziksel cihaz erişilebilirlik doğrulaması sonraki donanım geçişidir.

Commit oluşturuldu; bu depoda tanımlı remote olmadığından push yapılamadı. Worker deploy, Supabase migration/deploy veya gerçek oyuncu verisi işlemi yapılmadı. Mevcut Faz 7 değişiklikleri geri alınmadı ya da üzerine yazılmadı.

## Radikal görsel geçiş — son çalışma ağacı doğrulaması

Kullanıcının sonradan verdiği kapsamlı görsel yenileme talebi için, yukarıdaki
teslimin ardından sistem düzeyindeki etkileşim ve form tutarlılığı da
uygulandı. Bu ek değişiklikler çalışma ağacındadır; açık talimat nedeniyle
commit veya push yapılmamıştır.

- `client/theme/main_theme.tres`, projenin tek kalıcı Theme giriş noktasıdır.
  `UiTheme.theme()` bu kaynağı kopyalayıp mevcut token üreticisiyle doldurur;
  bu nedenle çalışma zamanı tema mimarisi veya ekranların mevcut kurulumu
  bozulmaz.
- `TactileButton`, ortak birincil/ikincil/ghost ve ikon eylemlerine basma,
  fare-over ve klavye-odak tepkisi ekler. Ölçek animasyonu `fast_animations`
  ile uyumludur; Reduce Motion'da anlık sonuca geçer. Headless/export
  koşumları için betik `UiKit` tarafından açıkça preload edilir.
- Krem yüzeyli standart `LineEdit` alanları artık ortak odak, placeholder,
  caret ve salt-okunur durum dilini kullanır. Ekrana özel istisnalar korunur.
- Ana menü/oyun kartları da aynı kısa, kesilebilir basılma tepkisini alır;
  kurallar, hamle koordinatları, ağ ve ekonomi akışları değiştirilmedi.

### Yeni gerçek render kanıtı

Bu geçişten sonra Compatibility renderer (OpenGL 3.3 / Intel UHD 620) ile
540×1170 çözünürlükte tekrar tur alındı:

- [Radikal geçiş turu — 43 gerçek Godot viewport PNG'si](/C:/KizmaBirader/artifacts/phase7g/radical-pass/)
- [Önceki final (sol) / radikal geçiş (sağ) — 43 yan yana karşılaştırma](/C:/KizmaBirader/artifacts/phase7g/comparisons-radical-pass/)
- [Ana menü](/C:/KizmaBirader/artifacts/phase7g/radical-pass/00a_home.png), [4 kişilik tahta ve PNG piyonlar](/C:/KizmaBirader/artifacts/phase7g/radical-pass/03_match_4p_start.png), [kozmetik ürün](/C:/KizmaBirader/artifacts/phase7g/radical-pass/71_cosmetic_detail_sample.png), [görevler](/C:/KizmaBirader/artifacts/phase7g/radical-pass/62_quests_sample.png)

Karşılaştırmalar uygulama ekran görüntüsü diye sunulmaz: solda önceki gerçek
renderer çıktısı, sağda bu geçişin gerçek renderer çıktısı bulunur.

### Son test / Android kanıtı

| Kontrol | Sonuç |
|---|---|
| Tam Godot test paketi | **39/39 geçti, 0 hata**, 74,9 sn |
| Godot UI gezinme | **9/9 geçti**, 5,2 sn |
| Godot tahta / piyon yerleşimi | **7/7 geçti**, 2,3 sn |
| TypeScript oyun motoru | **8 dosya, 85/85 geçti**, 11,92 sn |
| Game engine + Worker typecheck | Geçti |
| `git diff --check` | Geçti (yalnız CRLF çalışma ağacı uyarıları) |
| Android Debug export | Başarılı: [KizmaBirader-0.7.0-radical-pass-debug.apk](/C:/KizmaBirader/build/android/KizmaBirader-0.7.0-radical-pass-debug.apk), 30.825.531 bayt |

Android export Godot tarafından debug imzasıyla üretildi ve export adımı
tarafından doğrulandı. Bağlı cihaz/emülatör olmadığından kurulum veya fiziksel
Android erişilebilirlik testi yapılmadı.
