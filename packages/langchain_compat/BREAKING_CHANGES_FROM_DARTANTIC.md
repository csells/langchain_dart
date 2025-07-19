# Breaking Changes: dartantic to langchain_compat (dartantic 1.0)

This document provides a comprehensive list of breaking changes when migrating
from the existing dartantic package to langchain_compat (which will become
dartantic 1.0).

## 1. Import Path Changes **[NOT A BREAKING CHANGE]**

The package will remain as `dartantic_ai` when this code is merged. No import
changes needed.

```dart
import 'package:dartantic_ai/dartantic_ai.dart';  // Same as before
```

## 2. Agent Constructor Changes **[PARTIALLY FIXED]**

### apiKey and baseUrl Parameters **[FIXED]**

The Agent constructor now accepts `apiKey` and `baseUrl` parameters just like
before.

```dart
// Both old and new support these parameters
final agent = Agent(
  'openai:gpt-4o',
  apiKey: 'sk-...',                  // Still supported
  baseUrl: Uri.parse('https://...'), // Still supported
  systemPrompt: 'You are helpful',
  tools: tools,
  temperature: 0.7,
);
```

### Removed Constructor Parameters

The Agent constructor no longer accepts `embeddingModel`, `outputSchema`, or
`outputFromJson` parameters. These have been moved to different locations.

#### Old:
```dart
final agent = Agent(
  'openai:gpt-4o',
  embeddingModel: 'text-embedding-3-small',  // REMOVED from constructor
  systemPrompt: 'You are helpful',
  outputSchema: schema,                       // REMOVED from constructor
  outputFromJson: MyType.fromJson,           // REMOVED from constructor
  tools: tools,
  temperature: 0.7,
);
```

#### New:
```dart
final agent = Agent(
  'openai:gpt-4o',  // Still supports "provider", "provider:model", "provider/model"
  systemPrompt: 'You are helpful',
  tools: tools,
  temperature: 0.7,
  displayName: 'My Agent',  // NEW optional parameter
);

// outputSchema and outputFromJson are now passed to run methods
final result = await agent.runFor<MyType>(
  prompt,
  outputSchema: schema,
  outputFromJson: MyType.fromJson,
);
```

### New Constructor: Agent.forProvider

The `Agent.provider()` constructor has been renamed to `Agent.forProvider()` and
requires explicit model name.

#### Old:
```dart
final agent = Agent.provider(
  provider,
  // model name was optional
);
```

#### New:
```dart
final agent = Agent.forProvider(
  provider,
  modelName: 'gpt-4o',  // Now explicitly required or uses provider default
);
```

## 3. API Key and Base URL Configuration **[FIXED]**

Both API keys and custom base URLs are still supported in the Agent constructor,
just like before. The Agent.environment map also continues to work for
compatibility.

```dart
// All these options still work:

// Option 1: Pass directly
final agent = Agent('openai', apiKey: 'sk-...');

// Option 2: Static environment map
Agent.environment['OPENAI_API_KEY'] = 'sk-...';

// Option 3: Custom base URL
final agent = Agent(
  'openai',
  baseUrl: Uri.parse('https://my-proxy.com/v1'),
);
```

## 4. Run Method Parameter Changes

### Parameter Renamed: messages → history

The `messages` parameter in run methods has been renamed to `history`.

#### Old:
```dart
final response = await agent.run(
  prompt,
  messages: conversationHistory,  // Old parameter name
  attachments: files,
);
```

#### New:
```dart
final result = await agent.run(
  prompt,
  history: conversationHistory,  // New parameter name
  attachments: files,
);
```

### Output Schema Moved to Run Methods

The `outputSchema` parameter has moved from the constructor to the run methods.

#### Old:
```dart
// Schema in constructor
final agent = Agent(model, outputSchema: schema);
final response = await agent.run(prompt);
```

#### New:
```dart
// Schema in run method
final agent = Agent(model);
final result = await agent.run(
  prompt,
  outputSchema: schema,  // Pass here instead
);
```

## 5. Response Type Changes

### AgentResponse → ChatResult

