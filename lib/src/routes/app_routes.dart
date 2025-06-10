import 'package:chatty/src/core/presentation/chat/screens/chat_detail_screen.dart';
import 'package:chatty/src/core/presentation/chat/screens/chat_list_screen.dart';
import 'package:chatty/src/core/presentation/login/login_page.dart';
import 'package:chatty/src/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum Routes {
  // auth
  login,
  // chat
  chatList,
  chatDetail,
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>(
  (ref) {
    return GoRouter(
      navigatorKey: navigatorKey,
      debugLogDiagnostics: true,
      initialLocation: '/login',
      routerNeglect: true,
      redirect: (context, state) {
        return null;
      },
      redirectLimit: 1,
      routes: [
        GoRoute(
          path: '/login',
          name: Routes.login.name,
          builder: (context, state) => LoginPage(),
        ),
        GoRoute(
          path: '/chats',
          name: Routes.chatList.name,
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/chats/:userId',
          name: Routes.chatDetail.name,
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            final email = state.extra as String? ?? '';
            return ChatDetailScreen(
              chatId: 'chat_$userId',
              otherUserName: email,
            );
          },
        ),
      ],
      errorBuilder: (context, state) => ErrorPage(
        error: state.error,
      ),
    );
  },
);
