import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'constants/colors.dart';
import 'constants/routes.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/habit_provider.dart';
import 'services/database_service.dart';
import 'utils/db_helper.dart';
import 'screens/home/home_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/category/category_list_screen.dart';
import 'screens/schedule/schedule_screen.dart';

void main() {
  if (defaultTargetPlatform == TargetPlatform.windows || 
      defaultTargetPlatform == TargetPlatform.linux || 
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
      ],
      child: MaterialApp(
        title: '千寻',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            elevation: 0,
            centerTitle: true,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            type: BottomNavigationBarType.fixed,
          ),
          cardTheme: CardTheme(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        initialRoute: AppRoutes.home,
        routes: {
          AppRoutes.home: (context) => const MainScreen(),
          AppRoutes.categoryList: (context) => const CategoryListScreen(),
          AppRoutes.statistics: (context) => const StatisticsScreen(),
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const StatisticsScreen(),
    const ScheduleScreen(),
    const Scaffold(
      body: Center(
        child: Text(
          '设置功能开发中...',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // 先初始化数据库，现在 DBHelper 会自动确保有默认分类
      final db = await DBHelper.instance.database;
      debugPrint('Database initialized');
      
      if (!mounted) return;
      context.read<CategoryProvider>().loadCategories();
      context.read<TransactionProvider>().loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // 如果切换到首页，重置为当月
            if (index == 0) {
              context.read<TransactionProvider>().setDateRangeType('month');
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: '日程',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
