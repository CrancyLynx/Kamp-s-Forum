import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// Modern arama çubuğu widget'ı
class ModernSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;

  const ModernSearchBar({
    super.key,
    required this.controller,
    required this.hint,
    this.onClear,
  });

  @override
  State<ModernSearchBar> createState() => _ModernSearchBarState();
}

class _ModernSearchBarState extends State<ModernSearchBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear?.call();
                    setState(() {});
                  },
                )
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}

/// İstatistik kartı widget'ı
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          Icon(icon, color: color, size: 30),
        ],
      ),
    );
  }
}

/// Boş durum widget'ı
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Silme onay dialog'u
void showDeleteConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required VoidCallback onDelete,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("İptal"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            Navigator.pop(ctx);
            onDelete();
          },
          child: const Text("Sil", style: TextStyle(color: Colors.white)),
        )
      ],
    ),
  );
}

/// Kullanıcı yönetim dialog'u
void showUserManagementDialog({
  required BuildContext context,
  required String userName,
  required VoidCallback onViewProfile,
  required VoidCallback onDelete,
}) {
  showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(userName),
      children: [
        SimpleDialogOption(
          child: const Text("Profili Görüntüle"),
          onPressed: () {
            Navigator.pop(ctx);
            onViewProfile();
          },
        ),
        SimpleDialogOption(
          child: const Text("Kullanıcıyı Sil (Kalıcı)", style: TextStyle(color: Colors.red)),
          onPressed: () {
            Navigator.pop(ctx);
            onDelete();
          },
        ),
      ],
    ),
  );
}

/// Red sebebi dialog'u
void showRejectReasonDialog({
  required BuildContext context,
  required Function(String reason) onReject,
}) {
  final reasonController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Red Sebebini Yazın"),
      content: TextField(
        controller: reasonController,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: "Red sebebini yazınız...",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("İptal"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onReject(reasonController.text);
          },
          child: const Text("Reddet", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

/// SnackBar göster
void showSnackBar({
  required BuildContext context,
  required String message,
  required Color color,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
