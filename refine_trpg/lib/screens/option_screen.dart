// =======================================================================
// 📲 IMPORTS & BASIC SETUP
// =======================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes.dart';
import '../services/navigation_service.dart';
import '../services/auth_service.dart';
import '../services/auth_state_manager.dart';
import '../services/settings_manager.dart';

/// 앱의 다양한 설정 옵션을 관리하는 화면입니다.
class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  // =======================================================================
  // 🔐 ACCOUNT MANAGEMENT METHODS (LOGOUT & DELETE)
  // =======================================================================

  /// 로그아웃 처리를 수행합니다.
  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService.clearToken();
      // AuthStateManager를 통해 앱의 로그인 상태를 업데이트합니다.
      Provider.of<AuthStateManager>(context, listen: false).logout();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다.')),
      );
      // 모든 이전 화면 기록을 삭제하고 메인 화면으로 이동합니다.
      NavigationService.pushAndRemoveUntil(Routes.main);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다.')),
      );
    }
  }

  /// 회원 탈퇴 확인 다이얼로그를 표시합니다.
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('회원탈퇴'),
          content: const Text('정말 계정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteAccount(context); // 실제 탈퇴 로직 호출
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('탈퇴'),
            ),
          ],
        );
      },
    );
  }

  /// 실제 회원 탈퇴를 처리하는 함수입니다.
  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final result = await AuthService.deleteAccount();
      if (!context.mounted) return;

      if (result['success']) {
        Provider.of<AuthStateManager>(context, listen: false).logout();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '계정이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        NavigationService.pushAndRemoveUntil(Routes.main);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '회원탈퇴에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원탈퇴 중 오류가 발생했습니다: ${e.toString()}')),
      );
    }
  }

  // =======================================================================
  // 🎨 UI BUILD METHOD
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    // Provider를 통해 SettingsManager의 상태를 구독합니다.
    final settings = context.watch<SettingsManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: const Color(0xFF8C7853),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationService.goBack(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // --- 일반 설정 ---
            Card(
              child: ListTile(
                title: const Text('알림'),
                trailing: Switch(
                  value: settings.notificationsEnabled,
                  onChanged: (value) {
                    context
                        .read<SettingsManager>()
                        .updateNotificationsEnabled(value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('알림 설정이 저장되었습니다.')),
                    );
                  },
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('사운드'),
                trailing: Switch(
                  value: settings.soundEnabled,
                  onChanged: (value) {
                    context.read<SettingsManager>().updateSoundEnabled(value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('사운드 설정이 저장되었습니다.')),
                    );
                  },
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('테마'),
                subtitle: Text(settings.themeModeToString()),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _showThemeSelectionDialog(context),
              ),
            ),
            const SizedBox(height: 20),

            // --- 계정 관리 ---
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('닉네임 변경'),
                onTap: () => _showNicknameChangeDialog(context),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('비밀번호 변경'),
                onTap: () => _showPasswordChangeDialog(context),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                onTap: () => _showLogoutDialog(context),
              ),
            ),
            Card(
              color: Colors.red[50],
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('회원탈퇴', style: TextStyle(color: Colors.red)),
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ),
            const SizedBox(height: 20),

            // --- 앱 정보 ---
            Card(
              child: ListTile(
                leading: const Icon(Icons.info),
                title: const Text('앱 정보'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'TRPG App',
                    applicationVersion: 'v1.0.0',
                    applicationLegalese: '© 2025 My TRPG Team',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // 🧩 DIALOG & HELPER WIDGETS
  // =======================================================================

  /// 비밀번호 변경 다이얼로그를 표시합니다.
  void _showPasswordChangeDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> changePassword() async {
              if (!formKey.currentState!.validate()) return;

              setState(() => isLoading = true);
              try {
                final result = await AuthService.updatePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );

                if (result['success']) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(result['message']),
                        backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                        content: Text(result['message']),
                        backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('비밀번호 변경 중 오류: ${e.toString()}')),
                );
              } finally {
                if (Navigator.of(context).canPop()) {
                  setState(() => isLoading = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('비밀번호 변경'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: LinearProgressIndicator(),
                      ),
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: const InputDecoration(
                          labelText: '현재 비밀번호', border: OutlineInputBorder()),
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '현재 비밀번호를 입력하세요.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: const InputDecoration(
                          labelText: '새 비밀번호', border: OutlineInputBorder()),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return '새 비밀번호를 입력하세요.';
                        if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                        final passwordRegex = RegExp(
                            r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$');
                        if (!passwordRegex.hasMatch(v))
                          return '문자, 숫자, 특수문자를 포함해야 합니다.';
                        if (v == currentPasswordController.text)
                          return '현재 비밀번호와 다른 비밀번호를 사용해주세요.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                          labelText: '새 비밀번호 확인', border: OutlineInputBorder()),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return '새 비밀번호를 다시 입력하세요.';
                        if (v != newPasswordController.text)
                          return '새 비밀번호가 일치하지 않습니다.';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('취소')),
                ElevatedButton(
                    onPressed: isLoading ? null : changePassword,
                    child: const Text('변경')),
              ],
            );
          },
        );
      },
    );
  }

  /// 닉네임 변경 다이얼로그를 표시합니다.
  void _showNicknameChangeDialog(BuildContext context) {
    final nicknameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool isNicknameChecked = false;
    bool isNicknameAvailable = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 닉네임 중복 확인 로직
            Future<void> checkNickname() async {
              if (!formKey.currentState!.validate()) return;
              setState(() => isLoading = true);
              try {
                final result = await AuthService.checkNicknameAvailability(
                  nickname: nicknameController.text.trim(),
                );
                setState(() {
                  isNicknameChecked = true;
                  isNicknameAvailable = result['success'];
                });
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor:
                        result['success'] ? Colors.green : Colors.red,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('닉네임 확인 중 오류: ${e.toString()}')),
                );
              } finally {
                setState(() => isLoading = false);
              }
            }

            // 닉네임 변경 로직
            Future<void> updateNickname() async {
              if (!isNicknameChecked || !isNicknameAvailable) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('닉네임 중복 확인을 먼저 완료해주세요.')),
                );
                return;
              }
              setState(() => isLoading = true);
              try {
                final result = await AuthService.updateNickname(
                  nickname: nicknameController.text.trim(),
                );
                if (result['success']) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(result['message']),
                        backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                        content: Text(result['message']),
                        backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('닉네임 변경 중 오류: ${e.toString()}')),
                );
              } finally {
                if (Navigator.of(context).canPop()) {
                  setState(() => isLoading = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('닉네임 변경'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: LinearProgressIndicator(),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nicknameController,
                            decoration: InputDecoration(
                              labelText: '새 닉네임',
                              border: const OutlineInputBorder(),
                              suffixIcon: isNicknameChecked
                                  ? Icon(
                                      isNicknameAvailable
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: isNicknameAvailable
                                          ? Colors.green
                                          : Colors.red,
                                    )
                                  : null,
                            ),
                            onChanged: (_) {
                              setState(() {
                                isNicknameChecked = false;
                                isNicknameAvailable = false;
                              });
                            },
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return '닉네임을 입력하세요.';
                              }
                              if (v.trim().length < 2) {
                                return '2자 이상 입력하세요.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading ? null : checkNickname,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 15),
                          ),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('취소')),
                ElevatedButton(
                  onPressed: (isLoading || !isNicknameAvailable)
                      ? null
                      : updateNickname,
                  child: const Text('변경'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 테마 선택 다이얼로그를 표시합니다.
  void _showThemeSelectionDialog(BuildContext context) {
    final settings = context.read<SettingsManager>();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('테마 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['기본', '라이트', '다크'].map((theme) {
              return RadioListTile<String>(
                title: Text(theme),
                value: theme,
                groupValue: settings.themeModeToString(),
                onChanged: (value) {
                  if (value != null) {
                    settings.updateTheme(value);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('테마가 $value(으)로 변경되었습니다.')),
                    );
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// 로그아웃 확인 다이얼로그를 표시합니다.
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }
}
