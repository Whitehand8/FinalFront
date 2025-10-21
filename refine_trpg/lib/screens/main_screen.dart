// =======================================================================
// 📲 IMPORTS & BASIC SETUP
// =======================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes.dart';
import '../services/navigation_service.dart';
import '../services/auth_service.dart';
import '../services/auth_state_manager.dart';

/// 앱의 메인 화면으로, 사용자의 로그인 상태에 따라 다른 UI를 보여줍니다.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// =======================================================================
//  StatefulWidget State
// =======================================================================

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    // 위젯이 빌드된 후 로그인 상태를 확인하여 UI를 업데이트합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthStateManager>().checkLoginStatus();
    });
  }

  // =======================================================================
  // 🎨 UI BUILD METHOD
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRPG 메인 화면'),
        centerTitle: true,
        backgroundColor: const Color(0xFF8C7853),
        actions: [
          // 로그인 상태에 따라 로그아웃 버튼을 표시합니다.
          Consumer<AuthStateManager>(
            builder: (context, auth, child) {
              if (auth.isLoggedIn) {
                return IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await AuthService.clearToken();
                    auth.logout();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그아웃되었습니다.')));
                    }
                  },
                );
              }
              return const SizedBox.shrink(); // 로그인하지 않은 경우 아무것도 표시하지 않음
            },
          ),
        ],
      ),
      body: Consumer<AuthStateManager>(
        builder: (context, auth, child) {
          // 로딩 중일 경우 프로그레스 인디케이터를 표시합니다.
          if (auth.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // 로딩이 끝나면 로그인 상태에 맞는 화면을 표시합니다.
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'TRPG에 오신 것을 환영합니다!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // 로그인 상태에 따라 다른 버튼들을 표시합니다.
                  if (!auth.isLoggedIn)
                    ..._buildLoggedOutButtons()
                  else
                    ..._buildLoggedInButtons(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =======================================================================
  // 🧩 WIDGET HELPER METHODS
  // =======================================================================

  /// 로그아웃 상태일 때 표시될 버튼 목록을 생성합니다.
  List<Widget> _buildLoggedOutButtons() {
    return [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => NavigationService.navigateTo(Routes.login),
          style: _buttonStyle,
          child: const Text('로그인', style: TextStyle(fontSize: 18)),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => NavigationService.navigateTo(Routes.signup),
          style: _buttonStyle,
          child: const Text('회원가입', style: TextStyle(fontSize: 18)),
        ),
      ),
    ];
  }

  /// 로그인 상태일 때 표시될 버튼 목록을 생성합니다.
  List<Widget> _buildLoggedInButtons() {
    return [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => NavigationService.navigateTo(Routes.createRoom),
          icon: const Icon(Icons.add),
          label: const Text('방 만들기', style: TextStyle(fontSize: 18)),
          style: _buttonStyle,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => NavigationService.navigateTo(Routes.findRoom),
          icon: const Icon(Icons.search),
          label: const Text('방 찾기', style: TextStyle(fontSize: 18)),
          style: _buttonStyle,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => NavigationService.navigateTo(Routes.options),
          icon: const Icon(Icons.settings),
          label: const Text('설정', style: TextStyle(fontSize: 18)),
          style: _buttonStyle,
        ),
      ),
    ];
  }

  // =======================================================================
  // 🎨 STYLES
  // =======================================================================

  /// 앱 전체에서 사용될 공통 버튼 스타일입니다.
  final ButtonStyle _buttonStyle = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 14),
    backgroundColor: const Color(0xFFD4AF37),
    foregroundColor: const Color(0xFF2A3439),
    side: const BorderSide(color: Colors.blueAccent, width: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
