/// Default model lifecycle manager implementation
library;

import 'package:logging/logging.dart';

import '../../chat/chat_models/chat_models.dart';
import 'model_lifecycle_manager.dart';

/// Default implementation of ModelLifecycleManager that handles standard
/// model lifecycle operations.
///
/// This implementation:
/// - Creates models synchronously (no async initialization needed)
/// - Disposes models by calling their dispose() method
/// - Validates basic configuration requirements
class DefaultModelLifecycleManager implements ModelLifecycleManager {
  /// Creates a new DefaultModelLifecycleManager
  const DefaultModelLifecycleManager();

  static final _logger = Logger('dartantic.lifecycle.model');

  @override
  String get providerHint => 'default';

  @override
  Future<ChatModel<ChatModelOptions>> createModel(ModelConfig config) async {
    validateConfig(config);

    _logger.fine(
      'Creating model ${config.modelName} with provider '
      '${config.provider.name}',
    );

    // Standard model creation - providers handle their own initialization
    final model = config.provider.createModel(
      name: config.modelName,
      tools: config.tools,
      temperature: config.temperature,
      systemPrompt: config.systemPrompt,
      apiKey: config.apiKey,
      baseUrl: config.baseUrl,
    );

    _logger.info('Model ${config.modelName} created successfully');

    return model;
  }

  @override
  Future<void> disposeModel(ChatModel<ChatModelOptions> model) async {
    _logger.fine('Disposing model');

    try {
      // Call the model's dispose method
      model.dispose();
      _logger.info('Model disposed successfully');
      // Must catch to ensure cleanup completes even if dispose fails
      // ignore: exception_hiding
    } on Exception catch (error, stackTrace) {
      _logger.warning('Error disposing model: $error', error, stackTrace);
      // Don't rethrow - we want cleanup to complete
    }
  }

  @override
  void validateConfig(ModelConfig config) {
    // Basic validation
    if (config.modelName.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }

    // Validate temperature if provided
    if (config.temperature != null) {
      if (config.temperature! < 0 || config.temperature! > 2) {
        throw ArgumentError(
          'Temperature must be between 0 and 2, got ${config.temperature}',
        );
      }
    }

    // Provider-specific validation can be added in subclasses
  }
}
