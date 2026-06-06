# 千寻记账与日程管理应用

一款专注于个人财务管理和日程安排的移动应用。

## 项目概述

千寻是一款使用 Flutter 开发的记账与日程管理应用，采用 SQLite 进行本地数据存储，Provider 状态管理。

## 功能特性

### 记账功能 (已实现
- ✅ 添加收入/支出账单
- ✅ 选择分类（预设 19 个支出分类，5 个收入分类）
- ✅ 分类备注（例如：购物-短袖）
- ✅ 日期选择
- ✅ 账单列表展示
- ✅ 日期范围筛选（本周/本月/本年）
- ✅ 收支统计
- ✅ 分类占比展示
- ✅ 分类管理

### 日程管理 (预留)
- 📅 日程添加/编辑/删除
- 📅 日程提醒
- 📅 手机日历集成
- 📅 日程分类

### 打卡任务 (预留)
- 🎯 自定义添加打卡目标
- 🎯 习惯打卡
- 🎯 任务完成记录
- 🎯 打卡统计

## 技术栈

- **框架**: Flutter 3.0+
- **语言**: Dart
- **状态管理**: Provider
- **数据库**: SQLite (sqflite)
- **数据存储**: path_provider
- **图表**: fl_chart
- **日期处理**: table_calendar, intl
- **权限管理**: permission_handler

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── constants/                        # 常量定义
│   ├── colors.dart                  # 颜色常量
│   ├── icons.dart                   # 图标常量
│   └── routes.dart                  # 路由常量
├── models/                         # 数据模型
│   ├── category.dart               # 分类模型
│   ├── transaction.dart          # 账单模型
│   ├── schedule.dart              # 日程模型（预留）
│   ├── habit_goal.dart           # 打卡目标模型（预留）
│   └── habit_record.dart        # 打卡记录模型（预留）
├── providers/                     # 状态管理
│   ├── category_provider.dart   # 分类状态管理
│   └── transaction_provider.dart # 账单状态管理
├── services/                    # 服务层
│   └── database_service.dart  # 数据库服务
├── screens/                   # 页面
│   ├── home/
│   │   └── home_screen.dart  # 首页
│   ├── transaction/
│   │   └── add_transaction_screen.dart # 添加账单
│   ├── statistics/
│   │   └── statistics_screen.dart # 统计页
│   ├── category/
│   │   └── category_list_screen.dart # 分类管理页
│   ├── schedule/             # 日程页（预留）
│   ├── habit/                # 打卡页（预留）
│   └── settings/             # 设置页（预留）
├── widgets/                   # 通用组件
└── utils/                     # 工具类
    ├── date_utils.dart         # 日期工具
    ├── number_utils.dart    # 数字工具
    └── db_helper.dart       # 数据库帮助类
```

## 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Android SDK (for Android development)

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
flutter run
```

### 构建 APK

```bash
flutter build apk
```

## 使用说明

1. **记账
   - 点击首页可以查看当前时间范围内的账单列表
   - 点击右下角浮动按钮添加新账单
   - 选择支出/收入切换类型，选择分类，输入金额和备注
   - 可以选择日期记录历史账单
   - 可以切换时间范围查看本周/本月/本年账单
   - 在统计页查看支出/收入的分类占比

## 预留功能

日程管理和打卡任务的表结构已预留，后续可以继续开发。

## 设计方案

详细的设计方案请查看 `设计方案.md` 文件。

## License

MIT License
