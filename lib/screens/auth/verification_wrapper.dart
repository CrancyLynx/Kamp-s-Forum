import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../services/auth_service.dart';
import '../../main.dart'; 

class VerificationWrapper extends StatefulWidget {
  const VerificationWrapper({super.key});

  @override
  State<VerificationWrapper> createState() => _VerificationWrapperState();
}

class _VerificationWrapperState extends State<VerificationWrapper> {
  int _currentStep = 0; 
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? emailTimer;

  final TextEditingController _phoneController = TextEditingController(text: '+90');
  final TextEditingController _smsCodeController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    checkStatus();
  }

  @override
  void dispose() {
    emailTimer?.cancel();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  Future<void> checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.reload(); 
      if (!mounted) return;

      setState(() {
        isEmailVerified = user.emailVerified;
      });
      
      if (isEmailVerified || (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)) {
        emailTimer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AnaKontrolcu()),
        );
      }
    } catch (e) {
      debugPrint("Bağlantı hatası (önemsiz): $e");
    }
  }

  void startEmailVerification() async {
    setState(() => _currentStep = 1);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
      
      emailTimer = Timer.periodic(const Duration(seconds: 3), (_) => checkStatus());
      
      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 60));
      if (mounted) setState(() => canResendEmail = true);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  void startPhoneVerification() {
    setState(() => _currentStep = 2);
  }

  Future<void> sendSmsCode() async {
    var phone = _phoneController.text.trim();
    
    // ✅ Telefon validasyonu
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Telefon numarası boş olamaz.")),
      );
      return;
    }
    
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen geçerli bir telefon numarası girin (+90...)")),
      );
      return;
    }
    
    // Numara formatla
    if (!phone.startsWith('+')) {
       if (phone.startsWith('0')) phone = phone.substring(1);
       phone = '+90$phone';
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await linkPhoneCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Doğrulama Hatası: ${e.message}")));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _currentStep = 3; 
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
           if (mounted) setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  Future<void> verifySmsCode() async {
    final code = _smsCodeController.text.trim();
    
    // ✅ Code validasyonu
    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SMS kodunu tam olarak girin (6 hane).")),
      );
      return;
    }
    
    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Doğrulama ID'si kayboldu. Lütfen tekrar başlayın.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await linkPhoneCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String errorMsg = "Hatalı kod.";
      if (e.code == 'invalid-verification-code') {
        errorMsg = "SMS kodu yanlış. Lütfen kontrol edin.";
      } else if (e.code == 'session-expired') {
        errorMsg = "Doğrulama süresi doldu. Lütfen yeniden başlayın.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    }
  }

  Future<void> linkPhoneCredential(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.linkWithCredential(credential);
        await checkStatus();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (e.code == 'credential-already-in-use') {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu numara zaten kayıtlı. Lütfen çıkış yapıp telefonla giriş yapın.")));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.message}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppHeader(
        title: 'Hesap Doğrulama',
        actions: FirebaseAuth.instance.currentUser != null
            ? [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => AuthService().signOut(),
                  tooltip: "Cıkış Yap",
                )
              ]
            : null,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case 0:
        return Column(
          children: [
            const Icon(Icons.verified_user_outlined, size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              "Doğrulama Yöntemi Seçin",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Hesabınızı güvene almak için lütfen bir yöntem seçin.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildSelectionCard(
              icon: Icons.email_outlined,
              title: "E-posta ile Doğrula",
              subtitle: "Ücretsiz • Otomatik Öğrenci Onayı\n(.edu.tr mailine link gönderilir)",
              color: Colors.blue.shade50,
              onTap: startEmailVerification,
            ),
            const SizedBox(height: 20),
            _buildSelectionCard(
              icon: Icons.phone_android_outlined,
              title: "SMS ile Doğrula",
              subtitle: "Hızlı • Yönetici Onayı Gerekir\n(Telefonunuza kod gönderilir)",
              color: Colors.orange.shade50,
              onTap: startPhoneVerification,
            ),
          ],
        );

      case 1: 
        return Column(
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text("E-posta Gönderildi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "${FirebaseAuth.instance.currentUser?.email} adresine gelen linke tıklayın. Bekleniyor...",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: canResendEmail ? startEmailVerification : null,
              child: const Text("Tekrar Gönder"),
            ),
            TextButton(
              onPressed: () => setState(() { _currentStep = 0; emailTimer?.cancel(); }),
              child: const Text("Yöntem Değiştir"),
            ),
          ],
        );

      case 2:
        return Column(
          children: [
            const Icon(Icons.sms_outlined, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text("Telefon Numaranız", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Telefon (Örn: 555...)",
                hintText: "5XXXXXXXXX",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator() else ElevatedButton(
              onPressed: sendSmsCode,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text("Kod Gönder"),
            ),
            TextButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text("Vazgeç"),
            ),
          ],
        );

      case 3:
        return Column(
          children: [
            const Icon(Icons.lock_clock_outlined, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text("SMS Kodunu Girin", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _smsCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: "000000",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator() else ElevatedButton(
              onPressed: verifySmsCode,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text("Doğrula"),
            ),
            TextButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: const Text("Numarayı Düzenle"),
            ),
          ],
        );
        
      default:
        return Container();
    }
  }

  Widget _buildSelectionCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.black87),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}