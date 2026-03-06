import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/login_screen.dart';
import 'features/timer/timer_screen.dart';
import 'features/sessions/sessions_screen.dart';
import 'features/standup/standup_screen.dart';

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    // Let supabase_flutter handle the OAuth callback — don't try to route it
    if (state.uri.toString().contains('login-callback')) return '/login';

    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isOnLogin = state.matchedLocation == '/login';

    if (!isLoggedIn && !isOnLogin) return '/login';
    if (isLoggedIn && isOnLogin) return '/timer';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/timer',
      builder: (context, state) => const TimerScreen(),
    ),
    GoRoute(
      path: '/sessions',
      builder: (context, state) => const SessionsScreen(),
    ),
    GoRoute(
      path: '/standup',
      builder: (context, state) => const StandupScreen(),
    ),
  ],
);