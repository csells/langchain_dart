import '../../language_models/language_models.dart';
import 'chat_message.dart';

/// Result returned by the Chat Model.
class ChatResult<T extends Object> extends LanguageModelResult<T> {
  /// Creates a new chat result instance.
  ChatResult({
    required super.output,
    super.finishReason = FinishReason.unspecified,
    super.metadata = const {},
    super.usage = const LanguageModelUsage(),
    this.messages = const [],
    super.id,
  });

  /// The new messages generated during this chat interaction.
  final List<ChatMessage> messages;

  @override
  String get outputAsString =>
      output is String ? output as String : output.toString();

  @override
  String toString() =>
      '''
ChatResult{
  id: $id, 
  output: $output,
  messages: $messages,
  finishReason: $finishReason,
  metadata: $metadata,
  usage: $usage,
}''';
}
