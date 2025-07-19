# Agent Configuration Specification

This document specifies how API keys and base URLs are resolved in the
langchain_compat (dartantic 1.0) package, including the precedence hierarchy and
interaction between different configuration methods.

## Overview

The Agent configuration system supports multiple ways to specify API keys and
base URLs, with a clear precedence hierarchy that allows for maximum flexibility
while maintaining backward compatibility with the original dartantic API.

## API Key Resolution Hierarchy

API keys are resolved in the following order of precedence (highest to lowest):

1. **Direct Agent Constructor Parameter**
   ```dart
   Agent('openai:gpt-4', apiKey: 'sk-direct-key')
   ```

2. **Agent.environment Map**
   ```dart
   Agent.environment['OPENAI_API_KEY'] = 'sk-env-map-key';
   Agent('openai:gpt-4')
   ```

3. **Direct Provider.createModel Parameter**
   ```dart
   ChatProvider.openai.createModel(apiKey: 'sk-provider-key')
   ```

4. **System Environment Variable (via provider's apiKeyName)**
   ```dart
   // If OPENAI_API_KEY is set in system environment
   Agent('openai:gpt-4')
   ```

5. **No API Key**
   - Some providers (like Ollama) don't require API keys
   - If a required API key is not found, an exception is thrown

### Resolution Flow

```
Agent Constructor
    │
    ├── Has apiKey parameter? ──Yes──> Use it
    │                            No
    │                            ↓
    └── Agent.environment[apiKeyName]? ──Yes──> Use it
                                          No
                                          ↓
                                    Platform.environment[apiKeyName]? ──Yes──> Use it
                                                                        No
                                                                        ↓
                                                                  Throw if required
```

## Base URL Resolution Hierarchy

Base URLs are resolved in the following order of precedence (highest to lowest):

1. **Direct Agent Constructor Parameter**
   ```dart
   Agent('openai:gpt-4', baseUrl: Uri.parse('https://custom.api.com'))
   ```

2. **Direct Provider.createModel Parameter**
   ```dart
   ChatProvider.openai.createModel(baseUrl: Uri.parse('https://custom.api.com'))
   ```

3. **Provider's defaultBaseUrl**
   ```dart
   // Each provider has a defaultBaseUrl
   // e.g., OpenAI: 'https://api.openai.com/v1'
   Agent('openai:gpt-4')
   ```

4. **Model's defaultBaseUrl constant**
   ```dart
   // Each model class defines its own default
   // e.g., OpenAIChatModel.defaultBaseUrl
   ```

### Resolution Flow

```
Agent Constructor
    │
    ├── Has baseUrl parameter? ──Yes──> Use it
    │                            No
    │                            ↓
    └── Provider.defaultBaseUrl ──────> Use it
```

## Provider Configuration

Each provider has its own configuration that defines:

### 1. Provider Properties

- **`name`**: The canonical provider name (e.g., 'openai', 'anthropic')
- **`aliases`**: Alternative names for the provider (e.g., 'claude' for Anthropic)
- **`displayName`**: Human-readable name for UI display
- **`defaultModelName`**: The default model to use if none specified
- **`defaultBaseUrl`**: The default API endpoint (nullable - some providers like custom ones may not have a default)
- **`apiKeyName`**: The environment variable name for the API key (nullable - some providers like Ollama don't need API keys)
- **`caps`**: Set of capabilities (chat, embeddings, vision, etc.)

### 2. Provider Examples

#### Providers with API Keys and Base URLs
```dart
static final openai = OpenAIChatProvider(
  name: 'openai',
  displayName: 'OpenAI',
  defaultModelName: 'gpt-4o-mini',
  defaultBaseUrl: Uri.parse('https://api.openai.com/v1'),
  apiKeyName: 'OPENAI_API_KEY',
  caps: {ProviderCaps.chat, ProviderCaps.multiToolCalls, ...},
);
```

#### Providers without API Keys (Local)
```dart
static final ollama = OllamaChatProvider(
  name: 'ollama',
  displayName: 'Ollama',
  defaultModelName: 'llama3.2',
  defaultBaseUrl: Uri.parse('http://localhost:11434/api'),
  apiKeyName: null,  // No API key needed
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
provider.createModel(apiKey: X, baseUrl: Y)
                           ↓
         API Key: X ?? tryGetEnv(provider.apiKeyName)
         Base URL: Y ?? provider.defaultBaseUrl
                           ↓
                    Create Model Instance
```

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

### 1. Agent Constructor Takes Precedence

When API key or base URL is specified at the Agent level, it overrides all other
sources:

```dart
// This will use 'sk-agent-key' regardless of environment variables
Agent.environment['OPENAI_API_KEY'] = 'sk-env-key';
final agent = Agent('openai', apiKey: 'sk-agent-key');
```

### 2. Agent.environment vs System Environment

`Agent.environment` takes precedence over system environment variables:

```dart
// System env: OPENAI_API_KEY=sk-system-key
Agent.environment['OPENAI_API_KEY'] = 'sk-agent-env-key';
final agent = Agent('openai'); // Uses 'sk-agent-env-key'
```

### 3. Provider-Specific Resolution

Each provider may have different apiKeyName values:

```dart
// OpenAI looks for OPENAI_API_KEY
// Anthropic looks for ANTHROPIC_API_KEY
// Mistral looks for MISTRAL_API_KEY
```

### 4. Empty String Handling

Empty strings are treated as "not provided":

```dart
Agent('openai', apiKey: '') // Will fall back to environment lookup
```

### 5. Null vs Missing

Null values are treated the same as missing parameters:

```dart
Agent('openai', apiKey: null) // Same as Agent('openai')
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
Must pass through apiKey and baseUrl to model:

```dart
ChatModel<TOptions> createModel({
  String? apiKey,
  Uri? baseUrl,
  // ... other parameters
}) {
  return ConcreteModel(
    apiKey: apiKey ?? tryGetEnv(apiKeyName),
    baseUrl: baseUrl ?? defaultBaseUrl,
    // ...
  );
}
```

### Model Implementation
Must accept and use provided values:

```dart
class ConcreteModel {
  ConcreteModel({
    String? apiKey,
    Uri? baseUrl,
    // ...
  }) : _apiKey = apiKey ?? getEnv(apiKeyName),
       _baseUrl = baseUrl ?? defaultBaseUrl;
}
```

## Examples

### Example 1: Direct Configuration
```dart
final agent = Agent(
  'openai:gpt-4',
  apiKey: 'sk-123',
  baseUrl: Uri.parse('https://proxy.company.com/v1'),
);
// Uses: apiKey='sk-123', baseUrl='https://proxy.company.com/v1'
```

### Example 2: Environment Fallback
```dart
Agent.environment['OPENAI_API_KEY'] = 'sk-env-456';
final agent = Agent('openai:gpt-4');
// Uses: apiKey='sk-env-456', baseUrl='https://api.openai.com/v1'
```

### Example 3: Mixed Configuration
```dart
Agent.environment['OPENAI_API_KEY'] = 'sk-env-789';
final agent = Agent(
  'openai:gpt-4',
  baseUrl: Uri.parse('https://custom.api.com'),
);
// Uses: apiKey='sk-env-789', baseUrl='https://custom.api.com'
```

### Example 4: Provider-Level Override
```dart
final provider = ChatProvider.openai;
final model = provider.createModel(
  apiKey: 'sk-provider-key',
  baseUrl: Uri.parse('https://provider.api.com'),
);
// Uses: apiKey='sk-provider-key', baseUrl='https://provider.api.com'
```

## Testing Requirements

Tests must verify:
1. Each level of the precedence hierarchy
2. Interaction between different configuration methods
3. Cross-platform behavior differences
4. Error cases for missing required configuration
5. Empty string and null handling
6. Provider-specific apiKeyName resolution