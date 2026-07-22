# 🐾 HcyPet — 情侣伴侣电子宠物 App

> Flutter 3.12+ · iOS 26+ · Codemagic CI/CD · SideStore 侧载

---

## 📋 目录

1. [项目概述](#项目概述)
2. [视觉追踪模块（当前状态）](#视觉追踪模块当前状态)
3. [走神检测逻辑](#走神检测逻辑)
4. [架构总览](#架构总览)
5. [完整文件结构](#完整文件结构)
6. [依赖清单](#依赖清单)
7. [iOS 26 崩溃修复记录](#ios-26-崩溃修复记录)
8. [Firebase 配置](#firebase-配置)
9. [Codemagic 构建流水线](#codemagic-构建流水线)
10. [已知问题 & V2 规划](#已知问题--v2-规划)
11. [开发命令速查](#开发命令速查)

---

## 项目概述

情侣共同养一只电子宠物。支持 iOS 26+ 侧载（SideStore），通过 Firebase Realtime Database 同步宠物状态。

### 核心功能

| 模块 | 说明 |
|------|------|
| 🏠 **主页** | 宠物展示（CustomPainter 6 种情绪 + 睡眠动画）、抚摸/喂食/对话/摇晃互动 |
| 📚 **自习室** | 3 种计时模式（正向/倒计时/番茄钟）、专注评分、宠物陪伴学习 |
| 💕 **伴侣** | Firebase 匿名登录、配对码匹配、实时消息、宠物状态同步 |
| ⚙️ **设置** | 休眠/唤醒参数、通知开关、DEBUG 模式、重置宠物 |

### 宠物状态系统

```
6 种情绪: happy · calm · surprised · sad · sleepy · missing
6 种活动: idle · watching · playing · studying · sleeping · thinking
3 维数值: happiness(0-1) · energy(0-1) · intimacy(0-1)
```

- 每 30 秒自然衰减（happiness -0.005, energy -0.008）
- 精力 < 0.2 → sleepy，快乐 < 0.3 → sad，> 4h 无互动 → missing
- 状态持久化到 SharedPreferences

---

## 视觉追踪模块（当前状态）

### ⚠️ 当前为占位模式（Placeholder）

视觉追踪经历了 3 次尝试，均在 iOS 26 上失败：

| 尝试 | 方案 | 失败原因 |
|------|------|---------|
| 1 | `google_mlkit_face_detection` | 静态 MediaPipe framework 冲突，linker error |
| 2 | `vision_ai` package | 同上，依赖冲突 |
| 3 | 原生 Apple Vision (Swift MethodChannel) | `FlutterImplicitEngineDelegate` 编译错误 |

### 当前架构（占位）

```
lib/
├── services/vision_service.dart     ← 占位实现，initialize() 仅返回 true
├── bloc/vision_bloc.dart            ← VisionBloc（完整事件系统，但无实际检测）
└── models/                          ← EmotionResult 数据模型（支持 7 种情绪）
```

### EmotionResult 模型（V2 预留）

```dart
class EmotionResult {
  String emotion;        // happy | sad | angry | fearful | disgusted | surprised | neutral
  double confidence;     // 置信度 0-1
  bool isAttention;      // 是否专注（面向屏幕）
  double attentionScore; // 专注评分 0-100

  String get comfortMessage { ... }  // 内置安慰消息
}
```

### V2 视觉追踪方案建议

> ⚠️ 下个 Session 务必先调研目标版本的可用方案

| 方案 | 优点 | 风险 |
|------|------|-----|
| **Apple Vision** (原生 Swift) | 零额外依赖，iOS 原生 | 需正确配置 MethodChannel |
| **Google ML Kit** (bare) | 跨平台 | iOS 26 兼容性需验证 |
| **ARKit 面部追踪** | 精确头部姿态 | 仅 Face ID 设备有 TrueDepth |
| **Core Image** 人脸检测 | 轻量内置 | 仅检测位置，无情绪 |

---

## 走神检测逻辑

### 当前实现：模拟（无摄像头）

```
位置: lib/bloc/study_bloc.dart → _onTick()
触发: 计时器每秒 tick
专注评分: 60-100 随机波动（模拟）
走神阈值: 专注分 < 70
```

```dart
// 每 10 秒评估
_flucutation = (DateTime.now().millisecond % 5) - 2; // ±2
newScore = (focusScore + fluctuation).clamp(60, 100);
isFocused = newScore > 70;
```

### V2 真实走神检测设计

```
摄像头 → VisionService (Apple Vision / ML Kit)
  ↓ 每 1-3 秒一帧
EmotionResult {
  attentionScore: 头部姿态 + 视线方向
  isAttention: 超阈值
}
  ↓
StudyFocusUpdateEvent → StudyBloc._onFocusUpdate()

走神判定:
  · 视线离开屏幕 > 3 秒 → 走神
  · 头部大幅偏转 → 走神
  · 连续非专注 → 专注分 -5/次
  · 恢复专注 → 专注分 +2/次
  · 专注分 < 70 → 宠物提示 "专心学习哦~ 📚"
```

---

## 架构总览

### 状态管理：flutter_bloc

```
main.dart
  └─ BlocProvider<PetBloc>           ← 全局宠物状态（14 个事件）
      └─ MainPage（BottomNavigationBar 4 tab）
          ├─ HomePage                ← SensorService（加速度计 + 摇晃）
          │   ├─ PetWidget           ← AnimationController 呼吸动画
          │   │   └─ CustomPaint → PetPainter（6 情绪 + 睡眠绘制）
          │   ├─ TalkButton          ← 文字弹窗输入（替代语音）
          │   └─ 互动按钮
          ├─ StudyPage
          │   ├─ StudyBloc           ← 计时器 + 专注评分
          │   └─ VisionBloc          ← 视觉追踪（占位）
          ├─ PartnerPage
          │   └─ FirebaseService     ← 单例：init/auth/relation/message
          └─ SettingsPage
              └─ DebugConfig         ← DEBUG 全局开关
```

### 数据流

```
用户操作 → PetEvent → PetBloc → emit(PetState)
                                    ↓
                              PetPainter 重绘
                              SharedPreferences 持久化
                              Firebase DB 同步（伴侣模式）
```

---

## 完整文件结构

```
HcyPet/
├── lib/
│   ├── main.dart                         # 入口：ThemeData + BlocProvider + DebugBar overlay
│   ├── bloc/
│   │   ├── pet_bloc.dart                 # PetBloc: 14 事件处理器 + 30s 衰减 Timer
│   │   ├── study_bloc.dart               # StudyBloc: 3 模式计时 + 模拟专注评分
│   │   └── vision_bloc.dart              # VisionBloc: 占位（事件系统完整）
│   ├── models/
│   │   ├── pet_state.dart                # PetState: 6 情绪 × 6 活动 × 3 数值
│   │   ├── pet_event.dart                # 14 事件类
│   │   └── study_state.dart              # StudyState: 3 计时模式
│   ├── services/
│   │   ├── firebase_service.dart         # Firebase 全部操作 + ValueNotifier 调试
│   │   ├── sensor_service.dart           # accelerometer + shake（sensors_plus）
│   │   ├── vision_service.dart           # 占位
│   │   ├── notification_service.dart     # 本地推送
│   │   └── debug_config.dart             # 全局 DEBUG 开关（ValueNotifier<bool>）
│   └── presentation/
│       ├── pages/
│       │   ├── main_page.dart            # 4 tab 底部导航
│       │   ├── home_page.dart            # 主页完整 UI + 传感器 + 对话按钮
│       │   ├── study_page.dart           # 自习室：计时器 UI + 专注显示
│       │   ├── partner_page.dart         # 伴侣：配对 + 消息（异步初始化）
│       │   └── settings_page.dart        # 设置：配置 + DEBUG 开关
│       ├── pet/
│       │   ├── pet_painter.dart          # CustomPainter: 7 种绘制模式
│       │   └── pet_widget.dart           # AnimationController 呼吸动画包装
│       └── widgets/
│           ├── talk_button.dart          # 文字输入弹窗按钮
│           ├── voice_recorder_button.dart # 旧语音按钮（未使用）
│           └── debug_bar.dart            # DEBUG 面板：Firebase 实时状态
├── ios/
│   ├── Runner/
│   │   ├── Info.plist                    # Bundle + 权限（FirebaseAutoConfigureDisabled 已移除）
│   │   ├── GoogleService-Info.plist      # Firebase 配置（含 DATABASE_URL）
│   │   ├── AppDelegate.swift             # 标准 FlutterAppDelegate
│   │   └── GeneratedPluginRegistrant.m   # 已移除 SpeechToTextPlugin
│   └── Runner.xcodeproj/
├── codemagic.yaml                        # CI/CD: flutter build + ditto IPA
├── pubspec.yaml                          # 依赖（speech_to_text 已移除）
└── README.md                             # 本文件
```

---

## 依赖清单

| 类别 | 包名 | 版本 | 用途 |
|------|------|------|------|
| 状态管理 | flutter_bloc | ^8.1.4 | Bloc |
| | equatable | ^2.0.5 | 状态比较 |
| 存储 | shared_preferences | ^2.2.2 | KV 存储 |
| | sqflite | ^2.3.0 | SQLite |
| 传感器 | sensors_plus | ^6.1.0 | 加速度计 |
| | shake_plus | ^1.0.0 | 摇晃检测 |
| Firebase | firebase_core | ^4.12.1 | 核心 |
| | firebase_database | ^12.4.6 | Realtime DB |
| | firebase_auth | ^6.5.6 | 匿名登录 |
| 通知 | flutter_local_notifications | ^17.0.0 | 本地推送 |
| 计时 | stop_watch_timer | ^1.0.0 | 辅助 |
| UI | flutter_svg | ^2.0.9 | SVG |
| | cupertino_icons | ^1.0.8 | iOS 图标 |

### ❌ 已移除

| 包名 | 原因 |
|------|------|
| `speech_to_text` | iOS 26 SFSpeechRecognizer 崩溃 |
| `google_mlkit_face_detection` | 静态 framework 冲突 |
| `vision_ai` | 依赖冲突 |
| `camera` | 未使用 |

---

## iOS 26 崩溃修复记录

### 问题

App 在 iOS 26+ 通过 SideStore 侧载后立即闪退，极简版（MaterialApp+Text）正常。

### 6 轮渐进排查

| 测试 | 内容 | 结果 |
|------|------|------|
| A | PetBloc + 文字 | ✅ |
| B | CustomPaint 单独 | ✅ |
| C | A + B 结合 | ✅ |
| D | + AnimationController | ✅ |
| E | + BottomNavigationBar | ✅ |
| F | + 完整 HomePage | ❌ |
| G | HomePage - SensorService - VoiceRecorderButton | ✅ |
| H1 | + SensorService | ✅ |
| **→ 元凶** | **VoiceRecorderButton（speech_to_text）** | |

### 全部修复

| 修复 | 影响文件 |
|------|---------|
| 移除 speech_to_text，替换为 TalkButton | pubspec.yaml, talk_button.dart |
| ThemeData: useMaterial3=false + textTheme + DefaultTextStyle.merge | main.dart |
| FirebaseOptions 显式传入（iOS 26 自动初始化失效） | firebase_service.dart |
| 数据库规则补全 pairCodes + messages | Firebase Console |
| getCurrentRelation 异步化（不再阻塞 UI） | partner_page.dart |
| DEBUG 模式 + 全局开关 | debug_config.dart, settings_page.dart, debug_bar.dart |

---

## Firebase 配置

### 控制台 Checklist

- [ ] Authentication → **Anonymous** → Enable
- [x] Realtime Database 规则已更新
- [x] 数据库 URL: `https://hcypet-default-rtdb.firebaseio.com`
- [x] GoogleService-Info.plist 含 DATABASE_URL

### 数据库规则

```json
{
  "rules": {
    "users": { "$uid": {
      ".read": "auth != null",
      ".write": "auth != null && auth.uid == $uid"
    }},
    "pets": { "$petId": {
      ".read": "auth != null", ".write": "auth != null"
    }},
    "relations": { "$relationId": {
      ".read": "auth != null", ".write": "auth != null"
    }},
    "pairCodes": { "$code": {
      ".read": "auth != null", ".write": "auth != null"
    }},
    "messages": { "$relationId": {
      ".read": "auth != null", ".write": "auth != null"
    }}
  }
}
```

---

## Codemagic 构建流水线

```yaml
# codemagic.yaml
环境:    Flutter stable + Xcode latest + CocoaPods default
构建:    flutter build ios --release --no-codesign
打包:    ditto -c -k --sequesterRsrc --keepParent Payload → HcyPet.ipa (~8.7MB)
产物:    build/ios/ipa/HcyPet.ipa
通知:    hkliu178@outlook.com
```

---

## 已知问题 & V2 规划

### 🟡 当前待办

| 问题 | 优先级 | 状态 |
|------|--------|------|
| Firebase 匿名登录控制台启用 | P0 | 等待用户操作 |
| 伴侣页数据库首次查询挂起 | P1 | 已绕过，加 10s 超时 |
| withOpacity 弃用 | P3 | 部分已迁移 withValues |
| 传感器指示器 UI | P3 | 简化 |

### 🔵 V2 功能规划

| 功能 | 依赖 | 难度 |
|------|------|------|
| 真实视觉追踪 | Apple Vision / ML Kit | ⭐⭐⭐⭐⭐ |
| 走神检测真实数据 | 视觉追踪 | ⭐⭐⭐ |
| 语音输入恢复 | 调研 iOS 26 兼容方案 | ⭐⭐⭐ |
| 历史数据图表 | fl_chart | ⭐⭐ |
| 成就系统 | Firebase DB | ⭐⭐ |
| 桌面 Widget | iOS WidgetKit | ⭐⭐⭐ |
| Apple Watch | watchOS SwiftUI | ⭐⭐⭐⭐ |

---

## 开发命令速查

```bash
# 依赖
flutter pub get
cd ios && pod install && cd ..

# 检查
flutter analyze

# 构建 IPA
flutter build ios --release --no-codesign

# 手动打包
mkdir -p Payload
cp -R build/ios/iphoneos/Runner.app Payload/
ditto -c -k --sequesterRsrc --keepParent Payload build/ios/ipa/HcyPet.ipa

# 清理
flutter clean
rm -rf ios/Pods && cd ios && pod install && cd ..

# DEBUG 模式
# 设置页 → DEBUG 模式 → 开启 → 页面底部显示 Firebase 状态
```
