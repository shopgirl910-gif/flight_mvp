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

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
    _handleAuthStateChange();
    // リセットリンクから来た場合のチェック
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPasswordRecovery();
    });
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
      if (mounted) setState(() {});
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
                                Localizations.localeOf(
                                  this.context,
                                ).languageCode ==
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
                    : const Text('更新', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
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

  final List<Widget> _screens = [
    const SimulationScreen(),
    const FlightLogScreen(),
    const QuizScreen(),
    const CheckinScreen(),
  ];

  void _showUserMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ユーザー情報
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                          Supabase.instance.client.auth.currentUser?.email ??
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
            // ログアウト
            if (_isLoggedIn)
              ListTile(
                dense: true,
                leading: const Icon(Icons.logout, color: Colors.red, size: 20),
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
                      content: Text(isJapanese ? 'ログアウトしますか？' : 'Logout?'),
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
                leading: Icon(Icons.login, color: Colors.purple[700], size: 20),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    final isJapanese = currentLocale.languageCode == 'ja';

    return Scaffold(
      appBar: AppBar(
        title: const Text('MRP - Mileage Run Planner'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          // 言語切替ボタン
          GestureDetector(
            onTap: () {
              final newLocale = isJapanese
                  ? const Locale('en')
                  : const Locale('ja');
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
          // ユーザーメニューボタン
          GestureDetector(
            onTap: () => _showUserMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _isLoggedIn
                    ? Colors.white.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isLoggedIn ? Icons.person : Icons.person_outline,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.purple[700],
            child: Row(
              children: List.generate(_getTabLabels(context).length, (index) {
                final tabLabels = _getTabLabels(context);
                final isSelected = _selectedIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.white38, width: 1),
                      ),
                      child: Text(
                        tabLabels[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.purple[700] : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
    );
  }
}
