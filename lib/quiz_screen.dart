import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'auth_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Map<String, dynamic>? todayQuiz;
  bool isLoading = true;
  String? selectedAnswer;
  bool? isCorrect;
  bool hasAnswered = false;
  
  int totalCorrect = 0;
  String? lastCorrectDate;
  bool alreadyAnsweredToday = false;

  bool get isLoggedIn {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
    // ログイン状態の変化を監視
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        // ログイン時
        _fetchUserProgress();
        setState(() {});
      } else {
        // ログアウト時 - 状態をリセット
        setState(() {
          selectedAnswer = null;
          isCorrect = null;
          hasAnswered = false;
          totalCorrect = 0;
          lastCorrectDate = null;
          alreadyAnsweredToday = false;
        });
      }
    });
  }

  Future<void> _fetchData() async {
    await _fetchTodayQuiz();
    if (isLoggedIn) await _fetchUserProgress();
  }

  Future<void> _fetchTodayQuiz() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      var response = await Supabase.instance.client.from('quizzes').select().eq('date', today).maybeSingle();
      if (response == null) {
        final allQuizzes = await Supabase.instance.client.from('quizzes').select();
        if ((allQuizzes as List).isNotEmpty) { allQuizzes.shuffle(); response = allQuizzes.first; }
      }
      setState(() { todayQuiz = response; isLoading = false; });
    } catch (e) { setState(() => isLoading = false); }
  }

  Future<void> _fetchUserProgress() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('quiz_total_correct, quiz_last_correct')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        setState(() {
          totalCorrect = response['quiz_total_correct'] ?? 0;
          lastCorrectDate = response['quiz_last_correct'];
          alreadyAnsweredToday = (lastCorrectDate == today);
        });
      }
    } catch (e) {}
  }

  Future<void> _updateProgress() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      await Supabase.instance.client.from('user_profiles').update({
        'quiz_total_correct': totalCorrect + 1,
        'quiz_last_correct': today,
      }).eq('id', userId);
      
      setState(() {
        totalCorrect += 1;
        lastCorrectDate = today;
        alreadyAnsweredToday = true;
      });
    } catch (e) {}
  }

  void _onOptionTap(String answer) async {
    if (hasAnswered) return;
    
    // ファイナルアンサー確認
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$answer でファイナルアンサー？'),
        content: !isLoggedIn 
          ? const Text('⚠️ ログインしないと修行ロードが進みません', 
              style: TextStyle(color: Colors.orange, fontSize: 13))
          : null,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('やめる')),
          if (!isLoggedIn)
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
                Navigator.push(context, MaterialPageRoute(builder: (context) => AuthScreen(onAuthSuccess: () { Navigator.pop(context); _fetchUserProgress(); setState(() {}); })));
              },
              child: const Text('ログイン', style: TextStyle(color: Colors.purple)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B3A8B), foregroundColor: Colors.white),
            child: const Text('答える'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // 未ログインの場合はログイン画面へ遷移
    if (!isLoggedIn) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ログインが必要です'),
          content: const Text('修行ロードを進めるにはログインが必要です。\nログイン画面に移動しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
              child: const Text('ログインする'),
            ),
          ],
        ),
      );
      
      if (shouldProceed == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AuthScreen(
              onAuthSuccess: () {
                Navigator.pop(context);
                _fetchUserProgress();
                setState(() {});
              },
            ),
          ),
        );
      }
      return;
    }
    
    _submitAnswer(answer);
  }

  void _showLoginDialog() {
    // main.dartのAuthDialogを使用するため、親ウィジェットに通知
    showDialog(
      context: context,
      builder: (context) => _buildLoginDialog(),
    );
  }

  Widget _buildLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLogin = true;
    bool isLoading = false;
    String? errorMessage;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> submit() async {
          final email = emailController.text.trim();
          final password = passwordController.text.trim();
          if (email.isEmpty || password.isEmpty) {
            setDialogState(() => errorMessage = 'メールとパスワードを入力してください');
            return;
          }
          setDialogState(() { isLoading = true; errorMessage = null; });
          try {
            if (isLogin) {
              await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
            } else {
              final response = await Supabase.instance.client.auth.signUp(email: email, password: password);
              if (response.user != null) {
                await Supabase.instance.client.from('user_profiles').insert({
                  'id': response.user!.id, 'email': email, 'quiz_total_correct': 0,
                });
              }
            }
            Navigator.pop(context);
            _fetchUserProgress();
            setState(() {});
          } on AuthException catch (e) {
            setDialogState(() => errorMessage = e.message);
          } catch (e) {
            setDialogState(() => errorMessage = 'エラー: $e');
          } finally {
            setDialogState(() => isLoading = false);
          }
        }

        return AlertDialog(
          title: Text(isLogin ? 'ログイン' : '新規登録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'メールアドレス', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'パスワード', border: OutlineInputBorder(), isDense: true), obscureText: true),
              if (errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => setDialogState(() { isLogin = !isLogin; errorMessage = null; }), child: Text(isLogin ? 'アカウント作成' : 'ログインに戻る', style: const TextStyle(fontSize: 12))),
            ElevatedButton(
              onPressed: isLoading ? null : submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B3A8B), foregroundColor: Colors.white),
              child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isLogin ? 'ログイン' : '登録'),
            ),
          ],
        );
      },
    );
  }

  void _submitAnswer(String answer) {
    final correct = (answer == todayQuiz?['correct_answer']);
    setState(() { selectedAnswer = answer; isCorrect = correct; hasAnswered = true; });
    
    if (correct && isLoggedIn && !alreadyAnsweredToday) {
      _updateProgress();
    }
  }

  Map<String, dynamic> _parseOptions() {
    final raw = todayQuiz?['options'];
    if (raw == null) return {};
    if (raw is String) return jsonDecode(raw);
    return raw as Map<String, dynamic>;
  }

  String _getTitle(int total) {
    if (total >= 1000) return 'グランドマスター';
    if (total >= 500) return 'ミリオンマイラー';
    if (total >= 200) return 'JGC/SFC';
    if (total >= 100) return 'ダイヤモンド';
    if (total >= 50) return 'サファイア';
    if (total >= 30) return 'プラチナ';
    if (total >= 15) return 'クリスタル';
    if (total >= 5) return 'ブロンズ';
    return '一般会員';
  }

  int _getNextMilestone(int total) {
    if (total < 5) return 5;
    if (total < 15) return 15;
    if (total < 30) return 30;
    if (total < 50) return 50;
    if (total < 100) return 100;
    if (total < 200) return 200;
    if (total < 500) return 500;
    if (total < 1000) return 1000;
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildQuizSection()),
        Expanded(child: isLoggedIn ? _buildProgressSection() : _buildLoginPrompt()),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flight_takeoff, size: 48, color: Color(0xFF8B3A8B)),
            const SizedBox(height: 12),
            const Text('修行ロードを進めよう！', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('ログインするとクイズの正解記録が保存され、\n称号を獲得できます', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AuthScreen(
                      onAuthSuccess: () {
                        Navigator.pop(context);
                        _fetchUserProgress();
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('ログイン / 新規登録'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizSection() {
    if (todayQuiz == null) return const Center(child: Text('クイズがありません'));

    final question = todayQuiz!['question'] as String? ?? '';
    final options = _parseOptions();
    final category = todayQuiz!['category'] as String? ?? '';
    final correctAnswer = todayQuiz!['correct_answer'] as String? ?? '';
    final explanation = options['explanation'] as String? ?? '';
    final answerKeys = ['A', 'B', 'C', 'D'].where((k) => options.containsKey(k)).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _getCategoryColor(category), borderRadius: BorderRadius.circular(8)),
                child: Text(_getCategoryLabel(category), style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 10),
          ...answerKeys.map((key) => _buildOptionRow(key, options[key]?.toString() ?? '', correctAnswer)),
          const SizedBox(height: 10),
          if (hasAnswered) _buildResultCompact(correctAnswer, explanation),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String key, String value, String correctAnswer) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey[300]!;
    if (hasAnswered) {
      if (key == correctAnswer) { bgColor = Colors.green[100]!; borderColor = Colors.green; }
      else if (key == selectedAnswer) { bgColor = Colors.red[100]!; borderColor = Colors.red; }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: hasAnswered ? null : () => _onOptionTap(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(color: hasAnswered && key == correctAnswer ? Colors.green : Colors.purple[100], shape: BoxShape.circle),
                child: Center(child: Text(key, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hasAnswered && key == correctAnswer ? Colors.white : Colors.purple[800]))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
              if (hasAnswered && key == correctAnswer) const Icon(Icons.check, color: Colors.green, size: 16),
              if (hasAnswered && key == selectedAnswer && key != correctAnswer) const Icon(Icons.close, color: Colors.red, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCompact(String correctAnswer, String explanation) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: isCorrect! ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCorrect! ? Icons.check_circle : Icons.cancel, color: isCorrect! ? Colors.green : Colors.red, size: 18),
              const SizedBox(width: 4),
              Text(isCorrect! ? '正解！' : '不正解', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isCorrect! ? Colors.green : Colors.red)),
              if (isCorrect! && isLoggedIn && !alreadyAnsweredToday) const Text(' +1問！', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(explanation, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final currentPos = totalCorrect % 10;
    final lap = (totalCorrect ~/ 10) + 1;
    final title = _getTitle(totalCorrect);
    final nextMilestone = _getNextMilestone(totalCorrect);
    final remaining = nextMilestone - totalCorrect;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('✈️ $title', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          
          Text('修行ロード: $totalCorrect問正解 | 第${lap}周', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF546E7A), Color(0xFF37474F)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(10, (index) {
                final isCurrent = index == currentPos;
                final isDone = index < currentPos;
                final isGoal = index == 9;
                
                return Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isCurrent ? Colors.orange : (isDone ? Colors.green : Colors.transparent),
                    border: Border.all(
                      color: isGoal ? Colors.amber : (isCurrent ? Colors.orange : (isDone ? Colors.green : Colors.blueGrey)),
                      width: 2,
                      style: isDone || isCurrent ? BorderStyle.solid : BorderStyle.none,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCurrent
                        ? const Text('✈', style: TextStyle(fontSize: 12))
                        : isGoal
                            ? const Text('🏁', style: TextStyle(fontSize: 10))
                            : Text('${index + 1}', style: TextStyle(fontSize: 9, color: isDone ? Colors.white : Colors.blueGrey)),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            totalCorrect >= 1000 ? '🎉 最高称号達成！' : '次の称号「${_getTitle(nextMilestone)}」まで: あと${remaining}問',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    return {'calculation': Colors.blue, 'optimization': Colors.green, 'trivia': Colors.purple, 'news': Colors.orange}[category] ?? Colors.grey;
  }

  String _getCategoryLabel(String category) {
    return {'calculation': '計算', 'optimization': '最適化', 'trivia': 'トリビア', 'news': '時事'}[category] ?? category;
  }
}