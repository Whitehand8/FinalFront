// =======================================================================
// 📲 IMPORTS & BASIC SETUP
// =======================================================================

import 'package:flutter/material.dart';
import '../services/navigation_service.dart';
import '../services/auth_service.dart';

/// 사용자 회원가입을 위한 화면 위젯입니다.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

// =======================================================================
//  स्टेट WIDGET STATE
// =======================================================================

class _SignupScreenState extends State<SignupScreen> {
  // =======================================================================
  // 📝 STATE VARIABLES & CONTROLLERS
  // =======================================================================

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();

  String _name = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isLoading = false;

  // 중복 확인 및 사용 가능 여부 상태
  bool _isEmailChecked = false;
  bool _isEmailAvailable = false;
  bool _isNicknameChecked = false;
  bool _isNicknameAvailable = false;

  // =======================================================================
  // 🔄 LIFECYCLE METHODS
  // =======================================================================

  @override
  void dispose() {
    // 컨트롤러 리소스를 정리합니다.
    _emailController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // =======================================================================
  // 🚀 ASYNC & HELPER METHODS
  // =======================================================================

  /// 이메일 중복 여부를 서버에 확인 요청합니다.
  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이메일을 입력해주세요.')));
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('유효한 이메일 형식이 아닙니다.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.checkEmailAvailability(email: email);
      setState(() {
        _isEmailChecked = true;
        _isEmailAvailable = result['success'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이메일 확인 중 오류 발생: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 닉네임 중복 여부를 서버에 확인 요청합니다.
  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty || nickname.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임은 2자 이상이어야 합니다.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result =
          await AuthService.checkNicknameAvailability(nickname: nickname);
      setState(() {
        _isNicknameChecked = true;
        _isNicknameAvailable = result['success'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('닉네임 확인 중 오류 발생: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 회원가입 버튼을 눌렀을 때의 전체 로직을 처리합니다.
  Future<void> _onSignupPressed() async {
    if (!_formKey.currentState!.validate()) return;

    // 이메일 및 닉네임 중복 확인 여부를 검사합니다.
    if (!_isEmailChecked || !_isEmailAvailable) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이메일 중복 확인을 완료해주세요.')));
      return;
    }
    if (!_isNicknameChecked || !_isNicknameAvailable) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임 중복 확인을 완료해주세요.')));
      return;
    }

    _formKey.currentState!.save();

    // 비밀번호 일치 여부를 재확인합니다.
    if (_password != _confirmPassword) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.signup(
        name: _name,
        nickname: _nicknameController.text.trim(),
        email: _emailController.text.trim(),
        password: _password,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '회원가입 성공! 로그인해주세요.')),
        );
        NavigationService.goBack(); // 회원가입 성공 시 이전 화면으로 돌아갑니다.
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '회원가입 실패')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 중 오류 발생: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =======================================================================
  // 🎨 UI BUILD METHOD
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('회원가입'), backgroundColor: const Color(0xFF8C7853)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- 이름 입력 필드 ---
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                ),
                onSaved: (v) => _name = v?.trim() ?? '',
                validator: (v) {
                  if (v == null || v.isEmpty) return '이름을 입력하세요';
                  if (v.trim().length < 2) return '이름은 2자 이상이어야 합니다';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- 닉네임 입력 필드 ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        labelText: '닉네임',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isNicknameChecked
                            ? Icon(
                                _isNicknameAvailable
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _isNicknameAvailable
                                    ? Colors.green
                                    : Colors.red,
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {
                        _isNicknameChecked = false;
                        _isNicknameAvailable = false;
                      }),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '닉네임을 입력하세요';
                        if (v.trim().length < 2) return '닉네임은 2자 이상이어야 합니다';
                        if (v.trim().length > 20) return '닉네임은 20자 이하여야 합니다';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _checkNickname,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                    ),
                    child: const Text('중복 확인'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 이메일 입력 필드 ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: '이메일',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isEmailChecked
                            ? Icon(
                                _isEmailAvailable
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _isEmailAvailable
                                    ? Colors.green
                                    : Colors.red,
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {
                        _isEmailChecked = false;
                        _isEmailAvailable = false;
                      }),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '이메일을 입력하세요';
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(v)) {
                          return '유효한 이메일을 입력하세요';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _checkEmail,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                    ),
                    child: const Text('중복 확인'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 비밀번호 입력 필드 ---
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                onSaved: (v) => _password = v?.trim() ?? '',
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
                  if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다';
                  final passwordRegex = RegExp(
                    r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$',
                  );
                  if (!passwordRegex.hasMatch(v)) {
                    return '비밀번호는 문자, 숫자, 특수문자를 모두 포함해야 합니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- 비밀번호 확인 필드 ---
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                onSaved: (v) => _confirmPassword = v?.trim() ?? '',
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호를 다시 입력하세요';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // --- 회원가입 버튼 ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _onSignupPressed,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: const Color(0xFF2A3439),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
