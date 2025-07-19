# Agent Configuration Specification

This document specifies how API keys and base URLs are resolved in the
langchain_compat (dartantic 1.0) package, including the precedence hierarchy and
interaction between different configuration methods.

## Overview

The Agent configuration system follows a clear architectural principle: **Agents
are configured with providers, and providers manage their own API keys and base
URLs**. This separation of concerns ensures that:

1. Agents focus on orchestration and tool execution
2. Providers handle authentication and endpoint configuration
3. Models inherit configuration from their providers

Agents can be created with either:
- A provider name string (e.g., `'openai'` or `'openai:gpt-4'`)
- A provider instance (e.g., a custom `OpenAIChatProvider` with specific
  configuration)

## API Key Resolution Hierarchy

API keys are resolved at the provider level, not the agent level. The resolution
order is:

1. **Provider Instance apiKey Property**
   ```dart
   final provider = OpenAIChatProvider(
     apiKey: 'sk-provider-key',
     // ... other required params
   );
   // This takes precedence over environment variables
   ```

2. **Agent.environment Map**
   ```dart
   Agent.environment['OPENAI_API_KEY'] = 'sk-env-map-key';
   Agent('openai:gpt-4')
   ```

3. **System Environment Variable (via Platform.environment)**
   ```dart
   // If OPENAI_API_KEY is set in system environment
   Agent('openai:gpt-4')
   ```

4. **No API Key**
   - Some providers (like Ollama) don't require API keys
   - If a required API key is not found, an exception is thrown

### Resolution Flow

```
Agent Creation
    │
    ├── Using provider name? ──> Look up provider by name
    │                            (e.g. Agent('openai'))
    │
    └── Using provider instance? ──> Use existing provider instance
                                     (e.g. Agent.forProvider(ChatProvider.openai))
                    ↓
Provider.createModel()
    │
    ├── Provider has apiKeyName? ──Yes──> Pass: provider.apiKey ?? tryGetEnv(apiKeyName) -- may be null
    │                               No
    │                               ↓
    ├── Pass: provider.apiKey (may be null)
    └── Pass: provider.baseUrl ?? defaultBaseUrl (may be null)
                    ↓
Model Constructor
    │
    ├── apiKey provided? ──Yes──> Use it
    │                      No
    │                      ↓
    └── Model calls getEnv(Model.apiKeyName)
            │
            ├── Agent.environment[apiKeyName]? ──Yes──> Use it
            │                                      No
            │                                      ↓
            └── Platform.environment[apiKeyName]? ──Yes──> Use it
                                                    No
                                                    ↓
                                              Throw if required
```

## Base URL Resolution Hierarchy

Base URLs are resolved at the provider level, following the same principle as
API keys:

1. **Provider Constructor Parameter**
   ```dart
   final provider = OpenAIChatProvider(
     baseUrl: Uri.parse('https://custom.api.com'),
     // ... other required params
   );
   ```

2. **Provider's defaultBaseUrl**
   ```dart
   // Each provider has a defaultBaseUrl
   // e.g., OpenAI: 'https://api.openai.com/v1'
   Agent('openai:gpt-4')
   ```

3. **Model's defaultBaseUrl constant**
   ```dart
   // Each model class defines its own default
   // e.g., OpenAIChatModel.defaultBaseUrl
   ```

### Resolution Flow

```
Provider.createModel()
    │
    ├── Provider.baseUrl? ──Yes──> Pass to model
    │                        No
    │                        ↓
    └── Provider.defaultBaseUrl ──────> Pass to model
                    ↓
Model Constructor
    │
    └── Uses baseUrl ?? Model.defaultBaseUrl
```

## Provider Configuration

Each provider has its own configuration that defines:

### 1. Provider Properties

- **`name`**: The canonical provider name (e.g., 'openai', 'anthropic')
- **`aliases`**: Alternative names for the provider (e.g., 'claude' for
  Anthropic)
- **`displayName`**: Human-readable name for UI display
- **`defaultModelName`**: The default model to use if none specified
- **`defaultBaseUrl`**: The default API endpoint (nullable - some providers like
  custom ones may not have a default)
