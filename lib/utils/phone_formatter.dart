import 'package:flutter/services.dart';

/// Türkçe telefon numarası formatı: +90XXXXXXXXXX
class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Sadece +90 ile başlayan rakamlar kabul edilecek
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // +90 olmadan başlamışsa ekle
    if (!text.startsWith('+90')) {
      // + ile başlıyorsa
      if (text.startsWith('+')) {
        return oldValue; // değişikliği reddet
      }
      // Rakam ile başlıyorsa
      if (text[0].contains(RegExp(r'[0-9]'))) {
        // Eğer eski değer boşsa, +90 ekle
        if (oldValue.text.isEmpty || oldValue.text == '') {
          return newValue.copyWith(
            text: '+90$text',
            selection: TextSelection.collapsed(offset: '+90$text'.length),
          );
        }
      }
    }

    // Sadece rakamlar +90 sonrası
    String digits = text.replaceAll(RegExp(r'[^\d+]'), '');

    // +90 başını kontrol et
    if (!digits.startsWith('+90')) {
      // + ile başlıyorsa ama 90 değilse
      if (digits.startsWith('+')) {
        digits = digits.substring(1);
      }
      // 90 ile başlıyorsa + ekle
      if (digits.startsWith('90')) {
        digits = '+' + digits;
      }
      // Diğer hallerde +90 ekle
      else if (digits.isNotEmpty && !digits.startsWith('+')) {
        digits = '+90' + digits;
      }
    }

    // 13 karakteri (örn: +905551234567) aş
    if (digits.length > 13) {
      digits = digits.substring(0, 13);
    }

    return newValue.copyWith(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
