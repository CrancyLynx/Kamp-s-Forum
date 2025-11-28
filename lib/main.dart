import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';

// Servisler
import 'services/push_notification_service.dart'; 
import 'services/presence_service.dart'; 

// Widgetlar
import 'widgets/in_app_notification.dart'; 

// Sayfalar
import  '../screens/forum/forum_sayfasi.dart.';
import '../screens/auth/dogrulama_ekrani.dart';
import '../screens/home/ana_ekran.dart'; 
import '../screens/auth/giris_ekrani.dart'; 
import '../screens/auth/splash_screen.dart';
// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';
import '../screens/profile/kullanici_profil_detay_ekrani.dart';
import '../../widgets/typing_indicator.dart'; 

// --- TEMA YÖNETİCİSİ ---
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; 
  ThemeProvider(this._themeMode);
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }
}

// --- GLOBAL DEĞİŞKENLER ---
// Bildirimleri her yerden gösterebilmek için anahtar (CRITICAL)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Admin UID Listesi
const List<String> kAdminUids = [
  "oZ2RIhV1JdYVIr0xyqCwhX9fJYq1", 
  "VD8MeJIhhRVtbT9iiUdMEaCe3MO2"
];

// Arka Plan Bildirim İşleyicisi
Future<void> _bgHandler(RemoteMessage message) => firebaseMessagingBackgroundHandler(message);

// --- MAIN FONKSİYONU ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Arka plan mesajlarını dinle
  FirebaseMessaging.onBackgroundMessage(_bgHandler);
  
  // Kaydedilmiş temayı yükle
  final prefs = await SharedPreferences.getInstance();
  ThemeMode initialThemeMode = ThemeMode.system; 
  
  try {
    final themeValue = prefs.get('themeMode');
    if (themeValue is int) {
      initialThemeMode = ThemeMode.values[themeValue];
    }
  } catch (_) {}

  runApp( 
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(initialThemeMode),
      child: const BizimUygulama(),
    ),
  );
}

// --- ANA UYGULAMA WIDGET'I ---
class BizimUygulama extends StatefulWidget {
  const BizimUygulama({super.key});

  @override
  State<BizimUygulama> createState() => _BizimUygulamaState();
}

class _BizimUygulamaState extends State<BizimUygulama> {
  final PushNotificationService _notificationService = PushNotificationService();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    // 1. Bildirim Servisini Başlat
    _notificationService.initialize();
    
    // 2. Uygulama Açıkken Gelen Bildirimleri Dinle ve Göster
    _notificationService.onMessage.listen((message) {
      if (message.notification != null) {
        _showInAppNotification(
          message.notification!.title ?? 'Bildirim',
          message.notification!.body ?? '',
        );
      }
    });
  }

  // Uygulama İçi (In-App) Bildirim Gösterme Mantığı
  void _showInAppNotification(String title, String body) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    // navigatorKey üzerinden güvenli context al
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlayState = Overlay.of(context);
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100, end: 0), // Yukarıdan aşağı kayma efekti
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: InAppNotification(
                  title: title,
                  body: body,
                  onTap: () {
                    _overlayEntry?.remove();
                    // İleride buraya bildirim tıklama navigasyonu eklenebilir
                  },
                  onDismiss: () {
                    _overlayEntry?.remove();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);

    // 4 saniye sonra otomatik kapat
    Future.delayed(const Duration(seconds: 4), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kampüs Forum',
      navigatorKey: navigatorKey, // CRITICAL: Bildirimler için şart
      themeMode: context.watch<ThemeProvider>().themeMode,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, 
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[100],
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      // Uygulama Splash Screen ile başlar
      home: const SplashScreen(),
    );
  }
}

// --- ANA KONTROLCÜ (YÖNLENDİRME MERKEZİ) ---
// Splash Screen bittiğinde burası açılır ve kullanıcıyı nereye göndereceğine karar verir.
class AnaKontrolcu extends StatefulWidget {
  const AnaKontrolcu({super.key});

  @override
  State<AnaKontrolcu> createState() => _AnaKontrolcuState();
}

class _AnaKontrolcuState extends State<AnaKontrolcu> {
  @override
  void initState() {
    super.initState();
    // Kullanıcı online durumunu takip etmeye başla
    PresenceService().configure();
  }

  @override
  Widget build(BuildContext context) {
    // Status Bar ayarları
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    ));

    // 1. Kullanıcı Giriş Yapmış mı?
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) { 
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        
        if (authSnapshot.hasData) {
          final user = authSnapshot.data!;
          final userId = user.uid;

          // Misafir Kullanıcı -> Direkt Ana Ekrana
          if (user.isAnonymous) {
             return const AnaEkran(
              isGuest: true,
              isAdmin: false,
              userName: 'Misafir',
              realName: 'Misafir',
            );
          }

          final isAdministrator = kAdminUids.contains(userId);

          // 2. Kullanıcı Onaylı mı? (Firestore Kontrolü)
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').doc(userId).snapshots(),
            builder: (context, userSnapshot) { 
              // Veri yüklenirken bekleme ekranı
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }
              
              // Kullanıcı verisi yoksa (Hata durumu) -> Doğrulamaya at
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                 return const DogrulamaEkrani();
              }

              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              final status = userData?['status'] ?? 'Unverified';
              final String userName = userData?['takmaAd'] ?? userData?['ad'] ?? 'Anonim'; 
              final String realName = userData?['ad'] ?? 'Anonim'; 

              // Admin ise veya Durumu 'Verified' ise -> Ana Ekran
              if (isAdministrator || status == 'Verified') {
                return AnaEkran(
                  isGuest: false,
                  isAdmin: isAdministrator, 
                  userName: userName, 
                  realName: realName, 
                ); 
              } else {
                // Değilse -> Doğrulama Ekranı (Bekleme Odası)
                return const DogrulamaEkrani(); 
              }
            }, 
          ); 
        } 

        // Giriş yapmamışsa -> Giriş Ekranı
        return const GirisEkrani(); 
      }, 
    );
  }
}

// Basit Yükleme Ekranı
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );
  }
}