import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Hata Mesajlarını Türkçeleştirme
  String _handleError(Object e) {
    String msg = e.toString();
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found': return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
        case 'wrong-password': return 'Hatalı şifre.';
        case 'email-already-in-use': return 'Bu e-posta zaten kullanımda.';
        case 'invalid-email': return 'Geçersiz e-posta formatı.';
        case 'too-many-requests': return 'Çok fazla deneme yaptınız. Lütfen bekleyin.';
        case 'network-request-failed': return 'İnternet bağlantınızı kontrol edin.';
        case 'requires-recent-login': return 'Güvenlik gereği bu işlem için tekrar giriş yapmalısınız.';
        case 'credential-already-in-use': return 'Bu hesap bilgileri zaten kullanımda.';
        case 'permission-denied': return 'Erişim reddedildi. Yetkiniz yok.';
        default: return 'Bir hata oluştu: ${e.message}';
      }
    }
    return msg;
  }

  // --- 1. ŞİFRE SIFIRLAMA ---
  Future<String?> sendPasswordReset(String email) async {
    try {
      if (!email.contains('@')) return "Geçerli bir e-posta adresi girin.";
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 2. GİRİŞ YAPMA (MFA KONTROLLÜ) ---
  Future<String> signInWithEmail(String email, String password, bool rememberMe) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      if (rememberMe) {
        await _storage.write(key: 'saved_email', value: email);
      } else {
        await _storage.delete(key: 'saved_email');
      }

      // MFA Kontrolü
      final userDoc = await _firestore.collection('kullanicilar').doc(cred.user!.uid).get();
      final isTwoFactorEnabled = userDoc.data()?['isTwoFactorEnabled'] ?? false;

      if (isTwoFactorEnabled) {
        return "mfa_required";
      }

      return "success";
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 3. KAYIT OLMA ---
  Future<String?> register({
    required String email,
    required String password,
    required String adSoyad,
    required String takmaAd,
    required String phone,
  }) async {
    try {
      final lowerEmail = email.toLowerCase();
      if (!(lowerEmail.endsWith('.edu.tr') || lowerEmail.endsWith('.edu'))) {
        return "Sadece üniversite e-postası (.edu veya .edu.tr) ile kayıt olabilirsiniz.";
      }

      final checkNick = await _firestore.collection('kullanicilar').where('takmaAd', isEqualTo: takmaAd).limit(1).get();
      if (checkNick.docs.isNotEmpty) return "Bu takma ad zaten alınmış.";

      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;

      if (user != null) {
        await _createUserDocument(user, adSoyad, takmaAd, phone, email);
      }
      return null;
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- KULLANICI DOC OLUŞTURUCU ---
  Future<void> _createUserDocument(User user, String adSoyad, String takmaAd, String phone, String email) async {
    final adSoyadParts = adSoyad.split(' ');
    final sadeceAd = adSoyadParts.isNotEmpty ? adSoyadParts.first : '';
    
    await _firestore.collection('kullanicilar').doc(user.uid).set({
      'email': email,
      'phoneNumber': phone,
      'takmaAd': takmaAd,
      'ad': sadeceAd,
      'fullName': adSoyad,
      'kayit_tarihi': FieldValue.serverTimestamp(),
      'verified': false,
      'status': 'Unverified',
      'role': 'user',
      'isTwoFactorEnabled': false,
      'followerCount': 0,
      'followingCount': 0,
      'postCount': 0,
      'earnedBadges': [],
      'followers': [],
      'following': [],
      'savedPosts': []
    }, SetOptions(merge: true)); 
  }

  // --- 4. YENİDEN KİMLİK DOĞRULAMA ---
  Future<bool> reauthenticateUser(String password) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 5. TELEFON DOĞRULAMA (SMS) ---
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final user = _auth.currentUser;
        if (user != null) {
           try {
             await user.linkWithCredential(credential);
           } catch (_) {
             await user.reauthenticateWithCredential(credential);
           }
        } else {
           await _auth.signInWithCredential(credential);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          onError('Geçersiz telefon numarası.');
        } else {
          onError(_handleError(e));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // --- 6. TELEFON + ŞİFRE KONTROLÜ (GÜVENLİ) ---
  Future<String?> validatePhonePassword(String phone, String password) async {
    try {
      // DİKKAT: Firestore Rules'da "allow read: if true;" yoksa bu sorgu hata verir.
      // Güvenli çözüm için Cloud Function önerilir.
      final query = await _firestore.collection('kullanicilar').where('phoneNumber', isEqualTo: phone).limit(1).get();
      
      if (query.docs.isEmpty) return "Bu numara ile kayıtlı hesap bulunamadı.";
      
      final email = query.docs.first['email'];
      // Şifreyi doğrulamak için giriş yap
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      return null; // Başarılı
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Kullanıcıya özel hata mesajı
        return "Sistem Hatası: Veritabanı okuma izni yok. (Lütfen geliştirici ile iletişime geçin: Rule Permission)"; 
      }
      return _handleError(e);
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- 7. DİĞER YARDIMCILAR ---
  Future<String?> toggleMFA(bool enable) async {
    final user = _auth.currentUser;
    if (user == null) {
      return "Bu işlem için giriş yapmış olmalısınız.";
    }
    try {
      await _firestore.collection('kullanicilar').doc(user.uid).update({
        'isTwoFactorEnabled': enable,
      });
      return null;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<String?> signInGuest() async {
    try {
      await _auth.signInAnonymously();
      return null;
    } catch (e) { return _handleError(e); }
  }

  Future<String?> getSavedEmail() async {
    return await _storage.read(key: 'saved_email');
  }
}