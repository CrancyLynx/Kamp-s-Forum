// lib/screens/features_security_alerts_screen.dart
import 'package:flutter/material.dart';
import '../models/advanced_features_models.dart';
import '../services/advanced_features_services.dart';

class SecurityAlertsScreen extends StatefulWidget {
  const SecurityAlertsScreen({Key? key}) : super(key: key);

  @override
  State<SecurityAlertsScreen> createState() => _SecurityAlertsScreenState();
}

class _SecurityAlertsScreenState extends State<SecurityAlertsScreen> {
  final SecurityAlertService _alertService = SecurityAlertService();
  List<SecurityAlert> _alerts = [];
  bool _isLoading = true;
  String _selectedFilter = 'Hepsi';

  final List<String> _filters = ['Hepsi', 'Çözülmemiş', 'Kritik', 'Yüksek', 'Orta', 'Düşük'];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    
    List<SecurityAlert> alerts;
    if (_selectedFilter == 'Hepsi') {
      alerts = [];
    } else if (_selectedFilter == 'Çözülmemiş') {
      alerts = await _alertService.getUnresolvedAlerts();
    } else {
      alerts = await _alertService.getAlertsBySeverity(_selectedFilter.toLowerCase());
    }
    
    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _getSeverityTurkish(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Kritik';
      case 'high':
        return 'Yüksek';
      case 'medium':
        return 'Orta';
      case 'low':
        return 'Düşük';
      default:
        return severity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvenlik Uyarıları'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                        _loadAlerts();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Alerts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _alerts.isEmpty
                    ? const Center(child: Text('Uyarı bulunamadı'))
                    : RefreshIndicator(
                        onRefresh: _loadAlerts,
                        child: ListView.builder(
                          itemCount: _alerts.length,
                          itemBuilder: (context, index) {
                            final alert = _alerts[index];
                            return _buildAlertCard(alert);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(SecurityAlert alert) {
    final Color severityColor = _getSeverityColor(alert.severity);
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.warning,
                      color: severityColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.alertType,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _getSeverityTurkish(alert.severity),
                        style: TextStyle(color: severityColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alert.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (alert.suspiciousActivityDetails != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  alert.suspiciousActivityDetails!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  alert.detectedAt.toString().substring(0, 16),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!alert.isResolved)
                  ElevatedButton.icon(
                    onPressed: () {
                      _showResolveDialog(alert);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Çöz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  Chip(
                    label: const Text('Çözüldü'),
                    backgroundColor: Colors.green.shade100,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(SecurityAlert alert) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uyarıyı Çöz'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            hintText: 'Çözüm notları (opsiyonel)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              _alertService.resolveAlert(alert.id, notesController.text);
              Navigator.pop(context);
              _loadAlerts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uyarı çözüldü')),
              );
            },
            child: const Text('Çöz'),
          ),
        ],
      ),
    );
  }
}
