# Migration Specification: langchain_compat to dartantic_ai 1.0

## Overview
This document tracks the migration from the langchain_compat library architecture to the cleaner dartantic_ai 1.0 API.

## ✅ Completed Changes

### 1. Agent Class Enhancement
- [x] The `Agent` class now supports both chat and embeddings operations
- [x] Agent methods renamed: `run()` → `send()`, `runFor()` → `sendFor()`, `runStream()` → `sendStream()`
- [x] Added embeddings support: `embedQuery()` and `embedDocuments()`

### 2. Global Services
- [x] Moved `Agent.environment` for environment variables (replaced top-level `Dartantic` object)
- [x] Moved `Agent.loggingOptions` for logging configuration
- [x] Removed the top-level `Dartantic` object entirely

### 3. Unified Provider Architecture

#### Provider Base Class
- [x] Renamed `ChatProvider` to `Provider`
- [x] Renamed `createModel` to `createChatModel`
- [x] Added `createEmbeddingsModel` method
- [x] Moved from `String defaultModelName` to `Map<ModelKind, String> defaultModelNames`
- [x] Removed separate `EmbeddingsProvider` type

#### Provider Implementation
- [x] All providers extend the base `Provider` class
- [x] Providers implement both `createChatModel` and `createEmbeddingsModel` (throw `UnsupportedError` if not supported)
- [x] Single static instance per provider in `Provider` class (e.g., `Provider.openai`)
- [x] Providers handle API key resolution via environment

### 4. Model String Parser
- [x] Created `ModelStringParser` supporting multiple formats:
  - Simple format: `"provider"` (uses defaults)
  - Legacy format: `"provider:chatModel"`
  - Slash format: `"provider/chatModel"`
  - URI format: `"provider?chat=gpt-4&embeddings=text-embedding-3"`

### 5. Agent Model Creation
- [x] Agent parses model string using `ModelStringParser`
- [x] Gets provider using `Provider.forName()`
- [x] Lazily creates models using provider methods
- [x] Passes tools, temperature, and systemPrompt appropriately

### 6. API Key and Base URL Handling
- [x] Models take non-null API keys (when required) or no API key parameter (for local models)
- [x] Providers handle API key resolution from environment
- [x] Models take nullable baseUrl and pass directly to underlying API

## Architectural Implementation

### Separation of Concerns (Implemented)

1. **Agent** - Orchestrates tool execution, manages conversation state
   - ✅ Does NOT handle API keys or base URLs
   - ✅ Only knows about model specifications and tool orchestration

2. **Provider** - Factory for models, handles configuration
   - ✅ Resolves API keys from environment variables
   - ✅ Handles default base URLs and overrides
   - ✅ Throws if required API keys are missing
   - ✅ Creates models with all required configuration

3. **Model** - Direct interface to the LLM API
   - ✅ Takes non-null, non-empty API key for models that require them
   - ✅ Takes NO API key parameter for models that don't need them (e.g., Ollama)
   - ✅ Takes nullable baseUrl parameter
   - ✅ Underlying API knows its own default base URL

## Current Implementation Status

### Working Examples

All example applications in `example/bin/` demonstrate the new architecture:
- `agent.dart` - Shows basic Agent usage with tools
- `chat.dart` - Simple chat interactions
- `embeddings.dart` - Unified embeddings support through Agent
- `model_string.dart` - Various model string formats
- `typed_output.dart` - Structured output with JSON schemas
- `multi_provider.dart` - Cross-provider usage

### Provider Support

| Provider | Chat | Embeddings | Status |
|----------|------|------------|---------|
| OpenAI | ✅ | ✅ | Fully implemented |
| Google | ✅ | ✅ | Fully implemented |
| Anthropic | ✅ | ❌ | Chat only (no embeddings API) |
| Mistral | ✅ | ✅ | Fully implemented |
| Cohere | ✅ | ✅ | Fully implemented |
| Ollama | ✅ | ❌ | Chat only (native API) |
| OpenRouter | ✅ | ❌ | Chat only |
| Together | ✅ | ❌ | Chat only |

