import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_state.dart';
import '../models/pet_event.dart';
import '../models/user_action.dart';
import '../models/growth_state.dart';
import '../services/emotion_engine.dart';

/// 宠物 Bloc — V3 昼夜节律精力 + 情绪联动 + AI 引擎
class PetBloc extends Bloc<PetEvent, PetState> {
  Timer? _decayTimer;
  static const _decayInterval = Duration(seconds: 30);
  static const _storageKey = 'pet_state';

  /// AI 情感推理引擎
  final EmotionEngine _engine = EmotionEngine();

  /// 个人养成数据（本地，不与伴侣同步）
  GrowthState _growth = GrowthState.initial();
  GrowthState get growth => _growth;

  /// 每日随机事件
  DateTime _lastDailyEventDate = DateTime.now();

  /// 系统提示自动消失计时
  DateTime? _thoughtSetAt;
  static const _dailyEventCount = 3;
  int _todayEventsFired = 0;

  /// 起床时间（今天是否已计算过起床精力）
  DateTime? _todayWakeDate;

  PetBloc() : super(PetState.initial()) {
    on<PetInitEvent>(_onInit);
    on<PetPetEvent>(_onPet);
    on<PetTalkEvent>(_onTalk);
    on<PetFeedEvent>(_onFeed);
    on<PetShakeEvent>(_onShake);
    on<PetTickEvent>(_onTick);
    on<PetSetMoodEvent>(_onSetMood);
    on<PetSetActivityEvent>(_onSetActivity);
    on<PetStartStudyingEvent>(_onStartStudying);
    on<PetStopStudyingEvent>(_onStopStudying);
    on<PetUpdateIntimacyEvent>(_onUpdateIntimacy);
    on<PetResetEvent>(_onReset);
    on<PetPartnerMessageEvent>(_onPartnerMessage);
    on<PetVisionEvent>(_onVision);
    on<ClearThoughtEvent>(_onClearThought);

    add(PetInitEvent());
    _startDecayTimer();
  }

  /// 记录 thought 设置时间，5 秒后自动清除
  void _scheduleThoughtClear() {
    _thoughtSetAt = DateTime.now();
    Timer(const Duration(seconds: 5), () {
      if (!isClosed) add(ClearThoughtEvent());
    });
  }

  // ============ 辅助：应用引擎输出 ============

  PetState _applyReaction(PetReaction reaction, {PetActivity? activity}) {
    _engine.updateIntimacy(state.intimacy + reaction.intimacyDelta);
    final hint = reaction.systemHint.isNotEmpty ? reaction.systemHint : null;
    if (hint != null) _scheduleThoughtClear();
    return state.copyWith(
      mood: reaction.targetMood,
      happiness: (state.happiness + reaction.happinessDelta).clamp(0.0, 1.0),
      energy: (state.energy + reaction.energyDelta).clamp(0.0, 1.0),
      intimacy: (state.intimacy + reaction.intimacyDelta).clamp(0.0, 1.0),
      lastInteraction: DateTime.now(),
      activity: activity ?? reaction.suggestedActivity,
      thought: hint,
    );
  }

  // ============ 事件处理器 ============

