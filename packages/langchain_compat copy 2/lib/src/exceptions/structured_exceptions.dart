/// Structured exception hierarchy for langchain_compat providing detailed
/// error context
library;

/// Base exception class for all langchain_compat errors
abstract class LangchainCompatException implements Exception {
  /// Creates a new LangchainCompatException
  const LangchainCompatException({
    required this.message,
    required this.provider,
    required this.metadata,
    this.cause,
    this.causeStackTrace,
  });

  /// A descriptive message explaining what went wrong
  final String message;

  /// The provider that caused the exception (e.g., 'openai', 'anthropic')
  final String provider;

  /// Additional metadata about the error context
  final Map<String, dynamic> metadata;

  /// The underlying cause of this exception, if any
  final Object? cause;

  /// Stack trace of the underlying cause
  final StackTrace? causeStackTrace;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('$runtimeType: $message')
      ..writeln('Provider: $provider');

    if (metadata.isNotEmpty) {
      buffer.writeln('Metadata: $metadata');
    }

    if (cause != null) {
      buffer.writeln('Caused by: $cause');
    }

    return buffer.toString();
  }
}

/// Exception thrown when a model operation fails
class ModelOperationException extends LangchainCompatException {
  /// Creates a new ModelOperationException
  const ModelOperationException({
    required super.message,
    required super.provider,
    required super.metadata,
    super.cause,
    super.causeStackTrace,
  });
}

/// Exception thrown when tool execution fails
class ToolExecutionException extends LangchainCompatException {
  /// Creates a new ToolExecutionException
  const ToolExecutionException({
    required super.message,
    required super.provider,
    required this.toolName,
    required this.arguments,
    super.metadata = const {},
    super.cause,
    super.causeStackTrace,
  });

  /// The name of the tool that failed
  final String toolName;

  /// The arguments passed to the tool
  final Map<String, dynamic> arguments;

  @override
  Map<String, dynamic> get metadata => {
    ...super.metadata,
    'toolName': toolName,
    'arguments': arguments,
  };
}

/// Exception thrown when message mapping fails
class MessageMappingException extends LangchainCompatException {
  /// Creates a new MessageMappingException
  const MessageMappingException({
    required super.message,
    required super.provider,
    required this.mappingType,
    required this.originalData,
    super.metadata = const {},
    super.cause,
    super.causeStackTrace,
  });

  /// The type of mapping that failed
  final String mappingType;

  /// The original message data that failed to map
  final dynamic originalData;

  @override
  Map<String, dynamic> get metadata => {
    ...super.metadata,
    'mappingType': mappingType,
    'originalDataType': originalData.runtimeType.toString(),
  };
}

/// Exception thrown when streaming operations fail
class StreamingException extends LangchainCompatException {
  /// Creates a new StreamingException
  const StreamingException({
    required super.message,
    required super.provider,
    required this.streamingPhase,
    this.duringAccumulation = false,
    super.metadata = const {},
    super.cause,
    super.causeStackTrace,
  });

  /// The phase of streaming where the error occurred
  final String streamingPhase;

  /// Whether this was during accumulation
  final bool duringAccumulation;

  @override
  Map<String, dynamic> get metadata => {
    ...super.metadata,
    'streamingPhase': streamingPhase,
    'duringAccumulation': duringAccumulation,
  };
}

/// Exception thrown when provider configuration is invalid
class ProviderConfigurationException extends LangchainCompatException {
  /// Creates a new ProviderConfigurationException
  const ProviderConfigurationException({
    required super.message,
    required super.provider,
    required this.parameter,
    required this.invalidValue,
    super.metadata = const {},
    super.cause,
    super.causeStackTrace,
  });

  /// The configuration parameter that was invalid
  final String parameter;

  /// The invalid value that was provided
  final dynamic invalidValue;

  @override
  Map<String, dynamic> get metadata => {
    ...super.metadata,
    'parameter': parameter,
    'invalidValue': invalidValue?.toString() ?? 'null',
  };
}

/// Exception thrown when resource management fails
class ResourceManagementException extends LangchainCompatException {
  /// Creates a new ResourceManagementException
  const ResourceManagementException({
    required super.message,
    required super.provider,
    required this.resourceType,
    required this.operation,
    super.metadata = const {},
    super.cause,
    super.causeStackTrace,
  });

  /// The type of resource that failed
  final String resourceType;

  /// The operation that failed (create, dispose, etc.)
  final String operation;

  @override
  Map<String, dynamic> get metadata => {
    ...super.metadata,
    'resourceType': resourceType,
    'operation': operation,
  };
}
