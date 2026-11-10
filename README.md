# HBB Çok Amaçlı Salon Randevu ve Yönetim Sistemi

Hatay Büyükşehir Belediyesi personelinin salon randevularını gerçek PostgreSQL veritabanında tutan uygulama. Vatandaş sisteme girmez; kart ve randevu belediye personeli tarafından yazılır.

Arayüz React + TypeScript + Vite, sunucu Node.js + TypeScript + Express, veritabanı PostgreSQL’dir. Kalıcı kayıt tarayıcı belleğinde tutulmaz. Google Sheets, Apps Script ve Firebase kullanılmaz.

Gösterilen bütün tarih ve saatler `Europe/Istanbul` saat dilimindedir. Veritabanında `timestamptz` kullanılır. API, tarih-saat alanlarını `+03:00` ofsetli ISO 8601 olarak döner. Tam gün aralığı seçilen son günü kapsar ve veritabanında `[başlangıç günü 00:00, son günün ertesi 00:00)` olarak saklanır.

## 1. Gerekli araçlar

- Node.js 22 ve npm
- PostgreSQL 16 (Docker veya yerel kurulum)
- Üretim için Docker Compose ve Caddy (HTTPS)

Bu klasörde geliştirme, Docker kurulu olmadığı için yerel PostgreSQL 18 ile yapıldı. `docker-compose.yml` aynı kurulumu Docker ile tekrarlar.

## 2. Ortam değişkenleri

Kökteki `.env.example` yalnızca yer tutucu içerir. Gerçek şifre yazmayın.

```powershell
Copy-Item .env.example server\.env
```

`server/.env` içinde en az şunları düzenleyin:

- `DATABASE_URL` — uygulama veritabanı. Örnek: `postgres://hbb:GIZLI@localhost:5432/salon`
- `APP_ORIGIN` — arayüzün adresi. Geliştirmede `http://localhost:5173`
- `COOKIE_SECURE` — HTTP geliştirmede `false`, HTTPS üretimde `true`

`server/.env` git’e eklenmez.

## 3. Veritabanını başlatma

Docker varsa:

```powershell
docker compose up -d db
```

Yerel PostgreSQL kullanıyorsanız `salon` veritabanını ve `hbb` rolünü kendiniz oluşturun. Yeni kurulumda salon listesi boştur. Migration sahte salon veya vatandaş eklemez.

Üretimde veritabanı portunu internete açmayın. `docker-compose.prod.yml` portu yayımlamaz.

## 4. Migration

```powershell
cd server
npm install
npm run migrate
```

Komut `schema_migrations` tablosuna bakıp yalnızca uygulanmamış SQL dosyalarını çalıştırır. Aynı komut yeniden çalıştırılırsa mevcut kayıtlar durur.

## 5. İlk yönetici

```powershell
npm run bootstrap-admin
```

Yalnızca sistemde hiç kullanıcı yokken bir kez çalışır. Kullanıcı adı `admin` olur. Güçlü geçici şifre yalnızca bu komutun terminal çıktısında bir kez yazılır. Kaynak koduna, bu dosyaya veya seed dosyasına konmaz. İlk girişte şifre değişmeden diğer modüllere API üzerinden de erişilemez. Komut yeniden çalışırsa mevcut hesaplar ve şifreler korunur.

Yöneticiye ulaşılamazsa, yalnızca sunucu terminalinden:

```powershell
npm run recover-admin
```

Bu komut `admin` için yeni geçici şifre üretir, eski oturumları kapatır ve işlemi denetim kaydına yazar. İnternete açık şifre sıfırlama yoktur.

## 6. Uygulamayı başlatma

İki terminal:

```powershell
cd server
npm run dev
```

```powershell
cd client
npm install
npm run dev
```

Arayüz: http://localhost:5173  
API aynı geliştirme sunucusunda Vite vekili ile `/api` altından gider. Sağlık kontrolü: http://127.0.0.1:3000/health

Üretim derlemesi ve tek süreç:

```powershell
cd client
npm run build
cd ..\server
npm run build
npm start
```

`CLIENT_DIST` arayüz klasörünü gösterir. Docker imajı bunu `/app/client/dist` olarak ayarlar ve 8080 portunda arayüz ile API’yi aynı origin’den sunar.

```powershell
docker compose up --build
```

## 7. Gerçek salon listesini içe aktarma

Yönetici olarak **Salon Yönetimi** ekranına girin. **Boş şablon indir** ile UTF-8 CSV alın. Excel’de başlık satırını koruyarak doldurup metni yapıştırın veya dosya içeriğini alana koyun. **Önizle** sonrası **Tümünü kaydet** bütün satırları tek transaction’da yazar. Bir satır hatalıysa hiçbir salon eklenmez. Aynı ad ve ilçe/mahalle ikinci kez yazılmaz. 43 sabit bir üst sınır değildir; yönetici salon eklemeye devam edebilir.

