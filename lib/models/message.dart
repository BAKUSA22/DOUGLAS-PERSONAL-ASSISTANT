enum MessageRole { user, assistant }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.role, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
}
