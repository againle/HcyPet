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
| 主页 | 宠物展示（CustomPainter 6 种情绪 + 睡眠动画）、抚摸/喂食/对话/摇晃互动、昼夜节律精力 |
| 自习室 | 3 种计时模式 + Apple Vision 专注度检测 + 热力图日历（月/年）+ 24h 专注度折线图 |
| 伴侣 | Firebase 匿名登录、配对码匹配、实时消息、宠物状态同步 |
| 设置 | 休眠/唤醒参数、通知开关、DEBUG 模式、重置宠物 |

### 宠物状态系统

```
6 种情绪: happy · calm · surprised · sad · sleepy · missing
8 种活动: idle · watching · playing · studying · sleeping · thinking · groggy · celebrating
5 维数值: happiness(0-1) · energy(0-1) · intimacy(0-1) · fullness(0-1) · boredom(0-1)
```

- **昼夜节律精力**：双峰余弦曲线建模（晨峰 90% → 午饭后低谷 50% → 午后回升 80% → 晚间 < 20%），每 30s 平滑趋近
- **起床逻辑**：睡眠质量 = 时长因子 × (1 - 打断惩罚)，起床精力 = 90% × 质量，情绪联动（精力 < 70% → 情绪 40%）
- **睡眠系统**：夜间 23-7 点自动入睡（+3%/tick 恢复），白天精力 < 8% + 空闲 > 2h 自动小憩
- **白天精力地板**：7-23 点精力不低于 10%
- 状态持久化到 SharedPreferences

---

## 视觉追踪模块（V3 — 已实现）

### Apple Vision 原生检测（iOS MethodChannel）

视觉追踪已完成原生 Swift 实现，通过 MethodChannel (`com.hcypet.vision`) 与 Flutter 通信。所有代码嵌入 `ios/Runner/AppDelegate.swift`，无第三方依赖。

### 场景识别（5 种）

| 场景 | 判定条件 |
|:---|:---|
| 阅读/写字 | 头微低(pitch 0.1-0.35) + 头部稳定(yaw方差<0.04) |
| 电脑 | 头平视(\|pitch\|<0.15) + 水平扫视(yaw方差<0.06) |
| 手机 | 头低垂(pitch>0.35) + 人脸偏大(离得近) |
| 分心 | 频繁转头(yaw方差>0.08) 或 人脸频繁离开(<60%) |
| 无人脸 | 画面中未检测到人脸 |

### 多因子专注度评分（0-1）

```
focusScore = headStability(0.30) + eyeStability(0.25) + facePresence(0.20) + motionCalmness(0.15) + postureScore(0.10)
           × sceneMultiplier（阅读=1.0, 电脑=0.95, 手机=0.3, 分心=0.15）
```

### 连续情绪谱（7 维，0-1）

| 维度 | 检测方法 |
|:---|:---|
| calm 平静 | 眉毛不紧绷 + 嘴不抿 + 头部稳定 |
| focused 专注 | 即专注度评分 |
| frustrated 烦躁 | 眉毛微下压(< -0.05) + 抿嘴 + 微抖（敏感阈值） |
| bored 无聊 | 眼部持续偏低 + 歪头 + 面部静止 |
| happy 开心 | 嘴角上扬 + 眼部微眯(笑眼) |
| anxious 焦虑 | 眉毛上扬(微紧张) + 眨眼频率高 + 眼部偏大 |
| tired 疲惫 | 眼部趋势下降 + 眨眼增加 + 头部下倾 |

### 时序分析（30 帧滑动窗口）

- EMA 基线更新（眼部张开度 / 面部大小）
- 眨眼频率追踪（10 秒窗口）
- 眉毛变化 / 抿嘴历史
- 情绪趋势（前半段 vs 后半段均值差）

---

## 自习室

### 计时模式

