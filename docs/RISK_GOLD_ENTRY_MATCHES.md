# Risk Notu — Altın Giriş Bedelli Maçlar (Mağaza Politikası ve Mevzuat)

> **Durum:** Faz 2 sonrası güncelleme (2026-11-17).
>
> **Bu not hukuki görüş değildir.** Aşağıdakiler genel bilgi ve ürün riski değerlendirmesidir.
> - Altınlı maçlar, hedef ülkeler için bir hukukçu ve mağaza politikası incelemesi **tamamlanmadan** yayına hazır kabul edilmemelidir.
> - **Uygunluk doğrulanmadan yayınlanabilir olduğu varsayılmamalıdır.**
>
> **Bu güncellemede değişen:** Altın artık **gerçek parayla satın alınabiliyor** (kesin karar, 2026-11-17). Önceki sürümde riskin en etkili önlemi olarak önerilen "altın satın alınamasın" maddesi artık uygulanmıyor. Bu yüzden risk seviyesi **yükseldi**. Aşağıdaki önlemler ve inceleme, bu kararla birlikte zorunlu hale geldi.

## 1. Model

- **Akış:**
  1. Oyuncular bir seviyeye altın giriş bedeli öder (ör. 100 altın).
  2. Bedeller havuzda toplanır, olası bir kesinti düşülür.
  3. Kalan, sıralamaya göre paylaştırılır. Hesabı sunucu yapar.
- **Altın:**
  - Gerçek parayla satın alınabilir.
  - Oynayarak da kazanılabilir: maç ödülleri, günlük giriş, görev, başarım.
  - Standart kozmetiklerde kullanılabilir.
- **Elmas:** Gerçek parayla satın alınabilir. Maçta ve bahiste **kullanılmaz**.
- **Kesin sınırlar:**
  - Altın ve Elmas **nakde çevrilemez**.
  - Oyuncular arasında **transfer edilemez**.
  - Yalnızca oyun içinde kullanılır.

## 2. Neden risk var

**Kumarın unsurları:** Birçok ülkede kumar üç unsurla tanımlanır:
1. **bedel:** değeri olan bir şeyi ortaya koymak;
2. **şans:** sonucun önemli ölçüde şansa bağlı olması;
3. **ödül:** değeri olan bir şey kazanmak.

**Bizim modelde:**

| Unsur | Durum |
|---|---|
| Şans | Kızma Birader'de zar belirleyicidir; **güçlü**. |
| Bedel | Altın parayla satın alınabildiği için, giriş bedelinin **parasal değeri olan bir bedel** sayılması yorumu **güçlü**. |
| Ödül | Kazanılan altın nakde çevrilemez ve transfer edilemez. Bu, "gerçek dünyada parasal değeri olan ödül" unsurunu zayıflatır. Ancak altın parayla satın alınabildiği için bazı düzenleyiciler onu değerli sayabilir. **Belirsiz; ülkeye göre değişir.** |

Model bazı yorumlarda "sosyal kumarhane" (social casino) ya da simüle kumar benzeri olarak sınıflandırılabilir.

## 3. Mağaza politikaları (resmi metinlerden; 2026-11-17)

**Google Play** ("Real-Money Gambling, Games, and Contests"):
- **Yasaklanan:** Kullanıcıların, "gerçek parayla (**parayla satın alınan uygulama içi öğeler dahil**) bahse girmesine, pay koymasına ya da katılmasına" izin vererek "**gerçek dünyada parasal değeri olan** bir ödül" kazanmasını sağlayan içerik ve hizmetler.
- **İhlal örneği:** "Fiziksel ya da parasal bir ödül kazanma fırsatı karşılığında para kabul eden oyunlar."
- **Bizim durumumuz:**
  - Ödül nakde çevrilemiyor ve transfer edilemiyor. Bu, tanımın "gerçek dünyada parasal değer" koşulunu karşılamamak için önemli.
  - Ancak politika, sanal para kazanılan ve parayla satın alınmış öğeyle girilen maçları **açıkça ele almıyor**. Yorum Google'ın incelemesine kalır.
- **Simüle kumar:** Reklam şartlarında simüle kumar içeriği (sosyal kumarhane gibi) olan uygulamalara ek kısıtlar var (ör. kumar reklamları).
- **Kaynak:** https://support.google.com/googleplay/android-developer/answer/9877032

**Apple App Store** (App Store Review Guidelines):
- **5.3 (Gaming, Gambling, and Lotteries):** Bu tür işlevler "App Store'daki en çok düzenlenen" alanlardan. Yalnızca uygulamanın sunulduğu **her yerde yasal yükümlülükler tamamen incelendiyse** eklenmeli; inceleme süreci uzayabilir.
- **5.3.3:** "Uygulamalar, **herhangi bir tür gerçek para oyunuyla** birlikte kullanılacak kredi ya da para birimini uygulama içi satın almayla satın aldıramaz."
  - Altınlı maçlar gerçek para oyunu sayılırsa, altını IAP ile satmak **açıkça yasak** olur.
  - Nakde çevirme ve transfer yokluğu, "gerçek para oyunu olmadığı" savının temelidir.
