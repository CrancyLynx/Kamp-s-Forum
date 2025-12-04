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
import 'phase3_audit_log_tab.dart';
import 'phase3_api_quota_tab.dart';
import 'phase3_error_logs_tab.dart';
import 'phase3_feedback_tab.dart';
import 'phase3_photo_approval_tab.dart';
import 'phase3_system_bots_tab.dart';

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
    // 7 existing + 8 Phase 3 + 7 Phase 4 = 22 tabs total
    _tabController = TabController(length: 22, vsync: this);
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
                // Phase 3 Tabs (8 total)
                Tab(icon: Icon(Icons.history_rounded, size: 20), text: "Denetim Günü"),
                Tab(icon: Icon(Icons.trending_up_rounded, size: 20), text: "API Kontenjanı"),
                Tab(icon: Icon(Icons.bug_report_rounded, size: 20), text: "Hata Raporları"),
                Tab(icon: Icon(Icons.feedback_rounded, size: 20), text: "Geri Bildirim"),
                Tab(icon: Icon(Icons.check_circle_rounded, size: 20), text: "Fotoğraf Onayı"),
                Tab(icon: Icon(Icons.smart_toy_rounded, size: 20), text: "Sistem Botları"),
                Tab(icon: Icon(Icons.lock_rounded, size: 20), text: "Engellenenler"),
                Tab(icon: Icon(Icons.warning_rounded, size: 20), text: "İleri Moderasyon"),
                // Phase 4 Tabs (7 total)
                Tab(icon: Icon(Icons.directions_run_rounded, size: 20), text: "Ride Şikayetleri"),
                Tab(icon: Icon(Icons.grade_rounded, size: 20), text: "Puan Sistemi"),
                Tab(icon: Icon(Icons.emoji_events_rounded, size: 20), text: "Başarılar"),
                Tab(icon: Icon(Icons.card_giftcard_rounded, size: 20), text: "Ödüller"),
                Tab(icon: Icon(Icons.search_rounded, size: 20), text: "Arama Analiz"),
                Tab(icon: Icon(Icons.auto_awesome_rounded, size: 20), text: "AI İstatistik"),
                Tab(icon: Icon(Icons.monetization_on_rounded, size: 20), text: "Finansal Rapor"),
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
            // Phase 3 Real Tabs
            const Phase3AuditLogTab(),
            const Phase3ApiQuotaTab(),
            const Phase3ErrorLogsTab(),
            const Phase3FeedbackTab(),
            const Phase3PhotoApprovalTab(),
            const Phase3SystemBotsTab(),
            _buildPlaceholderTab("🔒 Engellenenler", "Engellenen kullanıcılar listesi"),
            _buildPlaceholderTab("⚠️ İleri Moderasyon", "Uyarı, mute, ban, timeout"),
            // Phase 4 Placeholder Tabs
            _buildPlaceholderTab("🚗 Ride Şikayetleri", "Sürüş güvenliği şikayetleri"),
            _buildPlaceholderTab("⭐ Puan Sistemi", "Kullanıcı puan ve seviye yönetimi"),
            _buildPlaceholderTab("🏆 Başarılar", "Başarı rozeti ve ilerleme takibi"),
            _buildPlaceholderTab("🎁 Ödüller", "Ödül dağıtımı ve riward sistemi"),
            _buildPlaceholderTab("🔍 Arama Analiz", "Popüler aramalar ve trendler"),
            _buildPlaceholderTab("🤖 AI İstatistik", "Yapay zeka model metrikleri"),
            _buildPlaceholderTab("💰 Finansal Rapor", "Gelir ve masraf analizi"),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, String description) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction_rounded, size: 100, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Yakında Kullanılabilir"),
          ),
        ],
      ),
    );
  }
}