- **正向计时**：无限计时，进度条按小时缩放
- **倒计时**：自定义分钟数，到 0 自动完成
- **番茄钟**：预设 25/45/50/90 分钟，完成自动切换阶段

### 专注度检测（实时视觉）

```
摄像头 → VisionDetector (Apple Vision) → VisionBloc → StudyBloc._onFocusData()
  ↓ 每 15 秒采样一次
FocusSample { elapsedSeconds, focusScore }
  ↓
StudyBloc 综合专注评分（avgCurve）
```

### 学习历史 + 热力图日历

- **日历面板**：顶部摘要条（今日 X 分 · 连续 X 天），点击下拉展开
  - **月视图**：当月热力图 + 图例，左右箭头切换月份，点击年份切换年视图
  - **年视图**：12 块迷你月热力图网格，点击任意月进入月视图
- **日详情**：点击热力图格子 → 底部弹窗显示 24 小时专注度折线图（蓝色 `#42A5F5`，渐变填充）
- **持久化**：`SharedPreferences` 存储每段学习的完整专注度采样曲线
- **学习结束**：宠物自动切换 celebrating + happy 状态，显示鼓励 thought

---

## 架构总览

### 状态管理：flutter_bloc

```
main.dart
  └─ BlocProvider<PetBloc>           ← 全局宠物状态（昼夜节律 + 睡眠 + 起床）
      └─ MainPage（BottomNavigationBar 4 tab）
          ├─ HomePage                ← SensorService（加速度计 + 摇晃）
          │   ├─ PetWidget           ← AnimationController 呼吸动画 + 空闲行为
          │   │   └─ CustomPaint → PetPainter（6 情绪 + 睡眠绘制）
          │   ├─ TalkButton          ← 文字弹窗输入（替代语音）
          │   └─ 互动按钮
          ├─ StudyPage               ← V3 完整自习室
          │   ├─ StudyBloc           ← 计时器 + 专注度采样 + 学习历史
          │   ├─ VisionBloc          ← Apple Vision 情绪检测 + 趋势分析
          │   ├─ HeatmapCalendar     ← 热力图日历（月/年视图）
          │   ├─ _DayFocusChart      ← 24h 专注度折线图
          │   └─ 学习结束宠物庆祝
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

摄像头 → VisionDetector (Swift) → MethodChannel → VisionBloc
                                    ↓
                              StudyBloc（专注度采样 + 趋势）
                              EmotionEngine（情绪干预）
                              PetBloc（宠物反应）
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
│   │   ├── pet_state.dart                # PetState: 6 情绪 × 8 活动 × 5 数值 + lastSleepAt
│   │   ├── pet_event.dart                # 事件类（含 VisionResult）
│   │   ├── study_state.dart              # StudyState: 3 计时模式 + focusCurve + completedSession
│   │   ├── user_action.dart              # UserAction + PetReaction（含 VisionResult）
│   │   └── growth_state.dart            # GrowthState: 等级/经验/每日上限
│   ├── services/
│   │   ├── emotion_engine.dart          # AI 情感推理引擎（规则 + 视觉情绪干预）
│   │   ├── firebase_service.dart        # Firebase 全部操作 + ValueNotifier 调试
│   │   ├── sensor_service.dart          # accelerometer + shake（sensors_plus）
│   │   ├── vision_service.dart          # V3: VisionResult/EmotionSpectrum/StudyScene
│   │   ├── study_history_service.dart   # V3: 学习记录 + 专注度曲线存储
│   │   ├── notification_service.dart    # 本地推送
│   │   └── debug_config.dart            # 全局 DEBUG 开关（ValueNotifier<bool>）
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
│           ├── heatmap_calendar.dart      # V3: 热力图日历组件（月视图）
│           ├── achievement_card.dart      # V3: 成就闪卡（备用）
│           ├── talk_button.dart           # 文字输入弹窗按钮
│           └── debug_bar.dart             # DEBUG 面板：Firebase 实时状态
├── ios/
│   ├── Runner/
│   │   ├── Info.plist                    # 权限声明（含 NSMicrophoneUsageDescription）
│   │   ├── GoogleService-Info.plist      # Firebase 配置
│   │   ├── AppDelegate.swift             # V3: VisionDetector 嵌入（场景识别+情绪谱+专注度）
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
| | table_calendar | ^3.1.2 | 日历组件 |
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

## 已知问题 & 版本演进

### 已完成（2026-07-23）

- [x] VisionDetector V3 — Apple Vision 原生（场景识别+情绪谱+专注度）
- [x] 昼夜节律精力系统（双峰余弦曲线 + 起床逻辑 + 睡眠质量）
- [x] 自习室热力图日历（月/年视图 + 24h 专注度折线图）
- [x] 学习历史存储 + 专注度采样曲线持久化
- [x] 学习结束宠物庆祝表现
- [x] 视觉情绪干预（7 维情绪谱 → 宠物反应）
- [x] 精力管理优化（白天地板 10% + 日间小憩 + 变化上限）
- [x] iOS 26 侧载崩溃修复

### 待开发

- [ ] 物理引擎重构（BlendShape + 微眼动 + 分频呼吸 + 情绪粒子）
- [ ] 手势交互矩阵（长按/连击/滑动/摇晃 + Haptic Feedback）
- [ ] DeepSeek API 集成 + 长期记忆系统
- [ ] 原生语音通道（SFSpeechRecognizer MethodChannel）
- [ ] 伴侣模式完善
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

---

# 🐾 HcyPet V2 — 完整更新文档

> 2026-07-22 · Phase 1-5 全部完成

---

## 📋 V2 目录

1. [V2 总体目标](#v2-总体目标)
2. [Phase 1: UI 极简重构](#phase-1-ui-极简重构)
3. [Phase 2: 双轨动画引擎](#phase-2-双轨动画引擎)
4. [Phase 3: AI 情感推理引擎](#phase-3-ai-情感推理引擎)
5. [Phase 4: Apple Vision 视觉追踪](#phase-4-apple-vision-视觉追踪)
6. [Phase 5: 整合打磨](#phase-5-整合打磨)
7. [养成系统完整规则](#养成系统完整规则)
8. [互动系统完整流程](#互动系统完整流程)
9. [V3 规划建议](#v3-规划建议)

---

## V2 总体目标

从"可用"升级到"动人"——让宠物真正"活"起来。

| 维度 | V1 | V2 |
|------|----|----|
| UI 风格 | Emoji + 毛玻璃 | 极简线条 + SF Symbols/Material Icons |
| 宠物动画 | 静态切换 | 60fps 双轨动画（空闲 + 情绪） |
| 宠物智能 | 5 种预设回应 | AI 情感推理 + 关键词分析 + 记忆 |
| 视觉追踪 | 占位 | Apple Vision 原生面部检测 |
| 养成系统 | 3 条基础进度条 | 等级/经验/称号/每日上限/饱腹度 |
| 陪伴体验 | 基础互动 | 作息模拟 + 随机事件 + 唤醒/入睡动画 |

---

## Phase 1: UI 极简重构

### 设计系统 (`lib/theme/design_constants.dart`)

| 常量 | 值 |
|------|-----|
| 主色 | `#4FC3F7` |
| 辅色 | `#2C3E50` |
| 强调色（亲密度） | `#FF6B9D` |
| 背景 | 纯黑 (`#000000`) |
| 字体 | SF Pro Display, ultralight/thin |

