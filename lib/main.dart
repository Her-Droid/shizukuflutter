import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shizuku_api/shizuku_api.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:shizukuflutter/file_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true);
  FlutterDownloader.registerCallback(DownloadManager.downloadCallback);
  runApp(MyApp());
}

class DownloadManager {
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    print("📥 Download Progress ($id): $progress%");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String fileName = "logo.zip";
  final String fileUrl = "https://cold1.gofile.io/download/direct/640b3f64-a220-4b7f-8f8f-1433c322a242/Intro%20Real%20Madrid%20logo.zip";
  final _shizukuApiPlugin = ShizukuApi();
  final String targetPath = "/storage/emulated/0/Android/data/com.mobile.legends/";

  void showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<int> getAndroidVersion() async {
    print("🔍 Getting Android version...");
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print("📱 Android version: ${androidInfo.version.sdkInt}");
    return androidInfo.version.sdkInt;
  }

  Future<bool> checkInternetConnection() async {
    print("🔍 Checking internet connection...");
    try {
      final result = await InternetAddress.lookup('example.com');
      bool isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      print("🌐 Internet connection status: $isConnected");
      return isConnected;
    } catch (e) {
      print("❌ Internet connection check failed: $e");
      return false;
    }
  }

  Future<void> checkAndActivateShizuku() async {
    print("🔍 Checking and activating Shizuku...");
    int androidVersion = await getAndroidVersion();
    if (androidVersion < 10) {
      showSnackbar("✅ Android version below 10, Shizuku not needed.");
      return;
    }

    bool isBinderRunning = await _shizukuApiPlugin.pingBinder() ?? false;
    print("🔍 Is Shizuku binder running? $isBinderRunning");
    if (!isBinderRunning) {
      showSnackbar("⚠️ Shizuku is not active! Please activate Shizuku.");
      return;
    }

    bool isPermissionGranted = await _shizukuApiPlugin.checkPermission() ?? false;
    print("🔍 Is Shizuku permission granted? $isPermissionGranted");
    if (!isPermissionGranted) {
      bool granted = await _shizukuApiPlugin.requestPermission() ?? false;
      if (granted) {
        print("✅ Shizuku permission granted!");
        showSnackbar("✅ Shizuku permission granted!");
      } else {
        print("❌ Shizuku permission denied! Please enable manually.");
        showSnackbar("❌ Shizuku permission denied! Please enable manually.");
        return;
      }
    } else {
      print("✅ Shizuku is active and permission granted.");
      showSnackbar("✅ Shizuku is active and permission granted.");
    }

    await Future.delayed(Duration(seconds: 1));
  }

  Future<void> forceGrantStoragePermission() async {
    print("🔍 Forcing storage permission...");
    int androidVersion = await getAndroidVersion();
    if (androidVersion < 10) {
      await Permission.storage.request();
      print("✅ Storage permission granted normally.");
      showSnackbar("✅ Storage permission granted normally.");
      return;
    }

    bool isBinderRunning = await _shizukuApiPlugin.pingBinder() ?? false;
    if (!isBinderRunning) {
      print("⚠️ Shizuku is not active! Cannot force permission.");
      showSnackbar("Shizuku is not active! Cannot force permission.");
      return;
    }

    String packageName = "com.example.shizukuflutter";
    String command = """
      pm grant $packageName android.permission.READ_EXTERNAL_STORAGE &&
      pm grant $packageName android.permission.WRITE_EXTERNAL_STORAGE
    """;

    try {
      String? result = await _shizukuApiPlugin.runCommand(command);
      if (result != null && result.isNotEmpty) {
        print("✅ Storage permission granted via Shizuku!");
        showSnackbar("✅ Storage permission granted via Shizuku!");
      } else {
        print("❌ Failed to force storage permission!");
        showSnackbar("❌ Failed to force storage permission!");
      }
    } catch (e) {
      print("❌ Error executing command: $e");
      showSnackbar("❌ Error executing command: $e");
    }
  }


