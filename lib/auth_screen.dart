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

  String _getErrorMessage(String message) {
    if (message.contains('Invalid login')) return 'メールまたはパスワードが間違っています';
    if (message.contains('User already registered')) return 'このメールは既に登録されています';
    if (message.contains('Password should be')) return 'パスワードは6文字以上必要です';
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'ログイン' : '新規登録'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flight_takeoff, size: 64, color: Colors.purple[700]),
                const SizedBox(height: 16),
                Text(_isLogin ? 'おかえりなさい！' : 'はじめまして！', 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('記録を保存してすごろくを進めよう！', 
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
