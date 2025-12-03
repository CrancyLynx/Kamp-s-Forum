import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_colors.dart';

/// Giriş ve Kayıt ekranlarında kullanılan modern metin giriş alanı.
class ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final dynamic iconData; // IconData veya FaIcon olabilir
  final bool isDark;
  final bool isPassword;
  final TextInputType inputType;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? prefixText;
  final int maxLines;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.iconData,
    required this.isDark,
    this.isPassword = false,
    this.inputType = TextInputType.text,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.prefixText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final Widget prefixIconWidget = iconData is IconData
        ? Icon(iconData, size: 20, color: AppColors.primary.withOpacity(0.7))
        : FaIcon(iconData, size: 20, color: AppColors.primary.withOpacity(0.7));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
          prefixIcon: prefixIconWidget,
          prefixText: prefixText,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          isDense: true,
        ),
      ),
    );
  }
}

/// Üniversite ve Bölüm seçimi gibi tıklanabilir seçim alanları.
class ModernSelectionField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;
  final IconData icon;

  const ModernSelectionField({
    super.key,
    required this.label,
    this.value,
    required this.hint,
    required this.enabled,
    required this.onTap,
    required this.isDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: enabled ? AppColors.primary.withOpacity(0.7) : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// Email/Telefon giriş modu değiştirme butonu.
class AuthToggleOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const AuthToggleOption({
    super.key,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey),
      ),
    );
  }
}