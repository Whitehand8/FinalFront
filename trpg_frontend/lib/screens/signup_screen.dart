import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/routers.dart';
import '../services/user_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  SignupScreenState createState() => SignupScreenState();
}

class SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  String _name = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // 중복 확인 상태
  bool _isEmailChecked = false;
  bool _isEmailAvailable = false;
  bool _isNicknameChecked = false;
  bool _isNicknameAvailable = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이메일을 입력해주세요.')));
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('유효한 이메일 형식이 아닙니다.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isAvailable = await UserService.instance.isEmailAvailable(email);
      if (!mounted) return;

      setState(() {
        _isEmailChecked = true;
        _isEmailAvailable = isAvailable;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAvailable ? '사용 가능한 이메일입니다.' : '이미 사용 중인 이메일입니다.'),
          backgroundColor: isAvailable ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이메일 확인 중 오류 발생')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty || nickname.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임은 2자 이상이어야 합니다.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isAvailable =
          await UserService.instance.isNicknameAvailable(nickname);
      if (!mounted) return;

      setState(() {
        _isNicknameChecked = true;
        _isNicknameAvailable = isAvailable;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAvailable ? '사용 가능한 닉네임입니다.' : '이미 사용 중인 닉네임입니다.'),
          backgroundColor: isAvailable ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임 확인 중 오류 발생')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSignupPressed() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (!_isEmailChecked || !_isEmailAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이메일 중복 확인을 완료해주세요.')));
      return;
    }
    if (!_isNicknameChecked || !_isNicknameAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임 중복 확인을 완료해주세요.')));
      return;
    }
    if (_password != _confirmPassword) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await UserService.instance.signup(
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
        context.go(Routes.login);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '회원가입에 실패했습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 중 네트워크 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: const Color(0xFF8C7853),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
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
                      onChanged: (_) {
                        setState(() {
                          _isNicknameChecked = false;
                          _isNicknameAvailable = false;
                        });
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) return '닉네임을 입력하세요';
                        if (v.trim().length < 2) return '닉네임은 2자 이상이어야 합니다';
                        if (v.trim().length > 20) return '닉네임은 20자 이하여야 합니다';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
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
                      onChanged: (_) {
                        setState(() {
                          _isEmailChecked = false;
                          _isEmailAvailable = false;
                        });
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) return '이메일을 입력하세요';
                        final emailRegex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(v)) {
                          return '유효한 이메일을 입력하세요';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
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
              TextFormField(
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                onSaved: (v) => _password = v?.trim() ?? '',
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
                  if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다';
                  final passwordRegex = RegExp(
                      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$');
                  if (!passwordRegex.hasMatch(v)) {
                    return '문자, 숫자, 특수문자를 모두 포함해야 합니다';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: '비밀번호 확인',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                onSaved: (v) => _confirmPassword = v?.trim() ?? '',
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호를 다시 입력하세요';
                  return null;
                },
                textInputAction: TextInputAction.done,
                onEditingComplete: _onSignupPressed,
              ),
              const SizedBox(height: 24),
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
                              fontSize: 18, fontWeight: FontWeight.bold),
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
