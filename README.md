# 🍡 Mochi V3 — 会呼吸的极简电子宠物

> Flutter 3.12+ · iOS 26+ · DeepSeek AI · Codemagic CI/CD

---

## 目录

1. [项目概述](#项目概述)
2. [核心模块](#核心模块)
3. [表情动画系统](#表情动画系统)
4. [触屏交互](#触屏交互)
5. [AI 对话与记忆](#ai-对话与记忆)
6. [视觉追踪](#视觉追踪)
7. [语音输入](#语音输入)
8. [自主行为](#自主行为)
9. [架构总览](#架构总览)
10. [完整文件结构](#完整文件结构)
11. [依赖清单](#依赖清单)
12. [Codemagic 构建](#codemagic-构建)
13. [已知缺陷 & 改进方向](#已知缺陷--改进方向)
14. [开发命令速查](#开发命令速查)

---

## 项目概述

Mochi V3 是一只住在手机里的极简电子宠物。**不画身体，只画神韵** —— 两个圆眼睛 + 可选弧线嘴巴，通过弹簧物理、Markov Chain 空闲调度、7 种触屏手势、DeepSeek AI 对话，成为一个"会呼吸的极简生命体"。

### 设计哲学

```
硬件是手机，软件是灵魂。
极简大眼萌 —— 极致简约，温度到骨子里。
```

### 宠物状态

| 情绪 | 视觉效果 |
|:---|:---|
| 平静 | 圆角矩形大眼，呼吸微波动 |
| 开心 | 弧形眯眼 ^ ^，脸红晕 |
| 惊讶 | 满开圆眼 + 螺旋晕（摇晃触发） |
| 难过 | 极扁细眼，微歪头 |
| 困倦 | 半闭眼 + Zzz |
| 思念 | 满开窄眼 + 爱心气泡 |
| 生气 | 后脑勺小眼 + 矢量 `#` 生气符号 |

---

## 核心模块

| 模块 | 说明 |
|:---|:---|
| 主页 | 宠物展示 + 互动按钮（抚触/喂食/说话） |
| 自习室 | 3 种计时 + Apple Vision 专注检测 + 热力图 |
| 伴侣 | Firebase 匿名登录 + 实时消息 |
| 设置 | API Key / 休眠参数 / Debug 开关 |

---

## 表情动画系统

### 参数化驱动

表情由 3 个浮点参数连续驱动：

| 参数 | 范围 | 作用 |
|:---|:---|:---|
| `eyelidOpen` | 0.0 ~ 1.0 | 0=全闭，1=满开 |
| `blushOpacity` | 0.0 ~ 0.6 | 开心/害羞脸红 |
| `eyeShiftX` | -1 ~ 1 | 平静时左右张望平移 |

### 弹簧物理 (MochiSpring + PhysicsTracker)

| 预设 | 刚度/阻尼 | 用途 |
|:---|:---|:---|
| `gentle` (100/22) | 临界阻尼 | 情绪平滑过渡 |
| `bouncy` (180/15) | 欠阻尼 | 开心弹跳、红晕 |
| `quick` (300/34) | 过阻尼 | 惊吓、挤压复位 |
| `bounce` (120/8) | 低阻尼 | 拖拽形变回弹 |

### Markov Chain 空闲调度

```
idle -> blinkQuick (48%) / lookLeft (12%) / lookRight (12%) / yawn (3%)
```

- IDLE 间隔 1.0~3.5s，呼吸波动 +-12%
- 眨眼 0.12~0.18s 快闭，触发闭眼弧线
- 张望 1.1~2.5s，滑出->停留->滑回，指数衰减返中
- 精力联动：>50% 张望加成，100% 时张望概率 ~40%

### 螺旋晕眼

摇晃/拉扯触发：阿基米德螺旋线 2.5 圈，左右镜像对旋，4 rad/s 持续旋转。

### 后脑勺生气

忽略心愿通知 1h 后，下次打开 App 显示 4s：小眼远距 + 矢量生气符号。

---

## 触屏交互

| 手势 | 效果 |
|:---|:---|
| 双击 | 弹跳开心 + Haptic light |
| 长按 (1.5s) | 抚摸眯眼 + Haptic medium |
| 连击 (3s 内 >=5) | 惊吓晕眩 + Haptic heavy |
| 滑动拖拽 | 橡皮拉伸（实时挤压形变） |
| 松手 | 弹回 + 晕眩 1.2s |
| 摇晃 (2s 内 >=3) | 晕眩 1.5s+ |

---

## AI 对话与记忆

| 功能 | 说明 |
|:---|:---|
| 对话 | 主页"说话" -> DeepSeek API -> AI 回复 |
| 记忆上下文 | 最近 5 条对话 + 昨日日记作为 prompt |
| 兜底 | 无 API Key/网络异常 -> 本地情绪引擎回复 |
| 重试 | 最多 3 次，间隔 500ms |

### SQLite 记忆库

```
memories: id, user_said, mood, time_label, timestamp (最多 200 条)
diary:    id, date, content (每天一条)
```

### 每日日记

凌晨 2:00 自动压缩今天 >=3 条记忆成 100 字日记。

---

## 视觉追踪

### EMA 深度滤波

| 参数 | 值 | 说明 |
|:---|:---|:---|
| 起始专注度 | 60% | 默认假设专注 |
| EMA (正常) | 0.12 | focus/calm 正常平滑 |
| EMA (负面) | 0.04 | frustrated/bored 慢涨快跌 |
| 烦躁阈值 | 0.55 | 仅 >0.55 才计 |
| 确认帧数 | 240 (~4s) | 需持续 4s 才上报 |
| 专注惯性 | 150 帧锁定 | 加持 +25% |

### Apple Vision 原生 (iOS)

5 种场景 × 7 维情绪谱 × 30 帧滑动窗口，全嵌入 `AppDelegate.swift`。

| 场景 | 判定条件 |
|:---|:---|
| 阅读/写字 | 头微低(pitch 0.1-0.35) + 头部稳定 |
| 电脑 | 头平视 + 水平扫视 |
| 手机 | 头低垂(pitch>0.35) + 人脸偏大 |
| 分心 | 频繁转头 或 人脸离开 >40% |
| 无人脸 | 未检测到人脸 |

**专注度评分** = headStability(0.30) + eyeStability(0.25) + facePresence(0.20) + motionCalmness(0.15) + postureScore(0.10)，乘以场景系数。

**7 维情绪**：calm · focused · frustrated · bored · happy · anxious · tired，各由 landmark 特征加权计算。

---

## 语音输入

按住 -> iOS AVAudioEngine + SFSpeechRecognizer (zh-CN) 实时收录，松手填入输入框。

---

## 自主行为

- 心愿系统：每 2h 推送通知，无视 1h -> 生气
- 不息屏：`UIApplication.shared.isIdleTimerDisabled = true`

---

## 架构总览

```
lib/
  main.dart
  bloc/          pet_bloc, study_bloc, vision_bloc
  models/        pet_state, pet_event, user_action, growth_state
  presentation/
    pages/       home_page, study_page, partner_page, settings_page
    pet/         mochi_physics, pet_painter, pet_widget, idle_behavior_scheduler, gesture_engine
    widgets/     talk_button, heatmap_calendar, ...
  services/      api_config, deepseek_service, memory_bank, wish_system,
                 vision_filter, vision_service, voice_service,
                 emotion_engine, notification_service, sensor_service, ...
  theme/         design_constants

ios/Runner/AppDelegate.swift   # Vision + Voice (single file)
```

---

## 依赖清单

flutter_bloc, shared_preferences, sqflite, http, path, sensors_plus, shake_plus, firebase_core/database/auth, flutter_local_notifications, flutter_svg, table_calendar

---

## Firebase 配置

### iOS 配置

1. 创建 Firebase 项目，添加 iOS App（Bundle ID: `com.hcypet.app`）
2. 下载 `GoogleService-Info.plist` → 放入 `ios/Runner/`
3. 启用服务：Authentication（匿名登录）、Realtime Database（测试模式）

### Database 规则

```json
{
  "rules": {
    "pets": { "$uid": { ".read": true, ".write": true } },
    "pairs": { "$code": { ".read": true, ".write": true } },
    "sessions": { "$sessionId": { ".read": true, ".write": true } }
  }
}
```

---

## Codemagic 构建

`codemagic.yaml` 配置：

- **触发**：推送 tag / 手动触发
- **构建**：`flutter build ipa --release`
- **签名**：App Store Connect API Key 自动管理
- **分发**：上传至 Codemagic Artifacts（配合 SideStore 侧载）

---

## iOS 26 兼容性

### 崩溃修复记录

| 问题 | 原因 | 修复 |
|:---|:---|:---|
| `AVAudioSession` 崩溃 | iOS 26 强制要求 `.record` 模式 | 语音录制前显式 `setCategory(.record)` |
| 多 Swift 文件打包失败 | Flutter 插件注册冲突 | 合并为单文件 `AppDelegate.swift` |
| Vision 权限未声明 | Info.plist 缺 `NSCameraUsageDescription` | 已添加 |

### 权限声明 (Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>HcyPet 需要使用摄像头进行视觉追踪和情绪检测</string>
<key>NSMicrophoneUsageDescription</key>
<string>HcyPet 需要使用麦克风接收你的语音指令</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>HcyPet 需要语音识别来理解你说的话</string>
```

---

## 已知缺陷 & 改进方向

### 视觉准确度问题

1. **起始专注度不稳定**：iOS 冷启动 raw 数据波动大，前几秒有跳变
2. **场景误判**：phone 和 reading 边界模糊，低头看手机偶尔被判 reading
3. **情绪谱原始偏差**：Apple Vision landmark 精度有限，frustrated/anxious 原始值偏高
4. **光线敏感**：暗光/逆光下丢失率高，noFace 频发

### 动画系统缺陷

1. **过渡僵硬**：只有 3 个 tracker，缺少"中间态"表情和曲线过渡
2. **空闲模式单一**：7 状态 Markov Chain 不够丰富，缺少好奇/害羞/偷笑等
3. **缺乏上下文感知**：动画不随场景变化（自习室不应频繁张望）
4. **螺旋眼简单**：静态旋转，无"清醒渐恢复"过渡

### 功能完善度

1. **伴侣模块未深度集成 V3**：语音消息、日记共享、同步生气状态
2. **语音仅 iOS 真机可用**：无 Web/模拟器降级方案
3. **DeepSeek 延迟无反馈**：API 调用时宠物静止，需 loading 状态
4. **心愿系统不灵活**：2h 固定间隔，无勿扰时段设置
5. **成长系统脱节**：升级无庆祝动画，等级仅数字变化

### 性能优化空间

1. PhysicsTracker 每帧全量更新，即使 settled
2. PetPainter.shouldRepaint 始终 true
3. 静态场景可加 RepaintBoundary 减少重绘

---

## 开发命令速查

```bash
flutter pub get          # 获取依赖
flutter run -d chrome    # Web 测试
flutter run -d <id>      # iOS 真机
flutter build ipa        # 构建 IPA
flutter analyze          # 代码分析
flutter clean && flutter pub get  # 清理重建
```

---

> Mochi V3 — 2026.07
> "不画身体，只画神韵。"