The return type has changed from `AgentResponse` to `ChatResult<String>` with
different properties.

#### Old:
```dart
final response = await agent.run(prompt);
print(response.text);       // Main output text
print(response.messages);   // All messages
// No metadata, usage, or finish reason
```

#### New:
```dart
final result = await agent.run(prompt);
print(result.output);         // Main output (same as old .text)
print(result.messages);       // New messages only
print(result.finishReason);   // Why generation stopped
print(result.usage);          // Token usage stats
print(result.metadata);       // Additional metadata
print(result.id);            // Result ID
```

### Streaming Behavior Change

Streaming now returns incremental chunks instead of accumulated text.

#### Old:
```dart
await for (final response in agent.runStream(prompt)) {
  print(response.text);  // Accumulated text (grows with each chunk)
}
```

#### New:
```dart
await for (final result in agent.runStream(prompt)) {
  print(result.output);     // Incremental chunk only
  print(result.messages);   // New messages (e.g., tool calls)
}
```

## 6. Message Type Changes

### Message → ChatMessage

The `Message` class has been renamed to `ChatMessage` with additional features.

#### Old:
```dart
final msg = Message(
  role: MessageRole.user,
  parts: [TextPart('Hello')],
);

// Factory constructors take only parts
Message.user([TextPart('Hello')])
Message.system([TextPart('You are helpful')])
```

#### New:
```dart
final msg = ChatMessage(
  role: MessageRole.user,
  parts: [TextPart('Hello')],
  metadata: {},  // NEW optional metadata field
);

// Factory constructors now take text as first parameter
ChatMessage.user('Hello', parts: [])  // Text required
ChatMessage.system('You are helpful')
ChatMessage.model('Response text')
```

### Message Collection Type Change

Messages now use `List<ChatMessage>` instead of `Iterable<Message>`.

#### Old:
```dart
Future<AgentResponse> run(String prompt, {
  Iterable<Message> messages = const [],
})
```

#### New:
```dart
Future<ChatResult<String>> run(String prompt, {
  List<ChatMessage> history = const [],
})
```

### No More fromRawJson

The `Message.fromRawJson()` constructor has been removed.

#### Old:
```dart
final msg = Message.fromRawJson(jsonString);
```

#### New:
```dart
// Must decode JSON first
final msg = ChatMessage.fromJson(jsonDecode(jsonString));
```

## 7. Tool API Changes

### Required Parameters

Tools now require `description` and `inputFromJson` (when the tool has
parameters).

#### Old:
```dart
Tool(
  name: 'weather',
  onCall: handler,
  description: 'Get weather',  // Was optional
  inputSchema: schema,
  // No inputFromJson parameter
)
```

#### New:
```dart
Tool<WeatherInput>(  // Generic type for input
  name: 'weather',
  onCall: handler,
  description: 'Get weather',  // Now required
  inputSchema: schema,
  inputFromJson: WeatherInput.fromJson,  // Required if tool has parameters
  strict: true,  // NEW optional strict mode
)
```

### Type-Safe Tool Handlers

Tools now use generics for type-safe input handling.

#### Old:
```dart
// Always Map<String, dynamic> for input and output
typedef ToolCallHandler = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> input
);

final tool = Tool(
  name: 'search',
  onCall: (input) async => {'result': await search(input['query'])},
);
```

#### New:
```dart
// Generic input type, flexible output
class SearchInput {
  final String query;
  SearchInput.fromJson(Map<String, dynamic> json) : query = json['query'];
}

final tool = Tool<SearchInput>(
  name: 'search',
  inputFromJson: SearchInput.fromJson,
  onCall: (SearchInput input) async => await search(input.query),
);
```

### Tool Execution Changes

Tools now have an `invoke()` method instead of direct `onCall` invocation.

#### Old:
```dart
// Direct call in model implementation
final result = await tool.onCall(arguments);
```

#### New:
```dart
// Use invoke() method
final result = await tool.invoke(arguments);
```

## 8. Removed Features

### Embeddings No Longer in Agent

Embeddings functionality has been moved to a separate `EmbeddingsProvider`
system.

