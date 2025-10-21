// lib/screens/options_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/screens/main_screen.dart';
import 'package:go_router/go_router.dart';

class OptionsScreen extends StatelessWidget {
  static const routeName = '/options';
  final _storage = FlutterSecureStorage();

  OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('설정')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('로그아웃'),
            onTap: () async {
              // 저장된 토큰 삭제
              await _storage.delete(key: 'access_token');
              await _storage.delete(key: 'refresh_token');
              // 메인 화면으로 복귀(로그인 전 상태)
           context.go(MainScreen.routeName);
            },
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('앱 정보'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'TRPG App',
                applicationVersion: 'v1.0.0',
                applicationLegalese: '© 2025 My TRPG Team',
              );
            },
          ),
          // TODO: 추가 설정 항목들...
        ],
      ),
    );
  }
}
