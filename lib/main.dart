import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kampus_yardim_app/services/presence_service.dart';
import 'package:kampus_yardim_app/services/push_notification_service.dart'; 
import 'package:provider/provider.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:timeago/timeago.dart' as timeago;
// Native Splash Paketi Importu
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../utils/app_colors.dart';
import '../../services/auth_service.dart';

// Widgetlar
import 'widgets/in_app_notification.dart'; 

// Sayfalar
import 'screens/home/ana_ekran.dart'; 
import 'screens/auth/giris_ekrani.dart'; 
import 'screens/auth/verification_wrapper.dart'; 
// Onboarding importu
// import 'screens/auth/onboarding_screen.dart'; // Kullanılmıyorsa kaldırılabilir
import 'screens/auth/splash_screen.dart'; 

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHander(RemoteMessage message) async {
  await Firebase.initializeApp(); 
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

  bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

  runApp( 
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(initialThemeMode),
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
  OverlayEntry? _overlayEntry;

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
    _overlayEntry?.remove();
    _overlayEntry = null;
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
            tween: Tween(begin: -100, end: 0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: InAppNotification(
                  title: title,
                  body: body,
                  onTap: () => _overlayEntry?.remove(),
                  onDismiss: () => _overlayEntry?.remove(),
                ),
              );
            },
          ),
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);
    Future.delayed(const Duration(seconds: 4), () {
      if (_overlayEntry != null && _overlayEntry!.mounted) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
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
                  Navigator.of(context).pop(); // Paneli kapat
                  AuthService().signOut(); // Misafir oturumunu sonlandır ve giriş ekranına yönlendir
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
  }

  @override
  void dispose() {
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

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) { 
        // 1. Auth Durumu Bekleniyor
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        
        // 2. Kullanıcı Giriş Yapmışsa
        if (authSnapshot.hasData) {
          final user = authSnapshot.data!;
          
          if (user.isAnonymous) {
             return AnaEkran(
                 isGuest: true,
                 showLoginPrompt: () => _showLoginPrompt(context),
             );
          }

          if (!user.emailVerified && (user.phoneNumber == null || user.phoneNumber!.isEmpty)) {
            return const VerificationWrapper();
          }

          final userId = user.uid;

          // 3. Firestore Verisi
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').doc(userId).snapshots(),
            builder: (context, userSnapshot) { 
              if (userSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 50),
                        const SizedBox(height: 16),
                        const Text("Veri yüklenirken hata oluştu."),
                        Text("Hata: ${userSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

              // DÜZELTME: Statü kontrolü kaldırıldı. Doğrudan Ana Ekran'a yönlendiriliyor.
              return AnaEkran(isAdmin: isAdministrator, userName: userName, realName: realName);
            }, 
          ); 
        } 

        // 4. Kullanıcı Yoksa (Giriş Ekranı)
        return const GirisEkrani(); 
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