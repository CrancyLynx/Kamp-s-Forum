import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _imageUrlController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.event!.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _locationController.text = data['location'] ?? '';
      _imageUrlController.text = data['imageUrl'] ?? '';
      _selectedDate = (data['date'] as Timestamp?)?.toDate();
    }
  }


  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _imageUrlController.dispose();
    super.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun ve bir tarih seçin."), backgroundColor: AppColors.warning));
      return;
    }

    setState(() => _isLoading = true);
    
    final eventData = {
      'title': _titleController.text.trim(),
      'location': _locationController.text.trim(),
      'imageUrl': _imageUrlController.text.trim(),
      'date': Timestamp.fromDate(_selectedDate!),
    };

    try {
      if (_isEditing) {
        // Düzenleme
        await FirebaseFirestore.instance
            .collection('etkinlikler')
            .doc(widget.event!.id)
            .update(eventData);
      } else {
        // Ekleme
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
              _buildModernInput(
                controller: _titleController, 
                label: "Etkinlik Başlığı", 
                icon: Icons.title
              ),
              const SizedBox(height: 16),
              _buildModernInput(
                controller: _locationController, 
                label: "Yer/Konum (Örn: Konferans Salonu)", 
                icon: Icons.location_on_outlined
              ),
              const SizedBox(height: 16),
              _buildModernInput(
                controller: _imageUrlController, 
                label: "Resim URL'si (Opsiyonel)", 
                icon: Icons.image_outlined
              ),
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

              if (_selectedDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Seçilen Tarih: ${DateFormat('dd.MM.yyyy').format(_selectedDate!)}", 
                    style: const TextStyle(fontSize: 12, color: AppColors.greyText)
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

  Widget _buildModernInput({required TextEditingController controller, required String label, required IconData icon, bool isOptional = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
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