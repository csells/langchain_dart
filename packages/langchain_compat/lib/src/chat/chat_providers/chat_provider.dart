import '../../provider_caps.dart';
import '../chat_models/chat_models.dart';
import '../tools/tool.dart';
import 'chat_providers.dart';

/// Provides a unified interface for accessing all major LLM, chat, and
/// embedding providers in LangChain.dart via a single import. This includes
/// OpenAI, GoogleAI, VertexAI, Anthropic, Mistral, Ollama (native and
/// OpenAI-compatible), and more. Each provider is represented as a static field
/// and can be selected by name or alias using [ChatProvider.providerMap] or
/// iterated via [ChatProvider.all].
///
/// The compat layer ensures all providers are accessible without importing
/// provider-specific packages. All configuration (API keys, base URLs, models)
/// is handled via the provider interface.
abstract class ChatProvider<TOptions extends ChatModelOptions> {
  /// Creates a new provider instance.
  ///
  /// [name]: The canonical provider name (e.g., 'openai', 'ollama').
  /// [displayName]: Human-readable name for display. [defaultModelName]: The
  /// default model for this provider (null means use model's own default).
  /// [defaultBaseUrl]: The default API endpoint. [apiKeyName]: The environment
  /// variable for the API key (if any). [aliases]: Alternative names for
  /// lookup.
  const ChatProvider({
    required this.name,
    required this.displayName,
    required this.defaultModelName,
    required this.caps,
    this.defaultBaseUrl,
    this.apiKeyName,
    this.aliases = const [],
  });

  /// The canonical provider name (e.g., 'openai', 'ollama').
  final String name;

  /// Alternative names for lookup (e.g., 'claude' for Anthropic).
  final List<String> aliases;

  /// Human-readable name for display.
  final String displayName;

  /// The default model for this provider.
  final String defaultModelName;

