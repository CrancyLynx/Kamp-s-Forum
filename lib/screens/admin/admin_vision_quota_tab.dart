// lib/screens/admin/admin_vision_quota_tab.dart
import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/admin_services.dart';

class VisionQuotaTab extends StatefulWidget {
  const VisionQuotaTab({Key? key}) : super(key: key);

  @override
  State<VisionQuotaTab> createState() => _VisionQuotaTabState();
}

class _VisionQuotaTabState extends State<VisionQuotaTab> {
  final VisionQuotaService _quotaService = VisionQuotaService();
  VisionQuota? _userQuota;
  bool _isLoading = true;
  final _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userIdController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _loadQuota() async {
    if (_userIdController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    final quota = await _quotaService.getUserQuota(_userIdController.text);
    setState(() {
      _userQuota = quota;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision API Kotası Yönetimi'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Search
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(
                  hintText: 'Kullanıcı ID',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _loadQuota,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Quota Display
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_userQuota == null)
                const Center(child: Text('Kota bilgisi bulunamadı'))
              else
                _buildQuotaDisplay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotaDisplay() {
    final quota = _userQuota!;
    final percentage = (quota.usedThisMonth / quota.monthlyLimit * 100).clamp(0, 100);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quota Progress
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aylık Kota Kullanımı',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${quota.usedThisMonth} / ${quota.monthlyLimit}'),
                    Text('${percentage.toStringAsFixed(1)}%'),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Stats
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        quota.remainingQuota.toString(),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text('Kalan Kota'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        quota.usageHistory.length.toString(),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text('Toplam Kullanım'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Reset Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _quotaService.resetMonthlyQuota(quota.userId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kota sıfırlandı')),
              );
              _loadQuota();
            },
            child: const Text('Aylık Kotayı Sıfırla'),
          ),
        ),
      ],
    );
  }
}
