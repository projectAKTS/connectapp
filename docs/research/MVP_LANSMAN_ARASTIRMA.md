# Helperly MVP Lansmanı: Kurallar ve Riskler Araştırması

31 Ekim 2026, Claude. Bu bir hukuki görüş değil. Kesin kararlar için
avukat veya lisanslı danışmana sorulmalı; aşağıdaki kaynaklar bu görüşmeye
hazırlık içindir.

## 1. Ücretli göç danışmanlığı (Kanada, IRPA madde 91)

**Kural:** Ücret ya da başka bir karşılık alarak göç veya vatandaşlık
tavsiyesi verebilenler:
- avukatlar;
- Québec noterleri;
- baro üyeleri (örneğin paralegaller; il bazında sınırlar var);
- CICC'ye kayıtlı, durumu "aktif" olan lisanslı danışmanlar (RCIC).

**Ceza:** ağır suçta 200.000 $'a kadar para cezası ve/veya 2 yıla kadar hapis.

**Ücretsiz yardım:** 91. madde ücretsiz yardıma uygulanmıyor. Ama ücretsiz
temsilcinin de başvuruda IMM 5476 formuyla bildirilmesi gerekiyor.

**Helperly için anlamı:** "Göç / PR / mülteci" konusunda lisanssız
yardımcıların **ücretli** görüşme vermesi, yardımcıyı (ve platformu riskli
şekilde) yasa dışı faaliyete açar. Bu yüzden MVP-1'de göç konusu sadece
"Immigration experience" (deneyim paylaşımı) olarak kaldı.

Senin vision deck'teki "Pro Helpers (Verified Experts)" fikri tam olarak
çözüm. Ücretli göç tavsiyesi, sadece **CICC registrisinden (college-ic.ca)
lisansı doğrulanmış RCIC'lere** açılmalı. Doğrulama, RCIC numarası (R + 6
rakam) ile ücretsiz yapılabiliyor.

