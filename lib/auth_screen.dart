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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_isLogin ? 'ログイン' : '新規登録', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('記録を保存してすごろくを進めよう！', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 24),
          
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'メールアドレス', border: OutlineInputBorder(), isDense: true),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'パスワード', border: OutlineInputBorder(), isDense: true),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B3A8B), foregroundColor: Colors.white),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isLogin ? 'ログイン' : '登録'),
            ),
          ),
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: () => setState(() { _isLogin = !_isLogin; _errorMessage = null; }),
            child: Text(_isLogin ? 'アカウントを作成' : 'ログインに戻る', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
