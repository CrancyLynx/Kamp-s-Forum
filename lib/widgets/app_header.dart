import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Uygulama genelinde kullanılan modern ve senkronize AppBar widget'ı
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final bool showLogo;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final VoidCallback? onLeadingPressed;
  final double elevation;
  final Color? backgroundColor;
  final TextStyle? titleStyle;

  const AppHeader({
    super.key,
    required this.title,
    this.centerTitle = true,
    this.showLogo = true,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.onLeadingPressed,
    this.elevation = 2,
    this.backgroundColor,
    this.titleStyle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      title: Row(
        children: [
          // Logo/İkon
          if (showLogo) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Başlık
          Expanded(
            child: Text(
              title,
              style: titleStyle ?? TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: centerTitle,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      elevation: elevation,
      backgroundColor: backgroundColor ?? 
        (isDarkMode ? Colors.grey[900] : Colors.white),
      foregroundColor: isDarkMode ? Colors.white : Colors.black87,
      surfaceTintColor: Colors.transparent,
      // Modern görünüm için bottom border
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDarkMode 
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
          height: 1,
        ),
      ),
    );
  }
}

/// Özel başlık kısımları için minimalista header
class SimpleAppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;

  const SimpleAppHeader({
    super.key,
    required this.title,
    this.actions,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.primary,
        ),
        onPressed: onBackPressed ?? () => Navigator.pop(context),
      ),
      actions: actions,
      elevation: 0,
      backgroundColor: isDarkMode 
        ? Colors.grey[900]
        : Colors.white,
      foregroundColor: isDarkMode ? Colors.white : Colors.black87,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDarkMode 
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
          height: 1,
        ),
      ),
    );
  }
}

/// Panel header'ları için özel tasarım (Forum, Pazar, Keşfet vb.)
class PanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget? trailing;

  const PanelHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    this.accentColor = AppColors.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.1),
            accentColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient fade çizgisi yerine
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 25,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accentColor.withOpacity(0.05),
                    accentColor.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              // İkon container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Başlık ve alt başlık
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode 
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              // Trailing widget
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
