import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_settings.dart';
import '../services/settings_service.dart';
import 'auth_provider.dart';

class SettingsState {
  final UserSettings? settings;
  final bool loading;

  const SettingsState({this.settings, this.loading = true});

  SettingsState copyWith({UserSettings? settings, bool? loading}) =>
      SettingsState(settings: settings ?? this.settings, loading: loading ?? this.loading);
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._userId) : super(const SettingsState()) {
    _load();
  }

  final String _userId;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    final settings = await SettingsService.fetchSettings(_userId);
    state = SettingsState(settings: settings, loading: false);
    _subscribe();
  }

  void _subscribe() {
    _channel = SettingsService.subscribeToSettings(_userId, (record) {
      state = state.copyWith(settings: UserSettings.fromJson(record));
    });
  }

  Future<void> update(Map<String, dynamic> updates) async {
    if (state.settings == null) return;
    final updated = UserSettings.fromJson({...state.settings!.toJson(), ...updates});
    state = state.copyWith(settings: updated);
    await SettingsService.updateSettings(_userId, updates);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final settingsProvider = StateNotifierProvider.autoDispose<SettingsNotifier, SettingsState>((ref) {
  final auth = ref.watch(authProvider);
  return SettingsNotifier(auth.user?.id ?? '');
});
