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

## 7. Québec'te yaşamak neyi değiştiriyor (31 Ekim 2026 ek araştırma)

### Fransızca: lansman şehrinden bağımsız
- **Kural:** Fransız Dili Şartı'na göre Québec'te kurulu ve Québec pazarına
  hitap eden işletmelerde:
  - web sitesindeki ticari içerik **Fransızca** olmalı;
  - herkese aynı sunulan sözleşmeler (kullanım koşulları gibi) önce
    **Fransızca** verilmeli (madde 55);
  - yazılımın Fransızca sürümü varsa diğer dillerden kötü olmayan
    koşullarla sunulmalı (madde 52.1). Yazılım kuralının tüketici
    uygulamalarına nasıl uygulandığı net değil; avukata sorulmalı.
- **Ceza:** şahıslar için 700–7.000 $, şirketler için 3.000–30.000 $;
  tekrarda iki katı. Uygulama çoğunlukla **şikâyet üzerine** işliyor.
  2023'te Fransızca olmayan siteler için verilen cezalar 1.500–3.000 $
  civarındaydı.
- **Helperly için anlamı:** Sen Québec'te yaşadığın için işletme de
  Québec'te sayılır. Lansmanı Toronto'da yapsan bile uygulama Québec'ten
  indirilebilir; Fransızca yükümlülüğü yine büyük ölçüde geçerli. İngilizce
  şehir seçmek riski azaltır, ortadan kaldırmaz.
- **Uygulamanın durumu:** dil altyapısı yok, ekranlarda en az ~240 sabit
  İngilizce metin var. Fransızca eklemek yapılabilir bir iş; hukuki
  metinlerin Fransızcası bir insan tarafından kontrol edilmeli.

