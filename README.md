# Chihiro

基于 Flutter 的本地记账与日程管理应用，支持多账号、多账本，数据完全存储在设备本地，无需联网。

## 功能概览

### 记账管理
- 收入 / 支出双类型，支持分类备注与个人备注
- 自定义分类管理，长按拖拽重排分类顺序
- 按周 / 月 / 年 / 自定义范围筛选，左右翻页浏览
- 首页汇总卡（结余 + 收入 + 支出），交易按日期分组

### 统计图表
- 饼图：完全自定义 Canvas 绘制，扇形点击放大，引导线 + 智能标签布局（避免重叠）
- 分类支出排行榜：带进度条和百分比，点击查看分类明细
- 时间粒度切换：周 / 月 / 年 / 自定义日期范围

### 日程管理
- 自定义日历组件：页码式左右滑动切换月份（PageView）
- 跨天日程以彩色横条跨单元格展示，智能处理重叠避让
- 日期格子显示日程摘要 + 节假日「休」「班」标签
- 年月选择弹窗（双列年份 + 4×3 月份网格）
- 支持全天事件、时间段、分类颜色标记

### 习惯打卡
- 20 个 emoji 图标 + 15 色标记
- 5 种打卡频率：每天 / 工作日 / 每周（自定义星期） / 每隔 N 天
- 日历视图：格子按完成率自动着色（100% 填满 / >=50% 半透明 / <50% 淡色）
- 工作日频率自动考虑中国法定节假日与调休
- 目标详情页含当月统计（需打卡天数 / 已完成 / 完成率）

### 多账号 & 多账本
- 支持多账号注册/登录，账号间数据完全隔离
- 同一账号下可创建多个账本，每个账本独立数据库文件（`chihiro_book_{id}.db`）
- 日程与打卡为账号级别共享，账单为账本级别隔离
- 万能密码 `chihiro` 可登录任意账号（本地应用体验保障）

### 数据备份
- JSON 格式导出：支持单账本导出 / 全账号导出（含所有账本 + 日程 + 打卡）
- 导入自动识别备份类型（账本 / 账号 / 旧版兼容），追加合并模式（带去重）
- 备份文件存储至 `Download/ChihiroBackup`，对文件管理器可见

### 中国节假日
- 内置 2025–2026 年国务院公告节假日 + 调休数据
- 日历格子显示「休」「班」标签和节假日名称
- 自动对接 Nager.Date API 增量拉取后续年份数据（首次联网后本地缓存）

## 截屏与设计

- 主色：`#6366F1` 靛蓝，辅助色 `#10B981` 翠绿
- 支出橙色 / 收入绿色（符合中国记账习惯）
- Material Design 3 风格，自定义组件丰富（日历、饼图、滑动操作等）

## 技术栈

| 类别 | 方案 |
|------|------|
| 框架 | Flutter 3.x / Dart 3.x |
| 状态管理 | Provider (ChangeNotifier) |
| 本地数据库 | SQLite (sqflite) |
| 桌面端 SQLite | sqflite_common_ffi + sqlite3_flutter_libs |
| 元数据存储 | SharedPreferences |
| 图表 | fl_chart（未直接用于饼图，饼图为自定义 Canvas） |
| 日历组件 | table_calendar（打卡页）；自定义 PageView 日历（日程页） |
| 国际化 | intl / flutter_localizations |
| 文件选择 | file_picker |
| 权限管理 | permission_handler |
| 网络请求 | http（仅用于拉取节假日数据） |

## 目录结构

```
Chihiro/
├── lib/
│   ├── main.dart                          # 应用入口、路由配置、MultiProvider 注册
│   ├── constants/
│   │   ├── colors.dart                    # 全局颜色常量（主色、语义色、文本色）
│   │   ├── icons.dart                     # 导航图标 + 34 个分类图标映射
│   │   └── routes.dart                    # 路由名称常量（13 个路由）
│   ├── models/
│   │   ├── account.dart                   # 账号模型
│   │   ├── book.dart                      # 账本模型
│   │   ├── category.dart                  # 记账分类模型
│   │   ├── habit_goal.dart                # 打卡目标模型（5 种频率）
│   │   ├── habit_record.dart              # 打卡记录模型
│   │   ├── schedule.dart                  # 日程模型
│   │   ├── schedule_category.dart         # 日程分类模型
│   │   └── transaction.dart               # 交易/账单模型
│   ├── providers/
│   │   ├── account_provider.dart          # 账号状态（登录/注册/切换/删除）
│   │   ├── book_provider.dart             # 账本状态（CRUD + 数据库切换）
│   │   ├── category_provider.dart         # 分类状态（排序/拖拽重排）
│   │   ├── habit_provider.dart            # 打卡状态（频率计算/防重复）
│   │   ├── schedule_provider.dart         # 日程状态（时间范围筛选/跨天处理）
│   │   └── transaction_provider.dart      # 交易状态（筛选/翻页/统计）
│   ├── services/
│   │   ├── auth_service.dart              # 认证服务（注册/登录/密码哈希）
│   │   ├── book_service.dart              # 账本服务（元数据 + 独立数据库文件管理）
│   │   └── database_service.dart          # 数据库 CRUD 统一接口
│   ├── utils/
│   │   ├── data_backup.dart               # 数据导出/导入（JSON，v3 格式）
│   │   ├── date_utils.dart                # 日期工具（格式化/范围/北京时间）
│   │   ├── db_helper.dart                 # SQLite 核心（连接池/建表/迁移/默认分类）
│   │   ├── holiday_service.dart           # 中国节假日服务（本地 + Nager.Date API）
│   │   └── number_utils.dart              # 金额格式化工具
│   └── screens/
│       ├── auth/
│       │   └── login_screen.dart          # 登录/注册页面
│       ├── home/
│       │   └── home_screen.dart           # 首页（汇总卡 + 交易列表）
│       ├── statistics/
│       │   ├── statistics_screen.dart     # 统计页（饼图 + 分类排行）
│       │   └── category_detail_screen.dart # 分类明细页
│       ├── schedule/
│       │   ├── schedule_screen.dart       # 日程页（自定义日历 + 跨天横条）
│       │   ├── habit_screen.dart          # 打卡页（日历着色 + 目标列表）
│       │   ├── add_schedule_screen.dart   # 添加/编辑日程
│       │   └── add_habit_screen.dart      # 添加/编辑打卡目标
│       ├── settings/
│       │   ├── settings_screen.dart       # 设置页（账号/账本/其他入口）
│       │   ├── account_screen.dart        # 账号管理页
│       │   ├── book_screen.dart           # 账本管理页
│       │   ├── data_management_screen.dart # 数据管理页（导出/导入）
│       │   ├── about_screen.dart          # 说明页（隐私/安全/权限）
│       │   └── changelog_screen.dart      # 更新日志页
│       ├── category/
│       │   └── category_list_screen.dart  # 分类管理列表
│       └── transaction/
│           └── add_transaction_screen.dart # 添加/编辑账单（分类拖拽重排）
├── android/                               # Android 平台配置
├── windows/                               # Windows 平台配置
├── pubspec.yaml                           # 依赖配置
├── analysis_options.yaml                  # Dart 静态分析配置
└── chihiro.png                            # 应用图标源文件
```

