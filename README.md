# 千寻 (Chihiro)

一个基于 Flutter 的记账与日程管理应用。

## 项目简介

千寻是一款集记账、日程管理、习惯记录于一体的个人效率工具，提供以下主要功能：

- **记账管理**：支持收入/支出记录、分类管理、数据统计与图表展示
- **日程管理**：基于日历的行程安排与提醒
- **习惯养成**：设置并追踪个人习惯目标
- **数据备份**：支持本地数据的导入与导出

项目同时支持 Android 与 Windows 平台。

## 技术栈

- **框架**：Flutter 3.x / Dart 3.x
- **状态管理**：Provider
- **本地存储**：SQLite (sqflite)
- **UI 组件**：fl_chart、table_calendar、cupertino_icons
- **国际化**：intl / flutter_localizations

## 目录结构

```
lib/
├── constants/        # 常量定义（颜色、图标、路由）
├── models/           # 数据模型
├── providers/        # 状态管理
├── screens/          # 页面与界面
├── services/         # 业务服务
├── utils/            # 工具函数
└── main.dart         # 应用入口
```

## 开发环境要求

- Flutter SDK >= 3.0.0，< 4.0.0
- Dart SDK >= 3.0.0

## 安装与运行

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
本项目以"现状"提供，不附带任何明示或暗示的保证。作者不对使用本项目产生的任何后果负责。

### 其他说明
- 如需商业使用，请联系项目作者获取授权
- 转载或引用请注明原项目出处
- 本许可最终解释权归项目作者所有

Copyright © 2026 千寻 (Chihiro) 项目作者。保留所有权利。
