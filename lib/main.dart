import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'simulation_screen.dart';
import 'flight_log_screen.dart';
import 'quiz_screen.dart';
import 'checkin_screen.dart';
import 'auth_screen.dart';

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
    // ログイン状態の変化を監視
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _ensureSignedIn() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      await Supabase.instance.client.auth.signInAnonymously();
    }
  }

  bool get _isLoggedIn {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  String get _displayName {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return 'guest';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              final newLocale = isJapanese ? const Locale('en') : const Locale('ja');
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
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // ログイン/ログアウトボタン
          GestureDetector(
            onTap: () {
              if (_isLoggedIn) {
                // ログアウト確認ダイアログ
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.logout),
                    content: Text(isJapanese ? 'ログアウトしますか？' : 'Logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Supabase.instance.client.auth.signOut();
                          // 匿名ユーザーとして再ログイン
                          await Supabase.instance.client.auth.signInAnonymously();
                          setState(() {});
                        },
                        child: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              } else {
                // ログイン画面へ
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
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _isLoggedIn ? Colors.white.withOpacity(0.2) : Colors.orange.withOpacity(0.8),
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
