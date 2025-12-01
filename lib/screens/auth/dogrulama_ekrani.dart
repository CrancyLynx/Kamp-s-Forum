import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kampus_yardim_app/main.dart';
import '../../utils/app_colors.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../utils/maskot_helper.dart';
import '../../services/university_service.dart';

class DogrulamaEkrani extends StatefulWidget {
  const DogrulamaEkrani({super.key}); 
  
  @override
  _DogrulamaEkraniState createState() => _DogrulamaEkraniState();
}

class _DogrulamaEkraniState extends State<DogrulamaEkrani> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  
  String? _selectedUniversity;
  String? _selectedDepartment;

  final GlobalKey _submitButtonKey = GlobalKey();
  bool _isSending = false;
  late Stream<DocumentSnapshot> _userStatusStream;
  
  @override
  void initState() {
    super.initState();
    // Veriyi yükle ve ekranı tazele
    UniversityService().loadData().then((_) {
      if(mounted) setState(() {});
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _userStatusStream = FirebaseFirestore.instance.collection('kullanicilar').doc(userId).snapshots();
    }

    // Maskot Tanıtımı
    _userStatusStream.first.then((snapshot) {
      if (mounted) {
        final userData = snapshot.data() as Map<String, dynamic>?;
        final status = userData?['status'] ?? 'Unverified';
        if (status == 'Unverified') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            MaskotHelper.checkAndShow(context,
                featureKey: 'dogrulama_tutorial_gosterildi',
                targets: [
                  TargetFocus(
                      identify: "submit-button",
                      keyTarget: _submitButtonKey,
                      contents: [TargetContent(align: ContentAlign.bottom, builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Profilini Tamamla', description: 'Öğrenci olduğunu doğrulamamız gerekiyor.', mascotAssetPath: 'assets/images/dedektif_bay.png'))])
                ]);
          });
        }
      }
    });
  }

  void _submitVerificationForm(String userId) async {
    if (_nameController.text.isEmpty || _surnameController.text.isEmpty || _ageController.text.isEmpty || _selectedUniversity == null || _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun."), backgroundColor: Colors.orange));
      return;
    }

    setState(() { _isSending = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';
      
      String newStatus = 'Pending';
      bool isVerified = false;
      
      // .edu.tr kontrolü
      if (user != null && user.emailVerified && (email.endsWith('.edu.tr') || email.endsWith('.edu'))) {
        newStatus = 'Verified';
        isVerified = true;
      }
      
      await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).update({
        'status': newStatus, 
        'verified': isVerified,
        'submissionData': {
          'name': _nameController.text,
          'surname': _surnameController.text,
          'age': int.tryParse(_ageController.text) ?? 0,
          'university': _selectedUniversity, 
          'department': _selectedDepartment, 
        },
        // Profil bilgilerini de doğrudan güncelle
        'universite': _selectedUniversity,
        'bolum': _selectedDepartment,
        'rejectionReason': null,
      });

      if (newStatus == 'Verified') {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Otomatik onaylandı!"), backgroundColor: AppColors.success));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bilgiler gönderildi. Onay bekleniyor.")));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if(mounted) setState(() { _isSending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilini Tamamla"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, 
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStatusStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final status = userData['status'] ?? 'Unverified';

          if (status == 'Verified') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AnaKontrolcu()), (route) => false);
            });
            return const Center(child: CircularProgressIndicator());
          } else if (status == 'Pending') {
            return _buildStatusView(Icons.hourglass_top, Colors.orange, "Onay Bekleniyor", "Bilgilerin inceleniyor.");
          } else if (status == 'Rejected') {
            return _buildStatusView(Icons.cancel, Colors.red, "Başvuru Reddedildi", userData['rejectionReason'] ?? 'Sebep yok.', isRejected: true);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Son Bir Adım!", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 30),
                
                _buildTextField(_nameController, "İsim"),
                const SizedBox(height: 15),
                _buildTextField(_surnameController, "Soyisim"),
                const SizedBox(height: 15),
                _buildTextField(_ageController, "Yaş", isNumber: true),
                const SizedBox(height: 15),
                
                // Üniversite Seçimi
                _buildAutocomplete(
                  label: "Üniversite",
                  options: UniversityService().getUniversityNames(),
                  onSelected: (val) {
                    setState(() {
                      _selectedUniversity = val;
                      _selectedDepartment = null;
                    });
                  },
                ),
                const SizedBox(height: 15),

                // Bölüm Seçimi
                _buildAutocomplete(
                  label: "Bölüm",
                  enabled: _selectedUniversity != null,
                  options: _selectedUniversity != null ? UniversityService().getDepartmentsForUniversity(_selectedUniversity!) : [],
                  onSelected: (val) => setState(() => _selectedDepartment = val),
                  key: ValueKey(_selectedUniversity),
                ),

                const SizedBox(height: 30),

                _isSending
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        key: _submitButtonKey, 
                        onPressed: () => _submitVerificationForm(FirebaseAuth.instance.currentUser!.uid),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text("Kaydet ve Gönder", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                const SizedBox(height: 20),
                TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text("Çıkış Yap")),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
    );
  }

  Widget _buildAutocomplete({required String label, required List<String> options, required Function(String) onSelected, bool enabled = true, Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        return Autocomplete<String>(
          optionsBuilder: (textValue) {
            if (textValue.text == '') return const Iterable<String>.empty();
            return options.where((opt) => opt.toLowerCase().contains(textValue.text.toLowerCase()));
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            if (!enabled && controller.text.isNotEmpty) controller.clear();
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              decoration: InputDecoration(
                labelText: label,
                hintText: enabled ? "Yazmaya başla..." : "Önce üniversite seçin",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: enabled ? Colors.white : Colors.grey[200],
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 250),
                  color: Colors.white,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(title: Text(option), onTap: () => onSelected(option));
                    },
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildStatusView(IconData icon, Color color, String title, String msg, {bool isRejected = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 40),
            if (isRejected)
              ElevatedButton(
                onPressed: () => FirebaseFirestore.instance.collection('kullanicilar').doc(FirebaseAuth.instance.currentUser!.uid).update({'status': 'Unverified'}),
                child: const Text("Tekrar Dene"),
              ),
            const SizedBox(height: 20),
            TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text("Çıkış Yap")),
          ],
        ),
      ),
    );
  }
}