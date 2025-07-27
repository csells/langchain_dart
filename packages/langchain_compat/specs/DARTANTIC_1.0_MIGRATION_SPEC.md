# Migration Specification: langchain_compat to dartantic_ai 1.0

## Overview
This document specifies the migration from the current langchain_compat library
architecture to a cleaner dartantic_ai 1.0 API.

## Core Requirements

### 1. Rename Agent to Agent
- [x] The `Agent` class should be renamed to `Agent`
- [x] The file should remain `chat_agent.dart` (DO NOT rename files)
- [x] Agent should support both chat and embeddings operations

### 2. Rename Agent Methods
Replace the "run" naming convention with "send":
- [x] `run()` → `send()`
- [x] `runFor()` → `sendFor()`
- [x] `runStream()` → `sendStream()`

Add embeddings support:
- [x] `embedQuery()` - for query embeddings
- [x] `embedDocuments()` - for document embeddings

### 3. Global Services
Move global services from the top-level `Dartantic` object to the `Agent` class:
- [x] `Agent.environment` - for environment variables
- [x] `Agent.loggingOptions` - for logging configuration

Remove the top-level `Dartantic` object entirely.

### 4. Unified Provider Architecture

#### Create Base Classes
1. [x] Rename `ChatProvider` to `Provider`
2. [x] rename `createModel` to `createChatModel`
3. [x] add `createEmbeddingsModel`
   ```dart
   abstract class Provider {
     ...
     
     ChatModel createChatModel({
       String? modelName,
       ChatModelOptions? options,
     });
     
     EmbeddingsModel createEmbeddingsModel({
       String? modelName,
       EmbeddingsModelOptions? options,
     });
   }
   ```
4. [x] Layer in static embeddings provider into into the unified list of
        providers by moving `String defaultModelName` to `Map<ModelKind, String>
        defaultModelNames`

5. [x] remove `EmbeddingsProvider` type.

5. [x] **LanguageModel** base class for all models

#### Provider Implementation Pattern
Each provider should:
- [x] Extend the base `Provider` class
- [x] Implement both `createChatModel` and `createEmbeddingsModel` (throw
  `UnsupportedError` if not supported)
- [x] Use `defaultModelNames` map with `ModelKind` keys
- [x] Have a single static instance in `Provider` class (e.g.,
  `Provider.openai`)

### 5. Model String Parser
Create a `ModelStringParser` that supports:
- [x] Simple format: `"provider"` (uses default chat and embeddings models)
- [x] Legacy format: `"provider:chatModel"` 
- [x] Explicit format: `"provider/chat:gpt-4/embeddings:text-embedding-3"`

### 6. Agent Model Creation
The Agent should:
- [x] Parse the model string using `ModelStringParser`
- [x] Get the provider using `Provider.forName()`
- [x] Lazily create models using `provider.createChatModel()` and
  `provider.createEmbeddingsModel()`
- [x] Pass tools, temperature, and systemPrompt to the model's `sendStream()`
  method or to `createChatModel()` as appropriate

## Architectural Principles

### Separation of Concerns
1. **Agent** - Orchestrates tool execution, manages conversation state, handles
   streaming UX
   - Does NOT handle API keys or base URLs
   - Only knows about model specifications and tool orchestration

2. **Provider** - Factory for creating models, handles configuration and API key
   resolution
   - Resolves API keys from environment variables
   - Handles default base URLs and overrides
   - Throws if required API keys are missing
   - Creates models with all required configuration

3. **Model** - Direct interface to the LLM API
   - Takes non-null, non-empty API key for models that require them
   - Takes NO API key parameter for models that don't need them (e.g., Ollama)
   - Takes nullable baseUrl and passes it directly to underlying API
     - The underlying provider-specific API already knows its default base URL

### API Key Handling
- Models that require API keys have a non-nullable String apiKey parameter
- Models that don't require API keys (like Ollama) have NO apiKey parameter at
  all
- Providers handle API key resolution and validation
- If a provider can't resolve a required API key, it throws immediately

### Base URL Handling
- All models take a nullable `Uri? baseUrl` parameter
- Models pass the baseUrl directly to their underlying API client
- The underlying API client knows its own default base URL
- This simplifies the architecture - models don't need to know about defaults

## Default model names, API key names, base URLs
- should ALL be kept in the static Provider.provider instances, e.g.
  Provider.openai

## Canonical Implementation Examples

