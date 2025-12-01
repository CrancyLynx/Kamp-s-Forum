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
  
  // Seçilen Değerler
  String? _selectedUniversity;
  String? _selectedDepartment;

  final GlobalKey _submitButtonKey = GlobalKey();
  bool _isSending = false;
  late Stream<DocumentSnapshot> _userStatusStream;
  
  @override
  void initState() {
    super.initState();
    
    // 1. Verileri Yükle
    UniversityService().loadData().then((_) {
      if(mounted) setState(() {}); // Yükleme bitince ekranı yenile
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _userStatusStream = FirebaseFirestore.instance.collection('kullanicilar').doc(userId).snapshots();
    }
    
    // Maskot Kodları
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
                      contents: [TargetContent(align: ContentAlign.bottom, builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Profilini Tamamla', description: 'Öğrenci olduğunu doğrulamamız için bilgilerini gir.', mascotAssetPath: 'assets/images/dedektif_bay.png'))])
                ]);
          });
        }
      }
    });
  }

  void _submitVerificationForm(String userId) async {
    if (_nameController.text.isEmpty || _surnameController.text.isEmpty || _ageController.text.isEmpty || _selectedUniversity == null || _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun ve listeden seçim yapın."), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isSending = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';
      
      String newStatus = 'Pending';
      bool isVerified = false;
      
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
        'universite': _selectedUniversity,
        'bolum': _selectedDepartment,
        'rejectionReason': null,
      });

      if (newStatus == 'Verified') {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Otomatik onaylandı!"), backgroundColor: AppColors.success));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bilgiler gönderildi. Yönetici onayı bekleniyor.")));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if(mounted) setState(() { _isSending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Öğrenci Profilini Tamamla"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, 
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStatusStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.hasError) return const Center(child: Text("Kullanıcı verisi alınamadı."));
          
          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
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
                const SizedBox(height: 10),
                const Text("Profilini oluşturmak için aşağıdaki bilgileri eksiksiz doldur.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                
                _buildTextField(_nameController, "İsim"),
                const SizedBox(height: 15),
                _buildTextField(_surnameController, "Soyisim"),
                const SizedBox(height: 15),
                _buildTextField(_ageController, "Yaş", isNumber: true),
                const SizedBox(height: 15),
                
                // 1. Üniversite Seçimi (Gelişmiş Autocomplete)
                _buildModernAutocomplete(
                  label: "Üniversite",
                  hint: "Üniversiteni ara...",
                  options: UniversityService().getUniversityNames(),
                  onSelected: (val) {
                    setState(() {
                      _selectedUniversity = val;
                      _selectedDepartment = null; // Üniversite değişince bölümü sıfırla
                    });
                  },
                  // HATA DÜZELTMESİ: Kullanıcı elle doğru yazarsa da kabul et
                  onChanged: (val) {
                    if (UniversityService().getUniversityNames().contains(val)) {
                      setState(() {
                        _selectedUniversity = val;
                        _selectedDepartment = null;
                      });
                    } else {
                      // Eşleşme bozulursa bölümü kilitle
                      if (_selectedUniversity != null) {
                        setState(() {
                          _selectedUniversity = null;
                          _selectedDepartment = null;
                        });
                      }
                    }
                  }
                ),

                const SizedBox(height: 15),

                // 2. Bölüm Seçimi (Gelişmiş Autocomplete)
                _buildModernAutocomplete(
                  label: "Bölüm",
                  hint: _selectedUniversity == null ? "Önce üniversite seçin" : "Bölümünü ara...",
                  enabled: _selectedUniversity != null,
                  options: _selectedUniversity != null ? UniversityService().getDepartmentsForUniversity(_selectedUniversity!) : [],
                  onSelected: (val) => setState(() => _selectedDepartment = val),
                  key: ValueKey(_selectedUniversity), // Üniversite değişince widget'ı yeniden oluştur
                ),

                const SizedBox(height: 30),

                _isSending
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        key: _submitButtonKey, 
                        onPressed: () => _submitVerificationForm(userId!),
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

  // --- MODERN AUTOCOMPLETE WIDGET ---
  Widget _buildModernAutocomplete({
    required String label, 
    required String hint,
    required List<String> options, 
    required Function(String) onSelected, 
    Function(String)? onChanged,
    bool enabled = true,
    Key? key
  }) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') return const Iterable<String>.empty();
            return options.where((String option) {
              // Türkçe karakter duyarlı basit arama
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            // onChanged listener ekle
            if (onChanged != null) {
               // Mevcut listenerları temizle (tekrar eklememek için)
               // Ancak basitlik adına burada inline builder içinde yeni bir listener eklemek yerine
               // controller'a bir kez listener eklemek daha doğru olurdu.
               // Pratik çözüm: onChanged'i TextField içinde kullanmak.
            }

            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              onChanged: onChanged,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: enabled ? Colors.white : Colors.grey[100],
                prefixIcon: Icon(
                  label == "Üniversite" ? Icons.school : Icons.book, 
                  color: enabled ? AppColors.primary : Colors.grey
                ),
                suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ),
            );
          },
          // --- MODERN LİSTE TASARIMI ---
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8.0, // Daha belirgin gölge
                color: Colors.transparent, // Container'ın rengini kullan
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 300), // Daha uzun liste
                  margin: const EdgeInsets.only(top: 8), // Textfield ile araya boşluk
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Text(
                              option,
                              style: const TextStyle(fontSize: 15, color: Colors.black87),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
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