### 页面改动

- **主页**: 移除所有 Emoji 图标/标签，改为 Material Icons outlined。去除毛玻璃背景框，纯文字互动按钮
- **底部导航**: 纯图标 24px，无 label
- **状态栏**: 顶部一行浓缩：`Lv.X | ██ XP条 | 心情/精力/亲密 · 状态`
- **系统提示**: 底部小字 12px，5 秒自动消失

---

## Phase 2: 双轨动画引擎

### 新建文件

| 文件 | 用途 |
|------|------|
| `lib/presentation/pet/idle_behavior_scheduler.dart` | 空闲行为调度器 |

### 空闲行为

| 行为 | 间隔 | 时长 | 效果 |
|------|------|------|------|
| 眨眼 | 3-7s | 150ms | 睑裂快速闭合张开 |
| 左看 | 6-14s | 400ms | 瞳孔左移 8px |
| 右看 | 7-16s | 400ms | 瞳孔右移 8px |
| 歪头 | 15-30s | 600ms | 头部偏移 4px |
| 打哈欠 | 30-90s | 1.5s | 眼睛缩小 70% |

### 情绪过渡

- `PetWidget` 检测 `oldState.mood != newState.mood` → 触发 `AnimationController(800ms)`
- `PetPainter` 接受 `previousMood` + `transitionProgress` 参数

