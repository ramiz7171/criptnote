import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/security_provider.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/files/files_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/board/board_screen.dart';
import '../screens/meetings/meetings_screen.dart';
import '../screens/transcripts/transcripts_screen.dart';
import '../screens/dashboard/note_editor_screen.dart';
import '../widgets/security/lock_screen.dart';

// ChangeNotifier that listens to auth + security state, used as GoRouter refreshListenable
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<SecurityState>(securityProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final securityState = ref.read(securityProvider);

      final isAuth = authState.user != null;
      final isLoading = authState.loading;
      final isMfaRequired = authState.mfaRequired;
      final isLocked = securityState.isLocked;

      if (isLoading) return null;

      final loc = state.matchedLocation;
      final isAuthRoute = loc.startsWith('/auth');
      final isLockRoute = loc == '/lock';

      if (!isAuth && !isAuthRoute) return '/auth';
      if (isAuth && isAuthRoute && !isMfaRequired) return '/dashboard';
      if (isAuth && isLocked && !isLockRoute) return '/lock';

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/board',
            builder: (context, state) => const BoardScreen(),
          ),
          GoRoute(
            path: '/meetings',
            builder: (context, state) => const MeetingsScreen(),
          ),
          GoRoute(
            path: '/transcripts',
            builder: (context, state) => const TranscriptsScreen(),
          ),
          GoRoute(
            path: '/files',
            builder: (context, state) => const FilesScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/note/:id',
        builder: (context, state) {
          final noteId = state.pathParameters['id']!;
          return NoteEditorScreen(noteId: noteId);
        },
      ),
    ],
  );
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _destinations = [
    (path: '/dashboard', icon: Icons.note_alt_outlined, activeIcon: Icons.note_alt, label: 'Notes'),
    (path: '/board', icon: Icons.draw_outlined, activeIcon: Icons.draw, label: 'Board'),
    (path: '/meetings', icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Meetings'),
    (path: '/transcripts', icon: Icons.mic_none_outlined, activeIcon: Icons.mic, label: 'Transcripts'),
    (path: '/files', icon: Icons.folder_outlined, activeIcon: Icons.folder, label: 'Files'),
    (path: '/settings', icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Sync bottom nav with actual route (handles programmatic navigation)
    final location = GoRouterState.of(context).matchedLocation;
    final routeIndex = _destinations.indexWhere((d) => location.startsWith(d.path));
    final displayIndex = routeIndex >= 0 ? routeIndex : _selectedIndex;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: displayIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          context.go(_destinations[index].path);
        },
        destinations: _destinations.map((d) => NavigationDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.activeIcon),
          label: d.label,
        )).toList(),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
    );
  }
}
