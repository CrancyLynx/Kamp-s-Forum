import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; 
import '../../utils/app_colors.dart';

class EtkinlikEklemeEkrani extends StatefulWidget {
  final DocumentSnapshot? event;

  const EtkinlikEklemeEkrani({super.key, this.event});

  @override
  State<EtkinlikEklemeEkrani> createState() => _EtkinlikEklemeEkraniState();
}

class _EtkinlikEklemeEkraniState extends State<EtkinlikEklemeEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _selectedDate;
  File? _selectedImage; 
  String? _currentImageUrl; 
  bool _isLoading = false;
  bool _isPickingImage = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.event!.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _locationController.text = data['location'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      // Kayıt linki kaldırıldığı için artık buradan çekmiyoruz.
      _currentImageUrl = data['imageUrl']; 
      _selectedDate = (data['date'] as Timestamp?)?.toDate();
    }
  }


  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  // Resim Seçme İşlemi
  Future<void> _pickImage() async {
    if (_isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          // Not: Artık URL controller'ı yok, sadece dosya/url tutuyoruz.
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Resim seçilemedi: $e"), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // Resim Yükleme İşlemi (Firebase Storage)
  Future<String?> _uploadImage() async {
    // 1. Yeni resim seçilmişse yükle
    if (_selectedImage != null) {
      try {
        final String fileName = 'events/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        
        final UploadTask uploadTask = storageRef.putFile(_selectedImage!);
        final TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Resim yüklenirken hata oluştu: $e"), backgroundColor: AppColors.error));
        }
        return null;
      }
    }
    // 2. Yeni resim yoksa, mevcut URL'yi döndür
    return _currentImageUrl;
  }
  

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary, 
              onPrimary: Colors.white, 
              onSurface: AppColors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm zorunlu alanları doldurun ve bir tarih seçin."), backgroundColor: AppColors.warning));
      return;
    }

    if (_selectedImage == null && _currentImageUrl == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir etkinlik resmi seçin."), backgroundColor: AppColors.warning));
       return;
    }

    setState(() => _isLoading = true);
    
    final String? finalImageUrl = await _uploadImage();

    if (finalImageUrl == null && (_selectedImage != null || _currentImageUrl == null)) {
      setState(() => _isLoading = false);
      return; 
    }

    // YENİ: registrationLink kaldırıldı
    final eventData = {
      'title': _titleController.text.trim(),
      'location': _locationController.text.trim(),
      'description': _descriptionController.text.trim(), 
      'date': Timestamp.fromDate(_selectedDate!),
      'imageUrl': finalImageUrl ?? '', 
      // attendees listesi ilk oluşturmada boş başlatılır, düzenlemede korunur.
      'attendees': _isEditing ? (widget.event!.data() as Map<String, dynamic>)['attendees'] ?? [] : [], 
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('etkinlikler')
            .doc(widget.event!.id)
            .update(eventData);
      } else {
        await FirebaseFirestore.instance.collection('etkinlikler').add({
          ...eventData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        final successMessage = _isEditing ? "Etkinlik başarıyla güncellendi!" : "Etkinlik başarıyla eklendi!";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: AppColors.success));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata oluştu: $e"), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Etkinliği Düzenle" : "Yeni Etkinlik Ekle"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSelector(), // Resim Seçici
              const SizedBox(height: 24),

              _buildModernInput(
                controller: _titleController, 
                label: "Etkinlik Başlığı", 
                icon: Icons.title
              ),
              const SizedBox(height: 16),
              _buildModernInput(
                controller: _descriptionController, 
                label: "Etkinlik Açıklaması", 
                icon: Icons.description_outlined,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildModernInput(
                controller: _locationController, 
                label: "Yer/Konum (Örn: Konferans Salonu)", 
                icon: Icons.location_on_outlined
              ),
              
              // Kayıt Linki Kaldırıldı.
              
              const SizedBox(height: 24),
              
              const Text("Etkinlik Tarihi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate == null 
                          ? "Bir tarih seçin" 
                          : DateFormat('dd MMMM yyyy, EEEE').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedDate == null ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),

              Center(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveEvent,
                  icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(_isEditing ? Icons.save : Icons.add, color: Colors.white),
                  label: Text(_isLoading ? "Kaydediliyor..." : "Etkinliği Kaydet", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Resim seçici widget'ı (Önceki adımdan taşındı/güncellendi)
  Widget _buildImageSelector() {
    final bool hasImage = _selectedImage != null || (_currentImageUrl != null && _currentImageUrl!.isNotEmpty);
    final String? displayUrl = _selectedImage != null ? null : _currentImageUrl;

    return Center(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: hasImage
                  ? (_selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: displayUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Center(child: Icon(Icons.image_not_supported, color: AppColors.error, size: 50)),
                        ))
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image, size: 50, color: AppColors.primary),
                          const SizedBox(height: 8),
                          Text("Etkinlik Afişi", style: TextStyle(color: AppColors.primary.withOpacity(0.8))),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text("Galeriden Seç"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_selectedImage != null || _currentImageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.delete_forever, color: AppColors.error),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _currentImageUrl = null;
                      });
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildModernInput({required TextEditingController controller, required String label, required IconData icon, bool isOptional = false, int maxLines = 1, bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Theme.of(context).cardColor : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          disabledBorder: InputBorder.none,
        ),
        validator: (v) {
          if (v!.trim().isEmpty && !isOptional) {
            return "$label boş olamaz";
          }
          return null;
        },
      ),
    );
  }
}