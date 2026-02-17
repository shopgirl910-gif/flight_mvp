import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'メールアドレスを入力してください');
      return;
    }

    if (_isLogin) {
      final password = _passwordController.text.trim();
      if (password.isEmpty) {
        setState(() => _errorMessage = 'パスワードを入力してください');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: _passwordController.text.trim(),
        );
        widget.onAuthSuccess();
      } else {
        // 新規登録: 仮パスワードで登録 → パスワード設定 → プロフィール設定
        final tempPassword = 'Temp${DateTime.now().millisecondsSinceEpoch}!';
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: tempPassword,
        );
        if (response.user != null) {
          await Supabase.instance.client.from('user_profiles').insert({
            'id': response.user!.id,
            'email': email,
            'quiz_total_correct': 0,
          });

          if (mounted) {
            setState(() => _isLoading = false);
            _showSetPasswordDialog();
          }
          return;
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = _getErrorMessage(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// パスワード設定後 → 既存のプロフィール設定画面へ
  void _goToProfileScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showSetPasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showPassword = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? dialogError;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('🔐 パスワードを設定'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '次回ログイン用のパスワードを設定してください。\n6文字以上で入力してください。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setDialogState(() => showPassword = !showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'パスワード確認',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setDialogState(() => showPassword = !showPassword),
                    ),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    dialogError!,
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        // アカウント削除処理
                        final userId =
                            Supabase.instance.client.auth.currentUser?.id;
                        if (userId != null) {
                          try {
                            await Supabase.instance.client.functions.invoke(
                              'delete-user',
                              body: {'userId': userId},
                            );
                          } catch (e) {
                            // エラーは無視
                          }
                        }

                        // 匿名ユーザーとして再ログイン
                        await Supabase.instance.client.auth.signInAnonymously();

                        if (mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newPass = newPasswordController.text.trim();
                        final confirmPass = confirmPasswordController.text
                            .trim();

                        if (newPass.isEmpty) {
                          setDialogState(() => dialogError = 'パスワードを入力してください');
                          return;
                        }
                        if (newPass.length < 6) {
                          setDialogState(() => dialogError = 'パスワードは6文字以上必要です');
                          return;
                        }
                        if (newPass != confirmPass) {
                          setDialogState(() => dialogError = 'パスワードが一致しません');
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          dialogError = null;
                        });

                        try {
                          await Supabase.instance.client.auth.updateUser(
                            UserAttributes(password: newPass),
                          );
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext);
                          _goToProfileScreen();
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            dialogError = 'エラー: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('設定する'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPasswordResetDialog() {
    final resetEmailController = TextEditingController();
    if (_emailController.text.trim().isNotEmpty) {
      resetEmailController.text = _emailController.text.trim();
    }

    showDialog(
      context: context,
      builder: (context) {
        String? dialogError;
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('パスワードリセット'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '登録済みのメールアドレスを入力してください。\nリセット用のリンクを送信します。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    dialogError!,
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty) {
                          setDialogState(
                            () => dialogError = 'メールアドレスを入力してください',
                          );
                          return;
                        }
                        if (!email.contains('@')) {
                          setDialogState(
                            () => dialogError = '正しいメールアドレスを入力してください',
                          );
                          return;
                        }

                        setDialogState(() {
                          isSending = true;
                          dialogError = null;
                        });

                        try {
                          await Supabase.instance.client.auth
                              .resetPasswordForEmail(email);
                          if (context.mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('$email にリセットメールを送信しました'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSending = false;
                            dialogError = 'エラーが発生しました: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                ),
                child: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('送信', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getErrorMessage(String message) {
    if (message.contains('Invalid login')) return 'メールまたはパスワードが間違っています';
    if (message.contains('User already registered')) return 'このメールは既に登録されています';
    if (message.contains('Password should be')) return 'パスワードは6文字以上必要です';
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'ログイン' : '新規登録'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                Icon(Icons.flight_takeoff, size: 64, color: Colors.purple[700]),
                const SizedBox(height: 16),
                Text(
                  _isLogin ? 'おかえりなさい！' : 'はじめまして！',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? (isJapanese
                            ? 'あなたの修行記録を残そう！'
                            : 'Keep track of your mileage run!')
                      : (isJapanese
                            ? 'メールアドレスだけで登録できます'
                            : 'Just enter your email to sign up'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),

                if (_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'パスワード',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 20),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isLogin ? 'ログイン' : 'メールで登録',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_isLogin)
                  TextButton(
                    onPressed: _isLoading ? null : _showPasswordResetDialog,
                    child: Text(
                      'パスワードを忘れた方',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = null;
                  }),
                  child: Text(
                    _isLogin ? 'アカウントを新規作成する' : 'ログインに戻る',
                    style: TextStyle(fontSize: 14, color: Colors.purple[700]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
