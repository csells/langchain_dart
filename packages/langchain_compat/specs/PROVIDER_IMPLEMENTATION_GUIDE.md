# Provider Implementation Guide

This guide shows the correct patterns for implementing providers and models in dartantic 1.0.

## Provider Implementation Pattern

```dart
class ExampleProvider extends Provider<ExampleChatOptions, ExampleEmbeddingsOptions> {
  /// Creates a provider instance with optional overrides.
  const ExampleProvider({
    this.apiKey,
    this.baseUrl,
  }) : super(
          name: 'example',
          displayName: 'Example AI',
          aliases: const ['ex', 'example-ai'],
          apiKeyName: 'EXAMPLE_API_KEY',  // null for local providers
          defaultModelNames: const {
            ModelKind.chat: 'example-chat-v1',
            ModelKind.embeddings: 'example-embed-v1',
          },
          caps: const {
            ProviderCaps.chat,
            ProviderCaps.embeddings,
            ProviderCaps.streaming,
            ProviderCaps.tools,
            ProviderCaps.multiToolCalls,
            ProviderCaps.typedOutput,
            ProviderCaps.vision,
          },
        );

  /// Optional API key override.
  final String? apiKey;

  /// Optional base URL override.
  final Uri? baseUrl;

  @override
  ChatModel createChatModel({
    String? name,  // Note: 'name' not 'modelName'
    List<Tool>? tools,
    double? temperature,
    String? systemPrompt,
    ExampleChatOptions? options,
  }) {
    // Provider resolves API key if needed
    final resolvedApiKey = apiKey ?? 
      (apiKeyName != null ? tryGetEnv(apiKeyName) : null);
    
    // Use provided name or default
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    return ExampleChatModel(
      name: modelName,  // Pass as 'name'
      apiKey: resolvedApiKey,  // May be null for local models
      baseUrl: baseUrl,  // Nullable, model knows default
      tools: tools,
      temperature: temperature,
      systemPrompt: systemPrompt,
      defaultOptions: options,
    );
  }

  @override
  EmbeddingsModel createEmbeddingsModel({
    String? name,
    ExampleEmbeddingsOptions? options,
  }) {
    final resolvedApiKey = apiKey ?? 
      (apiKeyName != null ? tryGetEnv(apiKeyName) : null);
    
    final modelName = name ?? defaultModelNames[ModelKind.embeddings]!;

    return ExampleEmbeddingsModel(
      name: modelName,
      apiKey: resolvedApiKey,
      baseUrl: baseUrl,
      defaultOptions: options,
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    // Implementation to list available models
    yield ModelInfo(
      id: 'example-chat-v1',
      providerName: name,
      kinds: {ModelKind.chat},
    );
    yield ModelInfo(
      id: 'example-embed-v1',
      providerName: name,
      kinds: {ModelKind.embeddings},
    );
  }
}
```

## Chat Model Implementation Pattern

```dart
class ExampleChatModel extends ChatModel<ExampleChatOptions> {
  /// Creates a chat model instance.
  ExampleChatModel({
    required super.name,  // Always 'name', passed to super
    required this.apiKey,  // Non-null for cloud providers
    this.baseUrl,  // Nullable
    super.tools,
    super.temperature,
    super.systemPrompt,
    super.defaultOptions,
  }) : _client = ExampleClient(
          apiKey: apiKey,
          baseUrl: baseUrl,  // Client knows its default
        );

  /// The API key (required for cloud providers).
  final String apiKey;

  /// Optional base URL override.
  final Uri? baseUrl;

  final ExampleClient _client;

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    ExampleChatOptions? options,
    JsonSchema? outputSchema,
  }) async* {
    // Prepare messages with system prompt
    final preparedMessages = prepareMessagesWithDefaults(messages);
    
    // Stream implementation
    await for (final chunk in _client.stream(...)) {
      yield ChatResult<ChatMessage>(
        // ... result construction
      );
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
```

## Embeddings Model Implementation Pattern

