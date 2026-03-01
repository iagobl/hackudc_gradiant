import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/cloud/supabase_config.dart';
import 'core/cloud/cloud_sync_manager.dart';
import 'core/security/screenshot_protection_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/settings/data/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await CloudSyncManager.instance.start();

  final storage = SecureStorageService();
  final spStr = await storage.readString(SettingsController.kScreenshotProtectionKey);
  final spEnabled = (spStr == null) ? true : spStr == 'true';
  await ScreenshotProtectionService().setEnabled(spEnabled);

  runApp(const VaultApp());
}
