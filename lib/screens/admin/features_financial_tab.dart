import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phase4FinancialTab extends StatefulWidget {
  const Phase4FinancialTab({Key? key}) : super(key: key);

  @override
  State<Phase4FinancialTab> createState() => _Phase4FinancialTabState();
}

class _Phase4FinancialTabState extends State<Phase4FinancialTab> {
  String _universityName = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
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
                  '💰 Mali Raporlar',
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
            const SizedBox(height: 24),

            // Filter Buttons
            SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterButton('all', 'Tümü'),
                    const SizedBox(width: 8),
                    _buildFilterButton('income', 'Gelir'),
                    const SizedBox(width: 8),
                    _buildFilterButton('expense', 'Gider'),
                    const SizedBox(width: 8),
                    _buildFilterButton('pending', 'Bekleme'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Summary Cards
            _buildSummaryCards(university),
            const SizedBox(height: 24),

            // Financial Records List
            Text(
              'Mali İşlemler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildFinancialRecordsList(university),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF4CAF50),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSummaryCards(String university) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('financial_records')
          .where('universityName', isEqualTo: university)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        double totalIncome = 0;
        double totalExpense = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final type = data['type'] as String? ?? 'transaction';

          if (type == 'income') {
            totalIncome += amount;
          } else if (type == 'expense') {
            totalExpense += amount;
          }
        }

        final netProfit = totalIncome - totalExpense;

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Toplam Gelir',
                amount: totalIncome,
                icon: Icons.trending_up,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Toplam Gider',
                amount: totalExpense,
                icon: Icons.trending_down,
                color: const Color(0xFFE74C3C),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Net Kar',
                amount: netProfit,
                icon: Icons.attach_money,
                color: netProfit >= 0 ? const Color(0xFF2196F3) : const Color(0xFFE74C3C),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              '₺${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRecordsList(String university) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('financial_records')
          .where('universityName', isEqualTo: university)
          .orderBy('recordedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('İşlem kaydı bulunmamaktadır'),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] as String? ?? 'transaction';

          if (_selectedFilter == 'all') return true;
          if (_selectedFilter == 'income') return type == 'income';
          if (_selectedFilter == 'expense') return type == 'expense';
          if (_selectedFilter == 'pending') return data['status'] == 'pending';
          return true;
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final type = data['type'] as String? ?? 'transaction';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final category = data['category'] as String? ?? 'Genel';
            final description = data['description'] as String? ?? 'Mali işlem';
            final status = data['status'] as String? ?? 'completed';
            final recordedAt = (data['recordedAt'] as Timestamp?)?.toDate();

            final isIncome = type == 'income';
            final color = isIncome ? const Color(0xFF4CAF50) : const Color(0xFFE74C3C);
            final icon = isIncome ? Icons.add_circle : Icons.remove_circle;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(icon, color: color),
                title: Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          recordedAt != null ? '${recordedAt.day}/${recordedAt.month}/${recordedAt.year}' : 'Tarihi yok',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: status == 'pending' ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status == 'pending' ? 'Bekleme' : 'Tamamlandı',
                            style: TextStyle(
                              fontSize: 11,
                              color: status == 'pending' ? Colors.orange : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Text(
                  '${isIncome ? '+' : '-'}₺${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
