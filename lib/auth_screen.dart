import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'メールとパスワードを入力してください');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      } else {
        final response = await Supabase.instance.client.auth.signUp(email: email, password: password);
        if (response.user != null) {
          // 新規登録時にuser_profilesにレコード作成
          await Supabase.instance.client.from('user_profiles').insert({
            'id': response.user!.id,
            'email': email,
            'quiz_total_correct': 0,
          });
        }
      }
      widget.onAuthSuccess();
    } on AuthException catch (e) {
      setState(() => _errorMessage = _getErrorMessage(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'エラー: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  void _showPasswordResetDialog() {
    final resetEmailController = TextEditingController();
    // ログイン画面のメールアドレスが入っていたら初期値にセット
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
                  Text(dialogError!, style: TextStyle(color: Colors.red[700], fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: isSending ? null : () async {
                  final email = resetEmailController.text.trim();
                  if (email.isEmpty) {
                    setDialogState(() => dialogError = 'メールアドレスを入力してください');
                    return;
                  }
                  if (!email.contains('@')) {
                    setDialogState(() => dialogError = '正しいメールアドレスを入力してください');
                    return;
                  }

                  setDialogState(() { isSending = true; dialogError = null; });

                  try {
                    await Supabase.instance.client.auth.resetPasswordForEmail(email);
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
                child: isSending
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                Text(_isLogin ? 'おかえりなさい！' : 'はじめまして！', 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(isJapanese ? 'あなたの修行記録を残そう！' : 'Keep track of your mileage run!',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, 
                            style: TextStyle(color: Colors.red[700], fontSize: 13)),
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
                      ? const SizedBox(width: 20, height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : Text(_isLogin ? 'ログイン' : '登録', 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  onPressed: () => setState(() { _isLogin = !_isLogin; _errorMessage = null; }),
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
