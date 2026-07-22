import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pet_state.dart';

/// 伴侣信息
class PartnerInfo {
  final String userId;
  final String? petId;
  final String? relationId;
  final bool isOnline;
  final DateTime? lastSeen;

  const PartnerInfo({
    required this.userId,
    this.petId,
    this.relationId,
    this.isOnline = false,
    this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'petId': petId,
    'relationId': relationId,
    'isOnline': isOnline,
    'lastSeen': lastSeen?.toIso8601String(),
  };

  factory PartnerInfo.fromJson(Map<String, dynamic> json) => PartnerInfo(
    userId: json['userId'] ?? '',
    petId: json['petId'],
    relationId: json['relationId'],
    isOnline: json['isOnline'] ?? false,
    lastSeen: json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'])
        : null,
  );
}

/// 配对信息
class RelationInfo {
  final String relationId;
  final String userAId;
  final String userBId;
  final String petId;
  final DateTime createdAt;
  final bool isActive;

  const RelationInfo({
    required this.relationId,
    required this.userAId,
    required this.userBId,
    required this.petId,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'relationId': relationId,
    'userAId': userAId,
    'userBId': userBId,
    'petId': petId,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory RelationInfo.fromJson(Map<String, dynamic> json) => RelationInfo(
    relationId: json['relationId'] ?? '',
    userAId: json['userAId'] ?? '',
    userBId: json['userBId'] ?? '',
    petId: json['petId'] ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    isActive: json['isActive'] ?? true,
  );
}

/// Firebase 服务
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase 实例
  FirebaseApp? _app;
  FirebaseDatabase? _database;
  FirebaseAuth? _auth;

  // 当前用户
  String? _currentUserId;
  String? _currentRelationId;

  // 同步订阅
  StreamSubscription<DatabaseEvent>? _petSubscription;
  StreamSubscription<DatabaseEvent>? _partnerSubscription;
  StreamSubscription<DatabaseEvent>? _messageSubscription;

  // 回调
  void Function(PetState petState)? onPetStateSync;
  void Function(PartnerInfo partner)? onPartnerSync;
  void Function(String message, String fromUserId)? onMessageReceived;

  bool get isInitialized => _app != null;
  bool get isAuthenticated => _auth?.currentUser != null;
  String? get currentUserId => _currentUserId;

  /// 调试信息（用于 UI 显示）
  String debugMessage = '';
  String debugStep = 'idle';

  /// 状态变化通知器
  final ValueNotifier<int> _changeNotifier = ValueNotifier<int>(0);
  ValueNotifier<int> get changeNotifier => _changeNotifier;

  void _notifyChange() {
    _changeNotifier.value++;
  }

  /// 初始化 Firebase
  Future<bool> initialize() async {
    try {
      debugStep = 'checking Firebase.app()';
      try {
        _app = Firebase.app();
        debugStep = 'got Firebase.app()';
      } catch (e1) {
        debugStep = 'Firebase.app() failed: ${e1.toString().substring(0, 80)}';
        _app = await Firebase.initializeApp();
        debugStep = 'Firebase.initializeApp() OK';
      }
      _database = FirebaseDatabase.instanceFor(
        app: _app!,
        databaseURL: 'https://hcypet-default-rtdb.firebaseio.com',
      );
      _auth = FirebaseAuth.instanceFor(app: _app!);
      debugStep = 'done';
      _notifyChange();
      return true;
    } catch (e) {
      debugMessage = e.toString();
      debugStep = 'error';
      _notifyChange();
      return false;
    }
  }

  /// 匿名登录（无需用户注册）
  Future<bool> signInAnonymously() async {
    try {
      debugStep = 'signInAnonymously start';
      final result = await _auth!.signInAnonymously();
      _currentUserId = result.user?.uid;
      debugStep = 'signed in: $_currentUserId';
      _notifyChange();
      return true;
    } catch (e) {
      debugMessage = e.toString();
      debugStep = 'auth error';
      _notifyChange();
      return false;
    }
  }

  /// 生成配对码（6位数字）
  String generatePairCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  /// 创建配对
  Future<RelationInfo?> createRelation({
    required String partnerId,
    String? pairCode,
  }) async {
    if (_currentUserId == null) return null;

    try {
      final relationId = 'relation_${DateTime.now().millisecondsSinceEpoch}';
      final petId = 'pet_${DateTime.now().millisecondsSinceEpoch}';

      final relation = RelationInfo(
        relationId: relationId,
        userAId: _currentUserId!,
        userBId: partnerId,
        petId: petId,
        createdAt: DateTime.now(),
      );

      // 保存关系
      await _database!.ref('relations/$relationId').set(relation.toJson());

      // 保存用户配对信息
      await _database!.ref('users/${_currentUserId}/relationId').set(relationId);
      await _database!.ref('users/$partnerId/relationId').set(relationId);
      await _database!.ref('users/${_currentUserId}/petId').set(petId);
      await _database!.ref('users/$partnerId/petId').set(petId);

      // 保存配对码映射
      if (pairCode != null) {
        await _database!.ref('pairCodes/$pairCode').set({
          'relationId': relationId,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      _currentRelationId = relationId;

      // 初始化宠物状态
      final initialPet = PetState.initial();
      await _savePetState(petId, initialPet);

      return relation;
    } catch (e) {
      print('❌ 创建配对失败: $e');
      return null;
    }
  }

  /// 通过配对码加入配对
  Future<String?> joinRelationByCode(String pairCode) async {
    if (_currentUserId == null) return null;

    try {
      // 查找配对码
      final snapshot = await _database!
          .ref('pairCodes/$pairCode')
          .once();

      if (snapshot.snapshot.value == null) {
        return '配对码无效';
      }

      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final relationId = data['relationId'];

      // 检查关系是否存在
      final relationSnapshot = await _database!
          .ref('relations/$relationId')
          .once();

      if (relationSnapshot.snapshot.value == null) {
        return '配对已失效';
      }

      final relation = RelationInfo.fromJson(
        Map<String, dynamic>.from(relationSnapshot.snapshot.value as Map),
      );

      // 更新用户信息
      await _database!.ref('users/${_currentUserId}/relationId').set(relationId);
      await _database!.ref('users/${_currentUserId}/petId').set(relation.petId);

      _currentRelationId = relationId;

      return null; // 成功
    } catch (e) {
      print('❌ 加入配对失败: $e');
      return '配对失败，请重试';
    }
  }

  /// 保存宠物状态
  Future<void> savePetState(PetState state) async {
    if (_currentRelationId == null) return;

    try {
      final petId = await _getPetId();
      if (petId != null) {
        await _savePetState(petId, state);
      }
    } catch (e) {
      print('❌ 保存宠物状态失败: $e');
    }
  }

  Future<void> _savePetState(String petId, PetState state) async {
    await _database!.ref('pets/$petId').update({
      'mood': state.mood.name,
      'activity': state.activity.name,
      'happiness': state.happiness,
      'energy': state.energy,
      'intimacy': state.intimacy,
      'isAwake': state.isAwake,
      'thought': state.thought,
      'lastInteraction': state.lastInteraction.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// 获取宠物 ID
  Future<String?> _getPetId() async {
    if (_currentUserId == null) return null;

    try {
      final snapshot = await _database!
          .ref('users/${_currentUserId}/petId')
          .once();
      return snapshot.snapshot.value as String?;
    } catch (e) {
      return null;
    }
  }

  /// 获取关系 ID
  Future<String?> _getRelationId() async {
    if (_currentUserId == null) return null;

    try {
      final snapshot = await _database!
          .ref('users/${_currentUserId}/relationId')
          .once();
      return snapshot.snapshot.value as String?;
    } catch (e) {
      return null;
    }
  }

  /// 监听宠物状态同步
  void listenPetState() async {
    final petId = await _getPetId();
    if (petId == null) return;

    _petSubscription?.cancel();
    _petSubscription = _database!
        .ref('pets/$petId')
        .onValue
        .listen((event) {
          if (event.snapshot.value == null) return;

          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final petState = _parsePetState(data);
          if (petState != null) {
            onPetStateSync?.call(petState);
          }
        });
  }

  /// 解析宠物状态
  PetState? _parsePetState(Map<dynamic, dynamic> data) {
    try {
      return PetState(
        mood: PetMood.values.firstWhere(
          (e) => e.name == data['mood'],
          orElse: () => PetMood.calm,
        ),
        activity: PetActivity.values.firstWhere(
          (e) => e.name == data['activity'],
          orElse: () => PetActivity.idle,
        ),
        happiness: (data['happiness'] as num?)?.toDouble() ?? 0.7,
        energy: (data['energy'] as num?)?.toDouble() ?? 0.8,
        intimacy: (data['intimacy'] as num?)?.toDouble() ?? 0.5,
        isAwake: data['isAwake'] ?? true,
        lastInteraction: data['lastInteraction'] != null
            ? DateTime.parse(data['lastInteraction'])
            : DateTime.now(),
        thought: data['thought'],
      );
    } catch (e) {
      return null;
    }
  }

  /// 监听伴侣状态
  void listenPartner() async {
    final relationId = await _getRelationId();
    if (relationId == null) return;

    _partnerSubscription?.cancel();
    _partnerSubscription = _database!
        .ref('relations/$relationId')
        .onValue
        .listen((event) {
          if (event.snapshot.value == null) return;

          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final relation = RelationInfo.fromJson(
            Map<String, dynamic>.from(data),
          );

          // 找出伴侣的 userId
          final partnerId = relation.userAId == _currentUserId
              ? relation.userBId
              : relation.userAId;

          // 获取伴侣信息
          _database!.ref('users/$partnerId').once().then((snapshot) {
            if (snapshot.snapshot.value != null) {
              final userData = snapshot.snapshot.value as Map<dynamic, dynamic>;
              final partner = PartnerInfo(
                userId: partnerId,
                petId: relation.petId,
                relationId: relationId,
                isOnline: userData['isOnline'] ?? false,
                lastSeen: userData['lastSeen'] != null
                    ? DateTime.parse(userData['lastSeen'])
                    : null,
              );
              onPartnerSync?.call(partner);
            }
          });
        });
  }

  /// 监听消息
  void listenMessages() async {
    if (_currentUserId == null) return;

    _messageSubscription?.cancel();
    _messageSubscription = _database!
        .ref('messages/${_currentUserId}')
        .orderByChild('createdAt')
        .limitToLast(50)
        .onChildAdded
        .listen((event) {
          if (event.snapshot.value == null) return;

          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final message = data['message'] ?? '';
          final fromUserId = data['fromUserId'] ?? '';

          if (message.isNotEmpty) {
            onMessageReceived?.call(message, fromUserId);
          }
        });
  }

  /// 发送消息给伴侣
  Future<bool> sendMessage(String message) async {
    if (_currentUserId == null) return false;

    try {
      final relationId = await _getRelationId();
      if (relationId == null) return false;

      // 获取伴侣信息
      final relationSnapshot = await _database!
          .ref('relations/$relationId')
          .once();

      if (relationSnapshot.snapshot.value == null) return false;

      final relation = RelationInfo.fromJson(
        Map<String, dynamic>.from(relationSnapshot.snapshot.value as Map),
      );

      final partnerId = relation.userAId == _currentUserId
          ? relation.userBId
          : relation.userAId;

      // 保存消息到伴侣的收件箱
      await _database!.ref('messages/$partnerId').push().set({
        'message': message,
        'fromUserId': _currentUserId,
        'createdAt': DateTime.now().toIso8601String(),
        'relationId': relationId,
      });

      return true;
    } catch (e) {
      print('❌ 发送消息失败: $e');
      return false;
    }
  }

  /// 更新在线状态
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_currentUserId == null) return;

    try {
      await _database!.ref('users/${_currentUserId}/isOnline').set(isOnline);
      await _database!.ref('users/${_currentUserId}/lastSeen')
          .set(DateTime.now().toIso8601String());
    } catch (e) {
      // 静默失败
    }
  }

  /// 获取当前关系信息
  Future<RelationInfo?> getCurrentRelation() async {
    final relationId = await _getRelationId();
    if (relationId == null) return null;

    try {
      final snapshot = await _database!
          .ref('relations/$relationId')
          .once();

      if (snapshot.snapshot.value == null) return null;

      return RelationInfo.fromJson(
        Map<String, dynamic>.from(snapshot.snapshot.value as Map),
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取伴侣信息
  Future<PartnerInfo?> getPartnerInfo() async {
    final relation = await getCurrentRelation();
    if (relation == null || _currentUserId == null) return null;

    final partnerId = relation.userAId == _currentUserId
        ? relation.userBId
        : relation.userAId;

    try {
      final snapshot = await _database!
          .ref('users/$partnerId')
          .once();

      if (snapshot.snapshot.value == null) return null;

      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      return PartnerInfo(
        userId: partnerId,
        petId: relation.petId,
        relationId: relation.relationId,
        isOnline: data['isOnline'] ?? false,
        lastSeen: data['lastSeen'] != null
            ? DateTime.parse(data['lastSeen'])
            : null,
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取消息历史
  Future<List<Map<String, dynamic>>> getMessageHistory({int limit = 50}) async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _database!
          .ref('messages/${_currentUserId}')
          .orderByChild('createdAt')
          .limitToLast(limit)
          .once();

      if (snapshot.snapshot.value == null) return [];

      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final messages = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final msg = Map<String, dynamic>.from(value);
        msg['key'] = key;
        messages.add(msg);
      });

      messages.sort((a, b) {
        final aTime = DateTime.parse(a['createdAt'] ?? '');
        final bTime = DateTime.parse(b['createdAt'] ?? '');
        return aTime.compareTo(bTime);
      });

      return messages;
    } catch (e) {
      print('❌ 获取消息历史失败: $e');
      return [];
    }
  }

  /// 监听新消息（只监听新添加的消息）
  void listenNewMessages(void Function(Map<String, dynamic> message) onNewMessage) {
    if (_currentUserId == null) return;

    _messageSubscription?.cancel();
    _messageSubscription = _database!
        .ref('messages/${_currentUserId}')
        .orderByChild('createdAt')
        .limitToLast(1)
        .onChildAdded
        .listen((event) {
          if (event.snapshot.value == null) return;

          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          data['key'] = event.snapshot.key;

          if (data['fromUserId'] != _currentUserId) {
            onNewMessage(data);
          }
        });
  }

  /// 标记消息已读
  Future<void> markMessagesRead() async {
    if (_currentUserId == null) return;

    try {
      await _database!
          .ref('messages/${_currentUserId}')
          .update({'isRead': true});
    } catch (e) {
      // 静默失败
    }
  }

  /// 断开连接（清理）
  void disconnect() {
    _petSubscription?.cancel();
    _partnerSubscription?.cancel();
    _messageSubscription?.cancel();
    _auth?.signOut();
    _currentUserId = null;
    _currentRelationId = null;
  }

  void dispose() {
    disconnect();
  }
}