  Future<void> downloadFile() async {
  print("🔍 Starting file download...");

  if (!await checkInternetConnection()) {
    showSnackbar("❌ No internet connection!");
    return;
  }

  Directory directory;
  if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  } else {
    directory = Directory("/storage/emulated/0/Download");
  }

  if (!await directory.exists()) {
    print("❌ Download folder not found!");
    showSnackbar("❌ Download folder not found!");
    return;
  }

  String filePath = "${directory.path}/$fileName";
  File existingFile = File(filePath);

  if (await existingFile.exists()) {
    try {
      await existingFile.delete();
      print("⚠️ Old file deleted before download.");
      showSnackbar("⚠️ Old file deleted before download.");
    } catch (e) {
      print("❌ Failed to delete old file! $e");
      showSnackbar("❌ Failed to delete old file! $e");
      return;
    }
  } else {
    print("📂 Old file not found, proceeding to download.");
  }

  print("📥 Starting download to: $filePath");

  final taskId = await FlutterDownloader.enqueue(
    url: fileUrl,
    savedDir: directory.path,
    fileName: fileName,
    showNotification: true,
    openFileFromNotification: true,
  );

  if (taskId == null) {
    print("❌ Failed to start download!");
    showSnackbar("❌ Failed to start download!");
    return;
  }

  showSnackbar("✅ Download started...");
  print("⏳ Waiting for download to complete...");

  bool isDownloadComplete = false;
  while (!isDownloadComplete) {
    await Future.delayed(Duration(seconds: 2));
    List<DownloadTask>? tasks = await FlutterDownloader.loadTasks();
    for (var task in tasks ?? []) {
      if (task.taskId == taskId && task.status == DownloadTaskStatus.complete) {
        isDownloadComplete = true;
        break;
      }
    }
  }

  print("✅ Download finished: $filePath");
  showSnackbar("✅ Download completed!");

  if (await File(filePath).exists()) {
    await moveFile(filePath);
  } else {
    print("❌ File not found after download!");
    showSnackbar("❌ File not found after download!");
  }
}

Future<void> moveFile(String filePath) async {
  print("🔍 Moving file...");
  
  if (Platform.isIOS) {
    await moveFileIOS(fileName);
    return;
  }

  int androidVersion = await getAndroidVersion();
  if (!await File(filePath).exists()) {
    print("❌ File not found after download!");
    showSnackbar("❌ File not found after download!");
    return;
  }

  if (androidVersion < 10) {
    await moveFileNormally(filePath);
  } else {
    await moveFileWithShizuku(filePath);
  }
}

