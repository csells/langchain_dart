/// Interface for managing model lifecycle
library;

import '../../chat/chat_providers/chat_providers.dart';
import '../../chat/tools/tools.dart';

/// Configuration for creating a model
class ModelConfig {
  /// Creates a new ModelConfig
  const ModelConfig({
    required this.provider,
    required this.modelName,
    this.tools,
    this.temperature,
    this.systemPrompt,
    this.apiKey,
    this.baseUrl,
    this.additionalOptions,
  });

  /// The chat provider to use
  final ChatProvider provider;

  /// The model name
  final String modelName;

  /// Tools available to the model
  final List<Tool>? tools;

  /// Temperature setting
  final double? temperature;

  /// System prompt
  final String? systemPrompt;

  /// API key override
  final String? apiKey;

  /// Base URL override
  final Uri? baseUrl;

  /// Additional provider-specific options
  final Map<String, dynamic>? additionalOptions;
}
