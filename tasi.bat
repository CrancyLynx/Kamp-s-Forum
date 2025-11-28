@echo off
echo Dosyalar tasiniyor...

:: Klasorleri Olustur
if not exist "lib\screens\auth" mkdir "lib\screens\auth"
if not exist "lib\screens\home" mkdir "lib\screens\home"
if not exist "lib\screens\forum" mkdir "lib\screens\forum"
if not exist "lib\screens\market" mkdir "lib\screens\market"
if not exist "lib\screens\chat" mkdir "lib\screens\chat"
if not exist "lib\screens\profile" mkdir "lib\screens\profile"
if not exist "lib\screens\admin" mkdir "lib\screens\admin"
if not exist "lib\screens\map" mkdir "lib\screens\map"
if not exist "lib\screens\search" mkdir "lib\screens\search"
if not exist "lib\screens\notification" mkdir "lib\screens\notification"
if not exist "lib\utils" mkdir "lib\utils"
if not exist "lib\models" mkdir "lib\models"
if not exist "lib\services" mkdir "lib\services"

:: Auth
move "lib\giris_ekrani.dart" "lib\screens\auth\"
move "lib\dogrulama_ekrani.dart" "lib\screens\auth\"
move "lib\splash_screen.dart" "lib\screens\auth\"

:: Home
move "lib\ana_ekran.dart" "lib\screens\home\"
move "lib\kesfet_sayfasi.dart" "lib\screens\home\"

:: Forum
move "lib\forum_sayfasi.dart" "lib\screens\forum\"
move "lib\gonderi_detay_ekrani.dart" "lib\screens\forum\"
move "lib\gonderi_ekleme_ekrani.dart" "lib\screens\forum\"
move "lib\gonderi_duzenleme_ekrani.dart" "lib\screens\forum\"

:: Market
move "lib\pazar_sayfasi.dart" "lib\screens\market\"
move "lib\urun_detay_ekrani.dart" "lib\screens\market\"
move "lib\urun_ekleme_ekrani.dart" "lib\screens\market\"

:: Chat
move "lib\sohbet_listesi_ekrani.dart" "lib\screens\chat\"
move "lib\sohbet_detay_ekrani.dart" "lib\screens\chat\"

:: Profile
move "lib\profil_ekrani.dart" "lib\screens\profile\"
move "lib\profil_duzenleme_ekrani.dart" "lib\screens\profile\"
move "lib\kullanici_profil_detay_ekrani.dart" "lib\screens\profile\"
move "lib\rozetler_sayfasi.dart" "lib\screens\profile\"

:: Admin
move "lib\admin_panel_ekrani.dart" "lib\screens\admin\"
move "lib\kullanici_listesi_ekrani.dart" "lib\screens\admin\"

:: Diger Ekranlar
move "lib\kampus_haritasi_sayfasi.dart" "lib\screens\map\"
move "lib\arama_sayfasi.dart" "lib\screens\search\"
move "lib\bildirim_ekrani.dart" "lib\screens\notification\"

:: Utils & Models & Services
move "lib\app_colors.dart" "lib\utils\"
move "lib\api_keys.dart" "lib\utils\"
move "lib\badge_model.dart" "lib\models\"
move "lib\news_service.dart" "lib\services\"

echo Islem tamamlandi!
pause