  Future<void> _onInit(PetInitEvent event, Emitter<PetState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final loaded = PetState.fromJson(data);
        _engine.updateIntimacy(loaded.intimacy);
        emit(loaded);
        _growth = await GrowthState.load();
        return;
      }
    } catch (_) {}
    _growth = await GrowthState.load();
    emit(PetState.initial());
  }

  Future<void> _onPet(PetPetEvent event, Emitter<PetState> emit) async {
    // 如果宠物在睡觉，需要先唤醒（记录睡眠打断）
    if (!state.isAwake || state.activity == PetActivity.sleeping) {
      final groggyState = state.copyWith(
        activity: PetActivity.groggy,
        mood: PetMood.sleepy,
        isAwake: true,
        wakeAttempts: state.wakeAttempts + 1,
        thought: '嗯... 刚睡醒...',
        lastInteraction: DateTime.now(),
      );
      _scheduleThoughtClear();
      emit(groggyState);
      _saveState(groggyState);
      // 2 秒后完全清醒
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) add(PetSetActivityEvent(PetActivity.idle));
      });
      return;
    }

    final action = UserAction.pet();
    final reaction = _engine.process(action, currentState: state);
    final newState = _applyReaction(reaction);
    _growth = _growth.recordPet();
    _growth.save();
    emit(newState);
    await _saveState(newState);

    Future.delayed(const Duration(seconds: 3), () {
      if (!isClosed) add(PetSetActivityEvent(PetActivity.idle));
    });
    // 4 秒后情绪回到平静
    Future.delayed(const Duration(seconds: 4), () {
      if (!isClosed) add(PetSetMoodEvent(PetMood.calm));
    });
  }

  Future<void> _onTalk(PetTalkEvent event, Emitter<PetState> emit) async {
    // 睡觉时说话也会唤醒
    if (!state.isAwake) {
      final groggyState = state.copyWith(
        activity: PetActivity.groggy, mood: PetMood.sleepy,
        isAwake: true, wakeAttempts: state.wakeAttempts + 1,
        thought: '嗯？你在叫我吗...', lastInteraction: DateTime.now(),
      );
      _scheduleThoughtClear();
      emit(groggyState);
      _saveState(groggyState);
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) add(PetSetActivityEvent(PetActivity.idle));
      });
      return;
    }

    final action = UserAction.talk(event.message ?? '');
    final reaction = _engine.process(action, currentState: state);
    final newState = _applyReaction(reaction);
    emit(newState);
    await _saveState(newState);

    Future.delayed(const Duration(seconds: 5), () {
      if (!isClosed) add(PetSetMoodEvent(PetMood.calm));
    });
  }

  Future<void> _onFeed(PetFeedEvent event, Emitter<PetState> emit) async {
    // 饱腹检查：太饱了会拒绝
    if (state.fullness > 0.9) {
      final angryState = state.copyWith(
        mood: PetMood.sad,
        thought: '太饱了！吃不下了...',
        lastInteraction: DateTime.now(),
      );
      _scheduleThoughtClear();
      emit(angryState);
      Future.delayed(const Duration(seconds: 3), () {
        if (!isClosed) add(PetSetMoodEvent(PetMood.calm));
      });
      return;
    }

    final action = UserAction.feed();
    final reaction = _engine.process(action, currentState: state);
    // 随机爱心表情
    final showHeart = state.fullness < 0.3; // 饿了会特别开心
    final hint = showHeart ? '好好吃！好爱你~' : reaction.systemHint;
    final newState = _applyReaction(reaction).copyWith(
      fullness: (state.fullness + 0.25).clamp(0.0, 1.0),
      lastFedAt: DateTime.now(),
      thought: hint.isNotEmpty ? hint : null,
    );
    _growth = _growth.recordFeed();
    _growth.save();
    emit(newState);
    await _saveState(newState);

    Future.delayed(const Duration(seconds: 4), () {
      if (!isClosed) add(PetSetMoodEvent(PetMood.calm));
    });
  }

  Future<void> _onShake(PetShakeEvent event, Emitter<PetState> emit) async {
    final action = UserAction.shake();
    final reaction = _engine.process(action, currentState: state);
    final newState = _applyReaction(reaction);
    emit(newState);
    await _saveState(newState);

    Future.delayed(const Duration(seconds: 2), () {
      if (!isClosed) add(PetSetMoodEvent(PetMood.calm));
    });
  }

  // ============================================================
  // V3 昼夜节律系统
  // ============================================================

  /// 计算任意时刻的昼夜节律目标精力值 (0~1)
  ///
  /// 曲线特征:
  ///   08:30 → ~90%  晨峰
  ///   12:30 → ~50%  午饭后低谷
  ///   16:00 → ~80%  午后回升
  ///   22:00 → ~15%  晚间入睡前
  ///   03:00 → ~8%   深夜最低
  double _computeCircadianTargetEnergy(DateTime now) {
    final hour = now.hour + now.minute / 60.0;

    // 用双峰余弦波建模昼夜节律:
    //   baseCos: 周期24h, 峰值8:30(90%), 谷值20:30(10%)
    //   afternoonHump: 下午3:30额外回升
    //   lunchDip: 午饭后深谷(12:30)

    final angle = (hour - 8.5) / 24.0 * 2 * math.pi;
    final baseCos = 0.5 + 0.4 * math.cos(angle);

    // 午后回升高斯（中心15:30，宽度±3h）
    final afternoonHump = 0.28 * math.exp(-((hour - 15.5) * (hour - 15.5)) / 18.0);

    // 午饭低谷高斯（中心12:30，宽度±1.5h）
    final lunchDip = 0.22 * math.exp(-((hour - 12.5) * (hour - 12.5)) / 2.8);

    var energy = baseCos + afternoonHump - lunchDip;
    return energy.clamp(0.06, 0.95);
  }

  /// 计算起床时的初始精力（基于睡眠质量）
  double _computeWakeUpEnergy() {
    final sleepAt = state.lastSleepAt;
    if (sleepAt == null) {
      // 无睡眠记录 → 默认90%
      return 0.90;
    }

    final now = DateTime.now();
    final sleepHours = now.difference(sleepAt).inMinutes / 60.0;

    // 睡眠质量 = 时长因子 × 打断惩罚
    // 理想8h=1.0, 4h=0.5, <2h=0.25
    final durationQuality = (sleepHours / 8.0).clamp(0.25, 1.0);

    // 每次被打断扣15%，最多扣60%
    final interruptionPenalty = (state.wakeAttempts * 0.15).clamp(0.0, 0.6);
    final quality = (durationQuality * (1.0 - interruptionPenalty)).clamp(0.2, 1.0);

    // 基础精力 = 质量 × 90%
    return (0.90 * quality).clamp(0.25, 0.95);
  }

  /// 计算起床时的初始情绪
  double _computeWakeUpMood(double wakeUpEnergy) {
    // 基础情绪60%，精力<70%时降到40%
    if (wakeUpEnergy < 0.70) return 0.40;
    return 0.60;
  }

  /// 检查是否为新的一天（需要重新计算起床精力）
  bool _isNewDay(DateTime now) {
    if (_todayWakeDate == null) return true;
    return _todayWakeDate!.day != now.day ||
           _todayWakeDate!.month != now.month ||
           _todayWakeDate!.year != now.year;
  }

  // ============================================================
  // 每 tick 处理（30秒一次）
  // ============================================================

  void _onTick(PetTickEvent event, Emitter<PetState> emit) {
    final now = DateTime.now();
    final hour = now.hour;
    final isNight = (hour >= 23 || hour < 7); // 23:00-07:00 夜间

    // ================================================================
    // 状态：睡眠中
    // ================================================================
    if (state.activity == PetActivity.sleeping || !state.isAwake) {
      // 记录入睡时间
      final effectiveSleepAt = state.lastSleepAt ?? now;

      // 睡眠期间精力恢复：每30s恢复3%
      final sleepRecovery = 0.03;
      final newEnergy = (state.energy + sleepRecovery).clamp(0.0, 0.95);

      // 早晨自动醒来 (7:00-9:00)
      if (hour >= 7 && hour < 9 && newEnergy >= 0.30) {
        final wakeEnergy = _computeWakeUpEnergy();
        final wakeMood = _computeWakeUpMood(wakeEnergy);
        _todayWakeDate = now;

        final moodLabel = wakeEnergy < 0.70 ? '还没睡够...' : '早上好！新的一天~';
        emit(state.copyWith(
          activity: PetActivity.groggy,
          mood: PetMood.sleepy,
          isAwake: true,
          energy: wakeEnergy,
          happiness: wakeMood,
          wakeAttempts: 0, // 重置
          lastInteraction: now,
          thought: moodLabel,
        ));
        _scheduleThoughtClear();
        _saveState(state); // will save after this emit in next tick
        // 3 秒后完全清醒
        Future.delayed(const Duration(seconds: 3), () {
          if (!isClosed) add(PetSetActivityEvent(PetActivity.idle));
        });
        return;
      }

      emit(state.copyWith(
        energy: newEnergy,
        lastSleepAt: effectiveSleepAt,
      ));
      return;
    }

    // ================================================================
    // 状态：刚醒（groggy → idle 过渡）
    // ================================================================
    if (state.activity == PetActivity.groggy) {
      // 几秒后自动转idle（由外部 Future.delayed 触发），这里不做额外衰减
      // 检查是否需要重新入睡（午夜被唤醒后快速回睡）
      if (isNight && state.energy < 0.20) {
        _goToSleep(emit, now);
        return;
      }
      return;
    }

    // ================================================================
    // 状态：清醒中 → 精力向昼夜节律目标平滑逼近
    // ================================================================

    // 1. 检查是否需要自动入睡
    //    夜间(23-7)：精力<18%且不在学习时入睡
    //    白天(7-23)：精力<8%且空闲>2小时时小憩
    if (isNight && state.energy < 0.18 && state.activity != PetActivity.studying) {
      _goToSleep(emit, now);
      return;
    }
    final isDaytime = hour >= 7 && hour < 23;
    final idleHours = now.difference(state.lastInteraction).inHours;
    if (isDaytime && state.energy < 0.08 && idleHours > 2 && state.activity == PetActivity.idle) {
      _goToSleep(emit, now);
      return;
    }

    // 2. 昼夜节律目标精力
    final circadianTarget = _computeCircadianTargetEnergy(now);

    // 3. 精力平滑趋向目标（带变化上限防止暴跌）
    //    白天：0.5%/tick，上限 ±0.3%
    //    晚间(20-23)：1%/tick，上限 ±0.6%（加速趋向入睡）
    //    低精力(<20%)回升：2%/tick，上限 +1%
    //    学习期间减半
    final energyGap = circadianTarget - state.energy;
    final eveningWindow = hour >= 20 && hour < 23;
    double baseRate = 0.005;
    double maxChange = 0.003;
    if (eveningWindow) { baseRate = 0.01; maxChange = 0.006; }
    if (state.energy < 0.20 && energyGap > 0) { baseRate = 0.02; maxChange = 0.01; }
    if (state.activity == PetActivity.studying) { baseRate *= 0.5; maxChange *= 0.5; }
    final energyDelta = (energyGap * baseRate).clamp(-maxChange, maxChange);
    var newEnergy = (state.energy + energyDelta).clamp(0.0, 1.0);

    // 白天精力地板：最低 10%，避免长期卡在极低值
    if (isDaytime && newEnergy < 0.10) newEnergy = 0.10;

    // 4. 心情衰减（基础 -0.003/tick，长时间未互动加速）
    double happinessDelta = -0.003;
    if (idleHours > 8) happinessDelta = -0.008;
    // 如果精力很低，心情也跟着下降
    if (newEnergy < 0.20) happinessDelta -= 0.005;

    // 5. 饱腹度衰减
    final feedHours = state.lastFedAt != null ? now.difference(state.lastFedAt!).inHours : 10;
    final newFullness = (state.fullness - 0.03 * (feedHours / 1.0).clamp(0.0, 2.0)).clamp(0.0, 1.0);
    final isHungry = newFullness < 0.25 && state.fullness >= 0.25;

    // 6. 亲密度衰减
    double intimacyDelta = -0.0015;
    if (idleHours > 12) intimacyDelta = -0.004;
    if (idleHours > 24) intimacyDelta = -0.010;
    if (idleHours > 72) intimacyDelta = -0.025;
    if (state.intimacy > 0.8) intimacyDelta *= 1.5;

    // 7. AI 引擎空闲处理
    final action = UserAction.idle(Duration(hours: idleHours));
    final reaction = _engine.process(action, currentState: state);

    // 8. 合成
    final newHappiness = (state.happiness + happinessDelta + reaction.happinessDelta).clamp(0.0, 1.0);
    final newIntimacy = (state.intimacy + intimacyDelta + reaction.intimacyDelta).clamp(0.0, 1.0);

    // 9. 情绪推断
    PetMood newMood = reaction.targetMood != state.mood ? reaction.targetMood : state.mood;
    if (isHungry && newMood != PetMood.missing) {
      newMood = PetMood.sad;
    } else if (newEnergy < 0.15) {
      newMood = PetMood.sleepy;
    } else if (newHappiness < 0.20) {
      newMood = PetMood.sad;
    } else if (newHappiness < 0.40) {
      newMood = PetMood.calm;
    }

    // 10. 每日随机事件
    String? eventThought = _checkDailyEvent(now, newMood);
    final hungryThought = isHungry ? '肚子好饿... 喂我吃点东西吧~' : null;

    final newState = state.copyWith(
      happiness: newHappiness,
      energy: newEnergy,
      intimacy: newIntimacy,
      mood: newMood,
      fullness: newFullness,
      thought: eventThought ?? hungryThought ?? (reaction.systemHint.isNotEmpty ? reaction.systemHint : state.thought),
    );
    _engine.updateIntimacy(newIntimacy);
    if (eventThought != null || hungryThought != null || reaction.systemHint.isNotEmpty) {
      _scheduleThoughtClear();
    }
    emit(newState);

    if (newState.mood != state.mood || newState.intimacy != state.intimacy) {
      _saveState(newState);
    }
  }

  /// 进入睡眠
  void _goToSleep(Emitter<PetState> emit, DateTime now) {
    emit(state.copyWith(
      activity: PetActivity.sleeping,
      isAwake: false,
      mood: PetMood.sleepy,
      lastSleepAt: now,
      thought: 'zzz... 晚安~',
    ));
    _scheduleThoughtClear();
    _saveState(state);
  }

  /// 每日随机心情事件（每天 2-4 次，随机时间触发）
  String? _checkDailyEvent(DateTime now, PetMood currentMood) {
    // 检查是否新的一天
    if (_lastDailyEventDate.day != now.day ||
        _lastDailyEventDate.month != now.month ||
        _lastDailyEventDate.year != now.year) {
      _lastDailyEventDate = now;
      _todayEventsFired = 0;
    }

    // 已达到每日事件上限
    if (_todayEventsFired >= _dailyEventCount) return null;

    // 每个 tick 有 2% 概率触发（约每 25 分钟一次）
    final seed = now.minute + now.second + now.day;
    if ((seed + _todayEventsFired * 17) % 50 != 0) return null;

    _todayEventsFired++;

    // 随机事件池
    final events = <String>[
      '突然好想出去玩！',
      '今天天气真不错~',
      '打了个小喷嚏',
      '做了个有趣的梦...',
      '好想听你说话',
      '肚子有点饿了',
      '发现了一只小蝴蝶',
      '今天特别想撒娇',
      '窗外有一只小鸟',
      '好像听到你在叫我',
      '伸了个懒腰',
      '闻到了好吃的气味',
    ];

    return events[(_todayEventsFired * 7 + now.second) % events.length];
  }

  void _onSetMood(PetSetMoodEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(mood: event.mood, lastInteraction: DateTime.now());
    emit(newState);
    _saveState(newState);
  }

  void _onSetActivity(PetSetActivityEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(
      activity: event.activity,
      isAwake: event.activity != PetActivity.sleeping,
    );
    emit(newState);
    _saveState(newState);
  }

  void _onStartStudying(PetStartStudyingEvent event, Emitter<PetState> emit) {
    final action = UserAction.studyStart();
    final reaction = _engine.process(action, currentState: state);
    final newState = _applyReaction(reaction);
    emit(newState);
    _saveState(newState);
  }

  void _onStopStudying(PetStopStudyingEvent event, Emitter<PetState> emit) {
    final action = UserAction.studyStop();
    final reaction = _engine.process(action, currentState: state);
    // 庆祝！随机推荐
    final recommendations = ['喝水', '吃东西', '拉伸运动', '听首歌', '抱抱宠物', '散个步', '深呼吸', '闭眼休息'];
    final rec = recommendations[DateTime.now().second % recommendations.length];
    final hint = '${reaction.systemHint} 建议$rec~';
    final newState = _applyReaction(reaction, activity: PetActivity.celebrating).copyWith(
      thought: hint,
    );
    _growth = _growth.recordStudy(0.5);
    _growth.save();
    emit(newState);
    _saveState(newState);

    Future.delayed(const Duration(seconds: 5), () {
      if (!isClosed) add(PetSetActivityEvent(PetActivity.idle));
      if (!isClosed) add(PetSetMoodEvent(PetMood.calm));
    });
  }

  void _onUpdateIntimacy(PetUpdateIntimacyEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(
      intimacy: (state.intimacy + event.amount).clamp(0.0, 1.0),
    );
    _engine.updateIntimacy(newState.intimacy);
    emit(newState);
    _saveState(newState);
  }

  void _onReset(PetResetEvent event, Emitter<PetState> emit) {
    _engine.clearMemory();
    emit(PetState.initial());
    _saveState(PetState.initial());
  }

  void _onPartnerMessage(PetPartnerMessageEvent event, Emitter<PetState> emit) {
    final action = UserAction.partnerMessage(event.message);
    final reaction = _engine.process(action, currentState: state);
    final newState = _applyReaction(reaction);
    _growth = _growth.recordPartnerMessage();
    _growth.save();
    emit(newState);
    _saveState(newState);

    Future.delayed(const Duration(seconds: 6), () {
      if (!isClosed) add(PetSetMoodEvent(PetMood.calm));
    });
  }

  void _onClearThought(ClearThoughtEvent event, Emitter<PetState> emit) {
    if (state.thought == null) return;
    emit(state.copyWith(thought: null));
    _thoughtSetAt = null;
  }

  void _onVision(PetVisionEvent event, Emitter<PetState> emit) {
    final vr = event.visionResult;
    final action = vr != null
        ? UserAction.visionResult(vr as dynamic)
        : UserAction.vision(
            emotion: event.emotion,
            attentionScore: event.attentionScore,
          );
    final reaction = _engine.process(action, currentState: state);
    final newState = _applyReaction(reaction);
    emit(newState);
  }

  // ============ 持久化 ============

  Future<void> _saveState(PetState s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(s.toJson()));
    } catch (_) {}
  }

  void _startDecayTimer() {
    _decayTimer?.cancel();
    _decayTimer = Timer.periodic(_decayInterval, (timer) {
      if (!isClosed) add(PetTickEvent(_decayInterval));
    });
  }

  @override
  Future<void> close() {
    _decayTimer?.cancel();
    return super.close();
  }
}
