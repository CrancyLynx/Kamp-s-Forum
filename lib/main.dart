import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:timeago/timeago.dart' as timeago;
// Native Splash Paketi
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Service & Utils
import 'services/auth_service.dart';
import 'services/push_notification_service.dart'; 
import 'services/presence_service.dart';
import 'services/welcome_service.dart';
import 'utils/app_colors.dart';
import 'utils/app_theme.dart'; // Tema dosyanız

// Providers
import 'providers/blocked_users_provider.dart';
import 'providers/gamification_provider.dart'; // YENİ EKLENDİ

// Widgets
import 'widgets/in_app_notification.dart'; 

// Screens
import 'screens/home/ana_ekran.dart'; 
import 'screens/auth/giris_ekrani.dart'; 
import 'screens/auth/verification_wrapper.dart'; 
import 'screens/auth/splash_screen.dart'; 

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHander(RemoteMessage message) async {
  await Firebase.initializeApp(); 
}

// Loglama sistemini yapılandır (Flogger uyarısını önlemek için)
void setupLogging() {
  // Firebase Analytics ve diğer sistemlerin loglarını kontrol et
  try {
    // Loglama seviyesini ayarla
    developer.log('Loglama sistemi başlatıldı', name: 'kampus_yardim.main');
  } catch (e) {
    debugPrint('Loglama yapılandırma hatası: $e');
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // Native Splash ekranını koru
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Loglama sistemini erken yapılandır (Flogger uyarısını önlemek için)
  // Bu, Firebase ve diğer kütüphanelerin loglama işlemlerini kontrol eder
  setupLogging();

  // Çevresel değişkenleri (.env) yükle
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("UYARI: .env dosyası bulunamadı veya yüklenemedi. API anahtarları çalışmayabilir.");
  }

  await initializeDateFormatting('tr_TR', null);
  await Firebase.initializeApp();
  
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHander); 
  
  Intl.defaultLocale = 'tr_TR'; 
  timeago.setLocaleMessages('tr', timeago.TrMessages());

  final prefs = await SharedPreferences.getInstance();
  
  ThemeMode initialThemeMode = ThemeMode.system; 
  try {
    final themeValue = prefs.get('themeMode');
    if (themeValue is int) {
      initialThemeMode = ThemeMode.values[themeValue];
    }
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider(initialThemeMode)),
        ChangeNotifierProvider(create: (context) => BlockedUsersProvider()),
        ChangeNotifierProvider(create: (context) => GamificationProvider()), // YENİ EKLENDİ
      ],
      child: const BizimUygulama(),
    ),
  );
}

class BizimUygulama extends StatelessWidget {
  const BizimUygulama({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kampüs Forum',
      navigatorKey: navigatorKey,
      
      // Merkezi Tema Kullanımı
      themeMode: context.watch<ThemeProvider>().themeMode,
      theme: AppTheme.lightTheme, 
      darkTheme: AppTheme.darkTheme,
      
      home: const AppLogic(),
    );
  }
}

class AppLogic extends StatefulWidget {
  const AppLogic({super.key});

  @override
  State<AppLogic> createState() => _AppLogicState();
}

class _AppLogicState extends State<AppLogic> {
  final PushNotificationService _notificationService = PushNotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();

