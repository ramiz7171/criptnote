import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/security_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _controller = TextEditingController();
  bool _usePinMode = true;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() { _error = null; _loading = true; });
    bool success;
    if (_usePinMode) {
      success = await ref.read(securityProvider.notifier).unlockWithPin(_controller.text.trim());
    } else {
      success = await ref.read(securityProvider.notifier).unlockWithPassword(_controller.text.trim());
    }
    setState(() { _loading = false; });
    if (!success) setState(() => _error = _usePinMode ? 'Incorrect PIN' : 'Incorrect password');
  }

  Future<void> _unlockBiometric() async {
    setState(() { _error = null; _loading = true; });
    final success = await ref.read(securityProvider.notifier).unlockWithBiometric();
    setState(() { _loading = false; });
    if (!success) setState(() => _error = 'Biometric authentication failed');
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.lock, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 24),
                  const Text('CriptNote Locked',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Enter your ${_usePinMode ? 'PIN' : 'password'} to unlock',
                    style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),

                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: _usePinMode ? 'PIN' : 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      fillColor: AppTheme.darkSurface,
                    ),
                    obscureText: true,
                    keyboardType: _usePinMode ? TextInputType.number : TextInputType.text,
                    maxLength: _usePinMode ? 6 : null,
                    onSubmitted: (_) => _unlock(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _unlock,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Unlock'),
                  ),

                  if (security.isBiometricAvailable) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _unlockBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use Biometrics'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _usePinMode = !_usePinMode;
                      _controller.clear();
                      _error = null;
                    }),
                    child: Text(_usePinMode ? 'Use password instead' : 'Use PIN instead',
                      style: const TextStyle(color: Colors.grey)),
                  ),

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                    child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
