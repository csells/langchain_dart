# Model String Format Specification

This document defines the model string parsing system for dartantic 1.0, including the supported formats and parsing behavior.

## Overview

The `ModelStringParser` class extracts provider, chat model, and embeddings model names from a string input. It supports multiple formats for flexibility and backward compatibility.

## Supported Formats

| Format | Example | Parsed Output |
|--------|---------|---------------|
| **Provider Only** | `providerName` | provider: `providerName`, chat: `null`, embeddings: `null` |
| **Provider + Chat (colon)** | `providerName:chatModelName` | provider: `providerName`, chat: `chatModelName`, embeddings: `null` |
| **Provider + Chat (slash)** | `providerName/chatModelName` | provider: `providerName`, chat: `chatModelName`, embeddings: `null` |
| **Query Parameters** | `providerName?chat=chatModel&embeddings=embeddingsModel` | provider: `providerName`, chat: `chatModel`, embeddings: `embeddingsModel` |

## URI-Based Parsing

The parser leverages Dart's `Uri` class for robust parsing:

```dart
factory ModelStringParser.parse(String model) {
  final uri = Uri.tryParse(model);
  if (uri != null) {
    if (uri.isAbsolute) {
      // Handle provider:model format (colon becomes scheme separator)
      provider = uri.scheme;
      chat = uri.path;
    } else if (uri.pathSegments.length == 1) {
      // Handle provider or provider?params format
      provider = uri.pathSegments.first;
      chat = uri.queryParameters['chat'];
      embeddings = uri.queryParameters['embeddings'];
      other = uri.queryParameters['other'];
    } else if (uri.pathSegments.length == 2) {
      // Handle provider/model format
      provider = uri.pathSegments.first;
      chat = uri.pathSegments.last;
    }
  }
}
```

## String Building

The `toString()` method builds strings based on the components:

```dart
String toString() {
  if (chatModelName == null && embeddingsModelName == null && otherModelName == null) {
    return providerName;  // Simple provider
  }
  
  if (chatModelName != null && embeddingsModelName == null && otherModelName == null) {
    return '$providerName:$chatModelName';  // Legacy format
  }
  
  // Query parameter format for complex cases
  return Uri(
    path: providerName,
    queryParameters: {
      if (chatModelName != null) 'chat': chatModelName,
      if (embeddingsModelName != null) 'embeddings': embeddingsModelName,
      if (otherModelName != null) 'other': otherModelName,
    },
  ).toString();
}
```

## Examples

### Basic Usage

```dart
// Provider only - uses all defaults
final parser1 = ModelStringParser.parse('openai');
// provider: 'openai', chat: null, embeddings: null

// Legacy format with chat model
final parser2 = ModelStringParser.parse('openai:gpt-4o');
// provider: 'openai', chat: 'gpt-4o', embeddings: null

// Slash format
final parser3 = ModelStringParser.parse('openai/gpt-4o');
// provider: 'openai', chat: 'gpt-4o', embeddings: null

// Query parameter format
final parser4 = ModelStringParser.parse('openai?chat=gpt-4o&embeddings=text-embedding-3-small');
// provider: 'openai', chat: 'gpt-4o', embeddings: 'text-embedding-3-small'
```

### Agent Integration

```dart
// Simple provider
final agent1 = Agent('openai');
// Uses default chat and embeddings models

// Specific chat model
final agent2 = Agent('openai:gpt-4o');
// Uses gpt-4o for chat, default for embeddings

// Different models for each operation
final agent3 = Agent('openai?chat=gpt-4o&embeddings=text-embedding-3-large');
// Explicit models for both operations
```

## Edge Cases

| Input | Provider | Chat Model | Embeddings Model |
|-------|----------|------------|------------------|
| `""` (empty) | Throws exception | - | - |
| `"provider:"` | `"provider"` | `null` | `null` |
| `"provider//"` | `"provider"` | `""` | `null` |
| `"provider?chat="` | `"provider"` | `null` | `null` |
| `"provider?chat=&embeddings=ada"` | `"provider"` | `null` | `"ada"` |

## Implementation Notes

1. **Empty strings**: Empty model names (e.g., `chat=`) are treated as `null`
2. **Whitespace**: No automatic trimming - whitespace is preserved
3. **Case sensitivity**: Provider and model names are case-sensitive
4. **Special characters**: URI encoding is handled automatically for query parameters
5. **Future extensibility**: The `other` query parameter supports future model types

## Related Specifications

- [Model Configuration Specification](./MODEL_CONFIGURATION_SPEC.md) - Provider defaults and model resolution
- [Agent Configuration Specification](./AGENT_CONFIG_SPEC.md) - API key and environment configuration
- [Dartantic 1.0 Migration](./DARTANTIC_1.0_MIGRATION_SPEC.md) - Migration guide and examples
