import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:firebase_storage/firebase_storage.dart'; 
import '../../utils/app_colors.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../utils/maskot_helper.dart';

class AnketEklemeEkrani extends StatefulWidget {
  final String userName;
  const AnketEklemeEkrani({super.key, required this.userName});

  @override
  State<AnketEklemeEkrani> createState() => _AnketEklemeEkraniState();
}

class _AnketEklemeEkraniState extends State<AnketEklemeEkrani> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  
  final List<TextEditingController> _optionControllers = [TextEditingController(), TextEditingController()];
  // Her seçenek için bir resim dosyası tutacak liste
  final List<File?> _optionImages = [null, null]; 

  // --- Tanıtım için Global Key'ler ---
  final GlobalKey _questionKey = GlobalKey();
  final GlobalKey _firstOptionKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  void _addOption() {
    if (_optionControllers.length < 5) {
      setState(() {
        _optionControllers.add(TextEditingController());
        _optionImages.add(null);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("En fazla 5 seçenek ekleyebilirsiniz.")));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MaskotHelper.checkAndShow(
        context,
        featureKey: 'anket_ekleme_tutorial_gosterildi',
        targets: [
          TargetFocus(
            identify: "anket-sorusu",
            keyTarget: _questionKey,
            alignSkip: Alignment.bottomRight,
            contents: [
              TargetContent(
                  align: ContentAlign.bottom,
                  builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Ne Merak Ediyorsun?', description: 'Topluluğa sormak istediğin soruyu buraya yazarak anketini başlat.', mascotAssetPath: 'assets/images/düsünceli_bay.png'))
            ],
          ),
          TargetFocus(
            identify: "anket-secenekleri",
            keyTarget: _firstOptionKey,
            alignSkip: Alignment.bottomRight,
            contents: [
              TargetContent(align: ContentAlign.bottom, builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Seçenekleri Belirle', description: 'Anketine en az iki seçenek eklemelisin. İstersen yandaki ikona tıklayarak seçeneklere resim de ekleyebilirsin!', mascotAssetPath: 'assets/images/mutlu_bay.png'))
            ],
          ),
          TargetFocus(
            identify: "anket-paylas",
            keyTarget: _shareButtonKey,
            alignSkip: Alignment.bottomLeft,
            contents: [TargetContent(align: ContentAlign.bottom, builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Fikirleri Topla!', description: 'Hazır olduğunda anketini buradan paylaşarak topluluğun fikrini alabilirsin.', mascotAssetPath: 'assets/images/duyuru_bay.png'))],
          ),
        ],
      );
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers.removeAt(index);
        _optionImages.removeAt(index);
      });
    }
  }

  // Seçenek için resim seç
  Future<void> _pickOptionImage(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (pickedFile != null) {
        setState(() {
          _optionImages[index] = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
    }
  }

  void _removeOptionImage(int index) {
    setState(() {
      _optionImages[index] = null;
    });
  }

  Future<void> _createPoll() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_optionControllers.any((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm seçenekleri doldurun.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      List<Map<String, dynamic>> optionsData = [];

      // Her seçenek için döngü
      for (int i = 0; i < _optionControllers.length; i++) {
        String? imageUrl;
        
        // Resim varsa yükle
        if (_optionImages[i] != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final ref = FirebaseStorage.instance.ref().child('anket_resimleri/$userId-$timestamp-$i.jpg');
          await ref.putFile(_optionImages[i]!);
          imageUrl = await ref.getDownloadURL();
        }

        optionsData.add({
          'text': _optionControllers[i].text.trim(),
          'voteCount': 0,
          'imageUrl': imageUrl, // Varsa URL, yoksa null
        });
      }

      await FirebaseFirestore.instance.collection('gonderiler').add({
        'type': 'anket',
        'baslik': _questionController.text.trim(),
        'ad': widget.userName,
        'realUsername': widget.userName,
        'userId': userId,
        'avatarUrl': userData['avatarUrl'],
        'zaman': FieldValue.serverTimestamp(),
        'lastCommentTimestamp': FieldValue.serverTimestamp(),
        'options': optionsData,
        'voters': {}, 
        'totalVotes': 0,
        'kategori': 'Anket',
        'mesaj': '',
        'commentCount': 0,
        'likes': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anket oluşturuldu!"), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu."), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Anket Oluştur"),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge?.color),
        titleTextStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          _isLoading 
            ? const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
            : TextButton( // --- KEY EKLE ---
                key: _shareButtonKey,
                onPressed: _createPoll,
                child: const Text("Paylaş", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: _questionKey, // --- KEY EKLE ---
                controller: _questionController,
                maxLength: 100,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: "Anket Sorusu",
                  hintText: "Topluluğa ne sormak istersin?",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.poll, color: AppColors.primary),
                ),
                validator: (v) => v!.trim().isEmpty ? "Soru boş olamaz" : null,
              ),
              const SizedBox(height: 20),
              const Text("Seçenekler", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text("Opsiyonel olarak seçeneklere resim ekleyebilirsiniz.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              
              ...List.generate(_optionControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: KeyedSubtree(
                    // --- İLK ELEMANA KEY EKLE ---
                    key: index == 0 ? _firstOptionKey : null,
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                      // Resim Ekleme/Gösterme Alanı
                      GestureDetector(
                        onTap: () => _pickOptionImage(index),
                        child: Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                            image: _optionImages[index] != null 
                                ? DecorationImage(image: FileImage(_optionImages[index]!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _optionImages[index] == null 
                              ? const Icon(Icons.add_photo_alternate, color: Colors.grey, size: 24)
                              : Stack(
                                  children: [
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: () => _removeOptionImage(index),
                                        child: Container(
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                        ),
                      ),

                      // Metin Alanı
                      Expanded(
                        child: TextFormField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            hintText: "${index + 1}. Seçenek",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => v!.trim().isEmpty ? "Bu alan boş bırakılamaz" : null,
                        ),
                      ),
                      
                      // Silme Butonu (Sadece 2'den fazla seçenek varsa)
                      if (_optionControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeOption(index),
                        ),
                    ],
                  ),
                  ),
                );
              }),
              
              if (_optionControllers.length < 5)
                Padding(
                  padding: const EdgeInsets.only(left: 60), // Resim kutusu hizasına getirmek için
                  child: TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add),
                    label: const Text("Seçenek Ekle"),
                  ),
                ),
                
              const SizedBox(height: 50), // Alt boşluk
            ],
          ),
        ),
      ),
    );
  }
}