- **3.1.1:** IAP ile satın alınan oyun içi para birimlerinin süresi dolamaz. Ayrıca rastgele öğe veren mekanizmalarda olasılıklar açıklanmalıdır (bizde rastgele ücretli içerik yok).
- **Kaynak:** https://developer.apple.com/app-store/review/guidelines/

**Yaş derecelendirmesi (IARC):** Modelin simüle kumar sayılıp sayılmayacağı yaş derecelendirmesini ve hedef kitle beyanını etkileyebilir. Hedef 13+ idi (K-02). Anket soruları ve sonuçları **doğrulanacak**.

## 4. Türkiye ve diğer pazarlar

- **Türkiye:** Şans oyunları ve bahis özel mevzuata ve lisans rejimine tabi. Sanal para ile giriş bedelli maçların bu kapsamda değerlendirilip değerlendirilmeyeceği **uzman görüşü gerektirir**.
- **AB ülkeleri:** Kurallar ülkeden ülkeye değişiyor; bazıları sanal para ve loot box konusunda sıkı.
- **Karar:** Hangi ülkelerde bu modun açık olacağı hukuki incelemeyle belirlenmeli (E-7).

## 5. Riski azaltan önlemler

**Kesinleşmiş olanlar:**
1. **Nakde çevirme yok, transfer yok, oyun dışı değer yok.**
2. **Elmas maçta ve bahiste kullanılmaz.**
3. **Bakiye sunucuda;** her hareket denetlenebilir defterde. Kötüye kullanım ve şikâyet incelemesi yapılabilir.

**Önerilenler** (uygulanması önerilir; bir kısmı açık karar):
1. **Para harcamadan sürekli oynanabilirlik:** Günlük ücretsiz altın, telafi (bakiye bitince), altınsız ücretsiz maçların ve özel odanın her zaman açık olması. **Altın satın alınabildiği için en önemli önlem bu.**
2. **Ölçülü paylar ve düşük kesinti** (E-3, E-4):
   - "Kazanan hepsini alır" ve yüksek kesinti "ev payı" algısı yaratır.
   - Kesinti sıfır ya da düşük olursa bu algı zayıflar. Kesinti yerine kozmetik harcamaları enflasyonu dengeleyebilir.
3. **Sunum:**
   - "Bahis", "kumarhane", "jackpot" gibi dil ve görseller kullanılmasın.
   - Kazanılan altın sade gösterilsin; parasal karşılığı ima eden ifadeler olmasın.
4. **Bölge ve yaş anahtarı (E-7):** Altınlı maç modu yapılandırmayla ülke bazında açılıp kapatılabilir. Hukuki görüş gelene kadar **kapalı** başlar. Gerekirse yaş doğrulamasıyla açılır.
5. **Şeffaflık:** Giriş bedeli, kesinti ve paylar maç öncesinde açıkça gösterilir.
6. **Sorumlu oyun:** Günlük altınlı maç sayısı ve harcama sınırı seçenekleri değerlendirilir.

**Hukuki görüş gerektirirse değerlendirilebilecek yedek seçenekler** (mevcut kararı değiştirir, bu yüzden **senin onayını gerektirir**):
- Giriş bedelinde yalnızca oynayarak kazanılmış altının kullanılması (satın alınmış altının yalnızca kozmetiğe gitmesi).
- Altınlı maçın, giriş bedelsiz ve sabit ödüllü modele dönüştürülmesi. Ödül tablosu yapılandırmada olduğu için kod değişikliği gerekmez.

## 6. Yayın öncesi kontrol listesi

- [ ] Hedef ülkeler için hukuki görüş: en az TR; AB'de hedeflenen ülkeler; ABD hedefleniyorsa eyalet bazında.
- [ ] Google Play ve App Store politikalarının **yayın tarihindeki güncel** metinleriyle karşılaştırma: gerçek para oyunu tanımı, simüle kumar, sanal para, hedef kitle.
- [ ] IARC anketinin modelle tutarlı doldurulması.
- [ ] Ülke bazında kapatma anahtarının (`app_config`) hazır ve testli olması (E-7).
- [ ] Mağaza açıklamasında ve uygulama içinde modelin dürüstçe anlatılması.
- [ ] Kesinti ve pay kararları (E-3, E-4).
- [ ] İade sonrası borç politikası (E-6).

## 7. Sonuç

- **Teknik hazırlık:** Altınlı maçlar ve satın alınabilir altın teknik olarak hazırlanabilir. Ekonomi mimarisi güvenli ve denetlenebilir biçimde tasarlandı: GOLD_AND_DIAMOND_ECONOMY.md, SECURITY_ARCHITECTURE.md.
- **Yayın durumu:** Uygunluk doğrulanmadan **yayınlanabilir sayılmaz**.
- **Risk:** Altının satın alınabilir olması riski yükseltiyor.
- **Riski düşük tutan unsurlar:**
  - nakde çevirme ve transfer yokluğu;
  - para harcamadan oynanabilirlik;
  - ülke bazında kapatılabilirlik.
