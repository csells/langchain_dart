/// Default message accumulator implementation
library;

import 'package:logging/logging.dart';

import '../../chat/chat_models/chat_models.dart';
import 'message_accumulator.dart';

/// Default implementation of MessageAccumulator that handles standard
/// streaming protocols.
///
/// This implementation:
/// - Concatenates text parts
/// - Merges tool calls with the same ID
/// - Preserves all other parts as-is
/// - Consolidates multiple TextParts into a single part
class DefaultMessageAccumulator implements MessageAccumulator {
  /// Creates a new DefaultMessageAccumulator
  const DefaultMessageAccumulator();

  /// Logger for accumulator.message operations.
  static final Logger _logger = Logger('dartantic.accumulator.message');

  @override
  String get providerHint => 'default';

  @override
  ChatMessage accumulate(ChatMessage accumulated, ChatMessage newChunk) {
    if (accumulated.parts.isEmpty) {
      return newChunk;
    }

    _logger.fine('Accumulating message chunk: ${newChunk.parts.length} parts');

    // Collect parts by type for merging
    final accumulatedParts = <Part>[...accumulated.parts];

    for (final newPart in newChunk.parts) {
      if (newPart is ToolPart && newPart.kind == ToolPartKind.call) {
        // Find existing tool call with same ID for merging
        final existingIndex = accumulatedParts.indexWhere(
          (part) =>
              part is ToolPart &&
              part.kind == ToolPartKind.call &&
              part.id.isNotEmpty &&
              part.id == newPart.id,
        );

        if (existingIndex != -1) {
          // Merge with existing tool call
          final existingToolCall = accumulatedParts[existingIndex] as ToolPart;
          final mergedToolCall = ToolPart.call(
            id: newPart.id,
            name: newPart.name.isNotEmpty
                ? newPart.name
                : existingToolCall.name,
            arguments: newPart.arguments?.isNotEmpty ?? false
                ? newPart.arguments!
                : existingToolCall.arguments ?? {},
            argumentsRawString:
                newPart.argumentsRawString ??
                existingToolCall.argumentsRawString,
          );
          accumulatedParts[existingIndex] = mergedToolCall;
        } else {
          // Add new tool call
          accumulatedParts.add(newPart);
        }
      } else {
        // Add other parts as-is (TextPart, DataPart, etc.)
        accumulatedParts.add(newPart);
      }
    }

    // Merge metadata from both messages
    final mergedMetadata = <String, dynamic>{
      ...accumulated.metadata,
      ...newChunk.metadata,
    };

    return ChatMessage(
      role: accumulated.role,
      parts: accumulatedParts,
      metadata: mergedMetadata,
    );
  }

  @override
  ChatMessage consolidate(ChatMessage accumulated) {
    _logger.fine(
      'Consolidating accumulated message: ${accumulated.parts.length} parts',
    );
    
    // Separate text and non-text parts
    final textParts = accumulated.parts.whereType<TextPart>().toList();
    final nonTextParts = accumulated.parts
        .where((part) => part is! TextPart)
        .toList();

    final finalParts = <Part>[];

    // Add consolidated text as a single TextPart (if any)
    if (textParts.isNotEmpty) {
      final consolidatedText = textParts.map((p) => p.text).join();
      if (consolidatedText.isNotEmpty) {
        finalParts.add(TextPart(consolidatedText));
      }
    }

    // Add all non-text parts (already properly merged)
    finalParts.addAll(nonTextParts);

    // Create final message with consolidated parts
    return ChatMessage(
      role: accumulated.role,
      parts: finalParts,
      metadata: accumulated.metadata,
    );
  }
}
