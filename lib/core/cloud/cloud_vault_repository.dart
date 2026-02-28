import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class CloudVaultRepository {
  CloudVaultRepository();

  SupabaseClient get _client => SupabaseService.client;

  static const String kHeadersTable = 'vault_headers';
  static const String kEntriesTable = 'vault_entries';

  Future<void> upsertHeader({
    required String userId,
    required Map<String, dynamic> header,
  }) async {
    final payload = {
      'user_id': userId,
      ...header,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _client.from(kHeadersTable).upsert(payload);
  }

  Future<Map<String, dynamic>?> getHeader({required String userId}) async {
    final res = await _client
        .from(kHeadersTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }

  Future<void> upsertEntry({
    required String userId,
    required String entryId,
    required Map<String, dynamic> entry,
  }) async {
    final payload = {
      'user_id': userId,
      'entry_id': entryId,
      ...entry,
    };
    await _client.from(kEntriesTable).upsert(payload);
  }

  Future<List<Map<String, dynamic>>> listEntries({required String userId}) async {
    final res = await _client
        .from(kEntriesTable)
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> deleteEntry({
    required String entryId,
    String? userId,
  }) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) throw Exception('No hay sesión en Supabase');

    await _client
        .from(kEntriesTable)
        .delete()
        .eq('user_id', uid)
        .eq('entry_id', entryId);
  }
}