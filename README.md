
# Namaz Vakti - Flutter (Android-first) - ZIP package
Bu paket **Android için öncelikli** olacak şekilde hazırlanmış Flutter proje iskeletidir.
Uygulama adı: **Namaz Vakti**

## İçerik
- `lib/main.dart` : Uygulama ana kodu (sade, açıklamalı)
- `pubspec.yaml` : Bağımlılıklar (geolocator, http, flutter_local_notifications, flutter_qiblah, provider, shared_preferences, intl)
- `assets/quran_sample.txt` : Örnek Kur'an metni dosyası (kopyalanmış örnek)
- `assets/README.txt` : Varlıklar klasörü bilgisi

## Önemli notlar & yapılacaklar (gereken adımlar)
1. **Bildirimler (Android)**: Proje `flutter_local_notifications` ile örnek zamanlama gösterir. Gerçek zamanlı zonedSchedule kullanımında `timezone` paketi ve doğru timezone ayarı (tz.initializeTimeZones()) gereklidir. main.dart içinde bu eklemeler örnek olarak belirtilmiştir ama üretim için `timezone` paketini entegre edin.
2. **Namaz vakitleri kaynağı**: Kod örneğinde `api.aladhan.com` kullanımı yer alır. Türkiye için resmi ve güncel veriyi almak istiyorsanız **Diyanet** API'lerini tercih edin (Diyanet'in erişim metodu ve anahtarları zaman içinde değişebilir). Diyanet kullanacaksanız `fetchPrayerTimes` fonksiyonunu Diyanet endpoint'ine göre düzenleyin ve API anahtarınızı ekleyin.
3. **Qibla / Compass**: `flutter_qiblah` kullanıldı. Gerçek cihaz üzerinde test edin.
4. **Kuran metinleri**: Telif haklarına dikkat edin. Projeye tam mushaf eklemeyin; kullanıcıya online gösterim veya lisanslı içerik sağlayın.
5. **iOS**: Bu ZIP Android öncelikli olarak gönderildi. iOS derlemeleri (widget, bildirim izinleri, entitlements) için ek konfigürasyon gerekecektir — bunu ikinci adımda hazırlayabilirim.
6. **APK oluşturma**: Bu proje dizininde `flutter build apk --release` komutu ile Android APK oluşturabilirsiniz (yerel Flutter kurulu olmalı).

## Hızlı kurulum (yerel geliştirme)
1. Flutter SDK kurulu olmalı.
2. Bu dizini açın ve terminalde `flutter pub get` çalıştırın.
3. `flutter run` veya `flutter build apk --release` ile testi yapın.

## Özellikler (şimdilik)
- Günlük ezan vakitleri (API'den çekilir)
- Şehir seçme
- Kıble pusulası (flutter_qiblah)
- Kur'an için örnek dosya yerleştirildi
- Bildirimler: vakitten 30 dk önce ve 2 dk önce örnek planlama kodu içerir
- Sonraki ezana kalan süre gösterimi
- Modern, sade tema

---
Geliştirme/dağıtım desteği istersen APK oluşturma, Play Console metadata, ikon/lokalleştirme ve App Store hazırlıkları için devam edebilirim.
