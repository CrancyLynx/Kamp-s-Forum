import 'package:flutter/material.dart';

/// Sistem botu yönetimi ekranı
class SystemBotScreen extends StatefulWidget {
  const SystemBotScreen({super.key});

  @override
  State<SystemBotScreen> createState() => _SystemBotScreenState();
}

class _SystemBotScreenState extends State<SystemBotScreen> {
  final List<Map<String, dynamic>> bots = [
    {
      'name': 'WelcomeBot',
      'description': 'Yeni üyeleri karşılar',
      'status': 'Aktif',
      'commands': 5,
      'lastRun': '2 saat önce',
    },
    {
      'name': 'ModeratorBot',
      'description': 'Otomatik moderasyon işlemleri',
      'status': 'Aktif',
      'commands': 12,
      'lastRun': '30 dakika önce',
    },
    {
      'name': 'NotificationBot',
      'description': 'Bildirimleri gönderir',
      'status': 'Pasif',
      'commands': 8,
      'lastRun': 'Hiç çalışmadı',
    },
    {
      'name': 'StatisticsBot',
      'description': 'İstatistik toplar',
      'status': 'Aktif',
      'commands': 6,
      'lastRun': '1 saat önce',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem Botları'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: bots.length,
        itemBuilder: (ctx, idx) {
          final bot = bots[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bot['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bot['description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(bot['status']),
                        backgroundColor: bot['status'] == 'Aktif'
                            ? Colors.green
                            : Colors.grey,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBotInfo('Komutlar', bot['commands'].toString()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBotInfo('Son Çalışma', bot['lastRun']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${bot['name']} konfigüre edildi')),
                            );
                          },
                          child: const Text('Yapılandır'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${bot['name']} çalıştırıldı')),
                            );
                          },
                          child: const Text('Çalıştır'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBotInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
