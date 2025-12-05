import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';

// Phase 1 - Tabs
import 'admin_notification_tab.dart';
import 'admin_requests_tab.dart';
import 'admin_users_tab.dart';
import 'admin_reports_tab.dart';
import 'etkinlik_listesi_ekrani.dart';
import 'admin_ring_moderation_tab.dart';
import 'admin_statistics_tab.dart';

// Admin System Tabs (formerly Phase 3)
import 'admin_audit_log_tab.dart';
import 'admin_api_quota_tab.dart';
import 'admin_error_logs_tab.dart';
import 'admin_feedback_tab.dart';
import 'admin_photo_approval_tab.dart';
import 'admin_system_bots_tab.dart';
import 'admin_blocked_users_tab.dart';
import 'admin_moderation_logs_tab.dart';

// Advanced Features Tabs (formerly Phase 4)
import 'features_ride_complaints_tab.dart';
import 'features_scoring_tab.dart';
import 'features_achievements_tab.dart';
import 'features_rewards_tab.dart';
import 'features_search_analytics_tab.dart';
import 'features_ai_stats_tab.dart';
import 'features_financial_tab.dart';

class AdminPanelHomeEkrani extends StatefulWidget {
  const AdminPanelHomeEkrani({super.key});

  @override
  State<AdminPanelHomeEkrani> createState() => _AdminPanelHomeEkraniState();
}