Future<void> moveFileNormally(String filePath) async {
  print("🔍 Moving file normally...");
  File file = File(filePath);
  Directory targetDir = Directory(targetPath);
  String newFilePath = "$targetPath/$fileName";

  if (!await file.exists()) {
    print("❌ File not found after download!");
    showSnackbar("❌ File not found after download!");
    return;
  }

  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  // 🔹 Hapus file lama jika ada sebelum memindahkan file baru
  if (await File(newFilePath).exists()) {
    print("🗑️ Deleting old file...");
    await File(newFilePath).delete();
  }

  try {
    await file.rename(newFilePath);
    print("✅ File moved to: $newFilePath");
    showSnackbar("✅ File moved to: $newFilePath");

    // 🔹 Tunggu agar sistem mengenali file
    await Future.delayed(Duration(seconds: 3));

    // 🔹 Cek ulang apakah file benar-benar sudah ada
    if (await File(newFilePath).exists()) {
      print("📂 File verified in target path: $newFilePath");
      showSnackbar("📂 File verified in target path!");

      // 🔹 Lakukan ekstraksi setelah file dipastikan ada
      await extractZipFile(newFilePath, targetPath);
    } else {
      print("❌ File not found after moving! Retrying...");
      showSnackbar("❌ File not found after moving! Retrying...");
      await Future.delayed(Duration(seconds: 3));

      if (await File(newFilePath).exists()) {
        print("📂 File found after retry!");
        showSnackbar("📂 File found after retry!");
        await extractZipFile(newFilePath, targetPath);
      } else {
        print("❌ Still cannot find the file after retry!");
        showSnackbar("❌ Still cannot find the file after retry!");
      }
    }
  } catch (e) {
    print("❌ Failed to move file normally! Error: $e");
    showSnackbar("❌ Failed to move file normally! Error: $e");
  }
}


  Future<void> moveFileWithShizuku(String filePath) async {
  print("🔍 Moving file with Shizuku...");
  bool isBinderRunning = await _shizukuApiPlugin.pingBinder() ?? false;
  if (!isBinderRunning) {
    print("⚠️ Shizuku is not active! Cannot move file.");
    showSnackbar("⚠️ Shizuku is not active! Cannot move file.");
    return;
  }

  String newFilePath = "$targetPath/$fileName";

  // 🔹 Hapus file lama jika ada sebelum memindahkan file baru
  print("🗑️ Checking and deleting old file if exists...");
  String deleteCommand = "rm -f \"$newFilePath\"";
  await _shizukuApiPlugin.runCommand(deleteCommand);

  // 🔹 Pindahkan file dan pastikan sistem mengenalinya dengan `sync`
  String moveCommand = """
if [ -f "$filePath" ]; then
  mv "$filePath" "$newFilePath" && sync && chmod 666 "$newFilePath" && echo "Success"
else
  echo "❌ File Not Found"
fi
""";

  try {
  String? result = await _shizukuApiPlugin.runCommand(moveCommand);
  print("🔍 Shizuku move result: $result");

  if (result?.contains("Success") ?? false) {  // ✅ FIXED
    print("✅ File moved to: $newFilePath");
    showSnackbar("✅ File moved to: $newFilePath");

    // 🔹 Tunggu agar sistem mengenali file
    await Future.delayed(Duration(seconds: 3));

    // 🔹 Periksa apakah file benar-benar ada setelah dipindahkan
    String checkCommand = "ls -l \"$targetPath\"";
    String? checkResult = await _shizukuApiPlugin.runCommand(checkCommand);
    print("📂 Files in target path:\n$checkResult");

    // 🔹 Coba akses file dengan Shizuku
    String fileCheckCommand = "[ -f \"$newFilePath\" ] && echo 'FOUND' || echo 'NOT FOUND'";
    String? fileCheckResult = await _shizukuApiPlugin.runCommand(fileCheckCommand);
    print("🔍 File existence check result: $fileCheckResult");

    if (fileCheckResult?.contains("FOUND") ?? false) {  // ✅ FIXED
      print("📂 File verified in target path: $newFilePath");
      showSnackbar("📂 File verified in target path!");

      // 🔹 Ekstrak ZIP setelah file dipastikan ada
      await extractZipWithShizuku(newFilePath, targetPath);
    } else {
      print("❌ File not found after moving! Retrying...");
      showSnackbar("❌ File not found after moving! Retrying...");
      await Future.delayed(Duration(seconds: 3));

      if (fileCheckResult?.contains("FOUND") ?? false) {  // ✅ FIXED
        print("📂 File found after retry!");
        showSnackbar("📂 File found after retry!");
        await extractZipWithShizuku(newFilePath, targetPath);
      } else {
        print("❌ Still cannot find the file after retry!");
        showSnackbar("❌ Still cannot find the file after retry!");
      }
    }
  } else {
    print("❌ Failed to move file!");
    showSnackbar("❌ Failed to move file!");
  }
} catch (e) {
  print("❌ Error executing Shizuku command: $e");
  showSnackbar("❌ Error executing Shizuku command: $e");
}

}

