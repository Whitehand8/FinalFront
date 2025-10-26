import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'find_room_screen.dart';
import 'create_room_screen.dart';
import 'option_screen.dart';
import '../services/auth_service.dart';

/// 통합 MainScreen: 로그인 전/후 버튼과 로그인 폼을 모두 포함
class MainScreen extends StatefulWidget {
  static const String routeName = '/main';

  const MainScreen({super.key});
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isLoggedIn = false;
  bool _showLoginForm = false; // 로그인 폼 표시 여부
  bool _isLoading = false; // 로딩 상태

  // 로그인 폼 관련 변수
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';

  // 색상 변수 정의
  final Color _primaryColor = Colors.blue;
  final Color _buttonTextColor = Colors.white;
  final Color _borderColor = Colors.blueAccent;
  final Color _linkTextColor = Colors.blue;
  final Color _appBarColor = Color(0xFF8C7853);
  final Color _mainButtonBgColor = Color(0xFFD4AF37);
  final Color _mainButtonTextColor = Color(0xFF2A3439);
  final Color _linkColor = Color(0xFF9E4638);

  // 로그인 처리 함수
  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      final success = await AuthService.login(
        email: _email,
        password: _password,
      );
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 성공')));
        setState(() {
          _isLoggedIn = true;
          _showLoginForm = false;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 실패: 이메일/비밀번호를 확인하세요.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인 중 오류 발생: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showLoginForm ? '로그인' : 'TRPG 메인 화면'),
        centerTitle: true,
        backgroundColor: _appBarColor,
        // 로그인 폼 표시 중에는 뒤로가기 버튼 추가
        leading: _showLoginForm
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showLoginForm = false;
                  });
                },
              )
            : null,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _showLoginForm
              ? _buildLoginForm() // 로그인 폼 표시
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _isLoggedIn
                      ? _buildLoggedInButtons()
                      : _buildLoggedOutButtons(),
                ),
        ),
      ),
    );
  }

  /// 로그인 폼 위젯
  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          // 이메일 입력
          TextFormField(
            decoration: InputDecoration(
              labelText: '이메일',
              labelStyle: TextStyle(color: _primaryColor),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _primaryColor),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            onSaved: (v) => _email = v?.trim() ?? '',
            validator: (v) {
              if (v == null || v.isEmpty) return '이메일을 입력하세요';
              if (!v.contains('@')) return '유효한 이메일을 입력하세요';
              return null;
            },
          ),
          SizedBox(height: 16),

          // 비밀번호 입력
          TextFormField(
            decoration: InputDecoration(
              labelText: '비밀번호',
              labelStyle: TextStyle(color: _primaryColor),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _primaryColor),
              ),
            ),
            obscureText: true,
            onSaved: (v) => _password = v ?? '',
            validator: (v) {
              if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
              if (v.length < 8) return '8자 이상 입력하세요';
              return null;
            },
          ),
          SizedBox(height: 24),

          // 로그인 버튼
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onLoginPressed,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: _mainButtonBgColor,
                      side: BorderSide(color: _borderColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '로그인',
                      style:
                          TextStyle(fontSize: 18, color: _mainButtonTextColor),
                    ),
                  ),
                ),
          SizedBox(height: 16),

          // 회원가입 링크
          TextButton(
            onPressed: () {
              // 회원가입 화면으로 이동 (필요한 경우 구현)
              context.go('/signup');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('회원가입 기능은 준비 중입니다.')));
            },
            child: Text(
              '아직 회원이 아니신가요? 회원가입',
              style: TextStyle(color: _linkColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 로그인 전: 로그인 버튼만 노출
  List<Widget> _buildLoggedOutButtons() {
    return [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _showLoginForm = true;
            });
          },
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14),
            backgroundColor: _mainButtonBgColor,
            foregroundColor: _mainButtonTextColor,
            side: BorderSide(color: _borderColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('로그인', style: TextStyle(fontSize: 18)),
        ),
      ),
    ];
  }

  /// 로그인 후: 방 만들기 / 방 찾기 / 설정 / 나가기 버튼 노출
  List<Widget> _buildLoggedInButtons() {
    return [
      // 1) 방 만들기
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            context.go(CreateRoomScreen.routeName);
          },
          icon: Icon(Icons.add),
          label: Text('방 만들기', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14),
            backgroundColor: _mainButtonBgColor,
            foregroundColor: _mainButtonTextColor,
            side: BorderSide(color: _borderColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      SizedBox(height: 16),

      // 2) 방 찾기
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            context.go(FindRoomScreen.routeName);
          },
          icon: Icon(Icons.search),
          label: Text('방 찾기', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14),
            backgroundColor: _mainButtonBgColor,
            foregroundColor: _mainButtonTextColor,
            side: BorderSide(color: _borderColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      SizedBox(height: 16),

      // 3) 옵션
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            context.go(OptionsScreen.routeName);
          },
          icon: Icon(Icons.settings),
          label: Text('설정', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14),
            backgroundColor: _mainButtonBgColor,
            foregroundColor: _mainButtonTextColor,
            side: BorderSide(color: _borderColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      SizedBox(height: 16),

      // 4) 나가기
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _isLoggedIn = false;
            });
          },
          icon: Icon(Icons.exit_to_app),
          label: Text('나가기', style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14),
            backgroundColor: _mainButtonBgColor,
            foregroundColor: _mainButtonTextColor,
            side: BorderSide(color: _borderColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ];
  }
}