Kaynaklar:
[IRCC – Kimler temsilci olabilir](https://www.canada.ca/en/immigration-refugees-citizenship/corporate/publications-manuals/operational-bulletins-manuals/service-delivery/use-representatives/who-act.html),
[Bridgepoint Law – IRPA s.91](https://bridgepointlaw.ca/authorized-immigration-representative-irpa-91/),
[IRB – Yetkisiz ücretli temsilci politikası](https://irb-cisr.gc.ca/en/legal-policy/policies/Pages/PolPaidRemun.aspx),
[RCIC nasıl doğrulanır](https://wildmountainimmigration.com/blog/how-to-verify-an-rcic).

## 2. Québec ve Fransızca (Bill 96 / Fransız Dili Şartı)

**Kural:** Bill 96'ya göre bir yazılımın Fransızca sürümü varsa, Québec'te
Fransızca olarak sunulması zorunlu. Bazı kaynaklar bunun Québec'te
kullanılan uygulama ve web siteleri için de geçerli olabileceğini, Fransızca
sürümün en az diğer diller kadar iyi koşullarda sunulması gerektiğini
söylüyor.

**Ceza:** bir kaynağa göre kurumlar için 3.000–30.000 $ (tekrarda daha
yüksek). Tüketici uygulamaları için kapsamın tam nasıl yorumlandığı net
değil.

**Helperly için anlamı:** Québec'te (Montréal) lansman yapılacaksa
uygulamanın Fransızcası da olmalı. Önerim: ilk soft launch'ı **Ontario /
BC**'de (Toronto, Vancouver) yapmak, Fransızcayı ilk büyük güncellemede
eklemek. Ya da Québec için baştan Fransızca çıkmak. Avukata sorulacak.

Kaynaklar:
[Miller Thomson – Bill 96](https://www.millerthomson.com/en/insights/publications/bill-96-quebec-french-language-law-overhaul/),
[Miller Thomson – Québec'te iş yapmak](https://www.millerthomson.com/en/insights/publications/special-considerations-doing-business-in-quebec-civil-law-language-compliance/),
[Osler – Bill 96](https://www.osler.com/?p=31884),
[Torys – Bill 96](https://www.torys.com/our-latest-thinking/publications/2021/05/bill-96-a-proposal-for-significant-modifications-to-the-precedence-of-french-in-quebec).

## 3. Apple App Store kuralları (resmi metinden)

- **1.2 Kullanıcı içeriği.** Zorunlular:
  - uygunsuz içerik **filtresi**: MVP-4'te eklendi;
  - **şikâyet** ve zamanında yanıt: MVP-1;
  - **engelleme**: MVP-1;
  - **yayınlanmış iletişim bilgisi**: Ayarlar ve site var; **gerçek destek
    e-postası lazım**.
- **5.1.1(v)** Hesap oluşturulabiliyorsa uygulama içinde **hesap silme**
  zorunlu. MVP-1 ve MVP-2'de eklendi.
- **3.1.3(d)** **Gerçek zamanlı** kişiden kişiye hizmetlerde (ders,
  danışmanlık vb.) Apple ödemesi (IAP) dışında ödeme kullanılabilir. Bu
  yüzden Stripe ile canlı görüşme satmak uygun, Apple komisyon almaz.
  - **Dikkat:** Apple, "mesajla sorup sonra cevap alma" gibi gerçek zamanlı
    olmayan hizmetleri dijital sayıyor, bunlarda IAP zorunlu. İleride
    "ücretli soru" gibi bir özellik eklenirse IAP gerekir.
  - Birden fazla kişiye (1'e-çok) canlı hizmetler de IAP gerektiriyor.
- **5.1.1(ix)** Sağlık, finans gibi düzenlenen alanlarda uygulama, şahıs
  geliştirici değil **şirket** tarafından gönderilmeli. Helperly bu listede
  değil. Ama ileride sağlık veya finans konusu eklenirse gerekir.
  - Apple geliştirici hesabının şahıs mı şirket mi olduğunu kontrol et.
- **1.4.1** Tıbbi konularda "doktora danışın" uyarısı. Ruh sağlığı MVP'den
  bu yüzden de çıkarıldı.

Kaynak: [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

## 4. Google Play kuralları

- Hesap oluşturulan uygulamalar, uygulama içi silmeye ek olarak **web
  üzerinden silme talebi bağlantısı** vermek ve bunu **Data safety**
  formunda belirtmek zorunda.
  - Sayfa çalışır durumda olmalı ve uygulama/geliştirici adını içermeli.
  - Bu sayfa hazırlandı: `public/delete-account.html`. Deploy sonrası
    adresi `https://connectapp-278b4.web.app/delete-account.html`.
- **Data safety** formunda şu veriler beyan edilmeli:
  - toplanan veriler (hesap, profil, mesaj, ödeme referansı);
  - çökme ve kullanım verisi (MVP-3).

Kaynaklar:
[Google Play – Hesap silme gereklilikleri](https://support.google.com/googleplay/android-developer/answer/13327111),
[Android Developers Blog (2023)](https://android-developers.googleblog.com/2023/04/giving-people-more-control-over-their-data.html).

## 5. Teknik: Firebase Dynamic Links

25 Ağustos 2025'te kapatıldı. O tarihten sonra `page.link` linkleri
çalışmıyor ve yeni link oluşturulamıyor.
- Uygulamadaki kullanım: MVP-1'de kaldırıldı.
- Paket: MVP-3'te kaldırıldı.
- Stripe yardımcı kaydındaki `page.link` adresleri: MVP-2'de düzeltildi.

Kaynak: [Firebase Dynamic Links FAQ](https://firebase.google.com/support/dynamic-links-faq/).

## 6. Fiyatlandırma notları (senin dokümanlarınla karşılaştırma)

- **Uygulamadaki fiyat tablosu:** ConnectApp Pricing Strategy ile aynı.
  Platform payı %20, video fiyatları sesli fiyatın 1,3 katı. Sunucu artık
  aynı tabloyla fiyatlıyor (MVP-2).
- **Dokümanlar arası farklar:**
  - "MicroHelp Vision Deck": 10 dk = **4,99** $, platform payı %15.
  - Uygulama ve diğer doküman: 10 dk = **4,49** $, platform payı %20.
  - Hangisi geçerli? Karar verince tek yerden (`PricingConfig` ve
    `consultation_price.js`) değiştiririm.
- **1 dakikalık sesli görüşme ücretsiz (0,00 $):** tabloda bu satır var,
  yani herkes her yardımcıyla 1 dakika ücretsiz konuşabilir. Bilinçli bir
  "tanışma araması" ise güzel. Değilse kaldırılmalı.
- **Yardımcıya ödeme:** uygulamanın kullandığı kayıtlı kartla ödeme akışı
  (`chargeStoredPaymentMethod`) parayı platform hesabına alıyor, yardımcıya
  aktarım (Stripe Connect transfer) yapmıyor. Aktarım yalnızca uygulamanın
  çağırmadığı barındırılan ödeme sayfası akışında
  (`createStripeCheckoutSession`) var. Yardımcılar
  para kazanacaksa bu MVP'den önce tamamlanmalı. Alternatif: lansmanı
  **önce ücretsiz** yapıp ücretli görüşmeyi ikinci aşamada açmak. Ben bunu
  öneriyorum: önce topluluk ve güven, sonra para.

## 7. Senden karar bekleyenler (özet)

1. Gerçek destek e-postası.
2. Lansman şehri: Ontario/BC mi, Québec mi (Fransızca)?
3. Ücretli görüşme MVP'de açık mı olacak, yoksa önce ücretsiz mi?
   - Açık olacaksa yardımcıya ödeme aktarımı tamamlanmalı.
4. Fiyat dokümanlarındaki farklar (4,49 $ / 4,99 $, %15 / %20) ve ücretsiz
   1 dakika.
5. Test verisinin canlı veritabanından silinmesine onay.
6. Avukat görüşmesi: koşullar ve gizlilik taslakları, RCIC kuralı,
   Fransızca.
