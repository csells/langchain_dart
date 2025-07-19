/// Interface for managing model lifecycle
library;

import '../../chat/chat_models/chat_models.dart';
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

/// Strategy interface for managing model lifecycle.
///
/// Different providers may have different requirements for model
/// initialization, configuration, and cleanup. This interface allows
/// provider-specific implementations while maintaining a consistent API.
abstract class ModelLifecycleManager {
  /// Creates and initializes a model with the given configuration.
  ///
  /// This method handles:
  /// - Provider-specific model creation
  /// - Configuration validation
  /// - Resource initialization
  /// - Connection setup (if needed)
  ///
  /// Returns a fully initialized ChatModel ready for use.
  Future<ChatModel<ChatModelOptions>> createModel(ModelConfig config);

  /// Disposes of a model and cleans up its resources.
  ///
  /// This method handles:
  /// - Closing connections
  /// - Releasing resources
  /// - Cleanup of provider-specific state
  ///
  /// Should be called when the model is no longer needed.
  Future<void> disposeModel(ChatModel<ChatModelOptions> model);

  /// Validates the model configuration before creation.
  ///
  /// This can be overridden by providers that need special validation.
  /// Throws an exception if the configuration is invalid.
  void validateConfig(ModelConfig config);

  /// Provider hint for debugging and logging.
  String get providerHint;
}
