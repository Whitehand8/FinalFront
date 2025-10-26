import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refine_trpg/router/app_router.dart';
import 'package:refine_trpg/services/settings_manager.dart';
import 'router/routers.dart';
import 'services/ApiClient.dart';
import 'services/auth_service.dart';

void main() {
  // 인증 만료 시 로그인 화면으로 이동
  ApiClient.instance.setOnUnauthenticated(() {
    appRouter.go(Routes.login);
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService.instance),
        ChangeNotifierProvider(create: (_) => SettingsManager()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsManager>(
      builder: (context, settingsManager, child) {
        return MaterialApp.router(
          routerConfig: appRouter,
          title: 'TRPG 앱',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          themeMode: settingsManager.themeMode,
        );
      },
    );
  }
}