### Key Implementation Files

1. **Agent**: `lib/src/agent/agent.dart`
   - Unified chat and embeddings operations
   - Model string parsing
   - Provider lookup

2. **Provider Base**: `lib/src/providers/provider.dart`
   - Base Provider class
   - Static provider registry
   - Provider discovery methods

3. **Model String Parser**: `lib/src/agent/model_string_parser.dart`
   - URI-based parsing
   - Legacy format support
   - String building

4. **Provider Implementations**: `lib/src/providers/`
   - OpenAI, Google, Anthropic, Mistral, Cohere, Ollama, etc.
   - Each implements the unified Provider interface

## Migration Guide

### For Users

#### Basic Usage
```dart
// OLD: Separate chat and embeddings
final chat = ChatOpenAI(apiKey: 'sk-...');
final embeddings = OpenAIEmbeddings(apiKey: 'sk-...');

// NEW: Unified Agent
final agent = Agent('openai');
await agent.send('Hello!');
await agent.embedQuery('test text');
```

#### Model String Formats
```dart
// All of these are supported:
Agent('openai')                                    // Uses defaults
Agent('openai:gpt-4')                             // Legacy format
Agent('openai/gpt-4')                             // Slash format
Agent('openai?chat=gpt-4&embeddings=ada')         // URI format
```

#### Custom Configuration
```dart
// OLD: Direct model configuration
final model = ChatOpenAI(
  apiKey: 'sk-custom',
  baseUrl: 'https://proxy.com',
);

// NEW: Provider-based configuration
final provider = OpenAIProvider(
  apiKey: 'sk-custom',
  baseUrl: Uri.parse('https://proxy.com'),
);
final agent = Agent.forProvider(provider);
```

### For Provider Implementers

To create a new provider:
1. Extend `Provider<TChatOptions, TEmbeddingsOptions>` with appropriate option types
2. Define provider metadata (name, displayName, defaultModelNames, capabilities)
3. Implement factory methods for chat and embeddings models
4. Add static instance to Provider registry

See existing provider implementations in `lib/src/providers/` for patterns and examples.

## Next Steps

### Documentation Updates
- [ ] Update all documentation to use new Agent API
- [ ] Create migration guide for users
- [ ] Update provider implementation guide

### Testing
- [ ] Ensure all tests use new architecture
- [ ] Add integration tests for embeddings
- [ ] Test all model string formats

### Final Cleanup
- [ ] Remove deprecated APIs
- [ ] Update package version to 1.0.0
- [ ] Publish dartantic_ai package

## Related Specifications

For detailed information about specific aspects of the architecture:

1. **[Agent Configuration Specification](./AGENT_CONFIG_SPEC.md)**
   - API key and base URL resolution
   - Environment variable handling
   - Provider configuration patterns

2. **[Model Configuration Specification](./MODEL_CONFIGURATION_SPEC.md)**
   - Model string format details
   - Provider default models
   - Model naming conventions

3. **[Unified Provider Architecture](./UNIFIED_PROVIDER_ARCHITECTURE.md)**
   - Architecture overview and design principles
   - Separation of concerns
   - Provider capabilities system

4. **[Provider Implementation Guide](./PROVIDER_IMPLEMENTATION_GUIDE.md)**
   - Concrete implementation patterns
   - Code examples for new providers
   - Testing patterns

## Summary

The migration to dartantic_ai 1.0 is functionally complete. The new architecture provides:

1. **Unified Agent API** - Single interface for chat and embeddings
2. **Clean Provider Architecture** - Consistent pattern across all providers
3. **Flexible Model Specification** - Multiple string formats supported
4. **Clear Separation of Concerns** - Agent, Provider, and Model layers
5. **Capability Discovery** - Easy to find providers by features
6. **Future-Proof Design** - Ready for new model types and capabilities

The implementation successfully maintains backward compatibility while providing a cleaner, more intuitive API for the future. All specifications have been consolidated to eliminate redundancy and provide clear guidance for users and implementers.