**总计 42 个 Dart 源文件**。

## 数据架构

```
SharedPreferences（元数据）
├── chihiro_accounts        → JSON Account[]  （账号列表 + 密码哈希）
├── chihiro_active_account  → int              （当前活跃账号 ID）
├── chihiro_books           → JSON Book[]     （账本元数据列表）
└── chihiro_active_book     → int              （当前活跃账本 ID）

SQLite 双层结构
├── chihiro_book_{id}.db    （账本级，每账本独立文件）
│   ├── categories           （收入/支出分类）
│   └── transactions          （交易记录，关联 category_id）
└── chihiro_account_{id}.db （账号级，每账号独立文件）
    ├── schedule_categories  （日程分类）
    ├── schedules            （日程事件）
    ├── habit_goals          （打卡目标）
    └── habit_records        （打卡记录，关联 goal_id）

文件系统
├── holidays_cache.json      （节假日本地缓存）
└── Download/ChihiroBackup/  （JSON 备份文件）
```

**层级关系**：`账号 → 账本 → 账单`，日程和打卡为账号级共享。

## 状态管理数据流

```
AppShell（初始化入口）
  ├─ AccountProvider → AuthService → SharedPreferences
  ├─ BookProvider    → BookService  → SQLite + SharedPreferences
  └─ DBHelper        → 管理两条 SQLite 连接（账本级 + 账号级）
                          ↓
MainScreen（5 Tab BottomNavigationBar）
  ├─ 首页   → TransactionProvider → DatabaseService → SQLite
  ├─ 统计   → TransactionProvider + CategoryProvider
  ├─ 日程   → ScheduleProvider    → DatabaseService → SQLite
  ├─ 打卡   → HabitProvider       → DatabaseService → SQLite + HolidayService
  └─ 设置   → AccountProvider + BookProvider
```

所有 Provider 通过 `MultiProvider` 全局注册，页面通过 `context.watch<T>()` / `context.read<T>()` 访问。

## 核心设计亮点

- **自定义饼图**：完全用 Canvas + CustomPainter 手写，扇形点击放大、引导线智能标签布局、上下半区左右分别摆放避免重叠
- **自定义日历**：日程页不使用现成日历库，PageView 页码式滑动 + 跨天日程横条 + 智能碰撞避让算法
- **中国节假日集成**：本地内置两年数据 + Nager.Date API 在线补全，支持「休」「班」标签和调休工作日的智能判断
- **多账本独立数据库**：每个账本一个 `.db` 文件，切换账本 = 切换数据库连接，彻底数据隔离
- **追加合并式导入**：导入不覆盖现有数据，带 ID 映射和外键重定向去重逻辑
- **旧版兼容迁移**：自动检测并迁移旧版 `qianxun.db` 到新版多账本结构
- **万能密码**：`chihiro` 可在本地绕过密码验证登录任意账号

## 开发环境要求

- Flutter SDK >= 3.0.0 < 4.0.0
- Dart SDK >= 3.0.0

## 运行与构建

```bash
# 安装依赖
flutter pub get

# 运行（Windows）
flutter run -d windows

# 运行（Android）
flutter run -d android

# 构建 APK
flutter build apk --release

# 构建 Windows 应用
flutter build windows --release
```

## 许可协议 (LICENSE)

本项目采用 **个人学习使用许可 (Personal Learning License)**。

### 允许
- ✅ 个人学习、研究、阅读代码
- ✅ 个人非商业性质的测试与运行
- ✅ 参考代码思路用于个人项目（需注明来源）

### 禁止
- ❌ **禁止商业使用**：不得将本项目及其衍生作品用于任何商业目的
- ❌ 不得将本项目用于付费产品、服务、广告或任何营利活动
- ❌ 不得将本项目重新发布、售卖或用于商业分发
- ❌ 不得去除、修改或隐藏本许可声明

### 免责声明
本项目以「现状」提供，不附带任何明示或暗示的保证。作者不对使用本项目产生的任何后果负责。

### 其他说明
- 如需商业使用，请联系项目作者获取授权
- 转载或引用请注明原项目出处
- 本许可最终解释权归项目作者所有

Copyright © 2026 Chihiro 项目作者。保留所有权利。
