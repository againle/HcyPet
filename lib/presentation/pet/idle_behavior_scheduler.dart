import 'dart:async';
import 'dart:math';

/// 空闲行为类型
enum IdleBehaviorType {
  blink,
  lookLeft,
  lookRight,
  headTilt,
  yawn,         // 打哈欠
}

/// 单个空闲行为实例
class IdleBehaviorState {
  final IdleBehaviorType type;
  final double progress; // 0.0 → 1.0
  final bool isActive;

  const IdleBehaviorState({
    required this.type,
    this.progress = 0.0,
    this.isActive = false,
  });

  static const none = IdleBehaviorState(
    type: IdleBehaviorType.blink,
    isActive: false,
  );
}

/// 空闲行为调度器
/// 管理眨眼、左右看、歪头等随机空闲动画
class IdleBehaviorScheduler {
  final Random _random = Random();

  // 当前活跃的行为
  IdleBehaviorState _current = IdleBehaviorState.none;

  // 行为配置：类型 → (最小间隔秒, 最大间隔秒, 持续时间秒)
  static const _configs = {
    IdleBehaviorType.blink: (3.0, 7.0, 0.15),
    IdleBehaviorType.lookLeft: (6.0, 14.0, 0.40),
    IdleBehaviorType.lookRight: (7.0, 16.0, 0.40),
    IdleBehaviorType.headTilt: (15.0, 30.0, 0.60),
    IdleBehaviorType.yawn: (30.0, 90.0, 1.5),
  };

  // 各行为的下次触发时间
  final Map<IdleBehaviorType, double> _nextTriggerAt = {};
  double _elapsed = 0;

  // 当前行为剩余时长
  double _activeRemaining = 0;
  double _activeDuration = 0;

  IdleBehaviorState get current => _current;
  bool get isActive => _current.isActive;

  /// 初始化所有行为的首次触发时间
  void reset() {
    _elapsed = 0;
    _current = IdleBehaviorState.none;
    _activeRemaining = 0;
    _activeDuration = 0;
    _nextTriggerAt.clear();
    for (final type in _configs.keys) {
      _scheduleNext(type);
    }
  }

  void _scheduleNext(IdleBehaviorType type) {
    final config = _configs[type]!;
    final interval = config.$1 + _random.nextDouble() * (config.$2 - config.$1);
    _nextTriggerAt[type] = _elapsed + interval;
  }

  /// 每帧调用，delta 为秒
  void update(double deltaSeconds) {
    _elapsed += deltaSeconds;

    if (_current.isActive) {
      // 正在执行行为
      _activeRemaining -= deltaSeconds;
      if (_activeRemaining <= 0) {
        // 行为结束
        _scheduleNext(_current.type);
        _current = IdleBehaviorState.none;
      } else {
        // 更新进度
        final progress = 1.0 - (_activeRemaining / _activeDuration);
        // 眨眼使用快速进出曲线（中间快两头慢）
        final easedProgress = _current.type == IdleBehaviorType.blink
            ? _blinkEase(progress)
            : _smoothEase(progress);
        _current = IdleBehaviorState(
          type: _current.type,
          progress: easedProgress,
          isActive: true,
        );
      }
      return;
    }

    // 检查是否有行为应该触发
    for (final entry in _nextTriggerAt.entries) {
      if (_elapsed >= entry.value) {
        _startBehavior(entry.key);
        break; // 一次只触发一个行为
      }
    }
  }

  void _startBehavior(IdleBehaviorType type) {
    final config = _configs[type]!;
    _activeDuration = config.$3;
    _activeRemaining = _activeDuration;
    _current = IdleBehaviorState(
      type: type,
      progress: 0.0,
      isActive: true,
    );
  }

  /// 眨眼缓动：快速开合
  double _blinkEase(double t) {
    if (t < 0.1) return t / 0.1 * 0.5;
    if (t < 0.5) return 0.5 + (t - 0.1) / 0.4 * 0.5;
    if (t < 0.6) return 1.0 - (t - 0.5) / 0.1 * 0.5;
    return 0.5 - (t - 0.6) / 0.4 * 0.5;
  }

  /// 平滑缓动
  double _smoothEase(double t) {
    return (sin((t - 0.5) * pi) + 1) / 2;
  }
}