- **`apiKeyName`**: The environment variable name for the API key (nullable -
  some providers like Ollama don't need API keys)
- **`caps`**: Set of capabilities (chat, embeddings, vision, etc.)

### 2. Provider Examples

#### Providers with API Keys and Base URLs
```dart
// Static instance with defaults
static final openai = OpenAIChatProvider(
  name: 'openai',
  displayName: 'OpenAI',
  defaultModelName: 'gpt-4o-mini',
  apiKeyName: 'OPENAI_API_KEY',
  caps: {ProviderCaps.chat, ProviderCaps.multiToolCalls, ...},
);

// Custom instance with overrides
final customOpenai = OpenAIChatProvider(
  name: 'openai',
  displayName: 'OpenAI',
  defaultModelName: 'gpt-4o-mini',
  apiKeyName: 'OPENAI_API_KEY',
  apiKey: 'sk-custom-key',  // Override API key
  baseUrl: Uri.parse('https://proxy.company.com/v1'),  // Override base URL
  caps: {ProviderCaps.chat, ProviderCaps.multiToolCalls, ...},
);
```

#### Providers without API Keys (Local)
```dart
static final ollama = OllamaChatProvider(
  name: 'ollama',
  displayName: 'Ollama',
  defaultModelName: 'llama3.2',
  apiKeyName: null,  // No API key needed
  caps: {ProviderCaps.chat, ProviderCaps.vision, ...},
);

// Custom Ollama instance with different base URL
final customOllama = OllamaChatProvider(
  name: 'ollama',
  displayName: 'Ollama',
  defaultModelName: 'llama3.2',
  baseUrl: Uri.parse('http://remote-server:11434/api'),  // Override base URL
  caps: {ProviderCaps.chat, ProviderCaps.vision, ...},
);
```

#### Custom Providers (Minimal Configuration)
```dart
class EchoProvider extends ChatProvider<EchoModelOptions> {
  @override
  String? get apiKeyName => null;  // No API key
  
  @override
  Uri? get defaultBaseUrl => null;  // No default URL
  
  @override
  String get defaultModelName => 'echo';
}
```

### 3. Provider Resolution Flow

When creating a model through a provider:

```
provider.createModel(name: modelName, ...)
                           ↓
         Provider resolves API key:
         - If provider.apiKeyName exists:
           apiKey = provider.apiKey ?? tryGetEnv(provider.apiKeyName)
         - Otherwise:
           apiKey = provider.apiKey
                           ↓
         Pass to Model Constructor:
         - apiKey: resolved API key (may still be null)
         - baseUrl: provider.baseUrl ?? provider.defaultBaseUrl
                           ↓
                    Model Constructor
                           ↓
         Model may do additional resolution:
         - Uses provided apiKey if not null
         - Otherwise calls getEnv(apiKeyName) as fallback
```

Note: The `createModel` method no longer accepts `apiKey` or `baseUrl`
parameters. These are now set at the provider level through the constructor.

### 4. Provider Discovery

Providers can be discovered by:
- **Name**: `ChatProvider.forName('openai')`
- **Alias**: `ChatProvider.forName('claude')` → resolves to Anthropic
- **Capabilities**: `ChatProvider.allWith({ProviderCaps.vision})`
- **All Providers**: `ChatProvider.all`

### 5. Provider-Specific Environment Variables

Each provider defines its own environment variable for API keys:

| Provider | apiKeyName | Example |
|----------|------------|---------|
| OpenAI | `OPENAI_API_KEY` | `sk-...` |
| Anthropic | `ANTHROPIC_API_KEY` | `sk-ant-...` |
| Google | `GEMINI_API_KEY` | `...` |
| Mistral | `MISTRAL_API_KEY` | `...` |
| Cohere | `COHERE_API_KEY` | `...` |
| OpenRouter | `OPENROUTER_API_KEY` | `sk-or-...` |
| Together | `TOGETHER_API_KEY` | `...` |
| Lambda | `LAMBDA_API_KEY` | `...` |
| Ollama | `null` | No API key needed |

## Interaction Rules

### 1. Provider Instance Takes Precedence

When using a custom provider instance with an apiKey or baseUrl set, it
overrides all other sources:

```dart
// Provider's apiKey takes precedence over Agent.environment
Agent.environment['OPENAI_API_KEY'] = 'sk-env-key';
final provider = OpenAIChatProvider(
  apiKey: 'sk-provider-key',
  // ... other params
);
final model = provider.createModel(); // Uses 'sk-provider-key'
```

### 2. Agent.environment vs System Environment

`Agent.environment` takes precedence over system environment variables when
looked up via `tryGetEnv`:

```dart
// System env: OPENAI_API_KEY=sk-system-key
Agent.environment['OPENAI_API_KEY'] = 'sk-agent-env-key';
final agent = Agent('openai'); // Uses 'sk-agent-env-key'
```

However, provider instance apiKey takes precedence over both:

```dart
// System env: OPENAI_API_KEY=sk-system-key
Agent.environment['OPENAI_API_KEY'] = 'sk-agent-env-key';
final provider = OpenAIChatProvider(
  apiKey: 'sk-provider-key',
  // ... other params
);
// Uses 'sk-provider-key', ignoring both environment sources
```

### 3. Provider-Specific Resolution

Each provider may have different apiKeyName values:

```dart
// OpenAI looks for OPENAI_API_KEY
// Anthropic looks for ANTHROPIC_API_KEY
// Mistral looks for MISTRAL_API_KEY
```

### 4. Empty String Handling

Empty strings in provider configuration are treated as "not provided":

```dart
final provider = OpenAIChatProvider(
  apiKey: '', // Will fall back to environment lookup
  // ... other params
);
```

### 5. Null vs Missing

Null values are treated the same as missing parameters:

```dart
final provider = OpenAIChatProvider(
  apiKey: null, // Same as not providing apiKey
  // ... other params
);
```

## Cross-Platform Behavior

### Web Platform
- Only `Agent.environment` is available (no system environment)
- Must use `Agent.environment` or direct parameters

### Native Platforms (iOS, Android, Desktop)
- Both `Agent.environment` and system environment available
- System environment accessed via `Platform.environment`

## Error Handling

### Missing Required API Key
```dart
// Throws: Exception('Environment variable OPENAI_API_KEY is not set')
Agent('openai') // When no API key is available
```

### Invalid API Key Format
- No validation at configuration time
- Errors occur during API calls

## Provider Implementation Requirements

### ChatProvider
Must resolve apiKey using tryGetEnv if apiKeyName is defined:

```dart
ChatModel<TOptions> createModel({
  String? name,
  List<Tool>? tools,
  double? temperature,
  String? systemPrompt,
  TOptions? options,
}) {
  // Provider resolves API key if it has an apiKeyName
  final resolvedApiKey = apiKey ?? 
    (apiKeyName != null ? tryGetEnv(apiKeyName) : null);
  
  return ConcreteModel(
    apiKey: resolvedApiKey,  // Pass resolved API key (may still be null)
    baseUrl: baseUrl ?? defaultBaseUrl,  // Use provider's baseUrl or default
    // ...
  );
}
```

### EmbeddingsProvider
Same pattern applies for embeddings providers:

```dart
EmbeddingsModel<TOptions> createModel({
  String? name,
  TOptions? options,
}) {
  // Provider resolves API key if it has an apiKeyName
  final resolvedApiKey = apiKey ?? 
    (apiKeyName != null ? tryGetEnv(apiKeyName) : null);
  
  return ConcreteEmbeddingsModel(
    apiKey: resolvedApiKey,  // Pass resolved API key
    baseUrl: baseUrl ?? defaultBaseUrl,  // Use provider's baseUrl or default
    // ...
  );
}
```

### Model Implementation
Must accept configuration and resolve API key from environment if needed:

```dart
class ConcreteModel {
  static const String apiKeyName = 'OPENAI_API_KEY';  // Model-specific constant
  static const Uri defaultBaseUrl = Uri.parse('https://api.openai.com/v1');
  
  ConcreteModel({
    String? apiKey,
    Uri? baseUrl,
    // ...
  }) : _apiKey = apiKey ?? getEnv(apiKeyName),  // Model calls getEnv if no apiKey provided
       _baseUrl = baseUrl ?? defaultBaseUrl;
}
```

The model is responsible for:
1. Defining its own `apiKeyName` constant
2. Calling `getEnv(apiKeyName)` when no API key is provided
3. Throwing an exception if a required API key is not found

## Examples

### Example 1: Using Provider Name with Environment
```dart
Agent.environment['OPENAI_API_KEY'] = 'sk-env-456';
final agent = Agent('openai:gpt-4');
// Uses: apiKey='sk-env-456', baseUrl='https://api.openai.com/v1'
```

### Example 2: Using Custom Provider Instance
```dart
// Create a custom provider with specific configuration
final provider = OpenAIChatProvider(
  name: 'openai',
  displayName: 'OpenAI',
  defaultModelName: 'gpt-4o-mini',
  apiKeyName: 'OPENAI_API_KEY',
  apiKey: 'sk-custom-key',
  baseUrl: Uri.parse('https://proxy.company.com/v1'),
  caps: ChatProvider.openai.caps,
);

final agent = Agent.forProvider(provider);
// Uses: apiKey='sk-custom-key', baseUrl='https://proxy.company.com/v1'
```

### Example 3: Mixed Configuration
```dart
// Provider instance with custom baseUrl, apiKey from environment
Agent.environment['OPENAI_API_KEY'] = 'sk-env-789';

final provider = OpenAIChatProvider(
  name: 'openai',
  displayName: 'OpenAI',
  defaultModelName: 'gpt-4o-mini',
  apiKeyName: 'OPENAI_API_KEY',
  baseUrl: Uri.parse('https://custom.api.com'),
  caps: ChatProvider.openai.caps,
);

final agent = Agent.forProvider(provider);
// Uses: apiKey='sk-env-789' (from environment), baseUrl='https://custom.api.com'
```

### Example 4: Provider-Level Override
```dart
// Create a custom provider instance with overrides
final provider = OpenAIChatProvider(
  name: 'openai',
  displayName: 'OpenAI',
  defaultModelName: 'gpt-4o-mini',
  apiKeyName: 'OPENAI_API_KEY',
  apiKey: 'sk-provider-key',  // Override API key
  baseUrl: Uri.parse('https://provider.api.com'),  // Override base URL
  caps: ChatProvider.openai.caps,
);

final model = provider.createModel();
// Uses: apiKey='sk-provider-key', baseUrl='https://provider.api.com'
```

### Example 5: ListModels with Provider Overrides
```dart
// Create provider with custom API key and base URL
final provider = OpenAIChatProvider(
  name: 'openai',
  displayName: 'OpenAI',
  defaultModelName: 'gpt-4o-mini',
  apiKeyName: 'OPENAI_API_KEY',
  apiKey: 'sk-custom-key',
  baseUrl: Uri.parse('https://custom.api.com'),
  caps: ChatProvider.openai.caps,
);

// List models will use the provider's apiKey and baseUrl
final models = await provider.listModels();
```

## Testing Requirements

Tests must verify:
1. Each level of the precedence hierarchy
2. Interaction between different configuration methods
3. Cross-platform behavior differences
4. Error cases for missing required configuration
5. Empty string and null handling
6. Provider-specific apiKeyName resolution
7. Agent creation with provider names vs provider instances

## Design Principles

### Separation of Concerns

1. **Agents** handle:
   - Tool orchestration and execution
   - Message streaming and formatting
   - Conversation flow management

2. **Providers** handle:
   - API key management (including environment lookup via tryGetEnv)
   - Base URL configuration
   - Model creation and configuration
   - Provider-specific capabilities

3. **Models** handle:
   - API key resolution from environment when not provided
   - Direct API communication
   - Request/response formatting
   - Provider-specific protocol implementation

### Configuration Best Practices

1. **For production use**: Create custom provider instances with explicit
   configuration
2. **For development**: Use environment variables with static provider instances
3. **For testing**: Use Agent.environment to avoid system environment
   dependencies
4. **For multi-tenant**: Create separate provider instances per tenant with
   different API keys