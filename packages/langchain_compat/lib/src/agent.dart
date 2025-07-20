import 'dart:async';
import 'dart:convert';

import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';

import 'agent/orchestrators/orchestrators.dart';
import 'agent/streaming_state.dart';
import 'chat/chat_models/chat_models.dart';
import 'chat/chat_providers/chat_providers.dart';
import 'chat/tools/tools.dart';
import 'language_models/language_models.dart';
import 'logging_options.dart';

/// An agent that manages chat models and provides tool execution and message
/// collection capabilities.
///
/// The Agent handles:
/// - Provider and model creation from string specification
/// - Tool call ID assignment for providers that don't provide them
/// - Automatic tool execution with error handling
/// - Message collection and streaming UX enhancement
/// - Model caching and lifecycle management
class Agent {
  /// Creates an agent with the specified model.
  ///
  /// The [model] parameter should be in the format "providerName",
  /// "providerName:modelName", or "providerName/modelName". For example:
  /// "openai", "openai:gpt-4o", "openai/gpt-4o", "anthropic",
  /// "anthropic:claude-3-sonnet", etc.
  ///
  /// Optional parameters:
  /// - [tools]: List of tools the agent can use
  /// - [temperature]: Model temperature (0.0 to 1.0)
  /// - [systemPrompt]: Default system prompt for the agent
  Agent(
    String model, {
    List<Tool>? tools,
    double? temperature,
    String? systemPrompt,
    String? displayName,
  }) {
    // split the model into provider name and model name
    final index = model.indexOf(RegExp('[:/]'));
    final providerName = index == -1 ? model : model.substring(0, index);
    final modelName = index == -1 ? null : model.substring(index + 1);

    _logger.info(
      'Creating agent with model: $model (provider: $providerName, '
      'model: $modelName)',
    );

    // cache the provider name from the input; it could be an alias
    _providerName = providerName;
    _displayName = displayName;

    // Store provider and model parameters
    _provider = ChatProvider.forName(providerName);
    _modelName = modelName ?? _provider.defaultModelName;
    _tools = tools;
    _temperature = temperature;
    _systemPrompt = systemPrompt;

    _logger.fine(
      'Agent created successfully with ${tools?.length ?? 0} tools, '
      'temperature: $temperature',
    );
  }

  /// Creates an agent from a provider
  Agent.forProvider(
    ChatProvider provider, {
    String? modelName,
    List<Tool>? tools,
    double? temperature,
    String? systemPrompt,
    String? displayName,
  }) {
    _logger.info(
      'Creating agent from provider: ${provider.name}, model: $modelName',
    );

    _providerName = provider.name;
    _displayName = displayName;

    // Store provider and model parameters
    _provider = provider;
    _modelName = modelName ?? provider.defaultModelName;
    _tools = tools;
    _temperature = temperature;
    _systemPrompt = systemPrompt;

    _logger.fine(
      'Agent created from provider with ${tools?.length ?? 0} tools, '
      'temperature: $temperature',
    );
  }

  /// Logger for agent operations.
  static final Logger _logger = Logger('dartantic.agent');

  /// Global logging configuration for all Agent operations.
  ///
  /// Controls logging level, filtering, and output handling for all dartantic
  /// loggers. Setting this property automatically configures the logging system
  /// with the specified options.
  ///
  /// Example usage:
  /// ```dart
  /// // Filter to only OpenAI operations
  /// Agent.loggingOptions = LoggingOptions(filter: 'openai');
  ///
  /// // Custom level and handler
  /// Agent.loggingOptions = LoggingOptions(
  ///   level: Level.FINE,
  ///   onRecord: (record) => myLogger.log(record),
  /// );
  /// ```
  static LoggingOptions get loggingOptions => _loggingOptions;
  static LoggingOptions _loggingOptions = const LoggingOptions();
  static StreamSubscription<LogRecord>? _loggingSubscription;

  /// Sets the global logging configuration and applies it immediately.
  static set loggingOptions(LoggingOptions options) {
    _loggingOptions = options;
    _setupLogging();
  }

