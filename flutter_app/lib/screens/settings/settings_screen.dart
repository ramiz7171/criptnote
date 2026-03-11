import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../services/auth_service.dart';
import '../../services/audit_service.dart';
import '../../models/audit_log.dart';
import '../../core/constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'General'), Tab(text: 'Security')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_GeneralSection(), _SecuritySection()],
      ),
    );
  }
}

class _GeneralSection extends ConsumerWidget {
  const _GeneralSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.settings;
    final notifier = ref.read(settingsProvider.notifier);
    final theme = ref.watch(themeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile
        _Section(
          title: 'Profile',
          children: [
            ListTile(
              leading: CircleAvatar(child: Text((auth.profile?.displayName.isNotEmpty == true ? auth.profile!.displayName[0] : 'U').toUpperCase())),
              title: Text(auth.profile?.displayName ?? auth.user?.email ?? ''),
              subtitle: Text(auth.user?.email ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editDisplayName(context, ref, auth.profile?.displayName ?? ''),
              ),
            ),
          ],
        ),

        // Theme
        _Section(title: 'Appearance', children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: theme == ThemeMode.dark,
            onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
        ]),

        // Default View
        if (settings != null) _Section(title: 'Default View', children: [
          ...['grid', 'list', 'infinite'].map((view) => RadioListTile<String>(
            title: Text(view[0].toUpperCase() + view.substring(1)),
            value: view,
            groupValue: settings.defaultView,
            onChanged: (v) => notifier.update({'default_view': v}),
          )),
        ]),

        // AI Preferences
        if (settings != null) _Section(title: 'AI Preferences', children: [
          ListTile(
            title: const Text('AI Tone'),
            trailing: DropdownButton<String>(
              value: settings.aiTone,
              underline: const SizedBox(),
              items: ['professional', 'casual', 'concise', 'detailed']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1))))
                  .toList(),
              onChanged: (v) => notifier.update({'ai_tone': v}),
            ),
          ),
          ListTile(
            title: const Text('Summary Length'),
            trailing: DropdownButton<String>(
              value: settings.summaryLength,
              underline: const SizedBox(),
              items: ['short', 'medium', 'long']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1))))
                  .toList(),
              onChanged: (v) => notifier.update({'summary_length': v}),
            ),
          ),
        ]),

        // Notifications
        if (settings != null) _Section(title: 'Notifications', children: [
          SwitchListTile(
            title: const Text('Email Summaries'),
            value: settings.notifications.emailSummaries,
            onChanged: (v) => notifier.update({'notifications': {...settings.notifications.toJson(), 'email_summaries': v}}),
          ),
          SwitchListTile(
            title: const Text('Meeting Reminders'),
            value: settings.notifications.meetingReminders,
            onChanged: (v) => notifier.update({'notifications': {...settings.notifications.toJson(), 'meeting_reminders': v}}),
          ),
          SwitchListTile(
            title: const Text('Transcript Ready'),
            value: settings.notifications.transcriptReady,
            onChanged: (v) => notifier.update({'notifications': {...settings.notifications.toJson(), 'transcript_ready': v}}),
          ),
        ]),

        // Sign Out
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => ref.read(authProvider.notifier).signOut(),
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
  }

  void _editDisplayName(BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Display Name'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(authProvider.notifier).updateProfile({'display_name': result});
    }
  }
}

class _SecuritySection extends ConsumerStatefulWidget {
  const _SecuritySection();

  @override
  ConsumerState<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<_SecuritySection> {
  List<AuditLog> _auditLogs = [];
  int _auditOffset = 0;
  bool _loadingLogs = false;

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;
    setState(() => _loadingLogs = true);
    final logs = await AuditService.fetchAuditLogs(auth.user!.id, offset: _auditOffset);
    setState(() { _auditLogs.addAll(logs); _auditOffset += logs.length; _loadingLogs = false; });
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final secNotifier = ref.read(securityProvider.notifier);
    final encryption = ref.watch(encryptionProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // PIN
        _Section(title: 'PIN Lock', children: [
          SwitchListTile(
            title: const Text('Enable PIN Lock'),
            subtitle: const Text('Lock app with a PIN code'),
            value: security.isPinEnabled,
            onChanged: (v) async {
              if (v) {
                _setupPin(context, secNotifier);
              } else {
                await secNotifier.removePin();
              }
            },
          ),
          if (security.isPinEnabled)
            ListTile(
              title: const Text('Change PIN'),
              leading: const Icon(Icons.dialpad),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _setupPin(context, secNotifier),
            ),
        ]),

        // Idle Timeout
        _Section(title: 'Idle Timeout', children: [
          ListTile(
            title: const Text('Auto-lock after'),
            trailing: DropdownButton<int>(
              value: security.idleTimeoutMinutes,
              underline: const SizedBox(),
              items: AppConstants.idleTimeoutOptions.map((m) => DropdownMenuItem(value: m, child: Text(m == 0 ? 'Never' : '${m}m'))).toList(),
              onChanged: (v) => secNotifier.setIdleTimeout(v ?? 0),
            ),
          ),
        ]),

        // Encryption
        _Section(title: 'End-to-End Encryption', children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Encryption Status'),
            subtitle: Text(encryption.isEncryptionEnabled ? (encryption.isUnlocked ? 'Enabled & Unlocked' : 'Enabled (Locked)') : 'Disabled'),
            trailing: Switch(
              value: encryption.isEncryptionEnabled,
              onChanged: (v) => v ? _enableEncryption(context) : _disableEncryption(context),
            ),
          ),
          if (encryption.isEncryptionEnabled && !encryption.isUnlocked)
            ListTile(
              title: const Text('Unlock Encryption'),
              leading: const Icon(Icons.lock_open_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _unlockEncryption(context),
            ),
        ]),

        // MFA
        _Section(title: 'Two-Factor Authentication', children: [
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Authenticator App (TOTP)'),
            subtitle: const Text('Add extra security to your account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _setupMfa(context),
          ),
        ]),

        // Password
        _Section(title: 'Password', children: [
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changePassword(context),
          ),
        ]),

