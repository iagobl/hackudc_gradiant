import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/cloud/supabase_config.dart';
import 'core/cloud/cloud_sync_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Arranca el listener de sync automático (si el usuario activa cloud).
  // No rompe nada si no hay sesión o el vault está bloqueado.
  await CloudSyncManager.instance.start();

  runApp(const VaultApp());
}
