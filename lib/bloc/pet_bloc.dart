import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_state.dart';
import '../models/pet_event.dart';
import '../models/user_action.dart';
import '../models/growth_state.dart';
import '../services/emotion_engine.dart';

/// 宠物 Bloc — V2 AI 情感引擎驱动 + 养成系统 + 作息模拟
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
  static const _dailyEventCount = 3; // 每天 3 次随机事件
  int _todayEventsFired = 0;
  final _random = DateTime.now().millisecond; // 伪随机种子

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
    // 如果宠物在睡觉，需要先唤醒
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

  void _onTick(PetTickEvent event, Emitter<PetState> emit) {
    final now = DateTime.now();
    final hour = now.hour;

    // 睡眠中：精力快速恢复
    if (state.activity == PetActivity.sleeping) {
      final newEnergy = (state.energy + 0.03).clamp(0.0, 1.0);
      // 早晨自动醒来 (7-9点)
      if (hour >= 7 && hour <= 9 && newEnergy > 0.6) {
        emit(state.copyWith(
          activity: PetActivity.groggy, energy: newEnergy,
          mood: PetMood.sleepy, isAwake: true,
          thought: '早上好... 刚睡醒~',
        ));
        _scheduleThoughtClear();
        Future.delayed(const Duration(seconds: 3), () {
          if (!isClosed) add(PetSetActivityEvent(PetActivity.idle));
        });
        return;
      }
      emit(state.copyWith(energy: newEnergy));
      return;
    }

    // 午夜/凌晨被唤醒 → 快速回到睡眠
    if ((hour >= 23 || hour < 5) && state.activity == PetActivity.groggy && state.energy < 0.3) {
      emit(state.copyWith(
        activity: PetActivity.sleeping, isAwake: false, mood: PetMood.sleepy, thought: 'zzz...',
      ));
      return;
    }

    // 晚上自动入睡 (23点后，精力低)
    if ((hour >= 23 || hour < 6) && state.energy < 0.2 && state.activity != PetActivity.studying) {
      emit(state.copyWith(
        activity: PetActivity.sleeping, isAwake: false,
        mood: PetMood.sleepy, thought: 'zzz... 晚安~',
      ));
      _scheduleThoughtClear();
      return;
    }

    final decayFactor = 1.0;
    final idleHours = now.difference(state.lastInteraction).inHours;

    // 饱腹度衰减
    final feedHours = state.lastFedAt != null ? now.difference(state.lastFedAt!).inHours : 10;
    final newFullness = (state.fullness - 0.03 * (feedHours / 1.0).clamp(0.0, 2.0)).clamp(0.0, 1.0);
    // 饿了会撒娇（低落）
    final isHungry = newFullness < 0.25 && state.fullness >= 0.25;

    // ======== 1. 精力：模拟人体昼夜节律 ========
    double energyDelta;
    if (hour >= 6 && hour < 10) {
      energyDelta = 0.012; // 早晨自然醒来，精力上升
    } else if (hour >= 10 && hour < 12) {
      energyDelta = -0.002;
    } else if (hour >= 12 && hour < 15) {
      energyDelta = -0.010; // 午饭后犯困加速
    } else if (hour >= 15 && hour < 17) {
      energyDelta = -0.005;
    } else if (hour >= 17 && hour < 21) {
      energyDelta = -0.003; // 傍晚恢复
    } else if (hour >= 21 || hour < 2) {
      energyDelta = -0.012; // 晚间加速下降
    } else {
      energyDelta = -0.018; // 深夜（2-6点）快速下降
    }

    // ======== 2. 心情：缓慢衰减 ========
    double happinessDecay = -0.003;
    // 长时间未互动加速衰减
    if (idleHours > 8) happinessDecay = -0.008;

    // ======== 3. 亲密度：经营式衰减 ========
    double intimacyDecay = -0.0015; // 每天约 -4.3%
    if (idleHours > 12) intimacyDecay = -0.004;  // 半天不互动
    if (idleHours > 24) intimacyDecay = -0.010;  // 一天不互动加速
    if (idleHours > 72) intimacyDecay = -0.025;  // 三天不互动陡降
    // 高亲密度时衰减更明显（维持需要更多努力）
    if (state.intimacy > 0.8) intimacyDecay *= 1.5;

    // ======== 4. AI 引擎空闲处理 ========
    final action = UserAction.idle(Duration(hours: idleHours));
    final reaction = _engine.process(action, currentState: state);

    // ======== 5. 合成新值 ========
    final newHappiness = (state.happiness + happinessDecay * decayFactor + reaction.happinessDelta).clamp(0.0, 1.0);
    final newEnergy = (state.energy + energyDelta * decayFactor + reaction.energyDelta).clamp(0.0, 1.0);
    final newIntimacy = (state.intimacy + intimacyDecay * decayFactor + reaction.intimacyDelta).clamp(0.0, 1.0);

    // ======== 6. 情绪判断 ========
    PetMood newMood = reaction.targetMood != state.mood ? reaction.targetMood : state.mood;
    if (isHungry && newMood != PetMood.missing) {
      newMood = PetMood.sad; // 饿了会撒娇
    } else if (newEnergy < 0.12 && newMood != PetMood.missing) {
      newMood = PetMood.sleepy;
    } else if (newHappiness < 0.20) {
      newMood = PetMood.sad;
    } else if (newHappiness < 0.40) {
      newMood = PetMood.calm;
    }

    // ======== 7. 每日随机事件 ========
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
    final action = UserAction.vision(
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
