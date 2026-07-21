import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_state.dart';
import '../models/pet_event.dart';

/// 宠物 Bloc - 管理所有宠物状态逻辑
class PetBloc extends Bloc<PetEvent, PetState> {
  static const _storageKey = 'pet_state';

  PetBloc() : super(PetState.initial()) {
    // 注册事件处理器
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

    add(PetInitEvent());
  }

  // ============ 事件处理器 ============

  /// 初始化：从 SharedPreferences 加载状态
  Future<void> _onInit(PetInitEvent event, Emitter<PetState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        final loadedState = PetState.fromJson(data);
        emit(loadedState);
        return;
      }
    } catch (e) {
      // 加载失败，使用默认状态
    }
    emit(PetState.initial());
  }

  /// 抚摸宠物
  Future<void> _onPet(PetPetEvent event, Emitter<PetState> emit) async {
    final newState = state.copyWith(
      mood: _getMoodAfterPet(state.mood),
      happiness: (state.happiness + 0.05).clamp(0.0, 1.0),
      intimacy: (state.intimacy + 0.02).clamp(0.0, 1.0),
      energy: (state.energy + 0.03).clamp(0.0, 1.0),
      lastInteraction: DateTime.now(),
      activity: PetActivity.playing,
      thought: '被抚摸了好舒服~ 🥰',
    );
    emit(newState);
    await _saveState(newState);

    // 3秒后恢复空闲状态
    Future.delayed(const Duration(seconds: 3), () {
      if (!isClosed) {
        add(PetSetActivityEvent(PetActivity.idle));
      }
    });
  }

  /// 与宠物说话
  Future<void> _onTalk(PetTalkEvent event, Emitter<PetState> emit) async {
    final newState = state.copyWith(
      mood: PetMood.happy,
      happiness: (state.happiness + 0.04).clamp(0.0, 1.0),
      intimacy: (state.intimacy + 0.03).clamp(0.0, 1.0),
      lastInteraction: DateTime.now(),
      thought: event.message?.isNotEmpty == true 
          ? '听到你说: ${event.message}' 
          : '你在和我说话吗~ 🎵',
    );
    emit(newState);
    await _saveState(newState);

    // 5秒后恢复平静
    Future.delayed(const Duration(seconds: 5), () {
      if (!isClosed) {
        add(PetSetMoodEvent(PetMood.calm));
      }
    });
  }

  /// 喂食宠物
  Future<void> _onFeed(PetFeedEvent event, Emitter<PetState> emit) async {
    final newState = state.copyWith(
      mood: PetMood.happy,
      happiness: (state.happiness + 0.08).clamp(0.0, 1.0),
      energy: (state.energy + 0.1).clamp(0.0, 1.0),
      intimacy: (state.intimacy + 0.04).clamp(0.0, 1.0),
      lastInteraction: DateTime.now(),
      thought: '好好吃！谢谢~ 🍖',
    );
    emit(newState);
    await _saveState(newState);

    Future.delayed(const Duration(seconds: 4), () {
      if (!isClosed) {
        add(PetSetMoodEvent(PetMood.calm));
      }
    });
  }

  /// 摇晃手机
  Future<void> _onShake(PetShakeEvent event, Emitter<PetState> emit) async {
    final newState = state.copyWith(
      mood: PetMood.surprised,
      lastInteraction: DateTime.now(),
      thought: '哇！地震了吗！？ 😮',
    );
    emit(newState);
    await _saveState(newState);

    Future.delayed(const Duration(seconds: 2), () {
      if (!isClosed) {
        add(PetSetMoodEvent(PetMood.calm));
      }
    });
  }

  /// 时间流逝（状态衰减）
  void _onTick(PetTickEvent event, Emitter<PetState> emit) {
    // 如果宠物在睡觉，不衰减
    if (state.activity == PetActivity.sleeping) return;

    // 计算衰减量
    final decayFactor = event.elapsed.inSeconds / 30.0; // 每30秒衰减一次

    // 快乐度缓慢下降
    final newHappiness = (state.happiness - 0.005 * decayFactor).clamp(0.0, 1.0);
    // 精力缓慢下降
    final newEnergy = (state.energy - 0.008 * decayFactor).clamp(0.0, 1.0);

    // 检测是否需要切换情绪
    PetMood newMood = state.mood;
    if (newEnergy < 0.2) {
      newMood = PetMood.sleepy;
    } else if (newHappiness < 0.3) {
      newMood = PetMood.sad;
    } else if (newHappiness < 0.5) {
      newMood = PetMood.calm;
    }

    // 检测长时间未互动 -> 思念
    final idleDuration = DateTime.now().difference(state.lastInteraction);
    if (idleDuration.inHours > 4 && state.mood != PetMood.missing) {
      newMood = PetMood.missing;
    }

    final newState = state.copyWith(
      happiness: newHappiness,
      energy: newEnergy,
      mood: newMood,
    );
    emit(newState);
    // 不频繁保存，仅在情绪变化时保存
    if (newState.mood != state.mood) {
      _saveState(newState);
    }
  }

  /// 手动设置情绪（调试用）
  void _onSetMood(PetSetMoodEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(
      mood: event.mood,
      lastInteraction: DateTime.now(),
    );
    emit(newState);
    _saveState(newState);
  }

  /// 设置活动状态
  void _onSetActivity(PetSetActivityEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(
      activity: event.activity,
    );
    emit(newState);
    _saveState(newState);
  }

  /// 开始学习
  void _onStartStudying(PetStartStudyingEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(
      activity: PetActivity.studying,
      mood: PetMood.calm,
      thought: '陪你一起学习~ 📚',
    );
    emit(newState);
    _saveState(newState);
  }

  /// 结束学习
  void _onStopStudying(PetStopStudyingEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(
      activity: PetActivity.idle,
      mood: PetMood.happy,
      thought: '学习结束！你真棒！ 🎉',
      happiness: (state.happiness + 0.05).clamp(0.0, 1.0),
    );
    emit(newState);
    _saveState(newState);

    Future.delayed(const Duration(seconds: 3), () {
      if (!isClosed) {
        add(PetSetMoodEvent(PetMood.calm));
      }
    });
  }

  /// 更新亲密度
  void _onUpdateIntimacy(PetUpdateIntimacyEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(
      intimacy: (state.intimacy + event.amount).clamp(0.0, 1.0),
    );
    emit(newState);
    _saveState(newState);
  }

  /// 重置
  void _onReset(PetResetEvent event, Emitter<PetState> emit) {
    emit(PetState.initial());
    _saveState(PetState.initial());
  }

  /// 伴侣消息
  void _onPartnerMessage(PetPartnerMessageEvent event, Emitter<PetState> emit) {
    final newState = state.copyWith(
      mood: PetMood.happy,
      thought: '💕 ${event.message}',
      intimacy: (state.intimacy + 0.05).clamp(0.0, 1.0),
      lastInteraction: DateTime.now(),
    );
    emit(newState);
    _saveState(newState);

    Future.delayed(const Duration(seconds: 6), () {
      if (!isClosed) {
        add(PetSetMoodEvent(PetMood.calm));
      }
    });
  }

  // ============ 辅助方法 ============

  /// 根据当前情绪计算抚摸后的情绪
  PetMood _getMoodAfterPet(PetMood currentMood) {
    if (currentMood == PetMood.sad) return PetMood.calm;
    if (currentMood == PetMood.sleepy) return PetMood.calm;
    return PetMood.happy;
  }

  /// 保存状态到 SharedPreferences
  Future<void> _saveState(PetState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (e) {
      // 保存失败静默处理
    }
  }

  @override
  Future<void> close() {
    return super.close();
  }
}
