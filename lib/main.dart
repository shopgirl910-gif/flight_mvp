import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'simulation_screen.dart';
import 'flight_log_screen.dart';
import 'quiz_screen.dart';
import 'checkin_screen.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'pro_purchase_dialog.dart';
import 'pro_service.dart';
import 'mrp_logo.dart';
import 'badge_widget.dart';
import 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ipxlsygkxgmramrjazhj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlweGxzeWdreGdtcmFtcmphemhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0Njk4MDgsImV4cCI6MjA4MDA0NTgwOH0.ZFr2MgXRA2Lx1xaDWqAPOSxf6N4kVtTq2IRbdlJrnjw',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(locale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ja');

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MRP - Mileage Run Planner',
      theme: ThemeData(primarySwatch: Colors.purple),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      locale: _locale,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _flightLogKey = GlobalKey<FlightLogScreenState>();
  
  // バッジ用カウント
  int _airportCount = 0;
  int _legCount = 0;
  int _quizCount = 0;

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
    _handleAuthStateChange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPasswordRecovery();
      _checkPaymentResult();
      _loadBadgeData();
    });
  }

  Future<void> _loadBadgeData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      // 空港チェックイン数（ユニーク空港数）
      final airports = await Supabase.instance.client
          .from('airport_checkins')
          .select('airport_code')
          .eq('user_id', user.id);
      final airportSet = <String>{};
      for (final row in airports) {
        airportSet.add(row['airport_code'] as String);
      }

      // 修行済みレグ数
      final itineraries = await Supabase.instance.client
          .from('saved_itineraries')
          .select('legs')
          .eq('user_id', user.id)
          .eq('is_completed', true);
      int totalLegs = 0;
      for (final row in itineraries) {
        final legs = row['legs'] as List?;
        if (legs != null) totalLegs += legs.length;
      }

      // クイズ正解数（user_profilesから取得）
      final quizData = await Supabase.instance.client
          .from('user_profiles')
          .select('quiz_total_correct')
          .eq('id', user.id)
          .maybeSingle();
      final quizCorrect = (quizData?['quiz_total_correct'] as int?) ?? 0;

      if (mounted) {
        setState(() {
          _airportCount = airportSet.length;
          _legCount = totalLegs;
          _quizCount = quizCorrect;
        });
      }
    } catch (e) {
      debugPrint('Badge data load error: $e');
    }
  }

  Future<void> _ensureSignedIn() async {
    final uri = Uri.base;
    if (uri.fragment.contains('type=recovery')) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      await Supabase.instance.client.auth.signInAnonymously();
    }
  }

  void _handleAuthStateChange() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _showNewPasswordDialog();
      }
      if (mounted) {
        setState(() {});
        _loadBadgeData(); // ログイン状態変更時にバッジ再読み込み
      }
    });
  }

  void _checkForPasswordRecovery() {
    final uri = Uri.base;
    if (uri.fragment.contains('type=recovery')) {
      _showNewPasswordDialog();
    }
  }

  void _showNewPasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? dialogError;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('新しいパスワードを設定'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新しいパスワード',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'パスワード確認',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.lock_outline),
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
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newPass = newPasswordController.text.trim();
                        final confirmPass =
                            confirmPasswordController.text.trim();

                        if (newPass.isEmpty) {
                          setDialogState(
                            () => dialogError = 'パスワードを入力してください',
                          );
                          return;
                        }
                        if (newPass.length < 6) {
                          setDialogState(
                            () => dialogError = 'パスワードは6文字以上必要です',
                          );
                          return;
                        }
                        if (newPass != confirmPass) {
                          setDialogState(
                            () => dialogError = 'パスワードが一致しません',
                          );
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
                          if (context.mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('パスワードを更新しました'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          String msg = e.toString();
                          if (msg.contains('same_password')) {
                            final isJa =
                                Localizations.localeOf(this.context)
                                    .languageCode ==
                                'ja';
                            msg = isJa
                                ? '現在と同じパスワードは使えません'
                                : 'New password must be different from the current one';
                          }
                          setDialogState(() {
                            isSaving = false;
                            dialogError = msg;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
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
                    : const Text(
                        '更新',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _checkPaymentResult() {
    final uri = Uri.base;
    final payment = uri.queryParameters['payment'];

    if (payment == 'success') {
      html.window.history.replaceState(null, '', uri.path);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('🎉 ご購入ありがとうございます！'),
            content: const Text(
              'Pro版が有効になりました。\n\n'
              '全機能をお楽しみください！',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    } else if (payment == 'cancel') {
      html.window.history.replaceState(null, '', uri.path);
    }
  }

  bool get _isLoggedIn {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  String get _displayName {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return 'Login';
    final email = user.email ?? '';
    if (email.length > 15) return '${email.substring(0, 12)}...';
    return email;
  }

  List<String> _getTabLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [l10n.tabSimulate, l10n.tabLog, l10n.tabQuiz, l10n.tabCheckin];
  }

  late final List<Widget> _screens = [
    const SimulationScreen(),
    FlightLogScreen(key: _flightLogKey),
    const QuizScreen(),
    const CheckinScreen(),
  ];

  void _showUserMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<bool>(
        future: ProService().isPro(),
        builder: (context, snapshot) {
          final isPro = snapshot.data ?? false;

          return AlertDialog(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ユーザー情報
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.purple[100],
                        child: Icon(Icons.person, color: Colors.purple[700]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Supabase
                                      .instance
                                      .client
                                      .auth
                                      .currentUser
                                      ?.email ??
                                  (isJapanese ? '未ログイン' : 'Not logged in'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _isLoggedIn
                                  ? (isJapanese ? 'ログイン中' : 'Logged in')
                                  : (isJapanese ? '未ログイン' : 'Not logged in'),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Pro版
                if (isPro)
                  // Pro版利用中
                  FutureBuilder<DateTime?>(
                    future: ProService().getProExpiryDate(),
                    builder: (context, expirySnapshot) {
                      final expiryDate = expirySnapshot.data;
                      String subtitle = '';

                      if (expiryDate != null) {
                        final formatted =
                            '${expiryDate.year}/${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.day.toString().padLeft(2, '0')}';
                        subtitle = isJapanese
                            ? '有効期限: $formatted'
                            : 'Expires: $formatted';
                      }

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Colors.green[700],
                        ),
                        title: Text(
                          isJapanese ? 'Pro版利用中 ✔' : 'Pro Version Active ✔',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                          ),
                        ),
                        subtitle: subtitle.isNotEmpty
                            ? Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                        onTap: null,
                      );
                    },
                  )
                else
                  // Pro版にアップグレード
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.workspace_premium,
                      size: 20,
                      color: Colors.amber[700],
                    ),
                    title: Text(
                      isJapanese ? 'Pro版にアップグレード' : 'Upgrade to Pro',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showProPurchaseDialog(context);
                    },
                  ),
                // プロフィール設定
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.settings, size: 20),
                  title: Text(
                    isJapanese ? 'プロフィール設定' : 'Profile Settings',
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                // ログイン中
                if (_isLoggedIn)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.red,
                      size: 20,
                    ),
                    title: Text(
                      l10n.logout,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n.logout),
                          content: Text(isJapanese ? 'ログアウトしますか?' : 'Logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                l10n.logout,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await Supabase.instance.client.auth.signOut();
                        await Supabase.instance.client.auth.signInAnonymously();
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                // ログイン
                if (!_isLoggedIn)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.login,
                      color: Colors.purple[700],
                      size: 20,
                    ),
                    title: Text(
                      isJapanese ? 'ログイン / 新規登録' : 'Login / Sign up',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AuthScreen(
                            onAuthSuccess: () {
                              Navigator.pop(context);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    final isJapanese = currentLocale.languageCode == 'ja';

    final tabLabels = _getTabLabels(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            MrpLogoWithText(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isJapanese
                    ? 'JALもANAも、FOPもPPもまとめて比較'
                    : 'Compare JAL & ANA — FOP, PP, miles in one place.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // バッジ（ログイン時のみ表示）
          if (_isLoggedIn)
            BadgeRow(
              airportCount: _airportCount,
              legCount: _legCount,
              quizCount: _quizCount,
              isJapanese: isJapanese,
            ),
          // 言語切替
          GestureDetector(
            onTap: () {
              final newLocale =
                  isJapanese ? const Locale('en') : const Locale('ja');
              MyApp.setLocale(context, newLocale);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isJapanese ? 'EN' : 'JA',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // ユーザーメニュー
          GestureDetector(
            onTap: () => _showUserMenu(context),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLoggedIn
                    ? Colors.white.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _isLoggedIn ? Icons.person : Icons.person_outline,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) _flightLogKey.currentState?.refresh();
        },
        backgroundColor: Colors.white,
        indicatorColor: Colors.purple[100],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.flight, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.flight, color: Colors.purple[700]),
            label: tabLabels[0],
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.menu_book, color: Colors.purple[700]),
            label: tabLabels[1],
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.quiz, color: Colors.purple[700]),
            label: tabLabels[2],
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.location_on, color: Colors.purple[700]),
            label: tabLabels[3],
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
    );
  }
}
