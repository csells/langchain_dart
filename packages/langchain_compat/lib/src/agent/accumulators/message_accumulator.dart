/// Interface for accumulating streaming message chunks
library;

import '../../chat/chat_models/chat_models.dart';

/// Strategy interface for accumulating streaming message chunks.
///
/// Different providers have different streaming protocols and may require
/// specialized accumulation logic. This interface allows provider-specific
/// implementations while maintaining a consistent API.
abstract class MessageAccumulator {
  /// Accumulates a new chunk into the existing message.
  ///
  /// This method handles the provider-specific logic for merging streaming
  /// chunks, including:
  /// - Text concatenation
  /// - Tool call merging (for providers that stream tool calls incrementally)
  /// - Metadata merging
  /// - Part deduplication
  ///
  /// Returns a new ChatMessage with the accumulated content.
  ChatMessage accumulate(ChatMessage accumulated, ChatMessage newChunk);

  /// Consolidates the accumulated message parts for final output.
  ///
  /// This method performs final processing on the accumulated message:
  /// - Consolidates multiple TextParts into a single TextPart
  /// - Orders parts appropriately
  /// - Cleans up any streaming artifacts
  ///
  /// Returns a ChatMessage ready for storage in conversation history.
  ChatMessage consolidate(ChatMessage accumulated);

  /// Provider hint for debugging and logging.
  String get providerHint;
}