### 呼吸动画

- 整体 scale 0.98 ↔ 1.02，3 秒周期

---

## Phase 3: AI 情感推理引擎

### 新建文件

| 文件 | 用途 |
|------|------|
| `lib/models/user_action.dart` | 9 种输入类型 + `PetReaction` 输出模型 |
| `lib/services/emotion_engine.dart` | 规则引擎核心 |

### 引擎架构

```
用户行为 → UserAction → EmotionEngine.process()
  ├─ 关键词情感分析（55 词库，中英文）
  ├─ 时间上下文（早/午/晚/深夜）
  ├─ 短时记忆（最近 5 条互动）
  ├─ 亲密度加权 + 递减收益
  └─ 短时冷却（重复互动收益递减）
       ↓
  PetReaction { targetMood, systemHint, intimacyDelta, shouldAnimate }
       ↓
  PetBloc._applyReaction() → emit 新状态
```

### 关键词词库（55 个）

**正面**: 开心/快乐/喜欢/爱/好/棒/厉害/加油/谢谢/哈哈/不错/太棒了/真好/完美/可爱/好看/漂亮/帅/成功/赢了/通过/放假/周末/休息/吃/美食/礼物/惊喜/nice/good/love/happy/great/wonderful/awesome

**负面**: 累/难过/伤心/烦/无聊/孤独/郁闷/痛苦/压力/疲惫/不好/不行/失败/讨厌/生气/困/想哭/崩溃/焦虑/紧张/害怕/担心/不舒服/头疼/感冒/生病/加班/熬夜/sad/tired/angry/bad/hate

### 短时冷却机制

| 间隔 | 抚摸收益 | 喂食收益 |
|------|:---:|:---:|
| < 10 秒 | 20% | 30% |
| 10-30 秒 | 50% | — |
| 30-60 秒 | 100% | 60% |
| > 60 秒 | 100% | 100% |

---

## Phase 4: Apple Vision 视觉追踪

### 新建文件

| 文件 | 用途 |
|------|------|
| `ios/Runner/VisionDetector.swift` | Apple Vision 原生实现 |
| `ios/Runner/AppDelegate.swift` | MethodChannel 注册 |

### 技术栈

```
Flutter (study_page) → VisionBloc → VisionService
       │ MethodChannel "com.hcypet.vision"
       ▼
Swift (VisionDetector)
  └─ AVCaptureSession (前置, .low 分辨率)
       └─ VNDetectFaceLandmarksRequest (5 FPS)
            ├─ 嘴部比例 → 情绪（开心/惊讶/难过/生气）
            ├─ 眉毛位置 → 情绪辅助
            ├─ 眼睛开合 → 困倦
            └─ 人脸位置 → 注意力评分
```

### 检测能力

