import '../chat_models/chat_models/chat_models.dart';
import '../chat_models/tools/tool.dart';
import '../embeddings_models/embeddings_model.dart';
import '../embeddings_models/embeddings_model_options.dart';
import '../provider_caps.dart';
import 'providers.dart';

/// Provides a unified interface for accessing all major LLM, chat, and
/// embedding providers in LangChain.dart via a single import. This includes
/// OpenAI, GoogleAI, VertexAI, Anthropic, Mistral, Ollama (native and
/// OpenAI-compatible), and more. Each provider is represented as a static field
/// and can be selected by name or alias using [Provider.providerMap] or
/// iterated via [Provider.all].
///
/// The compat layer ensures all providers are accessible without importing
/// provider-specific packages. All configuration (API keys, base URLs, models)
/// is handled via the provider interface.
abstract class Provider<
  TChatOptions extends ChatModelOptions,
  TEmbeddingsOptions extends EmbeddingsModelOptions
> {
  /// Creates a new provider instance.
  ///
  /// - [name]: The canonical provider name (e.g., 'openai', 'ollama').
  /// - [displayName]: Human-readable name for display.
  /// - [defaultModelNames]: The default model for this provider (null means use
  ///   model's own default).
  /// - [baseUrl]: The default API endpoint.
  /// - [apiKeyName]: The environment variable for the API key (if any).
  /// - [aliases]: Alternative names for lookup.
  const Provider({
    required this.name,
    required this.displayName,
    required this.defaultModelNames,
    required this.caps,
    this.apiKey,
    this.baseUrl,
    this.apiKeyName,
    this.aliases = const [],
  });

  /// The canonical provider name (e.g., 'openai', 'ollama').
  final String name;

  /// Alternative names for lookup (e.g., 'claude' => 'anthropic').
  final List<String> aliases;

  /// Human-readable name for display.
  final String displayName;

  /// The default model for this provider.
  final Map<ModelKind, String> defaultModelNames;

  /// The API key for this provider.
  final String? apiKey;

  /// The default API endpoint for this provider.
  final Uri? baseUrl;

  /// The environment variable for the API key (if any).
  final String? apiKeyName;

  /// The capabilities of this provider.
  final Set<ProviderCaps> caps;

  /// Returns all available models for this provider.
  ///
  /// Implementations may or may not cache results. If your application requires
  /// caching, you should implement it yourself rather than relying on the
  /// provider.
  Stream<ModelInfo> listModels();

  /// Creates a chat model instance for this provider.
  ChatModel<TChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    String? systemPrompt,
    TChatOptions? options,
  });

  /// Creates an embeddings model instance for this provider.
  EmbeddingsModel<TEmbeddingsOptions> createEmbeddingsModel({
    String? name,
    TEmbeddingsOptions? options,
  });

  /// OpenAI provider (cloud, OpenAI API).
  static final openai = OpenAIProvider();

  /// OpenRouter provider (OpenAI-compatible, multi-model cloud).
  static final openrouter = OpenAIProvider(
    name: 'openrouter',
    displayName: 'OpenRouter',
    defaultModelNames: {ModelKind.chat: 'google/gemini-2.0-flash'},
    baseUrl: Uri.parse('https://openrouter.ai/api/v1'),
    apiKeyName: 'OPENROUTER_API_KEY',
    caps: {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.vision,
    },
  );

  /// Together AI provider (OpenAI-compatible, cloud).
  ///
  /// - Note: Tool support is disabled because Together's streaming API returns
  ///   tool calls in a custom format with `<|python_tag|>` prefix instead of
  ///   the standard OpenAI tool_calls format while streaming.
  /// - TODO: perhaps move to non-streaming?
  static final together = OpenAIProvider(
    name: 'together',
    displayName: 'Together AI',
    defaultModelNames: {
      ModelKind.chat: 'meta-llama/Llama-3.2-3B-Instruct-Turbo',
    },
    baseUrl: Uri.parse('https://api.together.xyz/v1'),
    apiKeyName: 'TOGETHER_API_KEY',
    caps: {ProviderCaps.chat, ProviderCaps.typedOutput, ProviderCaps.vision},
  );

  /// Mistral AI provider (native API, cloud).
  static final mistral = MistralProvider();

  /// Cohere provider (OpenAI-compatible, cloud).
  static final cohere = CohereProvider();

  /// Lambda provider (OpenAI-compatible, cloud).
  static final lambda = OpenAIProvider(
    name: 'lambda',
    displayName: 'Lambda',
    defaultModelNames: {ModelKind.chat: 'hermes-3-llama-3.1-405b-fp8'},
    baseUrl: Uri.parse('https://api.lambda.ai/v1'),
    apiKeyName: 'LAMBDA_API_KEY',
    caps: {ProviderCaps.chat, ProviderCaps.typedOutput, ProviderCaps.vision},
  );

  /// Gemini (OpenAI-compatible) provider (Google AI, OpenAI API).
  static final googleOpenAI = OpenAIProvider(
    name: 'google-openai',
    displayName: 'Google AI (OpenAI-compatible)',
    defaultModelNames: {ModelKind.chat: 'gemini-2.0-flash'},
    baseUrl: Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/openai',
    ),
    apiKeyName: GoogleProvider.defaultApiKeyName,
    caps: {
      ProviderCaps.chat,
      ProviderCaps.embeddings,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.vision,
    },
  );

  /// Google Gemini native provider (uses Gemini API, not OpenAI-compatible).
  static final google = GoogleProvider();

  /// Anthropic provider (Claude, native API).
  static final anthropic = AnthropicProvider();

  /// Native Ollama provider (local, uses ChatOllama and /api endpoint). No API
  /// key required. Vision models like llava are available.
  static final ollama = OllamaProvider();

  /// OpenAI-compatible Ollama provider (local, uses /v1 endpoint). No API key
  /// required. Vision models like llava are available.
  static final ollamaOpenAI = OpenAIProvider(
    name: 'ollama-openai',
    displayName: 'Ollama (OpenAI-compatible)',
    defaultModelNames: {ModelKind.chat: 'llama3.2'},
    baseUrl: Uri.parse('http://localhost:11434/v1'),
    apiKeyName: null,
    caps: {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.vision,
    },
  );

  /// Returns a list of all available providers (static fields above).
  ///
  /// Use this to iterate or display all providers in a UI.
  /// NOTE: Filters out duplicate providers by alias.
  static List<Provider> get all => providerMap.entries
      .where((e) => !e.value.aliases.contains(e.key))
      .map((e) => e.value)
      .toList();

  /// Returns all providers that have the specified capabilities.
  static List<Provider> allWith(Set<ProviderCaps> caps) =>
      all.where((p) => p.caps.containsAll(caps)).toList();

  static final _providerMap = <String, Provider>{};
  static final _intrinsicProviders = <Provider>[
    openai,
    openrouter,
    together,
    mistral,
    cohere,
    lambda,
    google,
    googleOpenAI,
    anthropic,
    ollama,
    ollamaOpenAI,
  ];

  /// Returns a map of all providers by name or alias.
  /// Extensible at runtime by adding to your own [Provider] subclass.
  static Map<String, Provider> get providerMap {
    if (_providerMap.isEmpty) {
      for (final provider in _intrinsicProviders) {
        final providerName = provider.name.toLowerCase();
        assert(
          !_providerMap.containsKey(providerName),
          'Provider $providerName is already in use',
        );
        _providerMap[providerName] = provider;
        for (final alias in provider.aliases) {
          final providerAlias = alias.toLowerCase();
          assert(
            !_providerMap.containsKey(providerAlias),
            'Provider alias $providerAlias is already in use',
          );
          _providerMap[providerAlias] = provider;
        }
      }
    }

    return _providerMap;
  }

  /// Looks up a provider by name or alias (case-insensitive). Throws if not
  /// found.
  static Provider forName(String name) {
    final providerName = name.toLowerCase();
    final provider = providerMap[providerName];
    if (provider == null) throw Exception('Provider $providerName not found');
    return provider;
  }
}