    _notificationService.onMessage.listen((message) {
      if (message.notification != null) {
        _showInAppNotification(
          message.notification!.title ?? 'Bildirim',
          message.notification!.body ?? '',
        );
      }
    });
  }

  void _showInAppNotification(String title, String body) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        void removeOverlay() {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        }

        // Auto-dismiss after a delay
        Future.delayed(const Duration(seconds: 4), removeOverlay);

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -100, end: 0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: InAppNotification(
                    title: title,
                    body: body,
                    onTap: removeOverlay,
                    onDismiss: removeOverlay,
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

class AnaKontrolcu extends StatefulWidget {
  const AnaKontrolcu({super.key});
  @override
  State<AnaKontrolcu> createState() => _AnaKontrolcuState();
}

class _AnaKontrolcuState extends State<AnaKontrolcu> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSubscription;
  User? _currentUser;
  bool _authInitialized = false;

  void _showLoginPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                "Tüm Özellikler İçin Giriş Yapın",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "İlan vermek, konulara katılmak ve daha fazlası için bir hesabınız olmalı.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); 
                  AuthService().signOut(); 
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Giriş Yap veya Kayıt Ol"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    PresenceService().configure();
    
    final blockedUsersProvider = Provider.of<BlockedUsersProvider>(context, listen: false);
    final gamificationProvider = Provider.of<GamificationProvider>(context, listen: false); // YENİ EKLENDİ

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        if (!_authInitialized) _authInitialized = true;
      });

      if (user != null && !user.isAnonymous) {
        // Kullanıcı giriş yaptığında Gamification dinlemeyi başlat
        gamificationProvider.startListening(user.uid);
      }

      if (user == null || user.isAnonymous) {
        blockedUsersProvider.startListening(null);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
    ));

    if (!_authInitialized) {
      return const LoadingScreen();
    }
    
    final user = _currentUser;
    if (user != null) {
      if (user.isAnonymous) {
         return AnaEkran(
             isGuest: true,
             showLoginPrompt: () => _showLoginPrompt(context),
         );
      }

      if (!user.emailVerified && (user.phoneNumber == null || user.phoneNumber!.isEmpty)) {
        return const VerificationWrapper();
      }

      return _KullaniciVerisiYukleyici(user: user);
    } 

    return const GirisEkrani(); 
  }
}

class _KullaniciVerisiYukleyici extends StatefulWidget {
  final User user;
  const _KullaniciVerisiYukleyici({required this.user});

  @override
  State<_KullaniciVerisiYukleyici> createState() => _KullaniciVerisiYukleyiciState();
}

class _KullaniciVerisiYukleyiciState extends State<_KullaniciVerisiYukleyici> {
  late Stream<DocumentSnapshot> _userStream;
  late final BlockedUsersProvider _blockedUsersProvider;

  @override
  void initState() {
    super.initState();
    _blockedUsersProvider = Provider.of<BlockedUsersProvider>(context, listen: false);
    _blockedUsersProvider.startListening(widget.user.uid);
    _userStream = FirebaseFirestore.instance.collection('kullanicilar').doc(widget.user.uid).snapshots();
    
    // Hoşgeldin mesajını gönder
    _sendWelcomeMessages();
  }

  Future<void> _sendWelcomeMessages() async {
    try {
      // Sistem maskotu başlat
      await WelcomeService.initializeSystemUser();
      
      // Kullanıcının daha önce hoşgeldin almış olup olmadığını kontrol et
      final hasWelcome = await WelcomeService.hasReceivedWelcome(widget.user.uid);
      
      if (!hasWelcome) {
        // Hoşgeldin sohbetini gönder
        await WelcomeService.sendWelcomeMessage(widget.user.uid);
        
        // Hoşgeldin bildirimi gönder
        await WelcomeService.sendWelcomeNotification(widget.user.uid);
        
        debugPrint('[WELCOME] Yeni kullanıcı hoşgeldin mesajları başlatıldı');
      }
    } catch (e) {
      debugPrint('[WELCOME] Hoşgeldin mesaj hatası: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _KullaniciVerisiYukleyici oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _blockedUsersProvider.startListening(widget.user.uid);
      
      // Gamification için de güncelleme (opsiyonel, genelde AnaKontrolcu halleder)
      Provider.of<GamificationProvider>(context, listen: false).startListening(widget.user.uid);

      _userStream = FirebaseFirestore.instance.collection('kullanicilar').doc(widget.user.uid).snapshots();
    }
  }

  @override
  void dispose() {
    _blockedUsersProvider.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Uzgun_bay mascot with asset fallback
                  Image.asset(
                    'assets/images/uzgun_bay.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.error_outline, color: Colors.red, size: 50);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Veri yüklenirken hata oluştu 😢",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "Hata: ${userSnapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => AuthService().signOut(),
                    child: const Text("Çıkış Yap ve Tekrar Dene"),
                  )
                ],
              ),
            ),
          );
        }

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text("Profil hazırlanıyor..."),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => AuthService().signOut(), 
                    child: const Text("İptal Et ve Çıkış Yap")
                  )
                ],
              ),
            ),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final String userName = userData?['takmaAd'] ?? userData?['ad'] ?? 'Anonim'; 
        final String realName = userData?['ad'] ?? 'Anonim'; 
        final String role = userData?['role'] ?? 'user';
        final bool isAdministrator = (role == 'admin');

        return AnaEkran(isAdmin: isAdministrator, userName: userName, realName: realName);
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );
  }
}