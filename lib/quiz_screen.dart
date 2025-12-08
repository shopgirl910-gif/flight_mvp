import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchTodayQuiz();
  }

  Future<void> _fetchTodayQuiz() async {
    try {
      // 今日の日付
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      // 今日のクイズを取得
      var response = await Supabase.instance.client
          .from('quizzes')
          .select()
          .eq('date', today)
          .maybeSingle();

      // 今日のクイズがなければランダムに1問取得
      if (response == null) {
        final allQuizzes = await Supabase.instance.client
            .from('quizzes')
            .select();
        
        if ((allQuizzes as List).isNotEmpty) {
          allQuizzes.shuffle();
          response = allQuizzes.first;
        }
      }

      setState(() {
        todayQuiz = response;
        isLoading = false;
      });
    } catch (e) {
      print('クイズ取得エラー: $e');
      setState(() => isLoading = false);
    }
  }

  void _submitAnswer(String answer) {
    if (hasAnswered) return;

    final correctAnswer = todayQuiz?['correct_answer'] as String?;
    
    setState(() {
      selectedAnswer = answer;
      isCorrect = (answer == correctAnswer);
      hasAnswered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日のクイズ'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : todayQuiz == null
              ? const Center(child: Text('クイズがありません'))
              : _buildQuizContent(),
    );
  }

  Widget _buildQuizContent() {
    final question = todayQuiz!['question'] as String? ?? '';
    final options = todayQuiz!['options'] as Map<String, dynamic>? ?? {};
    final category = todayQuiz!['category'] as String? ?? '';
    final correctAnswer = todayQuiz!['correct_answer'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリバッジ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getCategoryColor(category),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _getCategoryLabel(category),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),

          const SizedBox(height: 16),

          // 問題文
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                question,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 選択肢
          ...options.entries.map((entry) {
            final key = entry.key;
            final value = entry.value.toString();
            return _buildOptionButton(key, value, correctAnswer);
          }),

          const SizedBox(height: 24),

          // 結果表示
          if (hasAnswered) _buildResultCard(correctAnswer, options),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String key, String value, String correctAnswer) {
    Color? backgroundColor;
    Color? borderColor;
    
    if (hasAnswered) {
      if (key == correctAnswer) {
        backgroundColor = Colors.green[100];
        borderColor = Colors.green;
      } else if (key == selectedAnswer) {
        backgroundColor = Colors.red[100];
        borderColor = Colors.red;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: hasAnswered ? null : () => _submitAnswer(key),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor ?? Colors.grey[300]!,
                width: borderColor != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hasAnswered && key == correctAnswer
                        ? Colors.green
                        : Colors.orange[100],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasAnswered && key == correctAnswer
                            ? Colors.white
                            : Colors.orange[800],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (hasAnswered && key == correctAnswer)
                  const Icon(Icons.check_circle, color: Colors.green),
                if (hasAnswered && key == selectedAnswer && key != correctAnswer)
                  const Icon(Icons.cancel, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(String correctAnswer, Map<String, dynamic> options) {
    return Card(
      color: isCorrect! ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              isCorrect! ? Icons.celebration : Icons.sentiment_dissatisfied,
              size: 48,
              color: isCorrect! ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 8),
            Text(
              isCorrect! ? '正解！' : '不正解...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isCorrect! ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '正解: $correctAnswer (${options[correctAnswer]})',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'calculation':
        return Colors.blue;
      case 'route':
        return Colors.green;
      case 'trivia':
        return Colors.purple;
      case 'current':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'calculation':
        return '計算問題';
      case 'route':
        return 'ルート最適化';
      case 'trivia':
        return '航空トリビア';
      case 'current':
        return '時事問題';
      default:
        return category;
    }
  }
}
