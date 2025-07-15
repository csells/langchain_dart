/// Default tool executor implementation
library;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import '../../chat/chat_models/chat_models.dart';
import '../../chat/tools/tools.dart';
import 'tool_executor.dart';

/// Default implementation of ToolExecutor that handles standard tool execution.
///
/// This implementation:
/// - Executes tools sequentially (can be overridden for parallel execution)
/// - Handles argument parsing edge cases (empty arguments, Cohere's "null")
/// - Formats results as JSON strings
/// - Includes error details in results for LLM consumption
class DefaultToolExecutor implements ToolExecutor {
  /// Creates a new DefaultToolExecutor
  const DefaultToolExecutor();

  static final _logger = Logger('DefaultToolExecutor');

  @override
  String get providerHint => 'default';

  @override
  Future<List<ToolExecutionResult>> executeBatch(
    List<ToolPart> toolCalls,
    Map<String, Tool> toolMap,
  ) async {
    final results = <ToolExecutionResult>[];

    // Execute tools sequentially by default
    // Subclasses can override for parallel execution
    for (final toolCall in toolCalls) {
      final result = await executeSingle(toolCall, toolMap);
      results.add(result);
    }

    return results;
  }

  @override
  Future<ToolExecutionResult> executeSingle(
    ToolPart toolCall,
    Map<String, Tool> toolMap,
  ) async {
    final tool = toolMap[toolCall.name];

    if (tool == null) {
      _logger.warning(
        'Tool ${toolCall.name} not found in available tools: '
        '${toolMap.keys.join(', ')}',
      );

      final error = Exception('Tool ${toolCall.name} not found');
      return ToolExecutionResult(
        toolPart: toolCall,
        resultPart: ToolPart.result(
          id: toolCall.id,
          name: toolCall.name,
          result: formatError(error),
        ),
        error: error,
      );
    }

    _logger.fine(
      'Executing tool: ${toolCall.name} with args: '
      '${toolCall.argumentsRaw}',
    );

    try {
      final args = parseArguments(toolCall);
      final result = await tool.invoke(args);
      final resultString = formatResult(result);

      _logger.info(
        'Tool ${toolCall.name}(${toolCall.id}) executed '
        'successfully, result length: ${resultString.length}',
      );

      return ToolExecutionResult(
        toolPart: toolCall,
        resultPart: ToolPart.result(
          id: toolCall.id,
          name: toolCall.name,
          result: resultString,
        ),
      );
      // Must catch this exception to pass the error along to the LLM
      // ignore: exception_hiding
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'Tool ${toolCall.name} execution failed: $error',
        error,
        stackTrace,
      );

      return ToolExecutionResult(
        toolPart: toolCall,
        resultPart: ToolPart.result(
          id: toolCall.id,
          name: toolCall.name,
          result: formatError(error),
        ),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Map<String, dynamic> parseArguments(ToolPart toolCall) {
    // Start with the arguments map if available
    var args = toolCall.arguments ?? {};

    // CRITICAL: Parse argumentsRaw when arguments is empty
    // This handles OpenAI-compatible providers that send empty arguments
    // during streaming
    if (args.isEmpty && (toolCall.argumentsRawString?.isNotEmpty ?? false)) {
      try {
        final parsed = json.decode(toolCall.argumentsRawString!);
        if (parsed is Map<String, dynamic>) {
          args = parsed;
        } else if (parsed == null || parsed == 'null') {
          // Handle Cohere edge case where it sends "null" for no params
          args = <String, dynamic>{};
        }
        // Must catch to handle malformed JSON gracefully
        // ignore: exception_hiding
      } on FormatException catch (e) {
        _logger.warning(
          'Failed to parse tool arguments for ${toolCall.name}: $e\n'
          'Raw arguments: ${toolCall.argumentsRawString}',
        );
        // Return empty args on parse failure
        args = <String, dynamic>{};
      }
    }

    return args;
  }

  @override
  String formatResult(dynamic result) {
    if (result is String) {
      return result;
    }
    return json.encode(result);
  }

  @override
  String formatError(Exception error) =>
      json.encode({'error': error.toString()});
}
