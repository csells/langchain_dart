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

  static final _logger = Logger('dartantic.executor.tool');

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
      '${json.encode(toolCall.arguments ?? {})}',
    );

    try {
      final args = toolCall.arguments ?? {};
      final result = await tool.call(args);
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
