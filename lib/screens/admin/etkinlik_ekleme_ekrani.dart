import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; 
import '../../utils/app_colors.dart';
import '../../services/image_compression_service.dart'; // Sıkıştırma servisi

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

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      
      if (pickedFile != null) {
        File original = File(pickedFile.path);
        // Servis üzerinden sıkıştırma
        File? compressed = await ImageCompressionService.compressImage(original);
        
        if (mounted) {
          setState(() {
            _selectedImage = compressed ?? original;
          });
        }
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<String?> _uploadImage() async {
    // Yeni resim seçilmediyse mevcut URL'yi (varsa) koru
    if (_selectedImage == null) return _currentImageUrl;
    
    try {
      final String fileName = 'events/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putFile(_selectedImage!);
      return await storageRef.getDownloadURL();
    } catch (_) { return null; }
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
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context, 
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          );
        }
      );
      
      if (time != null && mounted) {
         setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      }
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tarih ve saat seçin."), backgroundColor: AppColors.warning));
      return;
    }

    setState(() => _isLoading = true);
    
    final String? finalImageUrl = await _uploadImage();

    // Mevcut katılımcıları koru (Düzenleme moduysa)
    final List currentAttendees = _isEditing 
        ? ((widget.event!.data() as Map<String, dynamic>)['attendees'] ?? []) 
        : [];

    final eventData = {
      'title': _titleController.text.trim(),
      'location': _locationController.text.trim(),
      'description': _descriptionController.text.trim(), 
      'date': Timestamp.fromDate(_selectedDate!),
      'imageUrl': finalImageUrl ?? '', 
      'attendees': currentAttendees,
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('etkinlikler').doc(widget.event!.id).update(eventData);
      } else {
        await FirebaseFirestore.instance.collection('etkinlikler').add({
          ...eventData, 
          'createdAt': FieldValue.serverTimestamp()
        });
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Etkinlik kaydedildi!"), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: AppColors.error));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Etkinliği Düzenle" : "Yeni Etkinlik"), 
        backgroundColor: AppColors.primary, 
        foregroundColor: Colors.white
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Görsel Alanı
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    image: _selectedImage != null 
                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                        : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                            ? DecorationImage(image: CachedNetworkImageProvider(_currentImageUrl!), fit: BoxFit.cover) 
                            : null)
                  ),
                  child: (_selectedImage == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty)) 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey), 
                            SizedBox(height: 8), 
                            Text("Kapak Fotoğrafı Ekle")
                          ]
                        ) 
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              
              _buildModernInput(controller: _titleController, label: "Başlık", icon: Icons.title),
              const SizedBox(height: 16),
              _buildModernInput(controller: _locationController, label: "Konum", icon: Icons.location_on),
              const SizedBox(height: 16),
              _buildModernInput(controller: _descriptionController, label: "Açıklama", icon: Icons.description, maxLines: 4),
              const SizedBox(height: 20),
              
              // Tarih Seçici Butonu
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    border: Border.all(color: Colors.grey.withOpacity(0.2))
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                        child: const Icon(Icons.calendar_today, color: AppColors.primary)
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _selectedDate == null 
                            ? "Tarih ve Saat Seç" 
                            : DateFormat('dd MMM yyyy, HH:mm', 'tr').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w500,
                          color: _selectedDate == null ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color
                        )
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("Kaydet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent, // Container rengini kullanır
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (v) => v!.trim().isEmpty ? "Bu alan gerekli" : null,
      ),
    );
  }
}