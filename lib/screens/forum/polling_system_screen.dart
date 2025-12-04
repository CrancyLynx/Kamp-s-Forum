import 'package:flutter/material.dart';

/// Anket sistemi ekranı
class PollingSystemScreen extends StatefulWidget {
  const PollingSystemScreen({super.key});

  @override
  State<PollingSystemScreen> createState() => _PollingSystemScreenState();
}

class _PollingSystemScreenState extends State<PollingSystemScreen> {
  final List<Map<String, dynamic>> polls = [
    {
      'question': 'En sevdiğiniz forum kategorisi nedir?',
      'options': [
        {'text': 'Akademik', 'votes': 125},
        {'text': 'Sosyal', 'votes': 89},
        {'text': 'Etkinlik', 'votes': 67},
        {'text': 'Diğer', 'votes': 43},
      ],
      'totalVotes': 324,
      'status': 'Açık',
    },
    {
      'question': 'Kampüs haritasını kullanıyor musunuz?',
      'options': [
        {'text': 'Evet, sık sık', 'votes': 156},
        {'text': 'Bazen', 'votes': 98},
        {'text': 'Hiç kullanmadım', 'votes': 42},
      ],
      'totalVotes': 296,
      'status': 'Kapalı',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anketler'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: polls.length,
        itemBuilder: (ctx, idx) {
          final poll = polls[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          poll['question'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(poll['status']),
                        backgroundColor: poll['status'] == 'Açık'
                            ? Colors.green
                            : Colors.grey,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...(poll['options'] as List).asMap().entries.map((entry) {
                    final option = entry.value;
                    final percent =
                        (option['votes'] as int) / (poll['totalVotes'] as int);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(option['text']),
                              Text('${option['votes']} oy'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue[300]!,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(percent * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  Text(
                    'Toplam: ${poll['totalVotes']} oy',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