  /// Sets up the logging system with the current options.
  static void _setupLogging() {
    // Cancel existing subscription if any
    unawaited(_loggingSubscription?.cancel());

    // Configure root logger level
    Logger.root.level = _loggingOptions.level;

    // Set up new subscription with filtering
    _loggingSubscription = Logger.root.onRecord.listen((record) {
      // Apply level filter (should already be handled by Logger.root.level)
      if (record.level < _loggingOptions.level) return;

      // Apply name filter - empty string matches all
      if (_loggingOptions.filter.isNotEmpty &&
          !record.loggerName.contains(_loggingOptions.filter)) {
        return;
      }

      // Call the configured handler
      _loggingOptions.onRecord(record);
    });
  }

  /// Gets the provider name.
  String get providerName => _providerName;

  /// Gets the model name.
  String get modelName => _modelName;

  /// Gets the fully qualified model name.
  String get model => '$providerName:$modelName';

  /// Gets the display name.
  String get displayName => _displayName ?? model;

  /// Gets an environment map for the agent.
  static Map<String, String> environment = {};

  /// Closes the underlying model.
  void dispose() {
    // No longer needed since models are created on-the-fly
  }

  late final String _providerName;
  late final ChatProvider _provider;
  late final String _modelName;
  late final List<Tool>? _tools;
  late final double? _temperature;
  late final String? _systemPrompt;
  late final String? _displayName;

  /// Invokes the agent with the given prompt and returns the final result.
  ///
  /// This method internally uses [runStream] and accumulates all results.
  Future<ChatResult<String>> run(
    String prompt, {
    List<ChatMessage> history = const [],
    List<Part> attachments = const [],
    JsonSchema? outputSchema,
  }) async {
    _logger.info(
      'Running agent with prompt and ${history.length} history messages',
    );

    final allNewMessages = <ChatMessage>[];
    var finalOutput = '';
    var finalResult = ChatResult<String>(
      output: '',
      finishReason: FinishReason.unspecified,
      metadata: const <String, dynamic>{},
      usage: const LanguageModelUsage(),
    );

    await for (final result in runStream(
      prompt,
      history: history,
      attachments: attachments,
      outputSchema: outputSchema,
    )) {
      final outputText = result.outputAsString;
      if (outputText.isNotEmpty) {
        finalOutput += outputText;
      }
      allNewMessages.addAll(result.messages);
      finalResult = result;
    }

    // Return final result with all accumulated messages
    finalResult = ChatResult<String>(
      id: finalResult.id,
      output: finalOutput,
      messages: allNewMessages,
      finishReason: finalResult.finishReason,
      metadata: finalResult.metadata,
      usage: finalResult.usage,
    );

    _logger.info(
      'Agent run completed with ${allNewMessages.length} new messages, '
      'finish reason: ${finalResult.finishReason}',
    );

    return finalResult;
  }

  /// Runs the given [prompt] through the model and returns a typed response.
  ///
  /// Returns an [ChatResult<TOutput>] containing the output converted to type
  /// [TOutput]. Uses [outputFromJson] to convert the JSON response if provided,
  /// otherwise returns the decoded JSON.
  Future<ChatResult<TOutput>> runFor<TOutput extends Object>(
    String prompt, {
    required JsonSchema outputSchema,
    dynamic Function(Map<String, dynamic> json)? outputFromJson,
    List<ChatMessage> history = const [],
    List<Part> attachments = const [],
  }) async {
    final response = await run(
      prompt,
      outputSchema: outputSchema,
      history: history,
      attachments: attachments,
    );

    // Since runStream now normalizes output, JSON is always in response.output
    final jsonString = response.output;
    if (jsonString.isEmpty) {
      throw const FormatException(
        'No JSON output found in response. Expected JSON in response.output.',
      );
    }

    final outputJson = jsonDecode(jsonString);
    final typedOutput = outputFromJson?.call(outputJson) ?? outputJson;
    return ChatResult<TOutput>(
      id: response.id,
      output: typedOutput,
      messages: response.messages,
      finishReason: response.finishReason,
      metadata: response.metadata,
      usage: response.usage,
    );
  }

