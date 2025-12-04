import 'package:flutter/material.dart';

/// Arşivlenen mesajlar ekranı
class MessageArchiveScreen extends StatefulWidget {
  const MessageArchiveScreen({super.key});

  @override
  State<MessageArchiveScreen> createState() => _MessageArchiveScreenState();
}

class _MessageArchiveScreenState extends State<MessageArchiveScreen> {
  final List<Map<String, dynamic>> archivedMessages = [
    {
      'sender': 'Ahmet K.',
      'text': 'Proje deadline ne zaman?',
      'date': '2025-12-10',
      'category': 'Proje',
    },
    {
      'sender': 'Ayşe S.',
      'text': 'Kütüphanede buluşalım mı?',
      'date': '2025-12-09',
      'category': 'Sosyal',
    },
    {
      'sender': 'Sistem',
      'text': 'Bildirim: Yeni duyuru eklendi',
      'date': '2025-12-08',
      'category': 'Bildirim',
    },
  ];

  String _selectedCategory = 'Tümü';

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == 'Tümü'
        ? archivedMessages
        : archivedMessages
            .where((m) => m['category'] == _selectedCategory)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arşiv'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['Tümü', 'Proje', 'Sosyal', 'Bildirim']
                  .map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: cat == _selectedCategory,
                        onSelected: (v) {
                          if (v) setState(() => _selectedCategory = cat);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Arşiv boş'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final msg = filtered[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(msg['sender']),
                          subtitle: Text(msg['text']),
                          trailing: Text(
                            msg['date'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
