@echo off
REM 🚀 Kampus Forum Cache Sistem Test Scripti (Windows)
REM Bu script cache sistemi test etmek için kullanılır

echo.
echo 🔧 Kampus Forum - Cache Sistem Testi
echo ======================================
echo.

REM Flutter'ı temizle
echo 🧹 Flutter cache temizleniyor...
flutter clean

REM Pub dependencies'i yükle
echo 📦 Dependencies yükleniyor...
flutter pub get

REM Build yap
echo 🔨 Proje build ediliyor...
flutter build apk --verbose

echo.
echo ✅ Test hazır!
echo.
echo 🧪 Test Adımları:
echo 1. Chrome DevTools açın (F12)
echo 2. Network tab →  Throttling →  Slow 3G seçin
echo 3. App'ı açın: flutter run
echo 4. Splash ekranı izleyin:
echo    - Loading text dinamik olarak güncellenmelidir
echo    - App asla donmuş görünmemelidir
echo    - 2.5 saniye sonra ana ekrana geçmelidir
echo 5. Offline modda test edin (Airplane Mode)
echo.
echo 📊 Beklenen Davranış:
echo    - Hızlı Ağ: Tüm veriler yüklenir (✅ Veriler hazır 7/7)
echo    - Yavaş Ağ: Cache kullanılır, arka planda güncellenir
echo    - Offline: Cached veriler gösterilir
echo.
pause