```dart
class ExampleEmbeddingsModel extends EmbeddingsModel<ExampleEmbeddingsOptions> {
  /// Creates an embeddings model instance.
  ExampleEmbeddingsModel({
    required super.name,  // Always 'name'
    required this.apiKey,
    this.baseUrl,
    super.defaultOptions,
    super.dimensions,
    super.batchSize,
  }) : _client = ExampleClient(
          apiKey: apiKey,
          baseUrl: baseUrl,
        );

  final String apiKey;
  final Uri? baseUrl;
  final ExampleClient _client;

  @override
  Future<EmbeddingsResult> embedQuery(
    String query, {
    ExampleEmbeddingsOptions? options,
  }) async {
    final response = await _client.embed(
      texts: [query],
      model: name,
      dimensions: options?.dimensions ?? dimensions,
    );
    
    return EmbeddingsResult(
      embedding: response.embeddings.first,
      usage: LanguageModelUsage(
        inputTokens: response.usage?.inputTokens,
        outputTokens: response.usage?.outputTokens,
      ),
    );
  }

  @override
  Future<BatchEmbeddingsResult> embedDocuments(
    List<String> texts, {
    ExampleEmbeddingsOptions? options,
  }) async {
    final response = await _client.embed(
      texts: texts,
      model: name,
      dimensions: options?.dimensions ?? dimensions,
    );
    
    return BatchEmbeddingsResult(
      embeddings: response.embeddings,
      usage: LanguageModelUsage(
        inputTokens: response.usage?.inputTokens,
        outputTokens: response.usage?.outputTokens,
      ),
    );
  }

  @override
  void dispose() {
    _client.close();
  }
}
```

## Local Provider Pattern (No API Key)

```dart
class LocalProvider extends Provider<LocalChatOptions, LocalEmbeddingsOptions> {
  const LocalProvider({
    this.baseUrl,
  }) : super(
          name: 'local',
          displayName: 'Local Model',
          aliases: const [],
          apiKeyName: null,  // No API key needed
          defaultModelNames: const {
            ModelKind.chat: 'llama3.2',
          },
          caps: const {
            ProviderCaps.chat,
            ProviderCaps.streaming,
          },
        );

  final Uri? baseUrl;

  @override
  ChatModel createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    String? systemPrompt,
    LocalChatOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    return LocalChatModel(
      name: modelName,
      baseUrl: baseUrl ?? Uri.parse('http://localhost:11434'),
      tools: tools,
      temperature: temperature,
      systemPrompt: systemPrompt,
      defaultOptions: options,
    );
  }

  @override
  EmbeddingsModel createEmbeddingsModel({
    String? name,
    LocalEmbeddingsOptions? options,
  }) {
    throw UnsupportedError('Local provider does not support embeddings');
  }
}
```

## Static Provider Registration

Add your provider to the Provider class:

```dart
abstract class Provider {
  // ... base class definition ...
  
  // Add your provider as a static instance
  static final example = ExampleProvider();
  
  // Include in the intrinsic providers list
  static final _intrinsicProviders = <Provider>[
    openai,
    google,
    anthropic,
    // ... other providers ...
    example,  // Add your provider here
  ];
}
```

## Key Implementation Rules

1. **Parameter Naming**: Always use `name` for model names, not `model`, `modelId`, or `modelName`
2. **API Key Handling**: 
   - Cloud providers: require non-null API key
   - Local providers: no API key parameter at all
3. **Base URL**: Always nullable, models pass directly to client
4. **Environment Resolution**: Providers use `tryGetEnv()`, models use `getEnv()`
5. **Capabilities**: Accurately declare what your provider supports
6. **Error Handling**: Throw `UnsupportedError` for unsupported operations

## Testing Your Provider

```dart
// Test provider discovery
final provider = Provider.forName('example');
assert(provider.name == 'example');

// Test alias resolution
final aliased = Provider.forName('ex');
assert(aliased.name == 'example');

// Test Agent integration
final agent = Agent('example');
final result = await agent.send('Hello');

// Test embeddings
final embed = await agent.embedQuery('test');
```
