import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/session/session_store.dart';
import 'features/admin/admin_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/phone_screen.dart';
import 'features/bucket/bucket_detail_screen.dart';
import 'features/bucket/buckets_screen.dart';
import 'features/chat/chats_screen.dart';
import 'features/chat/group_chat_screen.dart';
import 'features/community/join_community_screen.dart';
import 'features/create_bucket/create_bucket_screen.dart';
import 'features/hold/hold_screen.dart';
import 'features/home/home_shell.dart';
import 'features/home/street_home_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/orders/order_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/vendor/vendor_screen.dart';
import 'features/wallet/wallet_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// All routes. To add a screen: create it under `lib/features/<feature>/`,
/// add a GoRoute here (top-level = full screen over the tabs; inside a
/// branch = keeps the bottom nav), and navigate with `context.push('/path')`.
GoRouter buildRouter(SessionStore session) {
  const publicPaths = {'/welcome', '/login', '/login/otp'};
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppConfig.startRoute,
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path;
      final isPublic = publicPaths.contains(path);
      if (!session.isLoggedIn) return isPublic ? null : '/welcome';
      final isVendor = session.user?.role == 'vendor';
      if (!session.hasCommunity) {
        // Vendors sell to communities; they don't need to live in one.
        if (isVendor) return path == '/vendor' || path.startsWith('/chat') || path.startsWith('/orders') ? null : '/vendor';
        return path == '/community/join' ? null : '/community/join';
      }
      if (isPublic) return '/street'; // /community/join stays reachable to switch or join another community
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const PhoneScreen()),
      GoRoute(path: '/login/otp', builder: (_, s) => OtpScreen(phone: s.uri.queryParameters['phone'] ?? '')),
      GoRoute(path: '/community/join', builder: (_, _) => const JoinCommunityScreen()),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/street', builder: (_, _) => const StreetHomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/buckets', builder: (_, _) => const BucketsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen())]),
        ],
      ),

      // Full-screen routes (pushed over the tabs).
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/bucket/:id',
        builder: (_, s) => BucketDetailScreen(bucketId: s.pathParameters['id']!),
        routes: [
          GoRoute(path: 'hold', builder: (_, s) => HoldScreen(bucketId: s.pathParameters['id']!)),
        ],
      ),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/create', builder: (_, _) => const CreateBucketScreen()),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/chat/:type/:id',
        builder: (_, s) => GroupChatScreen(
          channelId: s.pathParameters['id']!,
          direct: s.pathParameters['type'] == 'direct',
          title: s.uri.queryParameters['title'],
        ),
      ),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/orders', builder: (_, _) => const OrdersScreen()),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/orders/:id',
        builder: (_, s) => OrderScreen(orderId: s.pathParameters['id']!),
      ),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/vendor', builder: (_, _) => const VendorScreen()),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/admin', builder: (_, _) => const AdminScreen()),
    ],
  );
}
