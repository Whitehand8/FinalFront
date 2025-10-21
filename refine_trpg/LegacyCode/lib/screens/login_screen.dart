import 'package:flutter/material.dart';
import 'package:frontend/screens/main_screen.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  String _email = ''; // 아이디 대신 이메일로 변수명 변경
  String _password = '';
  bool _isLoading = false;

  Future<void> _onLoginPressed() async {
    // ① 폼 유효성 검사
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      // 이메일(email)과 비밀번호(password)를 넘겨 주도록 변경
      final success = await AuthService.login(
        email: _email,
        password: _password,
      );
      if (!mounted) return; 
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 성공')));
      context.go(MainScreen.routeName);
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
      appBar: AppBar(title: Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 1) 이메일 입력
              TextFormField(
                decoration: InputDecoration(labelText: '이메일'),
                keyboardType: TextInputType.emailAddress,
                onSaved: (v) => _email = v?.trim() ?? '',
                validator: (v) {
                  if (v == null || v.isEmpty) return '이메일을 입력하세요';
                  if (!v.contains('@')) return '유효한 이메일을 입력하세요';
                  return null;
                },
              ),
              SizedBox(height: 16),
              // 2) 비밀번호 입력
              TextFormField(
                decoration: InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                onSaved: (v) => _password = v ?? '',
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
                  if (v.length < 8) return '8자 이상 입력하세요';
                  return null;
                },
              ),
              SizedBox(height: 24),
              // 3) 로그인 버튼
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onLoginPressed,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('로그인', style: TextStyle(fontSize: 18)),
                    ),
                  ),
              SizedBox(height: 16),
              // 4) 회원가입으로 이동
              TextButton(
                onPressed: () {
                  context.go('/signup');
                },
                child: Text('아직 회원이 아니신가요? 회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
