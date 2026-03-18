import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSetupConfig {
  const SupabaseSetupConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String redirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: 'io.supabase.familyeating://login-callback/',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

class HouseholdSummary {
  const HouseholdSummary({required this.id, required this.name});

  final String id;
  final String name;
}

class HouseholdInvite {
  const HouseholdInvite({
    required this.code,
    this.expiresAt,
  });

  final String code;
  final DateTime? expiresAt;
}

class CloudSnapshot {
  const CloudSnapshot({
    required this.householdId,
    required this.data,
    required this.version,
    this.updatedAt,
    this.updatedBy,
  });

  final String householdId;
  final Map<String, dynamic> data;
  final int version;
  final DateTime? updatedAt;
  final String? updatedBy;
}

class AppCloudSync extends ChangeNotifier {
  AppCloudSync._();

  static const String _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static const String _activeHouseholdIdKey =
      'family_eating.cloud.active_household_id';
  static const String _activeHouseholdNameKey =
      'family_eating.cloud.active_household_name';

  static final AppCloudSync instance = AppCloudSync._();

  StreamSubscription<AuthState>? _authSubscription;
  SupabaseClient? _client;
  String? _initError;
  bool _isInitialized = false;
  bool _isSyncing = false;
  String? _lastSyncError;
  DateTime? _lastSyncedAt;
  String? _activeHouseholdId;
  String? _activeHouseholdName;

  bool get isConfigured => SupabaseSetupConfig.isConfigured;
  bool get isAvailable => _client != null;
  bool get hasSession => currentUser != null;
  bool get isSyncing => _isSyncing;
  bool get hasActiveHousehold => _activeHouseholdId != null;
  bool get isInitialized => _isInitialized;
  String? get initError => _initError;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get activeHouseholdId => _activeHouseholdId;
  String? get activeHouseholdName => _activeHouseholdName;

  User? get currentUser => _client?.auth.currentUser;
  String? get currentUserEmail => currentUser?.email;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _activeHouseholdId = prefs.getString(_activeHouseholdIdKey);
    _activeHouseholdName = prefs.getString(_activeHouseholdNameKey);

    if (!isConfigured) {
      notifyListeners();
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseSetupConfig.url,
        anonKey: SupabaseSetupConfig.publishableKey,
      );
      _client = Supabase.instance.client;
      await _authSubscription?.cancel();
      _authSubscription = _client!.auth.onAuthStateChange.listen((_) async {
        if (currentUser == null) {
          await _clearActiveHousehold();
        } else if (_activeHouseholdId != null) {
          await refreshActiveHousehold();
        }
        notifyListeners();
      });
      if (currentUser != null && _activeHouseholdId != null) {
        await refreshActiveHousehold();
      }
    } catch (error) {
      _initError = '$error';
    }
    notifyListeners();
  }

  Future<String?> signInWithEmailOtp(String email) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      return 'Supabase is not configured yet.';
    }
    final String normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return 'Enter an email address.';
    }

    try {
      await client.auth.signInWithOtp(
        email: normalizedEmail,
        emailRedirectTo: kIsWeb ? null : SupabaseSetupConfig.redirectUrl,
      );
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<String?> signOut() async {
    final SupabaseClient? client = _client;
    if (client == null) {
      return 'Supabase is not configured yet.';
    }
    try {
      await client.auth.signOut();
      await _clearActiveHousehold();
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<String?> createHousehold(String name) async {
    final SupabaseClient? client = _client;
    final User? user = currentUser;
    if (client == null || user == null) {
      return 'Sign in first.';
    }
    final String normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return 'Enter a household name.';
    }

    try {
      final Map<String, dynamic> household = await client
          .from('households')
          .insert(<String, dynamic>{
            'name': normalizedName,
            'created_by': user.id,
          })
          .select('id, name')
          .single();

      final String householdId = (household['id'] ?? '').toString();
      if (householdId.isEmpty) {
        return 'Supabase did not return a household id.';
      }

      await client.from('household_members').insert(<String, dynamic>{
        'household_id': householdId,
        'user_id': user.id,
        'role': 'owner',
      });

      await client.from('household_snapshots').upsert(<String, dynamic>{
        'household_id': householdId,
        'data_json': <String, dynamic>{
          'schemaVersion': 10,
          'foodItems': <dynamic>[],
          'routineItems': <dynamic>[],
          'weekPlans': <dynamic>[],
        },
        'version': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': user.id,
      });

      await _setActiveHousehold(
        householdId: householdId,
        householdName: (household['name'] ?? normalizedName).toString(),
      );
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<String?> joinHousehold(String inviteCode) async {
    final SupabaseClient? client = _client;
    final User? user = currentUser;
    if (client == null || user == null) {
      return 'Sign in first.';
    }
    final String normalizedCode = inviteCode.trim();
    if (normalizedCode.isEmpty) {
      return 'Enter an invite code.';
    }

    try {
      final Map<String, dynamic>? invite = await client
          .from('household_invites')
          .select('household_id, expires_at')
          .eq('code', normalizedCode)
          .maybeSingle();

      if (invite == null) {
        return 'Invite code not found.';
      }

      final DateTime? expiresAt = DateTime.tryParse(
        '${invite['expires_at'] ?? ''}',
      );
      if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
        return 'Invite code has expired.';
      }

      final String householdId = (invite['household_id'] ?? '').toString();
      if (householdId.isEmpty) {
        return 'Invite code is missing a household id.';
      }

      await client
          .from('household_invites')
          .update(<String, dynamic>{
            'used_by': user.id,
            'used_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('code', normalizedCode);

      await client.from('household_members').upsert(<String, dynamic>{
        'household_id': householdId,
        'user_id': user.id,
        'role': 'member',
      });

      final Map<String, dynamic> household = await client
          .from('households')
          .select('id, name')
          .eq('id', householdId)
          .single();

      await _setActiveHousehold(
        householdId: householdId,
        householdName: (household['name'] ?? 'Household').toString(),
      );
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<HouseholdInvite?> createInvite({
    Duration validFor = const Duration(days: 7),
  }) async {
    final SupabaseClient? client = _client;
    final User? user = currentUser;
    final String? householdId = _activeHouseholdId;
    if (client == null || user == null) {
      _lastSyncError = 'Sign in first.';
      notifyListeners();
      return null;
    }
    if (householdId == null) {
      _lastSyncError = 'Create or join a household first.';
      notifyListeners();
      return null;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    final DateTime expiresAt = DateTime.now().toUtc().add(validFor);

    try {
      for (int attempt = 0; attempt < 5; attempt++) {
        final String code = _generateInviteCode();
        try {
          await client.from('household_invites').insert(<String, dynamic>{
            'household_id': householdId,
            'code': code,
            'created_by': user.id,
            'expires_at': expiresAt.toIso8601String(),
          });
          _isSyncing = false;
          _lastSyncedAt = DateTime.now().toUtc();
          notifyListeners();
          return HouseholdInvite(code: code, expiresAt: expiresAt);
        } on PostgrestException catch (error) {
          if (error.code == '23505') {
            continue;
          }
          rethrow;
        }
      }
      _isSyncing = false;
      _lastSyncError = 'Could not generate a unique invite code.';
      notifyListeners();
      return null;
    } catch (error) {
      _isSyncing = false;
      _lastSyncError = '$error';
      notifyListeners();
      return null;
    }
  }

  Future<String?> refreshActiveHousehold() async {
    final SupabaseClient? client = _client;
    if (client == null || _activeHouseholdId == null || currentUser == null) {
      return null;
    }

    try {
      final Map<String, dynamic>? household = await client
          .from('households')
          .select('id, name')
          .eq('id', _activeHouseholdId!)
          .maybeSingle();
      if (household == null) {
        await _clearActiveHousehold();
        return 'Active household no longer exists or is not accessible.';
      }
      await _setActiveHousehold(
        householdId: (household['id'] ?? '').toString(),
        householdName: (household['name'] ?? 'Household').toString(),
      );
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<void> clearLastSyncError() async {
    _lastSyncError = null;
    notifyListeners();
  }

  Future<CloudSnapshot?> fetchLatestSnapshot() async {
    final SupabaseClient? client = _client;
    final String? householdId = _activeHouseholdId;
    if (client == null || currentUser == null || householdId == null) {
      return null;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      final Map<String, dynamic>? row = await client
          .from('household_snapshots')
          .select()
          .eq('household_id', householdId)
          .maybeSingle();
      _isSyncing = false;
      _lastSyncedAt = DateTime.now().toUtc();
      notifyListeners();

      if (row == null) {
        return null;
      }

      final dynamic rawJson = row['data_json'];
      final Map<String, dynamic> data = rawJson is Map
          ? Map<String, dynamic>.from(rawJson)
          : <String, dynamic>{};
      return CloudSnapshot(
        householdId: householdId,
        data: data,
        version: row['version'] is num ? (row['version'] as num).toInt() : 0,
        updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
        updatedBy: row['updated_by']?.toString(),
      );
    } catch (error) {
      _isSyncing = false;
      _lastSyncError = '$error';
      notifyListeners();
      return null;
    }
  }

  Future<String?> pushLatestSnapshot(Map<String, dynamic> data) async {
    final SupabaseClient? client = _client;
    final User? user = currentUser;
    final String? householdId = _activeHouseholdId;
    if (client == null || user == null || householdId == null) {
      return null;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      final Map<String, dynamic>? current = await client
          .from('household_snapshots')
          .select('version')
          .eq('household_id', householdId)
          .maybeSingle();
      final int nextVersion = current?['version'] is num
          ? (current!['version'] as num).toInt() + 1
          : 1;
      await client.from('household_snapshots').upsert(<String, dynamic>{
        'household_id': householdId,
        'data_json': data,
        'version': nextVersion,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': user.id,
      });
      _isSyncing = false;
      _lastSyncedAt = DateTime.now().toUtc();
      notifyListeners();
      return null;
    } catch (error) {
      _isSyncing = false;
      _lastSyncError = '$error';
      notifyListeners();
      return '$error';
    }
  }

  Future<void> _setActiveHousehold({
    required String householdId,
    required String householdName,
  }) async {
    _activeHouseholdId = householdId;
    _activeHouseholdName = householdName;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeHouseholdIdKey, householdId);
    await prefs.setString(_activeHouseholdNameKey, householdName);
    notifyListeners();
  }

  Future<void> _clearActiveHousehold() async {
    _activeHouseholdId = null;
    _activeHouseholdName = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeHouseholdIdKey);
    await prefs.remove(_activeHouseholdNameKey);
    notifyListeners();
  }

  String _generateInviteCode() {
    final Random random = Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < 8; index++) {
      buffer.write(_inviteAlphabet[random.nextInt(_inviteAlphabet.length)]);
      if (index == 3) {
        buffer.write('-');
      }
    }
    return buffer.toString();
  }
}
