import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageCompressionService {
  // Resmi sıkıştırıp File olarak döndüren fonksiyon
  static Future<File?> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = tempDir.path;
      final fileName = p.basename(file.path);
      final targetPath = '$path/compressed_$fileName';

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Kaliteyi %70'e düşür (gözle görülür fark az, boyut çok düşer)
        minWidth: 1024, // Maksimum genişlik 1024px
        minHeight: 1024,
      );

      if (result != null) {
        return File(result.path);
      }
      return file; // Sıkıştırma başarısızsa orijinali döndür
    } catch (e) {
      print("Sıkıştırma hatası: $e");
      return file;
    }
  }
}