  /// The default API endpoint for this provider.
  final Uri? defaultBaseUrl;

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
  ChatModel<TOptions> createModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    String? systemPrompt,
    TOptions? options,
    String? apiKey,
    Uri? baseUrl,
  });

  /// OpenAI provider (cloud, OpenAI API).
  static final openai = OpenAIChatProvider(
    name: 'openai',
    displayName: 'OpenAI',
    defaultModelName: OpenAIChatModel.defaultName,
    defaultBaseUrl: OpenAIChatModel.defaultBaseUrl,
    apiKeyName: OpenAIChatModel.apiKeyName,
    caps: {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.typedOutputWithTools,
      ProviderCaps.vision,
    },
  );

  /// OpenRouter provider (OpenAI-compatible, multi-model cloud).
  static final openrouter = OpenAIChatProvider(
    name: 'openrouter',
    displayName: 'OpenRouter',
    defaultModelName: 'google/gemini-2.5-flash',
    defaultBaseUrl: Uri.parse('https://openrouter.ai/api/v1'),
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
  /// Note: Tool support is disabled because Together's streaming API returns
  /// tool calls in a custom format with `<|python_tag|>` prefix instead of the
  /// standard OpenAI tool_calls format. Non-streaming API works correctly but
  /// we prioritize consistent behavior across streaming and non-streaming
  /// modes.
  static final together = OpenAIChatProvider(
    name: 'together',
    displayName: 'Together AI',
    defaultModelName: 'meta-llama/Llama-3.2-3B-Instruct-Turbo',
    defaultBaseUrl: Uri.parse('https://api.together.xyz/v1'),
    apiKeyName: 'TOGETHER_API_KEY',
    caps: {ProviderCaps.chat, ProviderCaps.typedOutput, ProviderCaps.vision},
  );

  /// Mistral AI provider (native API, cloud).
  static final mistral = MistralChatProvider(
    name: 'mistral',
    displayName: 'Mistral AI',
    defaultModelName: MistralChatModel.defaultName,
    defaultBaseUrl: MistralChatModel.defaultBaseUrl,
    apiKeyName: MistralChatModel.apiKeyName,
    caps: {ProviderCaps.chat, ProviderCaps.vision},
  );

  /// Cohere provider (OpenAI-compatible, cloud). Note: streamOptions is
  /// forcibly set to null for compatibility.
  /// Note: Does not support response_format with tools simultaneously.
  static final cohere = CohereChatProvider(
    name: 'cohere',
    displayName: 'Cohere',
    defaultModelName: CohereChatModelConstants.defaultName,
    defaultBaseUrl: CohereChatModelConstants.defaultBaseUrl,
    apiKeyName: CohereChatModelConstants.apiKeyName,
    caps: {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.vision,
    },
  );

  /// Lambda provider (OpenAI-compatible, cloud).
  static final lambda = OpenAIChatProvider(
    name: 'lambda',
    displayName: 'Lambda',
    defaultModelName: 'hermes-3-llama-3.1-405b-fp8',
    defaultBaseUrl: Uri.parse('https://api.lambda.ai/v1'),
    apiKeyName: 'LAMBDA_API_KEY',
    caps: {ProviderCaps.chat, ProviderCaps.typedOutput, ProviderCaps.vision},
  );

  /// Gemini (OpenAI-compatible) provider (Google AI, OpenAI API).
  static final googleOpenAI = OpenAIChatProvider(
    name: 'google-openai',
    displayName: 'Google AI (OpenAI-compatible)',
    defaultModelName: GoogleChatModel.defaultName,
    defaultBaseUrl: Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/openai',
    ),
    apiKeyName: GoogleChatModel.apiKeyName,
    caps: {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.vision,
    },
  );

  /// Google Gemini native provider (uses Gemini API, not OpenAI-compatible).
  static final google = GoogleChatProvider(
    name: 'google',
    aliases: ['gemini', 'googleai', 'google-gla'],
    displayName: 'Google AI',
    defaultModelName: GoogleChatModel.defaultName,
    defaultBaseUrl: GoogleChatModel.defaultBaseUrl,
    apiKeyName: GoogleChatModel.apiKeyName,
    caps: {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.vision,
    },
  );

  /// Anthropic provider (Claude, native API).
  static final anthropic = AnthropicChatProvider(
    name: 'anthropic',
    aliases: ['claude'],
    displayName: 'Anthropic',
    defaultModelName: AnthropicChatModel.defaultName,
    defaultBaseUrl: AnthropicChatModel.defaultBaseUrl,
    apiKeyName: AnthropicChatModel.apiKeyName,
    caps: {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.typedOutputWithTools,
      ProviderCaps.vision,
    },
  );

  /// Native Ollama provider (local, uses ChatOllama and /api endpoint). No API
  /// key required. Vision models like llava are available.
  static final ollama = OllamaChatProvider(
    name: 'ollama',
    displayName: 'Ollama',
    defaultModelName: OllamaChatModel.defaultName,
    defaultBaseUrl: OllamaChatModel.defaultBaseUrl,
    apiKeyName: null,
    caps: {
      ProviderCaps.chat,
      ProviderCaps.multiToolCalls,
      ProviderCaps.typedOutput,
      ProviderCaps.vision,
    },
  );

  /// OpenAI-compatible Ollama provider (local, uses /v1 endpoint). No API key
  /// required. Vision models like llava are available.
  static final ollamaOpenAI = OpenAIChatProvider(
    name: 'ollama-openai',
    displayName: 'Ollama (OpenAI-compatible)',
    defaultModelName: 'llama3.2',
    defaultBaseUrl: Uri.parse('http://localhost:11434/v1'),
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
  static List<ChatProvider> get all => providerMap.entries
      .where((e) => !e.value.aliases.contains(e.key))
      .map((e) => e.value)
      .toList();

  /// Returns all providers that have the specified capabilities.
  static List<ChatProvider> allWith(Set<ProviderCaps> caps) =>
      all.where((p) => p.caps.containsAll(caps)).toList();

  static final _providerMap = <String, ChatProvider>{};
  static final _intrinsicProviders = <ChatProvider>[
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
  /// Extensible at runtime by adding to your own [ChatProvider] subclass.
  static Map<String, ChatProvider> get providerMap {
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
  static ChatProvider forName(String name) {
    final providerName = name.toLowerCase();
    final provider = providerMap[providerName];
    if (provider == null) throw Exception('Provider $providerName not found');
    return provider;
  }
}