### AcmeProvider
```dart
import '../chat/chat_models/chat_models.dart';
import '../embeddings/embeddings.dart';
import '../model_kind.dart';
import '../provider.dart';
import '../provider_caps.dart';
import 'package:acme_dart/acme_dart.dart'; // hypothetical Acme API client

/// Acme AI provider implementation.
class AcmeProvider extends Provider<ChatModelOptions, EmbeddingsModelOptions> {
  /// Creates an Acme provider instance.
  const AcmeProvider({
    this.apiKey,
    this.baseUrl,
  }) : super(
          name: 'acme',
          displayName: 'Acme AI',
          aliases: const ['acmeai'],
          apiKeyName: 'ACME_API_KEY',
          defaultModelNames: const {
            ModelKind.chat: 'acme-chat-v1',
            ModelKind.embeddings: 'acme-embed-v1',
          },
        );

  /// Optional API key override.
  final String? apiKey;

  /// Optional base URL override.
  final Uri? baseUrl;

  @override
  Set<ProviderCaps> get caps => const {
        ProviderCaps.chat,
        ProviderCaps.embeddings,
        ProviderCaps.streaming,
        ProviderCaps.tools,
      };

  @override
  ChatModel createChatModel({
    String? modelName,
    ChatModelOptions? options,
  }) {
    // Provider handles API key resolution
    final resolvedApiKey = apiKey ?? getEnv(apiKeyName);
    final resolvedModelName = modelName ?? defaultModelNames[ModelKind.chat]!;

    return AcmeChatModel(
      apiKey: resolvedApiKey, // Non-null, non-empty
      modelId: resolvedModelName,
      baseUrl: baseUrl, // Nullable, passed through
      defaultOptions: options as AcmeChatOptions?,
    );
  }

  @override
  EmbeddingsModel createEmbeddingsModel({
    String? modelName,
    EmbeddingsModelOptions? options,
  }) {
    // Provider handles API key resolution
    final resolvedApiKey = apiKey ?? getEnv(apiKeyName);
    final resolvedModelName = modelName ?? defaultModelNames[ModelKind.embeddings]!;

    return AcmeEmbeddingsModel(
      apiKey: resolvedApiKey, // Non-null, non-empty
      modelId: resolvedModelName,
      baseUrl: baseUrl, // Nullable, passed through
      defaultOptions: options as AcmeEmbeddingsOptions?,
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    // Implementation would list available Acme models
    yield ModelInfo(
      id: 'acme-chat-v1',
      providerName: 'acme',
      kinds: {ModelKind.chat},
    );
    yield ModelInfo(
      id: 'acme-embed-v1',
      providerName: 'acme',
      kinds: {ModelKind.embeddings},
    );
  }
}
```

### AcmeChatModel
```dart
/// Acme chat model implementation.
class AcmeChatModel extends ChatModel<AcmeChatOptions> {
  /// Creates an Acme chat model.
  AcmeChatModel({
    required this.apiKey, // Non-null, non-empty
    required this.modelId,
    this.baseUrl, // Nullable
    super.defaultOptions,
  }) : _client = AcmeClient(
          apiKey: apiKey,
          baseUrl: baseUrl, // Client knows its own default
        );

  /// The API key for authenticating with Acme.
  final String apiKey;

  /// The model ID to use.
  final String modelId;

  /// Optional base URL override.
  final Uri? baseUrl;

  final AcmeClient _client;

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    AcmeChatOptions? options,
    JsonSchema? outputSchema,
  }) async* {...}

  @override
  void dispose() {...}
}

/// Acme-specific chat options.
class AcmeChatOptions extends ChatModelOptions {
  const AcmeChatOptions({
    super.temperature,
    this.maxTokens,
    this.topP,
    // ... other Acme-specific options
  });

  final int? maxTokens;
  final double? topP;
}
```

### AcmeEmbeddingsModel
```dart
/// Acme embeddings model implementation.
class AcmeEmbeddingsModel extends EmbeddingsModel<AcmeEmbeddingsOptions> {
  /// Creates an Acme embeddings model.
  AcmeEmbeddingsModel({
    required this.apiKey, // Non-null, non-empty
    required this.modelId,
    this.baseUrl, // Nullable
    super.defaultOptions,
  }) : _client = AcmeClient(
          apiKey: apiKey,
          baseUrl: baseUrl, // Client knows its own default
        );

  /// The API key for authenticating with Acme.
  final String apiKey;

  /// The model ID to use.
  final String modelId;

  /// Optional base URL override.
  final Uri? baseUrl;

  final AcmeClient _client;

  @override
  Future<EmbeddingsResult> embedDocuments(
    List<String> texts, {
    AcmeEmbeddingsOptions? options,
  }) async {...}

  @override
  Future<EmbeddingsResult> embedQuery(
    String text, {
    AcmeEmbeddingsOptions? options,
  }) async {...}

  @override
  void dispose() {...}
}

/// Acme-specific embeddings options.
class AcmeEmbeddingsOptions extends EmbeddingsModelOptions {
  const AcmeEmbeddingsOptions({
    this.dimensions,
    // ... other Acme-specific options
  });

  final int? dimensions;
}
```