  /// Streams responses from the agent, handling tool execution automatically.
  ///
  /// Returns a stream of [ChatResult] where:
  /// - [ChatResult.output] contains streaming text chunks
  /// - [ChatResult.messages] contains new messages since the last result
  Stream<ChatResult<String>> runStream(
    String prompt, {
    List<ChatMessage> history = const [],
    List<Part> attachments = const [],
    JsonSchema? outputSchema,
  }) async* {
    _logger.info(
      'Starting agent stream with prompt and ${history.length} '
      'history messages',
    );

    // Prepare tools, including return_result if needed
    var tools = _tools;
    if (outputSchema != null) {
      final returnResultTool = Tool<Map<String, dynamic>>(
        name: kReturnResultToolName,
        description:
            'REQUIRED: You MUST call this tool to return the final result. '
            'Use this tool to format and return your response according to '
            'the specified JSON schema. Call this after gathering any '
            'necessary information from other tools.',
        inputSchema: outputSchema,

        onCall: (args) async => json.encode(args),
      );
      tools = [...?_tools, returnResultTool];
    }

    // Create model directly from provider
    final model = _provider.createModel(
      name: _modelName,
      tools: tools,
      temperature: _temperature,
      systemPrompt: _systemPrompt,
    );

    try {
      // Create and yield user message
      final newUserMessage = ChatMessage.user(prompt, parts: attachments);

      _assertNoMultipleTextParts([newUserMessage]);
      yield ChatResult<String>(
        id: '',
        output: '',
        messages: [newUserMessage],
        finishReason: FinishReason.unspecified,
        metadata: const <String, dynamic>{},
        usage: const LanguageModelUsage(),
      );

      // Initialize state
      final conversationHistory = List<ChatMessage>.from([
        ...history,
        newUserMessage,
      ]);

      final state = StreamingState(
        conversationHistory: conversationHistory,
        toolMap: {for (final tool in model.tools ?? <Tool>[]) tool.name: tool},
      );

      // Select and configure orchestrator
      final orchestrator = _selectOrchestrator(
        outputSchema: outputSchema,
        tools: model.tools,
      );

      orchestrator.initialize(state);

      try {
        // Main streaming loop
        while (!state.done) {
          await for (final result in orchestrator.processIteration(
            model,
            state,
            outputSchema: outputSchema,
          )) {
            // Yield streaming text
            if (result.output.isNotEmpty) {
              yield ChatResult<String>(
                id: state.lastResult.id.isEmpty ? '' : state.lastResult.id,
                output: result.output,
                messages: const [],
                finishReason: result.finishReason,
                metadata: result.metadata,
                usage: result.usage ?? const LanguageModelUsage(),
              );
            }

            // Yield messages
            if (result.messages.isNotEmpty) {
              for (final message in result.messages) {
                _assertNoMultipleTextParts([message]);
              }
              yield ChatResult<String>(
                id: state.lastResult.id.isEmpty ? '' : state.lastResult.id,
                output: '',
                messages: result.messages,
                finishReason: result.finishReason,
                metadata: result.metadata,
                usage: result.usage ?? const LanguageModelUsage(),
              );
            }

            // Check continuation
            if (!result.shouldContinue) {
              state.complete();
            }
          }
        }
      } finally {
        orchestrator.finalize(state);
      }
    } finally {
      model.dispose();
    }
  }

  /// Selects the appropriate orchestrator based on context
  StreamingOrchestrator _selectOrchestrator({
    required JsonSchema? outputSchema,
    required List<Tool>? tools,
  }) {
    if (outputSchema != null) {
      final hasReturnResultTool =
          tools?.any((t) => t.name == kReturnResultToolName) ?? false;

      return TypedOutputStreamingOrchestrator(
        provider: _provider,
        hasReturnResultTool: hasReturnResultTool,
      );
    }

    return const DefaultStreamingOrchestrator();
  }

  /// Asserts that no message in the list contains more than one TextPart.
  ///
  /// This helps catch streaming consolidation issues where text content gets
  /// split into multiple TextPart objects instead of being properly accumulated
  /// into a single TextPart.
  ///
  /// Throws an AssertionError in debug mode if any message violates this rule.
  void _assertNoMultipleTextParts(List<ChatMessage> messages) {
    assert(() {
      for (final message in messages) {
        final textParts = message.parts.whereType<TextPart>().toList();
        if (textParts.length > 1) {
          throw AssertionError(
            'Message contains ${textParts.length} TextParts but should have '
            'at most 1. Message: $message. '
            'TextParts: ${textParts.map((p) => '"${p.text}"').join(', ')}. '
            'This indicates a streaming consolidation bug.',
          );
        }
      }
      return true;
    }());
  }
}
