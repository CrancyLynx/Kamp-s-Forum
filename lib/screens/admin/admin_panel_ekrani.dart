import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import 'admin_notification_tab.dart';
import 'admin_requests_tab.dart';
import 'admin_users_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_ring_moderation_tab.dart';
import 'admin_statistics_tab.dart';
import 'etkinlik_listesi_ekrani.dart';
import '../admin/audit_log_viewer_screen.dart';
import '../vision/vision_quota_monitor_screen.dart';
import '../admin/system_bot_screen.dart';

class AdminPanelEkrani extends StatefulWidget {
  const AdminPanelEkrani({super.key});

  @override
  State<AdminPanelEkrani> createState() => _AdminPanelEkraniState();
}

class _AdminPanelEkraniState extends State<AdminPanelEkrani> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isLoadingAuth = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _tabController = TabController(length: 10, vsync: this);
  }

  Future<void> _checkAdminAccess() async {
    if (_currentUserId.isEmpty) {
      if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(_currentUserId).get();
      if (doc.exists) {
        final role = doc.data()?['role'];
        if (mounted) setState(() { _isAdmin = (role == 'admin'); _isLoadingAuth = false; });
      } else {
        if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
      }
    } catch (e) {
      debugPrint("❌ Admin yetki hatası: $e");
      if (mounted) setState(() { _isAdmin = false; _isLoadingAuth = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.gpp_bad_outlined, size: 80, color: AppColors.error),
              SizedBox(height: 16),
              Text(
                "🔒 Erişim Reddedildi",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "Bu sayfayı görüntülemek için yönetici yetkisine sahip olmalısınız.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.greyText),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text(
              "Yönetim Paneli",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: const Color(0xFF2C3E50), // Dark slate-blue
            centerTitle: false,
            pinned: true,
            floating: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                  onPressed: () {},
                  tooltip: "Yönetici Ayarları",
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF00BCD4), // Cyan accent
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: const Color(0xFF00BCD4),
              unselectedLabelColor: Colors.grey[400],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.notifications_active_rounded, size: 20), text: "Bildirim"),
                Tab(icon: Icon(Icons.change_circle_rounded, size: 20), text: "Talepler"),
                Tab(icon: Icon(Icons.group_rounded, size: 20), text: "Kullanıcılar"),
                Tab(icon: Icon(Icons.report_problem_rounded, size: 20), text: "Şikayetler"),
                Tab(icon: Icon(Icons.event_note_rounded, size: 20), text: "Etkinlikler"),
                Tab(icon: Icon(Icons.directions_bus_rounded, size: 20), text: "Ring Modü"),
                Tab(icon: Icon(Icons.bar_chart_rounded, size: 20), text: "İstatistik"),
                Tab(icon: Icon(Icons.history_rounded, size: 20), text: "Denetim Günü"),
                Tab(icon: Icon(Icons.trending_up_rounded, size: 20), text: "API Kontenjanı"),
                Tab(icon: Icon(Icons.smart_toy_rounded, size: 20), text: "Sistem Botları"),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            const AdminNotificationTab(),
            const AdminRequestsTab(),
            const AdminUsersTab(),
            const AdminReportsTab(),
            const EtkinlikListesiEkrani(),
            const AdminRingModerationTab(),
            const AdminStatisticsTab(),
            const AuditLogViewerScreen(),
            const VisionQuotaMonitorScreen(),
            const SystemBotScreen(),
          ],
        ),
      ),
    );
  }
}