#### Old:
```dart
final agent = Agent(model, embeddingModel: 'text-embedding-3-small');
final embedding = await agent.createEmbedding('text');
final matches = await Agent.findTopMatches(embedding, embeddings);
```

#### New:
```dart
// Use separate EmbeddingsProvider
import 'package:langchain_compat/langchain_compat.dart';

final provider = EmbeddingsProvider.openai;
final model = provider.createModel(name: 'text-embedding-3-small');
final result = await model.embedQuery('text');

// Use provider's similarity functions
final similarity = EmbeddingsProvider.cosineSimilarity(embedding1, embedding2);
```

### DotPrompt Support Removed

DotPrompt integration is not available in langchain_compat.

#### Old:
```dart
await agent.runPrompt('myPrompt.md', params);
```

#### New:
```dart
// Not available - implement your own prompt template solution
// or use string interpolation
final prompt = 'Hello, $name!';
await agent.run(prompt);
```

### Provider Direct Access

The `Agent.providerFor()` static method has been removed.

#### Old:
```dart
final provider = Agent.providerFor('openai:gpt-4o');
```

#### New:
```dart
final provider = ChatProvider.forName('openai');
// Note: This returns the provider, not a model
```

## 9. Provider System Changes

### Provider Resolution

Providers are now accessed through `ChatProvider` instead of through Agent.

#### Old:
```dart
// Through Agent class
final provider = Agent.providerFor('openai');
final models = await provider.listModels();
```

#### New:
```dart
// Through ChatProvider class
final provider = ChatProvider.forName('openai');
final models = await provider.listModels().toList();
// Note: listModels() now returns a Stream
```

### Provider Capabilities

The capability system remains similar but with different organization.

#### Old:
```dart
if (provider.caps.contains(ProviderCaps.multiToolCalls)) {
  // Provider supports multiple tool calls
}
```

#### New:
```dart
// Same API, but embeddings capability is separate
if (provider.caps.contains(ProviderCaps.multiToolCalls)) {
  // Provider supports multiple tool calls
}
// Note: ProviderCaps.embeddings doesn't exist for ChatProvider
```

## 10. Part Type Changes

### ToolPart Streaming Support

ToolPart now includes `argumentsRawString` for better streaming compatibility.

#### Old:
```dart
ToolPart.call(
  id: 'id',
  name: 'tool',
  arguments: {...},
)
```

#### New:
```dart
ToolPart.call(
  id: 'id',
  name: 'tool',
  arguments: {...},
  argumentsRawString: '{}',  // NEW: raw JSON string for streaming
)
```

### DataPart File Handling

DataPart now uses cross-platform `XFile` instead of URL/stream methods.

#### Old:
```dart
// From URL
final part = await DataPart.url(Uri.parse('https://...'));

// From stream
final part = await DataPart.stream(
  stream,
  length: 1024,
  mimeType: 'image/png',
);
```

#### New:
```dart
import 'package:cross_file/cross_file.dart';

// From XFile (cross-platform)
final file = XFile('path/to/image.png');
final part = await DataPart.fromFile(file);

// Direct construction still available
final part = DataPart(
  bytes,
  mimeType: 'image/png',
  name: 'image.png',
);
```

## Migration Checklist

1. ✅ Update imports from `dartantic_ai` to `langchain_compat`
2. ✅ Remove `apiKey`, `baseUrl`, `embeddingModel` from Agent constructor
3. ✅ Set API keys via environment variables
4. ✅ Move `outputSchema` and `outputFromJson` to run methods
5. ✅ Rename `messages` to `history` in run methods
6. ✅ Update `Message` to `ChatMessage` with new factory signatures
7. ✅ Change `AgentResponse` to `ChatResult<String>` in type annotations
8. ✅ Add `description` to all Tools (now required)
9. ✅ Add `inputFromJson` to Tools with parameters
10. ✅ Update streaming code to handle incremental chunks
11. ✅ Use `EmbeddingsProvider` for embeddings instead of Agent
12. ✅ Replace DotPrompt usage with custom solution
13. ✅ Update provider access to use `ChatProvider.forName()`
14. ✅ Handle the removal of custom base URLs