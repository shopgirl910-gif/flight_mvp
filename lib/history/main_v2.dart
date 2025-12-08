import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'simulation_screen.dart';
import 'flight_record_screen.dart';
import 'history_screen.dart';
import 'quiz_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ipxlsygkxgmramrjazhj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlweGxzeWdreGdtcmFtcmphemhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0Njk4MDgsImV4cCI6MjA4MDA0NTgwOH0.ZFr2MgXRA2Lx1xaDWqAPOSxf6N4kVtTq2IRbdlJrnjw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '修行僧アプリ',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
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

  final List<String> _tabLabels = ['Simulate', '搭乗記録', '履歴', 'クイズ'];

  final List<Widget> _screens = [
    const SimulationScreen(),
    const FlightRecordScreen(),
    const HistoryScreen(),
    const QuizScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修行僧アプリ'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.purple[700],
            child: Row(
              children: List.generate(_tabLabels.length, (index) {
                final isSelected = _selectedIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected 
                            ? null 
                            : Border.all(color: Colors.white38, width: 1),
                      ),
                      child: Text(
                        _tabLabels[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.purple[700] : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
    );
  }
}