Kaynaklar:
[Miller Thomson – Québec'te iş yapmak](https://www.millerthomson.com/en/insights/publications/special-considerations-doing-business-in-quebec-civil-law-language-compliance/),
[BCF – Haziran 2025 yükümlülükleri](https://www.bcf.ca/en/thought-leadership/2025/the-charter-of-the-french-language-new-obligations-as-of-june-2025),
[Smart & Biggar – ihlal maliyeti](https://www.smartbiggar.ca/insights/publication/french-language-requirements-in-qu%C3%A9bec-part-8---the-cost-of-violating-the-french-language-requirements-in-the-province-of-qu%C3%A9bec),
[Montréal International](https://www.montrealinternational.com/en/?p=40110),
[CFIB – Law 14](https://cfib-fcei.ca/en/site/qc-law-14-bill-96).

### Gizlilik: Québec Law 25
- **Kapsam:** Küçük işletme veya şahıs istisnası yok.
- **Gizlilik sorumlusu:** Varsayılan olarak işletme sahibi (sen). Unvanı ve
  iletişim bilgisi sitede yayınlanmalı.
- **Etki değerlendirmesi:** Kişisel veri işleyen bir uygulama geliştirmeden
  önce ve veriyi **Québec dışına** aktarmadan önce yazılı bir gizlilik etki
  değerlendirmesi (PIA) gerekiyor. Firebase, Agora ve Stripe sunucuları ABD'de
  olduğu için bu aktarım sayılıyor.
- **Varsayılan gizlilik:** Kişiyi tanımlayan veya profilleyen izleme
  teknolojisi varsayılan olarak kapalı olmalı ve kullanıcı bilgilendirilmeli.
  Firebase Analytics için en güvenli yol, kullanıcı izin verene kadar kapalı
  tutmak.
- **Olay kaydı:** Veri sızıntısı olursa kayıt tutulmalı; ciddi durumlarda
  CAI'ye ve kullanıcılara bildirilmeli.

Kaynaklar:
[CFIB – Law 25](https://www.cfib-fcei.ca/en/site/qc-law-25),
[BCLP – Law 25](https://www.bclplaw.com/en-US/events-insights-news/quebec-law-no-25-a-little-known-privacy-law-with-a-big-reach.html),
[TrustArc – Law 25](https://trustarc.com/regulations/quebec-law-25/).

### Göç konusu: Québec ikinci bir kural ekliyor
Québec'in kendi seçim programları (CSQ vb.) için danışmanlık yapacak kişinin
**MIFI tarafından tanınmış** olması gerekiyor. Bu, federal RCIC kuralına
eklenir. "Immigration experience" konusu yalnızca ücretsiz deneyim paylaşımı
olarak kalmalı.

Kaynaklar:
[Québec – göç danışmanı olma koşulları](https://www.quebec.ca/immigration/consultants-immigration/obtenir-titre-consultant-immigration/conditions),
[Québec göç danışmanları kaydı](https://open.canada.ca/data/en/dataset/23f8d075-4574-4238-a3d1-f3ba5674fce0).

### İşletme kaydı
Şahıs olarak kendi adın dışında bir adla ("Helperly") iş yapacaksan
Registraire des entreprises'e kayıt zorunlu. Ücret yaklaşık 40 $; yıllık
beyan da var. Kayıttan sonra bir NEQ numarası alırsın. Ad kuralları
(Fransızca jenerik terim) avukata sorulmalı.

Kaynak: [Québec.ca – kayıt](https://www.quebec.ca/en/businesses-and-self-employed-workers/start-entreprise/register-constitute-enterprise/learn-about-registration/about-registration).

### Pazar
- 2024'te yeni daimi oturum sayısı: Montréal bölgesi ~38.700, Toronto
  ~124.660 (IRCC verisini aktaran ikincil kaynak).
- Québec'te Ocak 2025'te ~617.000 geçici göçmen vardı. Bunlar uygulamanın en
  doğal kullanıcıları: öğrenciler ve çalışma izinliler.
- MIFI, 2024–25'te 91.165 kişiye Fransızca eğitimi verdi (%25 artış).
  Fransızca pratiği ve Québec bürokrasisi Montréal'e özgü güçlü bir ihtiyaç.

Kaynaklar:
[CBC – Québec göç 2024](https://amp.cbc.ca/news/canada/montreal/quebec-immigration-fertility-1.7529965),
[MIFI 2024-25 raporu (Immigrant Québec)](https://immigrantquebec.com/fr/actualites/bilan-en-immigration-le-rapport-annuel-de-gestion-2024-2025-du-mifi-depose/),
[StatCan Q4 2025](https://www150.statcan.gc.ca/n1/daily-quotidien/260318/dq260318b-fra.htm).

### Ücretsiz veya düşük ücretli hukuki yardım (Montréal)
- Compass Startup Legal Clinic: girişimcilere ücretsiz hukuki bilgi
  ([McGill Engine](https://www.mcgill.ca/engine/resources/mcgill-engine-centre-support/partners)).
- YES Montréal: haftalık ücretsiz hukuki bilgi kliniği
  ([YES](https://yesmontreal.ca/events/2024-01-08/)).
- Barreau du Québec erişim kaynakları
  ([Barreau](https://www.barreau.qc.ca/en/general-public/access-justice/access-justice-resources/)).

## 8. Önerilen karar (Claude)

1. **Şehir:** Montréal, iki dilli (FR + EN). Fransızca zaten gerekecek.
   Yardımcı bulmak marketplace'in en zor kısmı ve bunu en iyi yaşadığın
   yerde, yüz yüze yaparsın.
   - Fransızca bitene kadar arkadaş ve topluluk çevresinde **kapalı beta**
     (TestFlight ve Play internal testing) İngilizce yapılabilir.
   - Herkese açık lansman Fransızca ile.
2. **Önce ücretsiz.** Ücretli görüşme yardımcıya ödeme aktarımı bağlanınca
   ve düzenli kullanım oluşunca açılır.
3. **Fiyat (ücretli aşamada):** 10 dk = 4,99 $, platform payı ilk aşamada
   %15 (yardımcıyı çekmek için). Ücretsiz 1 dakika kaldırılmalı; ücretsiz
   aşama zaten tanışmayı karşılıyor.
4. **Destek e-postası:** Bir alan adı al, support@ ve privacy@ adreslerini
   ücretsiz yönlendirme ile (Cloudflare Email Routing gibi) Gmail'e bağla.
   privacy@ Law 25 için gizlilik sorumlusu iletişimi olur.
5. **Law 25:**
   - gizlilik sorumlusu sen; adın ve iletişim bilgin gizlilik metnine
     eklenir;
   - Analytics izin verilene kadar kapalı (Crashlytics açık kalır);
   - PIA taslağı hazırlanır.
6. **İşletme kaydı:** "Helperly" adıyla Registraire des entreprises.
7. **Avukata (Compass / YES) sorulacaklar:**
   - Fransızca kapsamı;
   - koşullar ve gizlilik metni;
   - Law 25 PIA;
   - işletme adı;
   - ücretli aşamada vergi (GST/QST) ve tüketici koruma.

## 9. Senden karar bekleyenler (özet)

1. Gerçek destek e-postası.
2. Lansman şehri: Ontario/BC mi, Québec mi (Fransızca)?
3. Ücretli görüşme MVP'de açık mı olacak, yoksa önce ücretsiz mi?
   - Açık olacaksa yardımcıya ödeme aktarımı tamamlanmalı.
4. Fiyat dokümanlarındaki farklar (4,49 $ / 4,99 $, %15 / %20) ve ücretsiz
   1 dakika.
5. Test verisinin canlı veritabanından silinmesine onay.
6. Avukat görüşmesi: koşullar ve gizlilik taslakları, RCIC kuralı,
   Fransızca.
