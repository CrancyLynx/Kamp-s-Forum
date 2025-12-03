import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';

class GonderiDuzenlemeEkrani extends StatefulWidget {
  final String postId;
  final String initialTitle;
  final String initialMessage;

  const GonderiDuzenlemeEkrani({
    super.key,
    required this.postId,
    required this.initialTitle,
    required this.initialMessage,
  });

  @override
  State<GonderiDuzenlemeEkrani> createState() => _GonderiDuzenlemeEkraniState();
}

class _GonderiDuzenlemeEkraniState extends State<GonderiDuzenlemeEkrani> {
  late TextEditingController _titleController;
  late TextEditingController _messageController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _messageController = TextEditingController(text: widget.initialMessage);
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        await FirebaseFirestore.instance.collection('gonderiler').doc(widget.postId).update({
          'baslik': _titleController.text.trim(),
          'mesaj': _messageController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gönderi başarıyla güncellendi."), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(); // Düzenleme ekranını kapat
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Güncelleme sırasında bir hata oluştu: $e")),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppHeader(
        title: 'Gönderiyi Düzenle',
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: AppColors.primary),
            onPressed: _isLoading ? null : _saveChanges,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: "Başlık", border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Başlık boş bırakılamaz.';
                          if (value.trim().length < 3) return 'Başlık en az 3 karakter olmalıdır.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(labelText: "Mesaj", border: OutlineInputBorder()),
                        maxLines: 8,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Mesaj boş bırakılamaz.';
                          if (value.trim().length < 5) return 'Mesaj en az 5 karakter olmalıdır.';
                          return null;
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