Salonlar silinmez. Kullanım durumu değişir. Kapatırken gelecek randevular gösterilir ve kendiliğinden iptal edilmez.

## 8. Personel hesapları

Herkese açık kayıt ekranı yoktur. Yönetici **Kullanıcı Yönetimi**nden hesap açar. Geçici şifre yalnızca oluşturma yanıtında bir kez gösterilir. Personel ilk girişte şifresini değiştirir.

## 9. Yetki seviyeleri

| Rol | Yapabildikleri |
| --- | --- |
| Yönetici | Salon, vatandaş, randevu, kullanıcı, rapor, işlem geçmişi, etkinlik türü ve rezervasyon kuralları |
| Randevu yetkilisi | Vatandaş ve randevu işlemleri, takvim, operasyonel raporlar. Salon tanımı, kullanıcı, ayar ve işlem geçmişi yok |
| Görüntüleme | Dolu-boş takvim ve salon durumu. Yazma yok. Vatandaş adı, telefon, adres ve açıklama API yanıtına konmaz |

Menü, buton, API ve dönen alanlar birlikte kısıtlanır. Butonu gizlemek yetki sayılmaz.

Son yönetici kapatılamaz. Kullanıcı kendi hesabını kapatamaz. Hesap kapatılınca veya rol/şifre değişince ilgili oturumlar düşer.

## 10. Randevu ve geçici tutma

Yer tutan kayıtlar PostgreSQL `EXCLUDE USING gist` ile aynı salonda çakışamaz. Aralık yarı açıktır: bitiş anı, sonraki kaydın başlangıcı olabilir. İptal ve süresi dolmuş talep yer tutmaz.

**Talep alındı** kayıtlarının takvimi doldurup doldurmayacağı ve varsayılan geçerlilik süresi **Ayarlar**dadır. Süre dolunca kayıt silinmez; ekranda **Süresi doldu** görünür ve doluluk hesabından çıkar. Yer tutma açılırken mevcut talepler çakışırsa ayar değişikliği tamamen geri alınır.

Yeni randevu geçmişe yazılamaz. Yalnızca aktif salona yazılır. Kayıt sürümü uyuşmazsa güncelleme reddedilir; arayüz güncel kaydı açmayı önerir. Aynı istek anahtarı ikinci kez yeni randevu açmaz. Anahtar farklı içerikle gelirse reddedilir.

Etkinlik türü kapatılırsa eski randevular durur. Taziye birden fazla gün olabilir. Düğün ve nişan tam gün veya saat aralığı olabilir.

## 11. CSV ve PDF raporları

**Raporlar** ekranındaki filtreler JSON, CSV ve PDF için aynıdır. CSV UTF-8 BOM ile iner; formül enjeksiyonuna karşı hücre başındaki `=`, `+`, `-`, `@` işaretleri etkisizleştirilir. PDF gömülü DejaVu yazı tipiyle Türkçe karakter basar, sayfa numarası ve uygulanan filtreleri içerir.

Doluluk oranı, seçilen aralıkta yer tutan sürelerin birleşimidir. Aynı dakika iki kez sayılmaz. İptal ve süresi dolmuş tutma paya girmez. Kapalı kalınan süre ayrıca tutulmadığı için kullanıma kapalı salonlar paydaya alınmaz; rapordaki not bunu belirtir.

## 12. Yedekleme ve geri yükleme

Yedek kişisel veri içerir. Dosyayı yalnızca görevli personelin erişebildiği yerde tutun. Bu depoda saklamayın.

Docker hacmi `pgdata`:

```powershell
docker compose exec -T db pg_dump -U hbb -d salon > yedek.sql
```

Geri yükleme mevcut veritabanının üzerine yazar. Önce uygulamayı durdurun ve güncel bir yedeğiniz olduğundan emin olun.

```powershell
docker compose exec -T db psql -U hbb -d salon -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
Get-Content yedek.sql | docker compose exec -T db psql -U hbb -d salon
```

Yerel PostgreSQL için aynı işi `pg_dump` ve `psql` ile yapın. Geri yüklemeden sonra `npm run migrate` çalıştırın; uygulanmış migration tekrar veri silmez.

## 13. HTTPS ile üretime alma

`docker-compose.prod.yml` veritabanı portunu dışarı vermez, çerezi `Secure` yapar ve Caddy’yi 80/443 üzerinde açar.

```powershell
$env:POSTGRES_PASSWORD = "güçlü-veritabanı-şifresi"
$env:APP_ORIGIN = "https://salon.hatay.bel.tr"
$env:APP_DOMAIN = "salon.hatay.bel.tr"
$env:TLS_EMAIL = "eposta@hatay.bel.tr"
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec app node server/dist/scripts/bootstrapAdmin.js
```

