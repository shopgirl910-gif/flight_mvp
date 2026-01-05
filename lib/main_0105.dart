import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'simulation_screen.dart';
import 'history_screen.dart';
import 'quiz_screen.dart';
import 'auth_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ipxlsygkxgmramrjazhj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlweGxzeWdreGdtcmFtcmphemhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0Njk4MDgsImV4cCI6MjA4MDA0NTgwOH0.ZFr2MgXRA2Lx1xaDWqAPOSxf6N4kVtTq2IRbdlJrnjw',
  );

  runApp(const MyApp());
}

const Color mrpPurple = Color(0xFF8B3A8B);
const Color mrpPurpleDark = Color(0xFF6B2A6B);
const Color mrpPurpleLight = Color(0xFFAB5AAB);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MRP - Mileage Run Planner',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: mrpPurple, primary: mrpPurple),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
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
  final List<String> _tabLabels = ['Simulate', '履歴', 'クイズ'];
  final List<IconData> _tabIcons = [Icons.flight_takeoff, Icons.history, Icons.quiz];
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

  bool get isLoggedIn => Supabase.instance.client.auth.currentUser != null;
  String? get userEmail => Supabase.instance.client.auth.currentUser?.email;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      setState(() {});
    });
  }

  void _onTabChanged(int index) {
    setState(() => _selectedIndex = index);
    // 履歴タブに切り替えた時にデータをリフレッシュ
    if (index == 1) {
      _historyKey.currentState?.refresh();
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (context) => AuthDialog(onSuccess: () {
        Navigator.of(context).pop();
        setState(() {});
      }),
    );
  }

  void _showUserMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(userEmail ?? 'ユーザー', style: const TextStyle(fontSize: 14)),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('ログアウト', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
      },
    );
  }

  // ========== モバイルレイアウト（BottomNavigationBar） ==========
  Widget _buildMobileLayout() {
    return Scaffold(
      body: Container(
        color: mrpPurple,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ヘッダー（コンパクト版）
              _buildMobileHeader(),
              // メインコンテンツ
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBFBFF),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [const SimulationScreen(), HistoryScreen(key: _historyKey), const QuizScreen()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabChanged,
        selectedItemColor: mrpPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: List.generate(_tabLabels.length, (index) {
          return BottomNavigationBarItem(
            icon: Icon(_tabIcons[index]),
            label: _tabLabels[index],
          );
        }),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          const Text('MRP', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const Spacer(),
          // ログインボタン or ユーザーアイコン
          isLoggedIn
              ? GestureDetector(
                  onTap: _showUserMenu,
                  child: const Icon(Icons.account_circle, color: Colors.white, size: 28),
                )
              : GestureDetector(
                  onTap: _showAuthDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.person_outline, color: mrpPurple, size: 16),
                        SizedBox(width: 4),
                        Text('ログイン', style: TextStyle(color: mrpPurple, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ========== デスクトップレイアウト（上部タブ） ==========
  Widget _buildDesktopLayout() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(color: mrpPurple),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    children: [
                      const Text('MRP', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      const Spacer(),
                      const Icon(Icons.notifications_none, color: Colors.white70),
                      const SizedBox(width: 16),
                      // ログインボタン or ユーザーアイコン
                      isLoggedIn
                          ? GestureDetector(
                              onTap: _showUserMenu,
                              child: Row(
                                children: [
                                  const Icon(Icons.account_circle, color: Colors.white, size: 28),
                                  const SizedBox(width: 4),
                                  Text(userEmail?.split('@').first ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: _showAuthDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.person_outline, color: mrpPurple, size: 18),
                                    SizedBox(width: 4),
                                    Text('ログイン', style: TextStyle(color: mrpPurple, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                // タブバー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: List.generate(_tabLabels.length, (index) {
                        final isSelected = _selectedIndex == index;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _onTabChanged(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : [],
                              ),
                              child: Text(
                                _tabLabels[index],
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isSelected ? mrpPurple : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                // メインコンテンツ
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBFBFF),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [const SimulationScreen(), HistoryScreen(key: _historyKey), const QuizScreen()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