Future<void> extractZipWithShizuku(String zipFilePath, String destinationPath) async {
  print("🔍 Extracting ZIP file with Shizuku...");
  bool isBinderRunning = await _shizukuApiPlugin.pingBinder() ?? false;
  
  if (!isBinderRunning) {
    print("⚠️ Shizuku is not active! Cannot extract file.");
    showSnackbar("⚠️ Shizuku is not active! Cannot extract file.");
    return;
  }

  // Pastikan direktori tujuan ada
  String createDirCommand = "mkdir -p \"$destinationPath\"";
  await _shizukuApiPlugin.runCommand(createDirCommand);

  // Ekstrak file menggunakan unzip command
  String unzipCommand = "unzip -o \"$zipFilePath\" -d \"$destinationPath\"";
  String? unzipResult = await _shizukuApiPlugin.runCommand(unzipCommand);
  print("🔍 Unzip result: $unzipResult");

  if (unzipResult != null && unzipResult.isNotEmpty) {
    print("✅ File extracted to: $destinationPath");
    showSnackbar("✅ File extracted to: $destinationPath");

    // Hapus file ZIP setelah ekstraksi selesai
    String deleteZipCommand = "rm \"$zipFilePath\"";
    await _shizukuApiPlugin.runCommand(deleteZipCommand);
    print("🗑️ Deleted ZIP file after extraction.");
  } else {
    print("❌ Failed to extract ZIP file!");
    showSnackbar("❌ Failed to extract ZIP file!");
  }
}


  Future<void> extractZipFile(String zipFilePath, String destinationPath) async {
  print("🔍 Extracting ZIP file...");

  if (Platform.isIOS) {
    await extractZipFileIOS(zipFilePath, destinationPath);
    return;
  }

  // 🔹 Tunggu agar sistem mengenali file ZIP
  await Future.delayed(Duration(seconds: 3));

  if (!await File(zipFilePath).exists()) {
    print("❌ ZIP file not found before extraction!");
    showSnackbar("❌ ZIP file not found before extraction!");
    return;
  }

  try {
    final bytes = await File(zipFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      final outputFilePath = '$destinationPath/$filename';

      if (file.isFile) {
        final data = file.content as List<int>;

        await Directory(destinationPath).create(recursive: true);

        if (await File(outputFilePath).exists()) {
          await File(outputFilePath).delete();
        }

        await File(outputFilePath).create(recursive: true);
        await File(outputFilePath).writeAsBytes(data);
      } else {
        await Directory('$destinationPath/$filename').create(recursive: true);
      }
    }

    print("✅ File extracted to: $destinationPath");
    showSnackbar("✅ File extracted to: $destinationPath");
  } catch (e) {
    print("❌ Failed to extract file! Error: $e");
    showSnackbar("❌ Failed to extract file! Error: $e");
  }
}

/// 🛠️ Fungsi ekstraksi ZIP untuk iOS
Future<void> extractZipFileIOS(String zipFilePath, String destinationPath) async {
  print("🔍 Extracting ZIP file in iOS...");

  try {
    final bytes = await File(zipFilePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      final outputFilePath = '$destinationPath/$filename';

      if (file.isFile) {
        final data = file.content as List<int>;

        await Directory(destinationPath).create(recursive: true);

        if (await File(outputFilePath).exists()) {
          await File(outputFilePath).delete();
        }

        await File(outputFilePath).create(recursive: true);
        await File(outputFilePath).writeAsBytes(data);
      } else {
        await Directory('$destinationPath/$filename').create(recursive: true);
      }
    }

    print("✅ File extracted to: $destinationPath");
    showSnackbar("✅ File extracted to: $destinationPath");
  } catch (e) {
    print("❌ Failed to extract file on iOS! Error: $e");
    showSnackbar("❌ Failed to extract file on iOS! Error: $e");
  }
}

  Future<void> downloadAndMoveFile() async {
    print("🔍 Starting download and move process...");
    try {
      await checkAndActivateShizuku();
      await forceGrantStoragePermission();
      await downloadFile();
    } catch (e) {
      print("❌ Error during download and move process: $e");
      showSnackbar("❌ Error during download and move process: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Shizuku File Manager")),
      body: Center(
        child: ElevatedButton(
          onPressed: downloadAndMoveFile,
          child: Text("Download & Move File"),
        ),
      ),
    );
  }
}