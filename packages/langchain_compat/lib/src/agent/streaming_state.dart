/// State management for streaming operations in the Agent class
library;

import '../chat/chat_models/chat_models.dart';
import '../chat/chat_models/helpers/tool_id_helpers.dart';
import '../chat/tools/tools.dart';
import '../language_models/language_models.dart';
import 'accumulators/accumulators.dart';
import 'executors/executors.dart';

/// Encapsulates all mutable state required during streaming operations
class StreamingState {
  /// Creates a new StreamingState instance
  StreamingState({
    required this.conversationHistory,
    required this.toolMap,
    MessageAccumulator? accumulator,
    ToolExecutor? executor,
  }) : accumulator = accumulator ?? const DefaultMessageAccumulator(),
       executor = executor ?? const DefaultToolExecutor();

  /// The conversation history being built up during streaming
  final List<ChatMessage> conversationHistory;

  /// Map of available tools by name
  final Map<String, Tool> toolMap;

  /// Message accumulator for provider-specific streaming logic
  final MessageAccumulator accumulator;

  /// Tool executor for provider-specific tool execution
  final ToolExecutor executor;

  /// Coordinator for managing tool IDs across the conversation
  final ToolIdCoordinator toolIdCoordinator = ToolIdCoordinator();

  /// Whether we're done processing the stream
  bool done = false;

  /// Whether to prefix the next message with a newline for better UX
  bool shouldPrefixNextMessage = false;

  /// Whether this is the first chunk of the current message
  bool isFirstChunkOfMessage = true;

  /// The message being accumulated during streaming
  ChatMessage accumulatedMessage = const ChatMessage(
    role: MessageRole.model,
    parts: [],
  );

  /// The last result received from the model
  ChatResult<ChatMessage> lastResult = ChatResult<ChatMessage>(
    output: const ChatMessage(role: MessageRole.model, parts: []),
    finishReason: FinishReason.unspecified,
    metadata: const <String, dynamic>{},
    usage: const LanguageModelUsage(),
  );

  /// For typed output: metadata from suppressed tool calls
  Map<String, dynamic> suppressedToolCallMetadata = <String, dynamic>{};

  /// For typed output: text parts that were suppressed
  List<TextPart> suppressedTextParts = <TextPart>[];

  /// Resets state for a new message in the conversation
  void resetForNewMessage() {
    isFirstChunkOfMessage = true;
    accumulatedMessage = const ChatMessage(role: MessageRole.model, parts: []);
    lastResult = ChatResult<ChatMessage>(
      output: const ChatMessage(role: MessageRole.model, parts: []),
      finishReason: FinishReason.unspecified,
      metadata: const <String, dynamic>{},
      usage: const LanguageModelUsage(),
    );
  }

  /// Marks that we've started streaming content for the current message
  void markMessageStarted() {
    isFirstChunkOfMessage = false;
  }

  /// Sets the flag to prefix the next message (after tool calls)
  void requestNextMessagePrefix() {
    shouldPrefixNextMessage = true;
  }

  /// Completes the stream processing
  void complete() {
    done = true;
  }

  /// Adds a message to the conversation history
  void addToHistory(ChatMessage message) {
    conversationHistory.add(message);
  }

  /// For typed output: stores metadata from a suppressed tool call
  void addSuppressedMetadata(Map<String, dynamic> metadata) {
    suppressedToolCallMetadata.addAll(metadata);
  }

  /// For typed output: adds suppressed text parts
  void addSuppressedTextParts(List<TextPart> parts) {
    suppressedTextParts.addAll(parts);
  }

  /// For typed output: clears suppressed data after emission
  void clearSuppressedData() {
    suppressedToolCallMetadata = <String, dynamic>{};
    suppressedTextParts = <TextPart>[];
  }

  /// Resets the tool ID coordinator for a new conversation
  void resetToolIdCoordinator() {
    toolIdCoordinator.clear();
  }

  /// Registers a tool call with the coordinator
  void registerToolCall({
    required String id,
    required String name,
    Map<String, dynamic>? arguments,
  }) {
    toolIdCoordinator.registerToolCall(
      id: id,
      name: name,
      arguments: arguments,
    );
  }

  /// Validates that a tool result ID matches a registered tool call
  bool validateToolResultId(String id) =>
      toolIdCoordinator.validateToolResultId(id);
}
