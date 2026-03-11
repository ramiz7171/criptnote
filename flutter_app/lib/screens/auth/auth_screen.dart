import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _mfaController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMsg;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _errorMsg = null; _successMsg = null; });
    final error = await ref.read(authProvider.notifier).signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (error != null) setState(() => _errorMsg = error);
  }

  Future<void> _signUp() async {
    setState(() { _errorMsg = null; _successMsg = null; });
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Username is required');
      return;
    }
    final error = await ref.read(authProvider.notifier).signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
    );
    if (error != null) {
      setState(() => _errorMsg = error);
    } else {
      setState(() => _successMsg = 'Check your email to confirm your account.');
    }
  }

  Future<void> _sendMagicLink() async {
    setState(() { _errorMsg = null; _successMsg = null; });
    final error = await ref.read(authProvider.notifier).signInWithMagicLink(
      _emailController.text.trim(),
    );
    if (error != null) {
      setState(() => _errorMsg = error);
    } else {
      setState(() => _successMsg = 'Magic link sent! Check your email.');
    }
  }

  Future<void> _verifyMfa() async {
    setState(() { _errorMsg = null; });
    final error = await ref.read(authProvider.notifier).verifyMfa(_mfaController.text.trim());
    if (error != null) setState(() => _errorMsg = error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (auth.mfaRequired) {
      return _buildMfaScreen(auth);
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Brand
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.lock, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('CriptNote',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                  const SizedBox(height: 4),
                  Text('You script, we encrypt',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    )),
                  const SizedBox(height: 32),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Sign Up'),
                        Tab(text: 'Magic Link'),
                      ],
                      indicator: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      dividerColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tab content
                  SizedBox(
                    height: 300,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSignInForm(),
                        _buildSignUpForm(),
                        _buildMagicLinkForm(),
                      ],
                    ),
                  ),

                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                      ]),
                    ),
                  ],
                  if (_successMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_successMsg!, style: const TextStyle(color: Colors.green, fontSize: 13))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    final auth = ref.watch(authProvider);
    return Column(
      children: [
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: auth.loading ? null : _signIn,
          child: auth.loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Sign In'),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    final auth = ref.watch(authProvider);
    return Column(
      children: [
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(hintText: 'Username', prefixIcon: Icon(Icons.person_outlined)),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            hintText: 'Password (min 6 characters)',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signUp(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: auth.loading ? null : _signUp,
          child: auth.loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Create Account'),
        ),
      ],
    );
  }

  Widget _buildMagicLinkForm() {
    final auth = ref.watch(authProvider);
    return Column(
      children: [
        const Text('Enter your email and we\'ll send you a magic link to sign in.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendMagicLink(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: auth.loading ? null : _sendMagicLink,
          child: auth.loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Send Magic Link'),
        ),
      ],
    );
  }

  Widget _buildMfaScreen(AuthState auth) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, size: 64, color: AppTheme.primaryBlue),
                  const SizedBox(height: 16),
                  const Text('Two-Factor Authentication', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Enter the 6-digit code from your authenticator app.', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _mfaController,
                    decoration: const InputDecoration(hintText: '000000', prefixIcon: Icon(Icons.security)),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMsg != null) Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: auth.loading ? null : _verifyMfa,
                    child: auth.loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Verify'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.read(authProvider.notifier).clearMfa(),
                    child: const Text('Back to Login'),
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
