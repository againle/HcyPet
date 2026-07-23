import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../models/pet_state.dart';
import '../../bloc/pet_bloc.dart';
import '../../models/pet_event.dart';

/// 消息模型
class ChatMessage {
  final String id;
  final String text;
  final bool isFromMe;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isFromMe,
    required this.timestamp,
    this.isRead = false,
  });
}

/// 伴侣空间页面
class PartnerPage extends StatefulWidget {
  const PartnerPage({super.key});

  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends State<PartnerPage> {
  final FirebaseService _firebase = FirebaseService();
  final NotificationService _notification = NotificationService();

  bool _isLoading = true;
  bool _isPaired = false;
  String? _pairCode;
  String? _partnerName = '伴侣';
  bool _partnerOnline = false;
  String? _errorMessage;

  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickMessages = [
    '想你了', '休息一下', '加油', '晚安',
    '早安', '爱你', '学习加油', '分享一首歌',
  ];

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _initNotifications();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _firebase.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    await _notification.initialize();
  }

  Future<void> _initFirebase() async {
    setState(() => _isLoading = true);

    final initialized = await _firebase.initialize();
    if (!initialized) {
      setState(() {
        _errorMessage = 'Firebase 初始化失败\n${_firebase.debugMessage}';
        _isLoading = false;
      });
      return;
    }

    final signedIn = await _firebase.signInAnonymously();
    if (!signedIn) {
      setState(() {
        _errorMessage = '登录失败\n${_firebase.debugMessage}';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isPaired = false;
      _isLoading = false;
      _pairCode = _firebase.generatePairCode();
    });

    // 后台异步查询已有关系
    _checkExistingRelation();
  }

  Future<void> _checkExistingRelation() async {
    try {
      final relation = await _firebase
          .getCurrentRelation()
          .timeout(const Duration(seconds: 10));
      if (relation != null && mounted) {
        final partner = await _firebase.getPartnerInfo();
        if (mounted) {
          setState(() {
            _isPaired = true;
            _partnerName = '伴侣';
            if (partner != null) _partnerOnline = partner.isOnline;
          });
          _loadMessageHistory();
          _firebase.listenNewMessages((message) => _onNewMessage(message));
          _firebase.listenPartner();
          _firebase.listenMessages();
          _firebase.updateOnlineStatus(true);
        }
      }
    } catch (e) {
      _firebase.debugStep = 'DB: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}';
    }
  }

  Future<void> _createPair() async {
    setState(() => _isLoading = true);

    final partnerId = await _showPartnerInputDialog();
    if (partnerId == null || partnerId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final relation = await _firebase.createRelation(
      partnerId: partnerId,
      pairCode: _pairCode,
    );

    if (relation != null) {
      setState(() {
        _isPaired = true;
        _isLoading = false;
        _partnerName = '伴侣';
      });

      _firebase.listenNewMessages((m) => _onNewMessage(m));
      _firebase.listenPartner();
      _firebase.listenMessages();
      _firebase.updateOnlineStatus(true);
      await _loadMessageHistory();
    } else {
      setState(() {
        _errorMessage = '配对失败，请重试';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinPair() async {
    final code = await _showCodeInputDialog();
    if (code == null || code.isEmpty) return;

    setState(() => _isLoading = true);

    final error = await _firebase.joinRelationByCode(code);
    if (error == null) {
      setState(() {
        _isPaired = true;
        _isLoading = false;
        _partnerName = '伴侣';
      });

      _firebase.listenNewMessages((m) => _onNewMessage(m));
      _firebase.listenPartner();
      _firebase.listenMessages();
      _firebase.updateOnlineStatus(true);
      await _loadMessageHistory();
    } else {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  Future<String?> _showPartnerInputDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          '输入伴侣 ID',
          style: TextStyle(color: const Color(0xFF4FC3F7).withOpacity(0.8)),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFF4FC3F7)),
          decoration: InputDecoration(
            hintText: '请输入伴侣的 ID',
            hintStyle: TextStyle(
              color: const Color(0xFF4FC3F7).withOpacity(0.2),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: const Color(0xFF4FC3F7).withOpacity(0.1),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(
                color: const Color(0xFF4FC3F7).withOpacity(0.3),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              '配对',
              style: TextStyle(
                color: const Color(0xFF4FC3F7).withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCodeInputDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          '输入配对码',
          style: TextStyle(color: const Color(0xFF4FC3F7).withOpacity(0.8)),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 24),
          textAlign: TextAlign.center,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '123456',
            hintStyle: TextStyle(
              color: const Color(0xFF4FC3F7).withOpacity(0.2),
            ),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: const Color(0xFF4FC3F7).withOpacity(0.1),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(
                color: const Color(0xFF4FC3F7).withOpacity(0.3),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              '加入',
              style: TextStyle(
                color: const Color(0xFF4FC3F7).withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage({String? text}) async {
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty) return;

    final localMsg = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      text: messageText,
      isFromMe: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(localMsg);
      if (text == null) _messageController.clear();
    });
    _scrollToBottom();

    final success = await _firebase.sendMessage(messageText);
    if (!success) {
      setState(() {
        final index = _messages.indexOf(localMsg);
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: localMsg.id,
            text: '! $messageText',
            isFromMe: true,
            timestamp: localMsg.timestamp,
          );
        }
      });
    }
  }

  Future<void> _loadMessageHistory() async {
    final history = await _firebase.getMessageHistory();
    setState(() {
      _messages.clear();
      for (final msg in history) {
        _messages.add(ChatMessage(
          id: msg['key'] ?? '',
          text: msg['message'] ?? '',
          isFromMe: msg['fromUserId'] == _firebase.currentUserId,
          timestamp: DateTime.parse(msg['createdAt'] ?? DateTime.now().toIso8601String()),
          isRead: msg['isRead'] ?? false,
        ));
      }
    });
    _scrollToBottom();
  }

  void _onNewMessage(Map<String, dynamic> message) {
    final chatMsg = ChatMessage(
      id: message['key'] ?? '',
      text: message['message'] ?? '',
      isFromMe: false,
      timestamp: DateTime.parse(message['createdAt'] ?? DateTime.now().toIso8601String()),
    );
    setState(() => _messages.add(chatMsg));
    _scrollToBottom();
    _notification.showPartnerMessage(chatMsg.text, _partnerName ?? '伴侣');
    context.read<PetBloc>().add(PetPartnerMessageEvent(chatMsg.text));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : _errorMessage != null
                ? _buildError()
                : _isPaired
                    ? _buildPairedView()
                    : _buildUnpairedView(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: const Color(0xFF4FC3F7).withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '连接中...',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF4FC3F7).withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('X', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _initFirebase,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF4FC3F7).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF4FC3F7).withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Text(
                '重试',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF4FC3F7).withOpacity(0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnpairedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Color(0x4D4FC3F7)),
          const SizedBox(height: 16),
          Text(
            '尚未配对',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF4FC3F7).withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '与伴侣共同养一只宠物',
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFF4FC3F7).withOpacity(0.15),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF4FC3F7).withOpacity(0.06),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '配对码',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF4FC3F7).withOpacity(0.15),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pairCode ?? '------',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w200,
                    color: const Color(0xFF4FC3F7).withOpacity(0.6),
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.person_add_outlined,
                label: '创建配对',
                onTap: _createPair,
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: Icons.login,
                label: '加入配对',
                onTap: _joinPair,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPairedView() {
    return Column(
      children: [
        _buildPartnerStatus(),
        _buildQuickMessages(),
        Expanded(
          child: _messages.isEmpty ? _buildEmptyMessages() : _buildMessageList(),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildPartnerStatus() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4FC3F7).withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4FC3F7).withOpacity(0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _partnerOnline
                  ? Colors.green.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _partnerName ?? '伴侣',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF4FC3F7).withOpacity(0.6),
            ),
          ),
          const Spacer(),
          Text(
            _partnerOnline ? '在线' : '离线',
            style: TextStyle(
              fontSize: 10,
              color: _partnerOnline
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetSyncStatus(PetState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4FC3F7).withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '宠物状态已同步',
            style: TextStyle(
              fontSize: 9,
              color: const Color(0xFF4FC3F7).withOpacity(0.15),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(state.intimacy * 100).toInt()}%',
            style: TextStyle(
              fontSize: 9,
              color: const Color(0xFF4FC3F7).withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageArea() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 32, color: Color(0x264FC3F7)),
          const SizedBox(height: 8),
          Text(
            '发送消息给伴侣',
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFF4FC3F7).withOpacity(0.15),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '宠物会同步收到反应哦~',
            style: TextStyle(
              fontSize: 9,
              color: const Color(0xFF4FC3F7).withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFF4FC3F7).withOpacity(0.04),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF4FC3F7).withOpacity(0.6),
              ),
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: TextStyle(
                  color: const Color(0xFF4FC3F7).withOpacity(0.15),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: const Color(0xFF4FC3F7).withOpacity(0.05),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: const Color(0xFF4FC3F7).withOpacity(0.05),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: const Color(0xFF4FC3F7).withOpacity(0.1),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4FC3F7).withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF4FC3F7).withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.send,
                  color: const Color(0xFF4FC3F7).withOpacity(0.3),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF4FC3F7).withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF4FC3F7).withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF4FC3F7).withOpacity(0.4)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF4FC3F7).withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMessages() {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickMessages.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _sendMessage(text: _quickMessages[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4FC3F7).withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.06), width: 0.5),
              ),
              child: Text(_quickMessages[index], style: TextStyle(fontSize: 10, color: const Color(0xFF4FC3F7).withOpacity(0.3))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isFromMe = msg.isFromMe;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isFromMe ? const Color(0xFF4FC3F7).withOpacity(0.1) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFromMe ? const Color(0xFF4FC3F7).withOpacity(0.08) : Colors.white.withOpacity(0.03),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text, style: TextStyle(fontSize: 13, color: isFromMe ? const Color(0xFF4FC3F7).withOpacity(0.7) : Colors.white.withOpacity(0.5))),
            const SizedBox(height: 2),
            Text(_formatTime(msg.timestamp), style: TextStyle(fontSize: 8, color: const Color(0xFF4FC3F7).withOpacity(0.1))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 32, color: Color(0x264FC3F7)),
          const SizedBox(height: 8),
          Text('暂无消息', style: TextStyle(fontSize: 11, color: const Color(0xFF4FC3F7).withOpacity(0.15))),
          const SizedBox(height: 4),
          Text('发送消息或点击快捷提示', style: TextStyle(fontSize: 9, color: const Color(0xFF4FC3F7).withOpacity(0.08))),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
