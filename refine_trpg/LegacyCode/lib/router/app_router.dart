import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/main_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/create_room_screen.dart';
import '../screens/find_room_screen.dart';
import '../screens/option_screen.dart';
import '../screens/room_screen.dart';
import '../models/room.dart';
import '../services/room_service.dart';

final appRouter = GoRouter(
  initialLocation: MainScreen.routeName,
  routes: [
    GoRoute(
      path: MainScreen.routeName,
      builder: (context, state) => MainScreen(),
    ),
    GoRoute(
      path: LoginScreen.routeName,
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: SignupScreen.routeName,
      builder: (context, state) => SignupScreen(),
    ),
    GoRoute(
      path: CreateRoomScreen.routeName,
      builder: (context, state) => CreateRoomScreen(),
    ),
    GoRoute(
      path: FindRoomScreen.routeName,
      builder: (context, state) => FindRoomScreen(),
    ),
    GoRoute(
      path: OptionsScreen.routeName,
      builder: (context, state) => OptionsScreen(),
    ),
    GoRoute(
      path: '${RoomScreen.routeName}/:roomId',
      pageBuilder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return MaterialPage(
          key: state.pageKey,
          child: FutureBuilder<Room>(
            future: RoomService.getRoomById(roomId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('방 정보를 불러올 수 없습니다.'),
                        ElevatedButton(
                          onPressed: () => context.go(MainScreen.routeName),
                          child: const Text('홈으로'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return RoomScreen(room: snapshot.data!);
            },
          ),
        );
      },
    ),
  ],
  errorBuilder: (context, state) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('잘못된 접근입니다.'),
            ElevatedButton(
              onPressed: () => context.go(MainScreen.routeName),
              child: const Text('홈으로'),
            ),
          ],
        ),
      ),
    );
  },
);