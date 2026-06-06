import 'package:flutter/material.dart';

class AppIcons {
  static const IconData home = Icons.home_outlined;
  static const IconData homeFilled = Icons.home;
  static const IconData statistics = Icons.bar_chart_outlined;
  static const IconData statisticsFilled = Icons.bar_chart;
  static const IconData schedule = Icons.calendar_today_outlined;
  static const IconData scheduleFilled = Icons.calendar_today;
  static const IconData settings = Icons.settings_outlined;
  static const IconData settingsFilled = Icons.settings;
  
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData search = Icons.search;
  static const IconData filter = Icons.filter_list_outlined;
  static const IconData calendar = Icons.calendar_today_outlined;
  static const IconData arrowBack = Icons.arrow_back;
  static const IconData check = Icons.check;
  static const IconData close = Icons.close;
  static const IconData more = Icons.more_vert;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData chevronRight = Icons.chevron_right;
  
  static const Map<String, IconData> categoryIcons = {
    '餐饮': Icons.restaurant_outlined,
    '交通': Icons.directions_car_outlined,
    '购物': Icons.shopping_bag_outlined,
    '地铁': Icons.subway_outlined,
    '蔬菜': Icons.eco_outlined,
    '水果': Icons.apple_outlined,
    '零食': Icons.fastfood_outlined,
    '运动': Icons.fitness_center_outlined,
    '娱乐': Icons.sports_esports_outlined,
    '通讯': Icons.phone_outlined,
    '住房': Icons.house_outlined,
    '游戏': Icons.sports_baseball_outlined,
    '长辈': Icons.elderly_outlined,
    '社交': Icons.people_outlined,
    '日用': Icons.local_grocery_store_outlined,
    '旅行': Icons.flight_outlined,
    '数码': Icons.phone_android_outlined,
    '学习': Icons.menu_book_outlined,
    'AI': Icons.smart_toy_outlined,
    '工资': Icons.attach_money_outlined,
    '奖金': Icons.card_giftcard_outlined,
    '理财': Icons.show_chart_outlined,
    '兼职': Icons.work_outline,
    '其他': Icons.inventory_2_outlined,
  };
  
  static IconData getCategoryIcon(String categoryName) {
    return categoryIcons[categoryName] ?? Icons.inventory_2_outlined;
  }
}
