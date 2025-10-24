
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refine_trpg/routes.dart';
import 'package:refine_trpg/services/navigation_service.dart';
import 'package:refine_trpg/services/auth_service.dart';
import 'package:refine_trpg/services/auth_state_manager.dart';
import 'package:refine_trpg/services/settings_manager.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// 앱의 다양한 설정 옵션을 관리하는 화면입니다.
class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  /// 로그아웃 처리를 수행합니다.
  Future<void> _logout(BuildContext context) async {
    // Show loading indicator or disable button here if needed
    try {
      await AuthService.clearToken();

      // [수정됨] context 사용 전 mounted 확인
      if (!context.mounted) return;

      // Use read for safety in async gaps
      context.read<AuthStateManager>().logout();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다.')),
      );
      // Navigate after state update
      NavigationService.pushAndRemoveUntil(Routes.main);
    } catch (e) {
      debugPrint("Logout error: $e");
      // [수정됨] context 사용 전 mounted 확인
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: ${e.toString()}')),
      );
    } finally {
      // Hide loading indicator here if used
    }
  }

  /// 회원 탈퇴 확인 다이얼로그를 표시합니다.
  void _showDeleteAccountDialog(BuildContext context) {
    // Check mounted before showing dialog
    if (!context.mounted) return;
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
                // Pass the original context (from build method) to the delete function
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
     // Show loading indicator or disable button here if needed
    try {
      final result = await AuthService.deleteAccount();

      // [수정됨] context 사용 전 mounted 확인
      if (!context.mounted) return;

      if (result['success']) {
         // Use read for safety in async gaps
        context.read<AuthStateManager>().logout();
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
      debugPrint("Delete account error: $e");
      // [수정됨] context 사용 전 mounted 확인
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원탈퇴 중 오류가 발생했습니다: ${e.toString()}')),
      );
    } finally {
       // Hide loading indicator here if used
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
        // backgroundColor: const Color(0xFF8C7853), // Or use theme color
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
            _buildSectionTitle('일반'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('알림'),
                trailing: Switch(
                  value: settings.notificationsEnabled,
                  onChanged: (value) {
                    // Use read for actions
                    context.read<SettingsManager>().updateNotificationsEnabled(value);
                    if (context.mounted) { // Check mounted before showing SnackBar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('알림 설정 저장됨'), duration: Duration(seconds: 1)),
                      );
                    }
                  },
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: const Text('사운드'),
                trailing: Switch(
                  value: settings.soundEnabled,
                  onChanged: (value) {
                    context.read<SettingsManager>().updateSoundEnabled(value);
                     if (context.mounted) { // Check mounted
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('사운드 설정 저장됨'), duration: Duration(seconds: 1)),
                       );
                    }
                  },
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.color_lens_outlined),
                title: const Text('테마'),
                subtitle: Text(settings.themeModeToString()), // Display current theme
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeSelectionDialog(context),
              ),
            ),
            const SizedBox(height: 24), // Increased spacing

            // --- 계정 관리 ---
             _buildSectionTitle('계정'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('닉네임 변경'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showNicknameChangeDialog(context),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('비밀번호 변경'),
                 trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPasswordChangeDialog(context),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('로그아웃'),
                 trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLogoutDialog(context),
              ),
            ),
            Card(
              // color: Colors.red[50], // Use theme error color container?
              child: ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                title: Text('회원탈퇴', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ),
            const SizedBox(height: 24), // Increased spacing

            // --- 앱 정보 ---
            _buildSectionTitle('정보'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('앱 정보'),
                 trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Refined TRPG', // Updated name
                    applicationVersion: '0.1.0', // Example version
                    applicationLegalese: '© 2025 Raughtale Team', // Example
                    // applicationIcon: Image.asset('assets/icon/app_icon.png', width: 48, height: 48), // Add app icon if available
                  );
                },
              ),
            ),
             // Add link to privacy policy or terms of service if applicable
             // Card(child: ListTile( ... )),
          ],
        ),
      ),
    );
  }

  // Helper widget for section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700], // Or use theme color
        ),
      ),
    );
  }


  // =======================================================================
  // 🧩 DIALOG & HELPER WIDGETS
  // =======================================================================

  /// 비밀번호 변경 다이얼로그를 표시합니다.
  void _showPasswordChangeDialog(BuildContext context) {
    // Check mounted before showing dialog
    if (!context.mounted) return;

    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false; // State for loading indicator within the dialog

    showDialog(
      context: context,
      barrierDismissible: !isLoading, // Prevent dismissal while loading
      builder: (dialogContext) {
        // Use StatefulBuilder to manage isLoading state within the dialog
        return StatefulBuilder(
          builder: (stfContext, stfSetState) { // Use stfContext and stfSetState
            // Actual password change logic
            Future<void> changePassword() async {
              if (!formKey.currentState!.validate()) return; // Validate first

              stfSetState(() => isLoading = true); // Show loading indicator
              String? errorMessage; // Store potential error message

              try {
                final result = await AuthService.updatePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );

                // Check mounted status *before* using context after await
                if (!dialogContext.mounted) return;

                if (result['success']) {
                  Navigator.of(dialogContext).pop(); // Close dialog on success
                  ScaffoldMessenger.of(context).showSnackBar( // Show on main screen
                    SnackBar(
                        content: Text(result['message'] ?? '비밀번호 변경 성공'),
                        backgroundColor: Colors.green),
                  );
                  return; // Exit function on success
                } else {
                  errorMessage = result['message']; // Store error message from result
                }
              } catch (e) {
                 debugPrint("Password change error: $e");
                 errorMessage = '비밀번호 변경 중 오류 발생';
              } finally {
                 // Check mounted status again before calling stfSetState
                 if (stfContext.mounted) {
                   stfSetState(() => isLoading = false); // Hide loading indicator
                 }
              }

              // Show error message if not successful
              if (errorMessage != null && dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.redAccent),
                  );
              }
            }

            // Dialog UI
            return AlertDialog(
              title: const Text('비밀번호 변경'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Fit content height
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: LinearProgressIndicator(), // Show loading bar
                      ),
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: const InputDecoration(labelText: '현재 비밀번호'),
                      obscureText: true,
                      enabled: !isLoading, // Disable fields while loading
                      validator: (v) => (v == null || v.isEmpty) ? '현재 비밀번호를 입력하세요.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: const InputDecoration(labelText: '새 비밀번호'),
                      obscureText: true,
                      enabled: !isLoading,
                      validator: (v) {
                        if (v == null || v.isEmpty) return '새 비밀번호를 입력하세요.';
                        if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                        // Basic complexity check (example: require letter and number)
                        // More complex rules might be needed based on backend requirements
                        final hasLetter = v.contains(RegExp(r'[a-zA-Z]'));
                        final hasNumber = v.contains(RegExp(r'\d'));
                        if (!hasLetter || !hasNumber) return '문자와 숫자를 포함해야 합니다.';
                        // Ensure it's different from the current password
                        if (v == currentPasswordController.text) return '현재 비밀번호와 다른 비밀번호를 사용해주세요.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                      obscureText: true,
                      enabled: !isLoading,
                      validator: (v) {
                        if (v == null || v.isEmpty) return '새 비밀번호를 다시 입력하세요.';
                        if (v != newPasswordController.text) return '새 비밀번호가 일치하지 않습니다.';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    // Disable cancel while loading
                    onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('취소')),
                ElevatedButton(
                    // Disable button while loading
                    onPressed: isLoading ? null : changePassword,
                    child: const Text('변경하기')),
              ],
            );
          },
        );
      },
    );
  }


  /// 닉네임 변경 다이얼로그를 표시합니다.
  void _showNicknameChangeDialog(BuildContext context) {
    // Check mounted before showing dialog
    if (!context.mounted) return;

    final nicknameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool isNicknameChecked = false; // Was the availability check performed?
    bool isNicknameAvailable = false; // Is the currently entered nickname available?

    showDialog(
      context: context,
      barrierDismissible: !isLoading, // Prevent dismissal while loading
      builder: (dialogContext) {
        // Use StatefulBuilder for managing state within the dialog
        return StatefulBuilder(
          builder: (stfContext, stfSetState) { // Use specific context/setState

            // --- Nickname Availability Check Logic ---
            Future<void> checkNickname() async {
              // Validate only the nickname field for this check
              final isNicknameValid = formKey.currentState?.validate() ?? false;
              if (!isNicknameValid) return; // Don't proceed if format is wrong

              stfSetState(() => isLoading = true); // Show loading
              String? message;
              bool success = false;

              try {
                final result = await AuthService.checkNicknameAvailability(
                  nickname: nicknameController.text.trim(),
                );
                message = result['message'];
                success = result['success'];
              } catch (e) {
                 debugPrint("Nickname check error: $e");
                 message = '닉네임 확인 중 오류 발생';
              } finally {
                 // Check mounted before updating state
                 if (stfContext.mounted) {
                   stfSetState(() {
                     isLoading = false;
                     isNicknameChecked = true; // Mark check as performed
                     isNicknameAvailable = success; // Store availability result
                   });
                 }
              }

              // Show result in dialog's SnackBar
               if (message != null && dialogContext.mounted) {
                 ScaffoldMessenger.of(dialogContext).showSnackBar(
                   SnackBar(
                     content: Text(message),
                     backgroundColor: success ? Colors.green : Colors.redAccent,
                     duration: const Duration(seconds: 2),
                   ),
                 );
               }
            }

            // --- Nickname Update Logic ---
            Future<void> updateNickname() async {
              // Ensure nickname was checked and is available
              if (!isNicknameChecked || !isNicknameAvailable) {
                 if (dialogContext.mounted) {
                   ScaffoldMessenger.of(dialogContext).showSnackBar(
                     const SnackBar(content: Text('사용 가능한 닉네임인지 먼저 확인해주세요.')),
                   );
                 }
                return;
              }
              // Full form validation before final update
               if (!formKey.currentState!.validate()) return;

              stfSetState(() => isLoading = true); // Show loading
              String? message;
              bool success = false;

              try {
                final result = await AuthService.updateNickname(
                  newNickname: nicknameController.text.trim(), // Correct parameter name
                );
                message = result['message'];
                success = result['success'];

                // Check mounted before interacting with context after await
                if (!dialogContext.mounted) return;

                if (success) {
                  Navigator.of(dialogContext).pop(); // Close dialog on success
                  ScaffoldMessenger.of(context).showSnackBar( // Show on main screen
                    SnackBar(
                        content: Text(message ?? '닉네임 변경 성공'),
                        backgroundColor: Colors.green),
                  );
                  // Optionally update user info in a local state manager if needed
                  return; // Exit on success
                }
              } catch (e) {
                 debugPrint("Nickname update error: $e");
                 message = '닉네임 변경 중 오류 발생';
              } finally {
                 // Check mounted before updating state
                 if (stfContext.mounted) {
                   stfSetState(() => isLoading = false);
                 }
              }

              // Show error message if update failed
              if (message != null && dialogContext.mounted) {
                 ScaffoldMessenger.of(dialogContext).showSnackBar(
                   SnackBar(
                     content: Text(message),
                     backgroundColor: Colors.redAccent,
                   ),
                 );
              }
            }

            // --- Dialog UI ---
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
                      crossAxisAlignment: CrossAxisAlignment.start, // Align button properly
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nicknameController,
                            enabled: !isLoading,
                            decoration: InputDecoration(
                              labelText: '새 닉네임',
                              hintText: '2자 이상',
                              border: const OutlineInputBorder(),
                              // Show check/cancel icon based on availability check result
                              suffixIcon: isNicknameChecked
                                  ? Icon(
                                      isNicknameAvailable ? Icons.check_circle_outline : Icons.highlight_off,
                                      color: isNicknameAvailable ? Colors.green : Colors.red,
                                    )
                                  : null, // No icon if not checked yet
                            ),
                            // Reset check status when text changes
                            onChanged: (_) {
                              if (isNicknameChecked && stfContext.mounted) {
                                stfSetState(() {
                                  isNicknameChecked = false;
                                  isNicknameAvailable = false;
                                });
                              }
                            },
                            validator: (v) {
                              final trimmed = v?.trim() ?? '';
                              if (trimmed.isEmpty) return '닉네임을 입력하세요.';
                              if (trimmed.length < 2) return '닉네임은 2자 이상이어야 합니다.';
                              // Add other validation rules if needed (e.g., allowed characters)
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Availability Check Button
                        ElevatedButton(
                          onPressed: isLoading ? null : checkNickname,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15), // Adjust padding
                          ),
                          child: const Text('중복확인'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('취소')),
                // Update Button - Enabled only if checked and available
                ElevatedButton(
                  onPressed: (isLoading || !isNicknameChecked || !isNicknameAvailable)
                      ? null // Disable if loading, not checked, or not available
                      : updateNickname,
                  child: const Text('변경하기'),
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
    if (!context.mounted) return;

    final settings = context.read<SettingsManager>();
    final currentThemeString = settings.themeModeToString();

    // [수정됨] 테마 옵션 목록을 함수 내부에 직접 정의
    const List<String> themeOptions = ['기본', '라이트', '다크'];
    // TODO: 또는 SettingsManager 클래스 내부에 static const List<String> themeOptions = [...] 로 정의하고 SettingsManager.themeOptions 로 접근

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('테마 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            // [수정됨] 직접 정의한 themeOptions 리스트 사용
            children: themeOptions.map((themeString) {
              return RadioListTile<String>(
                title: Text(themeString),
                value: themeString,
                groupValue: currentThemeString,
                onChanged: (value) {
                  if (value != null) {
                    settings.updateTheme(value); // SettingsManager 업데이트 호출
                    Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('테마가 $value(으)로 변경되었습니다.'), duration: const Duration(seconds: 2)),
                      );
                    }
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }


  /// 로그아웃 확인 다이얼로그를 표시합니다.
  void _showLogoutDialog(BuildContext context) {
     // Check mounted before showing dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Use dialogContext
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // Close this dialog
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close this dialog
                _logout(context); // Call logout using the original screen's context
              },
              style: ElevatedButton.styleFrom(
                 backgroundColor: Theme.of(context).colorScheme.primary, // Use theme color
                 foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }

} // End of OptionsScreen