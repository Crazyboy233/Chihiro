import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'constants/routes.dart';
import 'constants/theme.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/account_provider.dart';
import 'providers/book_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'utils/db_helper.dart';
import 'screens/home/home_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/schedule/habit_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/category/category_list_screen.dart';
import 'screens/auth/login_screen.dart';

void main() {
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
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Chihiro',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          locale: const Locale('zh', 'CN'),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: AppRoutes.home,
          routes: {
            AppRoutes.home: (context) => const AppShell(),
            AppRoutes.categoryList: (context) => const CategoryListScreen(),
            AppRoutes.statistics: (context) => const StatisticsScreen(),
          },
        ),
      ),
    );
  }
}

/// 应用外壳：启动时先迁移旧数据 → 初始化账号系统，
/// 未登录显示登录页，已登录显示主界面
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _initializing = true;
  bool _bookReady = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final migrated = await DBHelper.migrateLegacyDbIfNeeded();
    final accountProvider = context.read<AccountProvider>();
    await accountProvider.init();

    if (migrated && accountProvider.accounts.isEmpty) {
      try {
        await AuthService.instance.register('默认用户', '123456');
        await accountProvider.refresh();
      } catch (_) {}
    }

    if (accountProvider.isLoggedIn && accountProvider.currentAccount != null) {
      await _initBooks(accountProvider.currentAccount!.id);
    }

    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _initBooks(int accountId) async {
    final bp = context.read<BookProvider>();
    await bp.loadBooks(accountId);
    if (bp.currentBook != null) {
      await bp.switchBook(bp.currentBook!.id);
    }
    await DBHelper.instance.setActiveAccount(accountId);
    if (mounted) setState(() => _bookReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在初始化...', style: TextStyle(color: Colors.grey))])));
    }

    final ap = context.watch<AccountProvider>();
    final bp = context.watch<BookProvider>();

    if (!ap.isLoggedIn) {
      _bookReady = false;
      return const LoginScreen();
    }

    // 仅在首次登录或 bookProvider 未就绪时才初始化账本
    if (!_bookReady || bp.currentBook == null) {
      final accountId = ap.currentAccount?.id;
      if (accountId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _initBooks(accountId));
      }
      return const Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在加载数据...', style: TextStyle(color: Colors.grey))])));
    }

    return const MainScreen();
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
    const HabitScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
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
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: '打卡',
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
