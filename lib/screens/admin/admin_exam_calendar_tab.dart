// lib/screens/admin/admin_exam_calendar_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/admin_models.dart';
import '../../services/admin_services.dart';

class ExamCalendarTab extends StatefulWidget {
  const ExamCalendarTab({Key? key}) : super(key: key);

  @override
  State<ExamCalendarTab> createState() => _ExamCalendarTabState();
}

class _ExamCalendarTabState extends State<ExamCalendarTab> {
  final ExamCalendarService _examService = ExamCalendarService();
  List<ExamCalendar> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    final exams = await _examService.getUpcomingExams();
    setState(() {
      _exams = exams;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınav Takvimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exams.isEmpty
              ? const Center(child: Text('Yaklaşan sınav bulunamadı'))
              : ListView.builder(
                  itemCount: _exams.length,
                  itemBuilder: (context, index) {
                    final exam = _exams[index];
                    return _buildExamCard(exam);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExamDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExamCard(ExamCalendar exam) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exam.courseName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.code, size: 18),
                const SizedBox(width: 8),
                Text(exam.courseCode),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(exam.examDate)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${exam.building} - ${exam.classroom}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, size: 18),
                    const SizedBox(width: 8),
                    Text('${exam.duration} dakika'),
                  ],
                ),
                Chip(
                  label: Text(exam.instructorName),
                  avatar: const Icon(Icons.person, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sınav Ekle'),
        content: const Text('Yeni sınav ekleme özelliği yakında gelecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
