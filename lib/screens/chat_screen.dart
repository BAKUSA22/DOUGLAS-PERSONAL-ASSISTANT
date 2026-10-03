import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/ai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AiService _aiService = LocalAiService();

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hello. I am DOUGLAS AI. How can I help you?',
      role: MessageRole.assistant,
    ),
  ];

  bool _sending = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, role: MessageRole.user));
      _sending = true;
    });

    _scrollToBottom();

    try {
      final response = await _aiService.sendMessage(
        message: text,
        history: List.unmodifiable(_messages),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(ChatMessage(text: response, role: MessageRole.assistant));
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text: 'I encountered an error. Please try again.',
            role: MessageRole.assistant,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF101828),
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFF344054),
              child: Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOUGLAS AI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Personal Assistant',
                  style: TextStyle(fontSize: 11, color: Color(0xFFD0D5DD)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(left: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'DOUGLAS is thinking...',
                  style: TextStyle(color: Color(0xFF667085), fontSize: 12),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message DOUGLAS...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: FloatingActionButton(
                      heroTag: 'send',
                      elevation: 1,
                      onPressed: _sending ? null : _sendMessage,
                      backgroundColor: const Color(0xFF101828),
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF101828) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: isUser
              ? null
              : [
                  BoxShadow(
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF101828),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