| 情绪 | 方法 | 精度 |
|------|------|:---:|
| 开心 | 嘴部比例 >0.3 | ~70% |
| 惊讶 | 张嘴 + 眉毛上扬 | ~75% |
| 难过 | 嘴部比例 <0.1 + 眉毛下压 | ~60% |
| 生气 | 眉毛下压 >0.2 | ~65% |
| 注意力 | 人脸中心偏移 | ~80% |

### 性能参数

| 参数 | 值 |
|------|-----|
| 帧率 | 5 FPS |
| 分辨率 | `.low` preset |
| 检测间隔 | 200ms |

---

## Phase 5: 整合打磨

- VisionService 回调泄漏修复（stop 时清空）
- study_page 视觉停止遗漏修复（学习结束 → VisionStopEvent）
- PetWidget ticker dispose 顺序修正
- 错误状态 UI 反馈（摄像头不可用 → 红色 "无法启动"）
- ClearThoughtEvent 机制确保文字 5 秒后必消失
- Settings ListTile 墨水飞溅 Material 包装修复

---

## 养成系统完整规则

### 属性系统

| 属性 | 范围 | 初始值 | 说明 |
|------|:---:|:---:|------|
| 心情 (happiness) | 0-100% | 70% | 互动提升，自然衰减 |
| 精力 (energy) | 0-100% | 80% | 昼夜节律 + 互动 |
| 亲密度 (intimacy) | 0-100% | 50% | 经营式衰减 + 递减收益 |
| 饱腹度 (fullness) | 0-100% | 50% | 随时间消化，喂食提升 |
| 等级 (level) | 1-99 | 1 | 累计经验升级 |
| 经验 (exp) | 0-100%/级 | 0% | 每次互动获得 |

### 精力昼夜节律

| 时段 | 每 30s 变化 | 说明 |
|------|:---:|------|
| 6-10 点 | +1.2% | 早晨清醒 |
| 10-14 点 | -0.2% | 上午平稳 |
| 14-17 点 | -0.5% | 午后略困 |
| 17-21 点 | -0.3% | 傍晚恢复 |
| 21-2 点 | -1.2% | 晚间下降 |
| 2-6 点 | -1.8% | 深夜快速消耗 |
| 睡眠中 | +3.0% | 精力恢复 |

### 亲密度经营规则

| 条件 | 每 30s 衰减 | 约每天 |
|------|:---:|:---:|
| 正常 | -0.15% | -4.3% |
| >12h 不互动 | -0.4% | -11.5% |
| >24h 不互动 | -1.0% | -28.8% |
| >72h 不互动 | -2.5% | -72% |
| >80% 高亲密度 | ×1.5 | 维持更费力 |

### 亲密度递减收益

| 亲密度区间 | 涨幅系数 |
|------|:---:|
| <50% | 100% |
| 50-75% | 70% |
| 75-90% | 40% |
| >90% | 15% |

### 每日经验上限

| 行为 | 每日上限 | 经验 |
|------|:---:|:---:|
| 抚摸 | 5 次 | 0.05/次 |
| 喂食 | 5 次 | 0.08/次 |
| 学习 | 无上限 | 0.15/小时 |
| 番茄钟完成 | 无上限 | 0.12/次 |
| 伴侣消息 | 无上限 | 0.06/次 |

### 升级阈值

- 每 1.0 经验升一级
- 1-2 级：初识 / 3-7 级：入门 / 8-14 级：新手
- 15-24 级：熟练 / 25-39 级：达人 / 40-59 级：专家
- 60-79 级：大师 / 80-99 级：传说

### 每日随机事件

- 每天 3 次随机心情事件
- 约每 25 分钟可能触发一次
- 12 种事件：想出去玩/打喷嚏/做有趣的梦/想撒娇/窗外小鸟/闻到好吃的气味...

---

## 互动系统完整流程

### 抚摸 (Pet)

