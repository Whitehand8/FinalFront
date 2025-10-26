import 'package:flutter/material.dart';
import 'router/app_router.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter, // GoRouter 적용
      title: 'TRPG App',
      theme: ThemeData(primarySwatch: Colors.indigo),
    );
  }
}