İlk yönetici komutunu konteyner içinde bir kez çalıştırın ve terminaldeki geçici şifreyi güvenli kanaldan iletin. `APP_ORIGIN` tarayıcının gördüğü adresle aynı olmalıdır.

## 14. Sürüm güncelleme

Kodu alın, imajı yeniden derleyin, migration çalıştırın. Güncelleme veriyi silmez.

```powershell
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec app node server/dist/scripts/migrate.js
```

Geliştirmede `npm run migrate` yeterlidir. Yedek almadan üretim güncellemesi yapmayın.

## 15. Testler

Testler `salon_test` veritabanına gider. `server/vitest.config.ts` bu adresi sabitler; uygulama veritabanına yazmaz.

```powershell
cd server
npm test
```

Docker’daki test veritabanı 5433 portundadır. Yerel kurulumda `salon_test` ve `hbb` / `hbb_dev_only` hazır olmalıdır. Farklı parola kullanıyorsanız testten önce rol parolasını eşitleyin veya `vitest.config.ts` içindeki adresi kendi test veritabanınıza çevirin. Uygulama veritabanının adresini buraya yazmayın.

## 16. Doğrulanan sınırlar ve eksikler

Doğrulananlar:

- Gerçek PostgreSQL üzerinde 18 entegrasyon testi geçti. Kapsam: eşzamanlı çakışma, bitişik aralık, iptal, süresi dolmuş ve dolmamış tutma, çok günlük taziye, tam gün sonu, kapalı salon, eşzamanlı kapatma, taşıma çakışması, eski sürüm, idempotency, telefon tekilliği, yetkisiz yazma, görüntüleme rolünde kişisel veri olmaması, hesap kapatma, ilk şifre kapısı, tutma ayarının geri alınması, toplu girişin atomik olması, başarısız işlemde denetim kaydı yazılmaması.
- Tarayıcıda şu akış çalıştırıldı: telefonla bulunamayan vatandaş, kart, boş salon sorgusunun saatini forma taşıması, randevu, vatandaş geçmişi, tarih taşıma, gerekçeli iptal, salonun yeniden boş görünmesi, iptal raporunun CSV ve PDF indirilmesi. PDF metninde Türkçe karakterler çözüldü.
- İstemci ve sunucu üretim derlemesi `npm run build` ile alındı.

Bu çalışma klasöründeki `salon` veritabanı kurulumdan sonra doğrulama için kullanıldı. İçinde personelin elle girdiği bir salon, bir vatandaş kartı ve iptal edilmiş bir randevu vardır. Bunlar migration veya seed değildir. Canlıya bu dosyayı kopyalamayın; yeni kurulum boş salon listesiyle açılır.

Açık noktalar:

- Bu makinede Docker CLI yoktu. İmaj ve `docker compose` burada çalıştırılmadı. Dosyalar hazırdır.
- Mobil yerleşim ve klavye odağı kodda vardır; ayrı bir cihaz turu yapılmadı.
- Üç rolün API yetkisi entegrasyon testinde doğrulandı. Tarayıcı turu yönetici hesabıyla yapıldı.
- Saklama ve silme süreleri kurum kararıdır. Uygulama kişisel veriyi kendiliğinden süreli silmez. Vatandaş kartında T.C. kimlik numarası ve doğum tarihi tutulur; bu alanlar yalnızca yönetici ve randevu yetkilisine döner. Görüntüleme rolünün yanıtında yer almaz. Yeni kartta T.C. kimlik numarası ve doğum tarihi yazılınca NVI’den getir, ad, soyad ve adresi KPS yanıtından doldurur. Bu dönüş için `NVI_USERNAME` ve `NVI_PASSWORD` gerekir; açık doğrulama servisi yalnızca evet veya hayır döner. Kayıt sırasında ad soyad, kimlik numarası ve doğum tarihi `server/src/integrations/nvi` üzerinden NVI servisine sorulur. Servis açıkça reddederse kart kaydedilmez. Servise ulaşılamazsa veya bu kurulumun isteği kabul edilmezse kart kaydedilir ve NVI doğrulaması işareti konmaz. `NVI_MODE=off` sorguyu kapatır. Belediyenin kurumsal KPS adresi `NVI_ENDPOINT` ile verilir. Kimlik numarası ve NVI isteği uygulama günlüğüne yazılmaz.

## Günlük akış

1. Genel Bakış’ta telefonu yazın.
2. Kart yoksa aynı numara forma taşınır.
3. İlçe, mahalle ve zamanı seçin veya Boş Salon Ara sonucundan randevuya geçin.
4. Üç adımda kontrol edip kaydedin. Randevu numarası, fiş ve takvim bağlantısı açılır.
5. Taşıma ve iptal randevu kartındadır. İptal gerekçe ister ve kaydı silmez.
