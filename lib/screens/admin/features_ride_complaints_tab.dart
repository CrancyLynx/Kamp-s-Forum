import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/advanced_features_models.dart';
    import '../../services/advanced_features_services.dart';class Phase4RideComplaintsTab extends StatefulWidget {
  const Phase4RideComplaintsTab({Key? key}) : super(key: key);

  @override
  State<Phase4RideComplaintsTab> createState() => _Phase4RideComplaintsTabState();
}

class _Phase4RideComplaintsTabState extends State<Phase4RideComplaintsTab> {
  late Phase4Services _services;
  String _selectedCategory = 'all';
  String _universityName = '';

  final List<String> _categories = [
    'all',
    'speeding',
    'reckless',
    'safety_issue',
    'behavior',
    'other'
  ];

  final Map<String, String> _categoryLabels = {
    'all': 'Tümü',
    'speeding': 'Hız Yapma',
    'reckless': 'Tehlikeli Sürüş',
    'safety_issue': 'Güvenlik Sorunu',
    'behavior': 'Davranış',
    'other': 'Diğer'
  };

  @override
  void initState() {
    super.initState();
    _services = Phase4Services();
    _loadUserUniversity();
  }

  Future<void> _loadUserUniversity() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        setState(() {
          _universityName = doc['universitesi'] ?? 'Belirsiz';
        });
      }
    } catch (e) {
      debugPrint('Üniversite yüklenemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final university = _universityName.isEmpty ? 'Yükleniyor...' : _universityName;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🚗 Sürüş Şikayetleri',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    university,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Filter
            SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_categoryLabels[category] ?? ''),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected ? category : 'all';
                          });
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: Colors.red[300],
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Complaints List
            StreamBuilder<List<RideComplaint>>(
              stream: _services.getRideComplaintsByUniversity(university),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.mood, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Şikayet bulunmamaktadır',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                var complaints = snapshot.data!;
                if (_selectedCategory != 'all') {
                  complaints = complaints
                      .where((c) => c.category == _selectedCategory)
                      .toList();
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: complaints.length,
                  itemBuilder: (context, index) {
                    final complaint = complaints[index];
                    return _buildComplaintCard(context, complaint);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard(BuildContext context, RideComplaint complaint) {
    final severityColors = [
      Colors.green,
      Colors.yellow[600] ?? Colors.yellow,
      Colors.orange,
      Colors.red[400] ?? Colors.red,
      Colors.red[700] ?? Colors.red,
    ];
    final severityColor = severityColors[complaint.severity - 1];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.driverName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        complaint.complainantName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ciddiyet: ${complaint.severity}/5',
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _categoryLabels[complaint.category] ?? complaint.category,
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(complaint.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusLabel(complaint.status),
                    style: TextStyle(
                      color: _getStatusColor(complaint.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              complaint.description,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Witness Count & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${complaint.witnessIds.length} Şahit',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  _formatDate(complaint.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'investigating':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'investigating':
        return 'İnceleniyor';
      case 'resolved':
        return 'Çözüldü';
      case 'dismissed':
        return 'Reddedildi';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inHours < 1) {
      return '${diff.inMinutes} dakika önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}
