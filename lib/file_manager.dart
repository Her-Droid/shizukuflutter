import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

const platform = MethodChannel('file_access');

/// 🔄 Fungsi untuk memindahkan file di iOS
Future<void> moveFileIOS(String fileName) async {
  Directory directory = await getApplicationDocumentsDirectory();
  String sourcePath = "${directory.path}/$fileName";
  String destinationPath = "${directory.path}/backup/$fileName";

  File sourceFile = File(sourcePath);
  if (await sourceFile.exists()) {
    await sourceFile.rename(destinationPath);
    print("✅ File berhasil dipindahkan ke: $destinationPath");
  } else {
    print("❌ File tidak ditemukan!");
  }
}

/// 📂 Mendapatkan path direktori penyimpanan di iOS
Future<String?> getAppDocumentsPath() async {
  try {
    final String? path = await platform.invokeMethod('getAppDocumentsPath');
    return path;
  } on PlatformException catch (e) {
    print("Error: ${e.message}");
    return null;
  }
}
