// lib/routes/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:trpg_frontend/services/auth_service.dart';
import 'package:trpg_frontend/screens/login_screen.dart';
import 'package:trpg_frontend/screens/menu_screen.dart';
import 'package:trpg_frontend/screens/signup_screen.dart';
import 'package:trpg_frontend/screens/join_room_screen.dart';
import 'package:trpg_frontend/screens/create_room_screen.dart';
import 'package:trpg_frontend/screens/option_screen.dart';
import 'package:trpg_frontend/screens/room_screen.dart';
import 'routers.dart';

final navigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  initialLocation: Routes.rooms,
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => Routes.rooms,
    ),
    GoRoute(
      path: Routes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.signup,
      name: 'signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: Routes.rooms,
      name: 'rooms',
      builder: (context, state) => const MenuScreen(),
    ),
    GoRoute(
      path: Routes.joinRoom,
      name: 'joinRoom',
      builder: (context, state) => const JoinRoomScreen(),
    ),
    GoRoute(
      path: Routes.createRoom,
      name: 'createRoom',
      builder: (context, state) => const CreateRoomScreen(),
    ),
    GoRoute(
      path: Routes.options,
      name: 'options',
      builder: (context, state) => const OptionsScreen(),
    ),
    GoRoute(
      path: Routes.roomDetail,
      name: 'roomDetail',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return RoomScreen.byId(roomId: roomId);
      },
    ),
  ],
  redirect: (context, state) async {
    final isAuth = AuthService.instance.isLoggedIn;
    final uri = state.uri.toString();

    // 인증 없이 접근 가능한 경로
    final publicPaths = [Routes.login, Routes.signup];
    final isPublic = publicPaths.any(uri.startsWith);

    if (!isAuth && !isPublic) {
      return Routes.login;
    }
    if (isAuth && isPublic) {
      return Routes.rooms;
    }
    return null;
  },
);
