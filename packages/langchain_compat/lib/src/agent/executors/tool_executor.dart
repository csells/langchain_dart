/// Interface for executing tools
library;

import 'dart:async';

import '../../chat/chat_models/chat_models.dart';
import '../../chat/tools/tools.dart';

/// Result of executing a single tool
class ToolExecutionResult {
  /// Creates a new ToolExecutionResult
  const ToolExecutionResult({
    required this.toolPart,
    required this.resultPart,
    this.error,
    this.stackTrace,
  });

  /// The original tool call part
  final ToolPart toolPart;

  /// The result part containing the execution result
  final ToolPart resultPart;

  /// Error if the execution failed
  final Exception? error;

  /// Stack trace if the execution failed
  final StackTrace? stackTrace;

  /// Whether the execution succeeded
  bool get isSuccess => error == null;
}

/// Strategy interface for executing tools.
///
/// Different providers may have different requirements for tool execution,
/// such as special error formatting, retry logic, or result transformations.
abstract class ToolExecutor {
  /// Executes a list of tool calls and returns their results.
  ///
  /// This method handles:
  /// - Parsing tool arguments (including handling streaming edge cases)
  /// - Invoking the actual tool functions
  /// - Formatting results appropriately
  /// - Error handling and reporting
  ///
  /// Returns a list of ToolExecutionResult objects containing both successes
  /// and failures.
  Future<List<ToolExecutionResult>> executeBatch(
    List<ToolPart> toolCalls,
    Map<String, Tool> toolMap,
  );

  /// Executes a single tool call.
  ///
  /// This is typically called by executeBatch for each tool, but can be
  /// overridden for provider-specific behavior.
  Future<ToolExecutionResult> executeSingle(
    ToolPart toolCall,
    Map<String, Tool> toolMap,
  );

  /// Formats a tool result for inclusion in the conversation.
  ///
  /// This can be overridden by providers that need special result formatting.
  String formatResult(dynamic result);

  /// Formats an error for inclusion in the conversation.
  ///
  /// This can be overridden by providers that need special error formatting.
  String formatError(Exception error);

  /// Provider hint for debugging and logging.
  String get providerHint;
}
