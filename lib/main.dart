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

// Servisler
import 'services/push_notification_service.dart'; 
import 'services/presence_service.dart'; 

// Widgetlar
import 'widgets/in_app_notification.dart'; 

// Sayfalar
import 'screens/auth/dogrulama_ekrani.dart';
import 'screens/home/ana_ekran.dart'; 
import 'screens/auth/giris_ekrani.dart'; 
import 'screens/auth/verification_wrapper.dart'; 
// Onboarding importu
import 'screens/auth/onboarding_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHander(RemoteMessage message) async {
  await Firebase.initializeApp(); 
  print("Arka planda bir mesaj işleniyor: ${message.messageId}");
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
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  await Firebase.initializeApp();
  
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHander); 
  
  Intl.defaultLocale = 'tr_TR'; 
  
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
      child: BizimUygulama(isFirstTime: isFirstTime),
    ),
  );
}

class BizimUygulama extends StatefulWidget {
  final bool isFirstTime;
  const BizimUygulama({super.key, required this.isFirstTime});
  @override
  State<BizimUygulama> createState() => _BizimUygulamaState();
}

class _BizimUygulamaState extends State<BizimUygulama> {
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
        top: 0, left: 0, right: 0,
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
     home: const AnaKontrolcu(),
    );
  }
}

class AnaKontrolcu extends StatefulWidget {
  const AnaKontrolcu({super.key});
  @override
  State<AnaKontrolcu> createState() => _AnaKontrolcuState();
}

class _AnaKontrolcuState extends State<AnaKontrolcu> {
  @override
  void initState() {
    super.initState();
    PresenceService().configure();
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
             return const AnaEkran(isGuest: true, isAdmin: false, userName: 'Misafir', realName: 'Misafir');
          }

          if (!user.emailVerified && (user.phoneNumber == null || user.phoneNumber!.isEmpty)) {
            return const VerificationWrapper();
          }

          final userId = user.uid;

          // 3. Firestore Verisi
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').doc(userId).snapshots(),
            builder: (context, userSnapshot) { 
              // HATA YÖNETİMİ EKLENDİ: Hata varsa otomatik çıkış yapma, hata göster
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
                          onPressed: () => FirebaseAuth.instance.signOut(),
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
              
              // DÜZELTME: Veri hemen gelmezse Loading göster, direkt çıkış yapma!
              // Eğer bağlantı aktifse ve veri YOKSA (null veya !exists), o zaman profil yok demektir.
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
                         // Uzun sürerse çıkış butonu
                         TextButton(
                           onPressed: () => FirebaseAuth.instance.signOut(), 
                           child: const Text("İptal Et ve Çıkış Yap")
                         )
                       ],
                     ),
                   ),
                 );
              }

              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              final status = userData?['status'] ?? 'Unverified';
              final String userName = userData?['takmaAd'] ?? userData?['ad'] ?? 'Anonim'; 
              final String realName = userData?['ad'] ?? 'Anonim'; 
              final String role = userData?['role'] ?? 'user';
              final bool isAdministrator = (role == 'admin');

              if (isAdministrator || status == 'Verified') {
                return AnaEkran(
                  isGuest: false,
                  isAdmin: isAdministrator, 
                  userName: userName, 
                  realName: realName, 
                ); 
              } else {
                return const DogrulamaEkrani(); 
              }
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