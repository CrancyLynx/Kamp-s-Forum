import 'package:flutter/material.dart';

/// Sınav takvimi ekranı
class ExamCalendarScreen extends StatefulWidget {
  const ExamCalendarScreen({super.key});

  @override
  State<ExamCalendarScreen> createState() => _ExamCalendarScreenState();
}

class _ExamCalendarScreenState extends State<ExamCalendarScreen> {
  final List<Map<String, dynamic>> exams = [
    {
      'subject': 'Matematik',
      'date': '2025-12-15',
      'time': '09:00',
      'location': 'A Blok - 101',
      'duration': 120,
      'quota': 45,
    },
    {
      'subject': 'Fizik',
      'date': '2025-12-16',
      'time': '14:00',
      'location': 'B Blok - 205',
      'duration': 90,
      'quota': 50,
    },
    {
      'subject': 'Kimya',
      'date': '2025-12-17',
      'time': '10:30',
      'location': 'C Blok - 301',
      'duration': 120,
      'quota': 40,
    },
    {
      'subject': 'Programlama',
      'date': '2025-12-18',
      'time': '15:30',
      'location': 'Lab - Bilgisayar Lab',
      'duration': 180,
      'quota': 30,
    },
  ];

  String _selectedFilter = 'Tümü';

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedFilter == 'Tümü'
        ? exams
        : exams
            .where((e) {
              final examDate = DateTime.parse(e['date']);
              final now = DateTime.now();
              if (_selectedFilter == 'Geçmiş') {
                return examDate.isBefore(now);
              } else if (_selectedFilter == 'Yaklaşan') {
                return examDate.isAfter(now);
              }
              return true;
            })
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınav Takvimi'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['Tümü', 'Yaklaşan', 'Geçmiş']
                  .map((filter) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: filter == _selectedFilter,
                          onSelected: (v) {
                            if (v) setState(() => _selectedFilter = filter);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final exam = filtered[idx];
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
                            Text(
                              exam['subject'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Chip(
                              label: Text('${exam['duration']}min'),
                              backgroundColor: Colors.blue[100],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildExamInfo(
                          Icons.calendar_today,
                          '${exam['date']} ${exam['time']}',
                        ),
                        const SizedBox(height: 8),
                        _buildExamInfo(
                          Icons.location_on,
                          exam['location'],
                        ),
                        const SizedBox(height: 8),
                        _buildExamInfo(
                          Icons.people,
                          'Kontenjan: ${exam['quota']}',
                        ),
                      ],
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

  Widget _buildExamInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}
