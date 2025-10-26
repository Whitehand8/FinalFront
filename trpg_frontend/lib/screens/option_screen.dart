// lib/screens/options_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../router/routers.dart';
import '../services/auth_service.dart';
import '../services/settings_manager.dart';
import '../services/user_service.dart';

/// 앱의 다양한 설정 옵션을 관리하는 화면입니다.
class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  /// 로그아웃 처리를 수행합니다.
  Future<void> _logout(BuildContext context) async {
    try {
      // AuthService가 토큰 삭제 + 상태 업데이트 + 서버 로그아웃 요청을 모두 처리
      await AuthService.instance.logout();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다.')),
      );

      // GoRouter로 로그인 페이지 이동
      context.go(Routes.login);
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
                _deleteAccount(context);
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
      final result = await AuthService.instance.deleteAccount();
      if (!context.mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '계정이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go(Routes.login);
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

  void _showNicknameChangeDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;
    bool isChecked = false;
    bool isAvailable = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> check() async {
              final nickname = controller.text.trim();
              if (nickname.isEmpty || nickname.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('닉네임은 2자 이상이어야 합니다.')),
                );
                return;
              }
              setState(() => isLoading = true);
              try {
                final available =
                    await UserService.instance.isNicknameAvailable(nickname);
                setState(() {
                  isChecked = true;
                  isAvailable = available;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(available ? '사용 가능한 닉네임입니다.' : '이미 사용 중입니다.'),
                    backgroundColor: available ? Colors.green : Colors.red,
                  ),
                );
              } finally {
                setState(() => isLoading = false);
              }
            }

            Future<void> update() async {
              if (!isChecked || !isAvailable) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('닉네임 중복 확인을 완료해주세요.')),
                );
                return;
              }
              setState(() => isLoading = true);
              try {
                final result = await UserService.instance
                    .updateNickname(controller.text.trim());
                if (result['success'] == true) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? '닉네임 변경 성공')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? '닉네임 변경 실패')),
                  );
                }
              } finally {
                setState(() => isLoading = false);
              }
            }

            return AlertDialog(
              title: const Text('닉네임 변경'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading) const LinearProgressIndicator(),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: '새 닉네임',
                            border: const OutlineInputBorder(),
                            suffixIcon: isChecked
                                ? Icon(
                                    isAvailable
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color:
                                        isAvailable ? Colors.green : Colors.red,
                                  )
                                : null,
                          ),
                          onChanged: (_) => setState(() {
                            isChecked = false;
                            isAvailable = false;
                          }),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return '입력하세요';
                            if (v.trim().length < 2) return '2자 이상';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: isLoading ? null : check,
                          child: const Text('확인')),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소')),
                ElevatedButton(
                  onPressed:
                      (!isChecked || !isAvailable || isLoading) ? null : update,
                  child: const Text('변경'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPasswordChangeDialog(BuildContext context) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> change() async {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('새 비밀번호가 일치하지 않습니다.')),
                );
                return;
              }
              setState(() => isLoading = true);
              try {
                final result = await UserService.instance.updatePassword(
                  currentPassword: currentController.text,
                  newPassword: newController.text,
                );
                if (result['success'] == true) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? '비밀번호 변경 성공')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? '비밀번호 변경 실패')),
                  );
                }
              } finally {
                setState(() => isLoading = false);
              }
            }

            return AlertDialog(
              title: const Text('비밀번호 변경'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading) const LinearProgressIndicator(),
                  TextFormField(
                    controller: currentController,
                    decoration: const InputDecoration(
                        labelText: '현재 비밀번호', border: OutlineInputBorder()),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: newController,
                    decoration: const InputDecoration(
                        labelText: '새 비밀번호', border: OutlineInputBorder()),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: confirmController,
                    decoration: const InputDecoration(
                        labelText: '새 비밀번호 확인', border: OutlineInputBorder()),
                    obscureText: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소')),
                ElevatedButton(
                    onPressed: isLoading ? null : change,
                    child: const Text('변경')),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // SettingsManager는 그대로 사용 (UI 설정과 무관)
    final settings = context.watch<SettingsManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: const Color(0xFF8C7853),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.rooms),
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
                child: const Text('취소')),
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