class _AdminPanelHomeEkraniState extends State<AdminPanelHomeEkrani> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isLoadingAuth = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    if (_currentUserId.isEmpty) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _isLoadingAuth = false;
        });
      }
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(_currentUserId)
          .get();
      if (doc.exists) {
        final role = doc.data()?['role'];
        if (mounted) {
          setState(() {
            _isAdmin = (role == 'admin');
            _isLoadingAuth = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _isLoadingAuth = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Admin yetki hatası: $e");
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _isLoadingAuth = false;
        });
      }
    }
  }

  void _navigateToTab(Widget screen, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminTabScaffold(
          title: title,
          child: screen,
        ),
      ),
    );
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Yönetim Paneli",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        centerTitle: false,
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
              icon: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.white),
              onPressed: () {},
              tooltip: "Yönetici Ayarları",
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase 1 - Temel Yönetim
            _buildSectionTitle("📋 Temel Yönetim"),
            _buildAdminGrid([
              _AdminCard(
                icon: Icons.notifications_active_rounded,
                title: "Bildirim",
                subtitle: "Kullanıcı bildirimleri",
                color: const Color(0xFFFF6B6B),
                onTap: () => _navigateToTab(
                  const AdminNotificationTab(),
                  "Bildirimler",
                ),
              ),
              _AdminCard(
                icon: Icons.change_circle_rounded,
                title: "Talepler",
                subtitle: "Kullanıcı talepleri",
                color: const Color(0xFF4ECDC4),
                onTap: () => _navigateToTab(
                  const AdminRequestsTab(),
                  "Talepler",
                ),
              ),
              _AdminCard(
                icon: Icons.group_rounded,
                title: "Kullanıcılar",
                subtitle: "Kullanıcı yönetimi",
                color: const Color(0xFF45B7D1),
                onTap: () => _navigateToTab(
                  const AdminUsersTab(),
                  "Kullanıcılar",
                ),
              ),
              _AdminCard(
                icon: Icons.report_problem_rounded,
                title: "İçerik Şikayetleri",
                subtitle: "Uygunsuz içerik bildirimleri",
                color: const Color(0xFFFFA502),
                onTap: () => _navigateToTab(
                  const AdminReportsTab(),
                  "İçerik Şikayetleri",
                ),
              ),
            ]),
            const SizedBox(height: 32),

            // Phase 2 - Sistem Yönetimi
            _buildSectionTitle("🎯 Sistem Yönetimi"),
            _buildAdminGrid([
              _AdminCard(
                icon: Icons.event_note_rounded,
                title: "Etkinlikler",
                subtitle: "Etkinlik yönetimi",
                color: const Color(0xFF6C5CE7),
                onTap: () => _navigateToTab(
                  const EtkinlikListesiEkrani(),
                  "Etkinlikler",
                ),
              ),
              _AdminCard(
                icon: Icons.directions_bus_rounded,
                title: "Ring Modü",
                subtitle: "Ring sefer yönetimi",
                color: const Color(0xFF00B894),
                onTap: () => _navigateToTab(
                  const AdminRingModerationTab(),
                  "Ring Moderasyonu",
                ),
              ),
              _AdminCard(
                icon: Icons.bar_chart_rounded,
                title: "İstatistik",
                subtitle: "Sistem istatistikleri",
                color: const Color(0xFFBD3B73),
                onTap: () => _navigateToTab(
                  const AdminStatisticsTab(),
                  "İstatistikler",
                ),
              ),
            ]),
            const SizedBox(height: 32),

            // Phase 3 - Gelişmiş Yönetim
            _buildSectionTitle("⚙️ Gelişmiş Yönetim"),
            _buildAdminGrid([
              _AdminCard(
                icon: Icons.history_rounded,
                title: "Denetim Günü",
                subtitle: "İşlem logları",
                color: const Color(0xFF1E90FF),
                onTap: () => _navigateToTab(
                  const Phase3AuditLogTab(),
                  "Denetim Günü",
                ),
              ),
              _AdminCard(
                icon: Icons.trending_up_rounded,
                title: "API Kontenjanı",
                subtitle: "API kullanım takibi",
                color: const Color(0xFF32CD32),
                onTap: () => _navigateToTab(
                  const Phase3ApiQuotaTab(),
                  "API Kontenjanı",
                ),
              ),
              _AdminCard(
                icon: Icons.bug_report_rounded,
                title: "Hata Raporları",
                subtitle: "Sistem hataları",
                color: const Color(0xFFDC143C),
                onTap: () => _navigateToTab(
                  const Phase3ErrorLogsTab(),
                  "Hata Raporları",
                ),
              ),
              _AdminCard(
                icon: Icons.feedback_rounded,
                title: "Geri Bildirim",
                subtitle: "Kullanıcı geri bildirimi",
                color: const Color(0xFFFFD700),
                onTap: () => _navigateToTab(
                  const Phase3FeedbackTab(),
                  "Geri Bildirim",
                ),
              ),
              _AdminCard(
                icon: Icons.check_circle_rounded,
                title: "Fotoğraf Onayı",
                subtitle: "Ring fotoğraf onayı",
                color: const Color(0xFF9370DB),
                onTap: () => _navigateToTab(
                  const Phase3PhotoApprovalTab(),
                  "Fotoğraf Onayı",
                ),
              ),
              _AdminCard(
                icon: Icons.smart_toy_rounded,
                title: "Sistem Botları",
                subtitle: "Bot yönetimi",
                color: const Color(0xFF20B2AA),
                onTap: () => _navigateToTab(
                  const Phase3SystemBotsTab(),
                  "Sistem Botları",
                ),
              ),
              _AdminCard(
                icon: Icons.lock_rounded,
                title: "Engellenenler",
                subtitle: "Engellenen kullanıcılar",
                color: const Color(0xFFFF4500),
                onTap: () => _navigateToTab(
                  const Phase3BlockedUsersTab(),
                  "Engellenenler",
                ),
              ),
              _AdminCard(
                icon: Icons.warning_rounded,
                title: "İleri Moderasyon",
                subtitle: "Uyarı, mute, ban, timeout",
                color: const Color(0xFFB22222),
                onTap: () => _navigateToTab(
                  const ModerationLogsTab(),
                  "İleri Moderasyon",
                ),
              ),
            ]),
            const SizedBox(height: 32),

            // Phase 4 - İleri Özellikler
            _buildSectionTitle("🚀 İleri Özellikler"),
            _buildAdminGrid([
              _AdminCard(
                icon: Icons.directions_run_rounded,
                title: "Ride Şikayetleri",
                subtitle: "Sürüş güvenliği",
                color: const Color(0xFF2F4F4F),
                onTap: () => _navigateToPhase4(
                  "Ride Şikayetleri",
                  const Phase4RideComplaintsTab(),
                ),
              ),
              _AdminCard(
                icon: Icons.grade_rounded,
                title: "Puan Sistemi",
                subtitle: "Kullanıcı puan yönetimi",
                color: const Color(0xFF4169E1),
                onTap: () => _navigateToPhase4(
                  "Puan Sistemi",
                  const Phase4ScoringTab(),
                ),
              ),
              _AdminCard(
                icon: Icons.emoji_events_rounded,
                title: "Başarılar",
                subtitle: "Başarı rozeti yönetimi",
                color: const Color(0xFFFF8C00),
                onTap: () => _navigateToPhase4(
                  "Başarılar",
                  const Phase4AchievementsTab(),
                ),
              ),
              _AdminCard(
                icon: Icons.card_giftcard_rounded,
                title: "Ödüller",
                subtitle: "Ödül dağıtımı",
                color: const Color(0xFF228B22),
                onTap: () => _navigateToPhase4(
                  "Ödüller",
                  const Phase4RewardsTab(),
                ),
              ),
              _AdminCard(
                icon: Icons.search_rounded,
                title: "Arama Analiz",
                subtitle: "Popüler aramalar",
                color: const Color(0xFF8B008B),
                onTap: () => _navigateToPhase4(
                  "Arama Analiz",
                  const Phase4SearchAnalyticsTab(),
                ),
              ),
              _AdminCard(
                icon: Icons.auto_awesome_rounded,
                title: "AI İstatistik",
                subtitle: "Model metrikleri",
                color: const Color(0xFF00CED1),
                onTap: () => _navigateToPhase4(
                  'AI İstatistikleri',
                  const Phase4AiStatsTab(),
                ),
              ),
              _AdminCard(
                icon: Icons.monetization_on_rounded,
                title: "Finansal Rapor",
                subtitle: "Gelir analizi",
                color: const Color(0xFF2E8B57),
                onTap: () => _navigateToPhase4(
                  "Finansal Rapor",
                  const Phase4FinancialTab(),
                ),
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigateToPhase4(String title, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminTabScaffold(
          title: title,
          child: screen,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2C3E50),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAdminGrid(List<_AdminCard> cards) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🚀 $title - Yakında aktif olacak"),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _AdminCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<_AdminCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.05).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withOpacity(0.8),
                  widget.color.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper Scaffold - Her tab'ın kendi AppBar'ı olacak
class AdminTabScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const AdminTabScaffold({
    required this.title,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: child,
    );
  }
}
