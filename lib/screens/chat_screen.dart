import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/message.dart';
import '../services/ai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AiService _aiService = LocalAiService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechAvailable = false;
  bool _isListening = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hello. I am DOUGLAS AI. How can I help you?',
      role: MessageRole.assistant,
    ),
  ];

  bool _sending = false;
  String _avatarMode = 'IDLE';
  double _speechIntensity = 0.0;

  String get _avatarState => _avatarMode;
  late final AnimationController _idleController;

  @override
  void initState() {
    super.initState();

    _initializeSpeech();
    _initializeTts();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  void _setAvatarState(String state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarMode = state;
    });
  }

  void setListeningState() => _setAvatarState('LISTENING');

  void setSpeakingState() => _setAvatarState('SPEAKING');

  Future<void> _initializeTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _avatarMode = 'SPEAKING';
        });
      }
    });

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          if (!_sending && !_isListening) {
            _avatarMode = 'IDLE';
            _speechIntensity = 0.0;
          }
        });
      }
    });

    _tts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          if (!_sending && !_isListening) {
            _avatarMode = 'IDLE';
            _speechIntensity = 0.0;
          }
        });
      }
    });

    _tts.setProgressHandler((String text, int start, int end, String word) {
      if (!mounted || _avatarState != 'SPEAKING') {
        return;
      }

      setState(() {
        _speechIntensity = 1.0;
      });

      _idleController.forward(from: 0.0);
    });
  }

  Future<void> _speakResponse(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    await _tts.stop();

    if (mounted) {
      setState(() {
        _avatarMode = 'SPEAKING';
        _speechIntensity = 0.0;
      });
    }

    await _tts.speak(text);
  }

  Future<void> _initializeSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }

        if (status == 'listening') {
          setState(() {
            _isListening = true;
            _avatarMode = 'LISTENING';
          });
        } else if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
            if (!_sending) {
              _avatarMode = 'IDLE';
            }
          });
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isListening = false;
          if (!_sending) {
            _avatarMode = 'IDLE';
          }
        });
      },
    );

    if (mounted) {
      setState(() {
        _speechAvailable = available;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable || _sending) {
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
          _avatarMode = 'IDLE';
        });
      }
      return;
    }

    setState(() {
      _isListening = true;
      _avatarMode = 'LISTENING';
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }

        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, role: MessageRole.user));
      _sending = true;
      _avatarMode = 'THINKING';
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
        _avatarMode = 'SPEAKING';
      });

      await _speakResponse(response);
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
          if (!_isListening && _avatarState != 'SPEAKING') {
            _avatarMode = 'IDLE';
          }
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
    _tts.stop();
    _idleController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF080B12),
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/avatar/douglas_avatar.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOUGLAS AI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Digital Human Assistant',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF101722),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF263142),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: _idleController,
                    builder: (context, child) {
                      final t = _idleController.value;
                      final baseBreathing = 1.0 + (t * 0.008);
                      final speakingPulse =
                          _avatarState == 'SPEAKING'
                              ? 1.0 +
                                  ((t * 0.025) *
                                      (1.0 + (_speechIntensity * 0.35)))
                              : 1.0;
                      final thinkingPulse =
                          _avatarState == 'THINKING'
                              ? 1.0 + ((t * 0.012))
                              : 1.0;
                      final breathing =
                          baseBreathing * speakingPulse * thinkingPulse;

                      final attentionShift =
                          _avatarState == 'LISTENING'
                              ? -0.004
                              : _avatarState == 'THINKING'
                                  ? 0.003
                                  : _avatarState == 'SPEAKING'
                                      ? 0.002
                                      : 0.0;

                      final sway =
                          ((t - 0.5) * 0.006) + attentionShift;

                      return Transform.translate(
                        offset: Offset(sway * 100, 0),
                        child: Transform.scale(
                          scale: breathing,
                          alignment: Alignment.center,
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      'assets/avatar/douglas_avatar.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        stops: const [0.45, 0.68, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sending
                                ? const Color(0xFFFFC857)
                                : const Color(0xFF32D583),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 10,
                                color: (_sending
                                        ? const Color(0xFFFFC857)
                                        : const Color(0xFF32D583))
                                    .withValues(alpha: 0.55),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          _avatarState == 'THINKING'
                              ? 'DOUGLAS is thinking...'
                              : _avatarState == 'LISTENING'
                                  ? 'DOUGLAS is listening...'
                                  : _avatarState == 'SPEAKING'
                                      ? 'DOUGLAS is speaking...'
                                      : 'DOUGLAS is ready',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FB),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _MessageBubble(message: message);
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_speechAvailable)
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                tooltip: _isListening
                                    ? 'Stop listening'
                                    : 'Talk to DOUGLAS',
                                onPressed: _sending
                                    ? null
                                    : _toggleListening,
                                icon: Icon(
                                  _isListening
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: _isListening
                                      ? const Color(0xFF12B76A)
                                      : const Color(0xFF475467),
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'Talk to DOUGLAS...',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(
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
