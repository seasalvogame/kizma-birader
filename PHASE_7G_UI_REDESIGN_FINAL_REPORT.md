# Kızma Birader — Faz 7G UI Yenileme Kapanış Raporu

**Tarih:** 19 Kasım 2026
**Kapsam:** Akşam Masası görsel sistemi korunarak mobil UI, kozmetik deneyimi,
tahta/piyon/zar sunumu ve başlangıç akışının uygulanmış yenilemesi.

## Ortam ve kanıt

- Terminal, Git ve Godot çalıştı.
- Godot: `4.7.2.stable.official.ed1daf0bf`.
- Gerçek görsel tur `godot_console --path ...` ile **headless olmayan** Godot
  Compatibility renderer üzerinde alındı: OpenGL 3.3, Intel UHD 620.
- Windows UI otomasyonu da doğrulandı: gerçek `Kızma Birader (DEBUG)` penceresi
  yakalandı. Pencere yerel önbellekteki günlük ödül iletişim kutusuyla açıldı;
  bu kullanıcı durumuna dokunulmadan kapatıldı.

## Uygulanan yenileme

- Uygulama artık doğrudan boş ana ekrana düşmek yerine gerçek oturum, profil ve
  kozmetik hazırlığını gösteren bir açılış yüzeyinden geçer. Ağ yenilenemezse
  kullanıcı yalnızca açıkça etiketlenmiş tekrar dene/çevrimdışı devam et
  seçeneklerini görür.
- Cüzdan rozeti, mevcut RLS korumalı `wallets` satırından gelen Gold ve Gem
  değerini gösterir; örnek para veya istemci tarafı bakiye hesabı yoktur.
  Onaylanmış satın alma makbuzunun döndürdüğü bakiye anında UI’a yansır.
- Mağaza artık satın alınmış öğeleri saklamaz: kart üzerindeki sahip/kuşanıldı
  durumu anlaşılır, satır tekrarları kaldırılmış ve büyük bakiyeler kırpılmak
  yerine `14.5K` gibi güvenli kısa gösterime geçirilmiştir.
- Koleksiyon kartları dokunulabilir, klavye odağı alabilir, sarmalanan metin ve
  sahip/kuşanıldı rozetiyle okunabilir kalır.
- Aktif maçta kuşanılan zar değişimi `Online.cosmetics.changed` sinyalinden
  doğrudan ana zar ile oyuncu kartındaki zar görünümüne gelir. Zar animasyonu
  hazırlanma, döndürme, kesin son değere yerleşme ve kısa sekme kullanır;
  azaltılmış hareket ayarını korur.
- Aynı karedeki 2, 3 ve 4 piyon simetrik, ölçeklenmiş kümeler hâlinde
  yerleşir. Bu yalnızca çizim konumudur; yol, dokunma hedefi, kurallar ve
  sunucu durumu değişmez. Yüksek çözünürlüklü PNG piyon yüzeyleri mevcut
  kozmetik sisteminden kullanılmaya devam eder.
- Akşam Masası tokenları (koyu mor gece, krem kart, mango ana eylem, yıldız
  ayrıntısı, Baloo 2/Nunito) merkezi tema ve dokunsal buton yüzeylerinde
  korunmuştur.

## Ekran görüntüleri

| Set | Sayı | İçerik |
|---|---:|---|
| [Önce](/C:/KizmaBirader/artifacts/ui-redesign/before) | 43 | Yenilemeden önce gerçek Godot turu |
| [Sonra](/C:/KizmaBirader/artifacts/ui-redesign/after) | 46 | Gerçek Godot turu; ana menü, ayarlar, sosyal/oda, görev/ödül, sıralama, mağaza/koleksiyon ve maçlar |
| [Karşılaştırmalar](/C:/KizmaBirader/artifacts/ui-redesign/comparisons) | 43 | Aynı ekranların `ÖNCE` / `SONRA` yan yana PNG’leri |

Öne çıkan gerçek-renderer kanıtları:

- [Başlangıç yüzeyi](/C:/KizmaBirader/artifacts/ui-redesign/after/00_boot_loading.png)
- [Cüzdanlı mağaza](/C:/KizmaBirader/artifacts/ui-redesign/after/70a_store_wallet_sample.png)
- [Dört piyonlu aynı-kare kümesi](/C:/KizmaBirader/artifacts/ui-redesign/after/04b_match_stack_4.png)
- [Ana menü karşılaştırması](/C:/KizmaBirader/artifacts/ui-redesign/comparisons/00a_home.png)
- [Maç tahtası karşılaştırması](/C:/KizmaBirader/artifacts/ui-redesign/comparisons/04_match_4p_roll.png)

`00_boot_loading`, `70a_store_wallet_sample` ve `04b_match_stack_4` yeni
özellik denetim ekranları olduğundan yalnızca “sonra” setindedir. Turdaki
profil, sosyal ve kozmetik örnek satırları sadece ekran görüntüsü testinin
yerel fixtürleridir; uygulama ekranları gerçek Godot UI’dan üretilmiştir ve
üretim oyuncu verisi değiştirilmemiştir.

## Testler

| Kontrol | Sonuç |
|---|---|
| Godot tam test paketi | **40 test / 0 hata**, 84.5 sn |
| Yeni piyon kümesi + anlık zar kozmetiği gerilemesi | Geçti (2/3/4 kümeler ve açık maç zar yenilemesi) |
| TypeScript oyun motoru | **85 test / 0 hata** |
| Oyun motoru typecheck | Geçti |
| Worker typecheck | Geçti |
| `git diff --check` | Geçti |
| Android Debug export | Geçti; Godot debug imzası oluşturuldu |
| APK `apksigner verify` | Geçti: v2 ve v3 imza şemaları |

## APK teslimi

- Yerel APK: [KizmaBirader-0.7.0-ui-redesign-debug.apk](/C:/KizmaBirader/build/android/KizmaBirader-0.7.0-ui-redesign-debug.apk)
- Boyut: 30.834.047 bayt
- SHA-256: `50197DADB174526EF2B3A86A37CA3F02FC5F11E88EBEF96402339E5628E88961`
- Özel GitHub release: [v0.7.1-ui-redesign](https://github.com/seasalvogame/kizma-birader-builds/releases/tag/v0.7.1-ui-redesign)
- İndirme (GitHub oturumu gerektirir): [APK](https://github.com/seasalvogame/kizma-birader-builds/releases/download/v0.7.1-ui-redesign/KizmaBirader-0.7.0-ui-redesign-debug.apk)

## Bilinen sınırlar ve korunmuş alanlar

- Bağlı fiziksel Android cihaz/emülatör olmadığı için APK’nın cihaz üstünde
  kurulum, TalkBack, gerçek güvenli alan ve performans testi yapılmadı.
- Windows `python` komut yönlendirmesi bozuktu; sistemdeki gerçek Python 3.12
  yorumlayıcısı ile çeviri üreticisi başarıyla çalıştırıldı. Bu proje kaynak
  sorunu değildir.
- Oyun motoru/kuralları, Supabase şeması, Worker/Durable Object yapısı,
  kimlik doğrulama, ekonomi ve sunucu otoritesi değiştirilmedi.
- Kaynak proje için commit, git push, Worker deploy veya Supabase migration
  yapılmadı. APK yalnızca kullanıcının daha önce onayladığı özel GitHub builds
  deposuna release varlığı olarak yüklendi.