        // Audit Log
        _Section(
          title: 'Audit Log',
          children: [
            if (_auditLogs.isEmpty && _loadingLogs)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else ...[
              ..._auditLogs.map((log) => ListTile(
                leading: const Icon(Icons.history, size: 18),
                title: Text(log.action, style: const TextStyle(fontSize: 13)),
                subtitle: Text(log.createdAt.substring(0, 16), style: const TextStyle(fontSize: 11)),
                dense: true,
              )),
              if (!_loadingLogs)
                TextButton(onPressed: _loadAuditLogs, child: const Text('Load More')),
            ],
          ],
        ),

        // Sign out all sessions
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await AuthService.signOut();
            ref.read(authProvider.notifier).signOut();
          },
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Sign Out All Sessions', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
  }

  void _setupPin(BuildContext context, SecurityNotifier notifier) async {
    String? pin = await showDialog<String>(context: context, builder: (_) => const _PinDialog());
    if (pin != null) await notifier.setupPin(pin);
  }

  void _enableEncryption(BuildContext context) async {
    final passphrase = await showDialog<String>(context: context, builder: (_) => const _PassphraseDialog(title: 'Enable Encryption', hint: 'Create a passphrase (min 8 chars)'));
    if (passphrase != null && passphrase.length >= 8) {
      final auth = ref.read(authProvider);
      if (auth.user == null) return;
      await ref.read(encryptionProvider.notifier).enableEncryption(
        passphrase: passphrase,
        userId: auth.user!.id,
        existingNotes: [],
      );
    }
  }

  void _disableEncryption(BuildContext context) async {
    final passphrase = await showDialog<String>(context: context, builder: (_) => const _PassphraseDialog(title: 'Disable Encryption', hint: 'Enter your passphrase to confirm'));
    if (passphrase != null) {
      final auth = ref.read(authProvider);
      if (auth.user == null) return;
      await ref.read(encryptionProvider.notifier).disableEncryption(passphrase: passphrase, userId: auth.user!.id);
    }
  }

  void _unlockEncryption(BuildContext context) async {
    final passphrase = await showDialog<String>(context: context, builder: (_) => const _PassphraseDialog(title: 'Unlock Encryption', hint: 'Enter your passphrase'));
    if (passphrase != null) {
      final success = await ref.read(encryptionProvider.notifier).unlock(passphrase);
      if (!success && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect passphrase'), backgroundColor: Colors.red));
    }
  }

  void _setupMfa(BuildContext context) async {
    // Show MFA setup info
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Setup 2FA'),
      content: const Text('Scan the QR code from your authenticator app to set up two-factor authentication.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ));
  }

  void _changePassword(BuildContext context) async {
    final controller = TextEditingController();
    final newPass = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('New Password'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Enter new password'), obscureText: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Update')),
      ],
    ));
    if (newPass != null && newPass.length >= 6) {
      await AuthService.updatePassword(newPass);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1, fontWeight: FontWeight.w600)),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set PIN'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _pinController, decoration: const InputDecoration(labelText: 'PIN (4-6 digits)'), keyboardType: TextInputType.number, maxLength: 6, obscureText: true),
        const SizedBox(height: 8),
        TextField(controller: _confirmController, decoration: const InputDecoration(labelText: 'Confirm PIN'), keyboardType: TextInputType.number, maxLength: 6, obscureText: true),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (_pinController.text.length < 4) { setState(() => _error = 'PIN must be 4-6 digits'); return; }
          if (_pinController.text != _confirmController.text) { setState(() => _error = 'PINs do not match'); return; }
          Navigator.pop(context, _pinController.text);
        }, child: const Text('Set PIN')),
      ],
    );
  }
}

class _PassphraseDialog extends StatelessWidget {
  final String title;
  final String hint;
  const _PassphraseDialog({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, decoration: InputDecoration(hintText: hint), obscureText: true, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Confirm')),
      ],
    );
  }
}
