// =======================================================================
// 🎯 MAIN APPLICATION ENTRY POINT
// =======================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './routes.dart';
import './services/navigation_service.dart';
import './services/auth_state_manager.dart';
import './services/settings_manager.dart';
import './screens/main_screen.dart';
import './screens/login_screen.dart';
import './screens/signup_screen.dart';
import './screens/find_room_screen.dart';
import './screens/create_room_screen.dart';
import './screens/option_screen.dart';
import './screens/room_screen.dart';
import './models/room.dart';

/// 앱의 시작점입니다.
void main() {
  runApp(const MyApp());
}

// =======================================================================
// 📱 MYAPP WIDGET
// =======================================================================

/// 앱의 최상위 위젯으로, 전체적인 구조와 상태 관리를 담당합니다.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 정적 라우트 정보를 정의하는 빌더 맵입니다.
  static final Map<String, WidgetBuilder> _routeBuilders = {
    Routes.main: (context) => const MainScreen(),
    Routes.login: (context) => const LoginScreen(),
    Routes.signup: (context) => const SignupScreen(),
    Routes.findRoom: (context) => const FindRoomScreen(),
    Routes.createRoom: (context) => const CreateRoomScreen(),
    Routes.options: (context) => const OptionsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    // MultiProvider를 사용하여 앱 전역에서 상태를 관리합니다.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthStateManager()),
        ChangeNotifierProvider(create: (_) => SettingsManager()),
      ],
      child: Consumer<SettingsManager>(
        builder: (context, settingsManager, child) {
          // MaterialApp을 통해 앱의 기본 시각적 구조를 설정합니다.
          return MaterialApp(
            navigatorKey: NavigationService.navigatorKey,
            title: 'My Flutter App',
            // =============================================
            // 🎨 THEME CONFIGURATION
            // =============================================
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue, brightness: Brightness.light),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue, brightness: Brightness.dark),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            themeMode: settingsManager.themeMode,
            // =============================================
            // 🧭 ROUTING CONFIGURATION
            // =============================================
            initialRoute: Routes.main,
            onGenerateRoute: (settings) {
              // 1. 정적 경로 처리: 미리 정의된 경로 맵에 있는지 확인합니다.
              if (_routeBuilders.containsKey(settings.name)) {
                return MaterialPageRoute(
                    builder: _routeBuilders[settings.name]!);
              }

              // 2. 동적 경로 처리: '/rooms/:id' 형태의 경로를 처리합니다.
              final uri = Uri.parse(settings.name ?? '');
              if (uri.pathSegments.length == 2 &&
                  uri.pathSegments.first == 'rooms') {
                final roomId = uri.pathSegments[1];

                // arguments로 Room 객체가 직접 전달된 경우, 즉시 화면을 빌드합니다.
                if (settings.arguments is Room) {
                  return MaterialPageRoute(
                    builder: (context) =>
                        RoomScreen(room: settings.arguments as Room),
                  );
                }
                // roomId만 있는 경우, RoomScreen.byId 팩토리 위젯을 사용하여 데이터를 비동기적으로 로드합니다.
                return MaterialPageRoute(
                  builder: (context) => RoomScreen.byId(roomId: roomId),
                );
              }

              // 3. 일치하는 경로가 없는 경우 404 에러 페이지를 표시합니다.
              return MaterialPageRoute(
                builder: (context) => _build404Page(settings.name),
              );
            },
          );
        },
      ),
    );
  }

  /// 지정된 경로를 찾을 수 없을 때 표시할 404 에러 페이지 위젯입니다.
  Widget _build404Page(String? route) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('페이지를 찾을 수 없습니다'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Text('요청한 페이지를 찾을 수 없습니다: $route'),
      ),
    );
  }
}