```
触摸"抚触"按钮
  ↓
检查睡眠状态？
  ├─ 是 → groggy 朦胧状态 2s → 完全清醒
  └─ 否 → 正常处理
       ↓
  EmotionEngine.process(UserAction.pet)
    ├─ 短时冷却检查（<10s→20%, 10-30s→50%）
    ├─ 亲密度递减收益
    └─ 随机系统提示（5 选 1）
       ↓
  PetState 更新：happiness +0.02×冷却, energy +0.01×冷却, intimacy +递减值
  GrowthState.recordPet() → 每日上限检查 → 经验 +0.05
  5 秒后 thought 自动消失
```

### 喂食 (Feed)

```
触摸"喂食"按钮
  ↓
饱腹度检查？
  ├─ >90% → 生气拒绝："太饱了！吃不下了..."（3s 后恢复）
  └─ 正常 → 继续
       ↓
  EmotionEngine.process(UserAction.feed)
    ├─ 短时冷却（<10s→30%, 10-60s→60%）
    └─ 饿了（<30%）→ 特别开心 "好好吃！好爱你~"
       ↓
  PetState：happiness +0.06×冷却, energy +0.12×冷却, fullness +0.25
  GrowthState.recordFeed() → 每日上限检查 → 经验 +0.08
```

### 说话 (Talk)

```
触摸"说话"按钮 → 弹窗输入文字
  ↓
检查睡眠状态？
  ├─ 是 → groggy "嗯？你在叫我吗..." 2s
  └─ 否 → 正常
       ↓
  EmotionEngine.process(UserAction.talk)
    ├─ 解析文字 → 关键词情感分析（55 词库）
    ├─ 正面 → happy mood + 正面提示
    ├─ 负面 → sad/sleepy mood + 共情提示（亲密度 +0.05）
    └─ 中性 → calm + 随机回应
       ↓
  PetState 更新
```

### 学习 (Study)

```
自习室标签 → 选择模式 → "开始"
  ↓
├─ 正向计时：无目标限制，累计计时
├─ 倒计时：设置目标分钟数，倒数至 0
└─ 番茄钟：预设 25/45/50/90min，完成自动记录
       ↓
  运行中：
    ├─ VisionBloc 启动摄像头（5 FPS 面部检测）
    ├─ 走神检测 → 宠物提醒 "专注点哦~"
    └─ 情绪检测 → 宠物共情反应
       ↓
  结束：
    ├─ PetActivity.celebrating 庆祝状态
    ├─ 随机推荐：喝水/吃东西/拉伸/听歌/散步...
    └─ GrowthState.recordStudy(0.5h) → 经验 +0.075
```

### 自动入睡/唤醒

```
_onTick（每 30s）
  ↓
23 点后 && 精力 <20% → 自动入睡 "zzz... 晚安~"
  ↓
睡眠中：
  ├─ 精力快速恢复 +3%/tick
  └─ 抚摸/说话 → groggy 唤醒 → 2s 后完全清醒
       ↓
7-9 点 && 精力 >60% → 自动醒来 "早上好... 刚睡醒~"
  ├─ 3s 朦胧状态
  └─ 完全清醒
```

---

## V3 规划建议

### 🎨 视觉升级
- 多种宠物品种可选（猫/狗/兔/仓鼠）
- 自定义颜色/饰品（项圈/帽子/围巾）
- 粒子特效（爱心飘出/星星闪烁/下雨）
- 更丰富的动画过渡（弹性/弹簧物理）

### 🤖 AI 升级
- 接入 Gemini Nano（Google 设备端 AI，免费离线）
- 对话式互动（不仅是关键词匹配，而是语义理解）
- 宠物性格系统（活泼/安静/傲娇，影响反应风格）
- 长期记忆（记住用户说过的重要事件）

### 🏠 场景系统
- 宠物房间装饰（家具/壁纸）
- 天气系统（根据真实天气变化宠物心情）
- 季节事件（生日/节日特殊内容）
- 外出冒险（宠物自己去探索带回礼物）