import 'package:flutter/material.dart';

/// ============================================================
/// HcyPet V2 — 极简主义设计系统
/// ============================================================

// ---------- 颜色 ----------

/// 主色（天空蓝）
const Color kPrimaryColor = Color(0xFF4FC3F7);

/// 辅色（深灰蓝）
const Color kSecondaryColor = Color(0xFF2C3E50);

/// 强调色（亲密度粉）
const Color kAccentColor = Color(0xFFFF6B9D);

/// 纯黑背景
const Color kBackgroundColor = Colors.black;

/// 主色半透明度快捷值
class PrimaryAlpha {
  PrimaryAlpha._();
  static Color a05 = kPrimaryColor.withValues(alpha: 0.05);
  static Color a08 = kPrimaryColor.withValues(alpha: 0.08);
  static Color a10 = kPrimaryColor.withValues(alpha: 0.10);
  static Color a12 = kPrimaryColor.withValues(alpha: 0.12);
  static Color a20 = kPrimaryColor.withValues(alpha: 0.20);
  static Color a30 = kPrimaryColor.withValues(alpha: 0.30);
  static Color a40 = kPrimaryColor.withValues(alpha: 0.40);
  static Color a60 = kPrimaryColor.withValues(alpha: 0.60);
  static Color a100 = kPrimaryColor;
}

// ---------- 字体 ----------

/// 字体族（SF Pro Display → 系统默认 fallback）
const String kFontFamily = '.SF Pro Display';

/// 字重映射
const FontWeight kFontUltralight = FontWeight.w200;
const FontWeight kFontThin = FontWeight.w100;
const FontWeight kFontRegular = FontWeight.w400;
const FontWeight kFontMedium = FontWeight.w500;

// ---------- 尺寸规格 ----------

/// 宠物容器
class PetSize {
  PetSize._();
  static const double container = 280.0;
  static const double breathScaleMin = 0.98;
  static const double breathScaleMax = 1.02;
}

/// 状态条
class StatusBarSpec {
  StatusBarSpec._();
  static const double fontSize = 11.0;
  static const Color textColor = kPrimaryColor;
  static const double textOpacity = 0.80;
  static const double spacing = 8.0;
}

/// 互动按钮
class InteractionButtonSpec {
  InteractionButtonSpec._();
  static const double iconSize = 22.0;
  static const double fontSize = 12.0;
  static const double spacing = 24.0;
  static const Color textColor = kPrimaryColor;
  static const double textOpacity = 0.70;
  static const double underlineWidth = 1.0;
  static const double dotSize = 3.0;
}

/// 进度条
class ProgressBarSpec {
  ProgressBarSpec._();
  static const double height = 2.0;
  static const double borderRadius = 2.0;
  static const Color activeColor = kPrimaryColor;
  static const Color bgColor = Color(0x0F4FC3F7); // #4FC3F7 @ 6%
  static const double labelFontSize = 9.0;
  static const double labelOpacity = 0.55;
}

/// 系统提示
class SystemHintSpec {
  SystemHintSpec._();
  static const double fontSize = 12.0;
  static const Color textColor = kPrimaryColor;
  static const double textOpacity = 0.5;
}

/// 底部导航
class BottomNavSpec {
  BottomNavSpec._();
  static const double iconSize = 24.0;
  static const Color selectedColor = kPrimaryColor;
  static const Color unselectedColor = Color(0x594FC3F7);
  static const double borderOpacity = 0.05;
  static const double borderWidth = 0.5;
}

/// 宠物绘制线条
class PetStrokeSpec {
  PetStrokeSpec._();
  static const Color color = kPrimaryColor;
  static const double thin = 1.5;
  static const double normal = 2.5;
  static const double thick = 3.5;
}

// ---------- 通用间距 ----------

class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

// ---------- 圆角 ----------

class AppRadius {
  AppRadius._();
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 999.0;
}

// ---------- 动画 ----------

class AnimDuration {
  AnimDuration._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration moodTransition = Duration(milliseconds: 800);
}

// ---------- 极细分隔线 ----------

class AppDivider {
  /// 顶部/底部导航分隔线
  static BorderSide navBorder(Color color) => BorderSide(
        color: color.withValues(alpha: 0.05),
        width: 0.5,
      );
}

/// ============================================================
/// V2 底部导航图标集（Material Icons — outlined）
/// ============================================================

class AppIcons {
  AppIcons._();

  // 底部导航
  static const IconData home = Icons.pets_outlined;
  static const IconData homeActive = Icons.pets;
  static const IconData study = Icons.menu_book_outlined;
  static const IconData studyActive = Icons.menu_book;
  static const IconData partner = Icons.favorite_outline;
  static const IconData partnerActive = Icons.favorite;
  static const IconData settings = Icons.settings_outlined;
  static const IconData settingsActive = Icons.settings;

  // 互动按钮
  static const IconData pet = Icons.pets; // 抚摸
  static const IconData feed = Icons.restaurant_outlined; // 喂食
  static const IconData shake = Icons.vibration_outlined; // 摇晃
  static const IconData talk = Icons.mic_outlined; // 说话
}
