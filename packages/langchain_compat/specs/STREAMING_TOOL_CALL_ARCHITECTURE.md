# Streaming Tool Call Architecture

This document specifies how the LangChain Dart compatibility layer handles streaming messages and tool calls across different providers using the new orchestrator-based architecture.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Core Concepts](#core-concepts)
3. [Provider Capabilities](#provider-capabilities)
4. [Streaming Patterns](#streaming-patterns)
5. [Orchestration Layer](#orchestration-layer)
6. [Tool Execution Layer](#tool-execution-layer)
7. [State Management](#state-management)
8. [Implementation Details](#implementation-details)
9. [Provider-Specific Details](#provider-specific-details)
10. [Testing and Validation](#testing-and-validation)

## Architecture Overview

The system operates through a six-layer architecture with specialized components for streaming and tool execution:

```
┌─────────────────────────────────────────────────────────────┐
│                         API Layer                            │
│  - Agent: User-facing interface (run/runStream)             │
│  - Orchestrator selection and coordination                   │
│  - Final result formatting and validation                   │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Orchestration Layer                       │
│  - StreamingOrchestrator: Workflow coordination             │
│  - Business logic and streaming management                   │
│  - Provider-agnostic tool execution orchestration          │
│  - Streaming state transitions and UX enhancement          │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                Provider Abstraction Layer                    │
│  - ChatModel: Provider-agnostic interface                   │
│  - MessageAccumulator: Strategy pattern for streaming       │
│  - ProviderCaps: Capability-based feature detection        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│               Provider Implementation Layer                   │
│  - Provider-specific models and mappers                     │
│  - Protocol-specific streaming accumulation                 │
│  - Tool ID assignment and argument handling                 │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                        │
│  - ToolExecutor: Centralized tool execution                 │
│  - StreamingState: Mutable state encapsulation             │
│  - Resource management via try/finally patterns            │
│  - RetryHttpClient: Cross-cutting HTTP concerns            │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     Protocol Layer                           │
│  - HTTP clients for each provider                           │
│  - Network communication and error handling                 │
│  - Request/response serialization                          │
└─────────────────────────────────────────────────────────────┘
```

## Core Concepts

### Streaming Message Flow
- **Text Streaming**: Immediate output of text chunks to users
- **Tool Accumulation**: Building complete tool calls across chunks
- **Message Boundaries**: Preserving complete messages in history
- **Streaming UX**: Visual separation between tool calls and responses

### Tool Execution
- **Tool Calls**: LLM-initiated function invocations with structured arguments
- **Tool Results**: Responses from tool execution returned to LLM
- **ID Matching**: Ensuring tool calls and results are properly paired
- **Error Handling**: Tool errors returned to LLM for recovery

## Provider Capabilities

### Tool Support Matrix

| Provider   | Streaming | Tools | Tool IDs | Streaming Format |
|------------|-----------|-------|----------|------------------|
| OpenAI     | ✅        | ✅    | ✅       | Partial chunks   |
| OpenRouter | ✅        | ✅    | ✅       | OpenAI-compatible|
| Anthropic  | ✅        | ✅    | ✅       | Event-based      |
| Google     | ✅        | ✅    | ❌       | Complete chunks  |
| Ollama     | ✅        | ✅    | ❌       | Complete chunks  |
| Mistral    | ✅        | ❌    | N/A      | Text only        |
| Cohere     | ✅        | ✅    | ✅       | Custom format    |
| Together   | ✅        | ✅    | ✅       | OpenAI-compatible|

## Streaming Patterns

### OpenAI-Style (Partial Chunks)

Tool calls are built incrementally across multiple chunks:

```dart
// Chunk 1: Tool call starts
{
  tool_calls: [{
    index: 0,
    id: 'call_123',
    function: {name: 'get_weather', arguments: ''}
  }]
}

// Chunk 2: Arguments accumulate
{
  tool_calls: [{
    index: 0,
    function: {arguments: '{"city"'}
  }]
}

// Chunk 3: More arguments
{
  tool_calls: [{
    index: 0,
    function: {arguments: ': "Boston"}'}
  }]
}
```

**Mapper Behavior**:
- Accumulates arguments across chunks
- Preserves raw argument string for Agent parsing
- Merges tool calls with same index

### Google/Ollama-Style (Complete Chunks)

Each chunk contains complete information:

```dart
// Single chunk with complete tool call
{
  functionCalls: [{
    name: 'get_weather',
    args: {city: 'Boston'}  // Already parsed
  }]
}
```

**Mapper Behavior**:
- Assigns UUID for tool call ID
- Converts parsed args to JSON string
- Preserves raw string for consistency

### Anthropic-Style (Event-Based)

Structured event sequence:

```dart
// Event 1: Tool use starts
ContentBlockStart {
  type: 'tool_use',
  id: 'toolu_123',
  name: 'get_weather'
}

// Events 2-4: Arguments streamed
InputJsonBlockDelta { partial_json: '{"ci' }
InputJsonBlockDelta { partial_json: 'ty": "Bos' }
InputJsonBlockDelta { partial_json: 'ton"}' }

// Event 5: Tool use complete
ContentBlockStop
```

**Transformer Behavior**:
- Tracks state across events
- Accumulates arguments in StringBuffer
- Emits complete tool call on ContentBlockStop

## Orchestration Layer

### StreamingOrchestrator Interface

The orchestration layer coordinates streaming workflows through the `StreamingOrchestrator` interface:

```dart
abstract interface class StreamingOrchestrator {
  /// Provider hint for orchestrator selection
  String get providerHint;
  
  /// Initialize the orchestrator with streaming state
  void initialize(StreamingState state);
  
  /// Process a single iteration of the streaming workflow
  Stream<StreamingIterationResult> processIteration(
    ChatModel<ChatModelOptions> model,
    StreamingState state, {
    JsonSchema? outputSchema,
  });
  
  /// Finalize the orchestrator after streaming completes
  void finalize(StreamingState state);
}
```

### Orchestrator Selection

The Agent selects the appropriate orchestrator based on request characteristics:

```dart
StreamingOrchestrator _selectOrchestrator({
  JsonSchema? outputSchema,
  List<Tool>? tools,
}) {
  // Select TypedOutputStreamingOrchestrator for structured output
  if (outputSchema != null) {
    return const TypedOutputStreamingOrchestrator();
  }
  
  // Default orchestrator for regular chat and tool calls
  return const DefaultStreamingOrchestrator();
}
```

### DefaultStreamingOrchestrator

Handles standard streaming patterns:

1. **Stream Model Response**: Process chunks until stream closes
2. **Message Accumulation**: Use MessageAccumulator strategy
3. **Tool Detection**: Identify tool calls in consolidated message
4. **Tool Execution**: Delegate to ToolExecutor
5. **Continuation Logic**: Loop until no more tool calls

```dart
// Main iteration pattern
await for (final result in model.sendStream(state.conversationHistory)) {
  // Stream text chunks immediately
  if (textOutput.isNotEmpty) {
    yield StreamingIterationResult(output: textOutput, shouldContinue: true);
  }
  
  // Accumulate complete message
  state.accumulatedMessage = state.accumulator.accumulate(
    state.accumulatedMessage,
    result.output,
  );
}

// Process consolidated message
final consolidatedMessage = state.accumulator.consolidate(state.accumulatedMessage);
final toolCalls = consolidatedMessage.parts.whereType<ToolPart>()
    .where((p) => p.kind == ToolPartKind.call).toList();

if (toolCalls.isNotEmpty) {
  // Execute tools and continue streaming
  final results = await state.executor.executeBatch(toolCalls, state.toolMap);
  // ... add results to conversation and continue
}
```

## Tool Execution Layer

### ToolExecutor Interface

Centralized tool execution with provider-specific strategies:

```dart
abstract interface class ToolExecutor {
  /// Provider hint for executor selection
  String get providerHint;
  
  /// Execute multiple tools, potentially in parallel
  Future<List<ToolExecutionResult>> executeBatch(
    List<ToolPart> toolCalls,
    Map<String, Tool> toolMap,
  );
  
  /// Execute a single tool with error handling
  Future<ToolExecutionResult> executeSingle(
    ToolPart toolCall,
    Map<String, Tool> toolMap,
  );
}
```

### DefaultToolExecutor

Standard implementation with robust error handling:

#### 1. Argument Parsing Fallback
```dart
// Critical: Handle streaming argument edge cases
var args = toolCall.arguments ?? {};
if (args.isEmpty && (toolCall.argumentsRawString?.isNotEmpty ?? false)) {
  try {
    final parsed = json.decode(toolCall.argumentsRawString!);
    if (parsed is Map<String, dynamic>) {
      args = parsed;
    } else if (parsed == null || parsed == 'null') {
      // Handle Cohere edge case: "null" for parameterless tools
      args = <String, dynamic>{};
    }
  } on FormatException catch (e) {
    // Return parse error to LLM for correction
    return ToolExecutionResult.error(
      toolCall: toolCall,
      error: 'Invalid JSON in tool arguments: $e',
    );
  }
}
```

#### 2. Tool Execution with Error Recovery
```dart
try {
  final tool = toolMap[toolCall.name];
  if (tool == null) {
    return ToolExecutionResult.error(
      toolCall: toolCall,
      error: 'Tool "${toolCall.name}" not found',
    );
  }

  final result = await tool.invoke(args);
  final resultString = result is String ? result : json.encode(result);
  
  return ToolExecutionResult.success(
    toolCall: toolCall,
    result: resultString,
  );
} on Exception catch (error, stackTrace) {
  _logger.warning('Tool execution failed', error, stackTrace);
  
  return ToolExecutionResult.error(
    toolCall: toolCall,
    error: error.toString(),
  );
}
```

#### 3. Result Consolidation
```dart
// Convert execution results to ToolPart.result for conversation
final toolResultParts = results.map((result) => ToolPart.result(
  id: result.toolCall.id,
  name: result.toolCall.name,
  result: result.isSuccess ? result.result : json.encode({
    'error': result.error,
  }),
)).toList();

// Create single user message with all results
final toolResultMessage = ChatMessage(
  role: MessageRole.user,
  parts: toolResultParts,
);
```

## State Management

### StreamingState

Encapsulates all mutable state during streaming operations:

```dart
class StreamingState {
  /// Conversation history being built during streaming
  final List<ChatMessage> conversationHistory;
  
  /// Available tools mapped by name
  final Map<String, Tool> toolMap;
  
  /// Strategy for provider-specific message accumulation
  final MessageAccumulator accumulator;
  
  /// Strategy for tool execution
  final ToolExecutor executor;
  
  /// Tool ID coordination across conversation
  final ToolIdCoordinator toolIdCoordinator;
  
  /// Workflow control flags
  bool done = false;
  bool shouldPrefixNextMessage = false;
  bool isFirstChunkOfMessage = true;
  
  /// Current message being accumulated from stream
  ChatMessage accumulatedMessage;
  
  /// Last result from model stream
  ChatResult<ChatMessage> lastResult;
}
```

### State Lifecycle

1. **Initialization**: Create state with conversation history and tools
2. **Message Reset**: Clear accumulated message before each model call
3. **Accumulation**: Build message from streaming chunks
4. **Consolidation**: Finalize message and extract tool calls
5. **Tool Execution**: Process tools and update conversation
6. **Continuation**: Check if more streaming needed

### UX State Management

```dart
// Streaming UX enhancement tracking
bool _shouldPrefixNewline(StreamingState state) {
  return state.shouldPrefixNextMessage && state.isFirstChunkOfMessage;
}

// Update state after streaming text
void _updateStreamingState(StreamingState state, String textOutput) {
  if (textOutput.isNotEmpty) {
    state.isFirstChunkOfMessage = false;
  }
}

// Set UX flags after tool execution
void _setToolExecutionFlags(StreamingState state) {
  state.shouldPrefixNextMessage = true; // Next AI message needs newline prefix
}
```

## Implementation Details

### Tool ID Assignment

For providers without tool IDs (Google, Ollama):

```dart
// In mapper
final toolId = Uuid().v4();
return ToolPart.call(
  id: toolId,
  name: functionCall.name,
  arguments: functionCall.args,
  argumentsRawString: json.encode(functionCall.args),
);
```

### Raw Argument Preservation

All mappers preserve raw argument strings:

```dart
// OpenAI mapper
argumentsRawString: argumentsAccumulator.toString()

// Anthropic transformer
argumentsRawString: json.encode(toolUse.input)

// Google mapper
argumentsRawString: json.encode(functionCall.args)
```

### Error Handling

Tool execution errors are included in the consolidated tool result message:

```dart
catch (error, stackTrace) {
  _logger.warning('Tool ${toolPart.name} execution failed: $error');
  
  // Add error result part to collection
  toolResultParts.add(
    ToolPart.result(
      id: toolPart.id,
      name: toolPart.name,
      result: json.encode({'error': error.toString()}),
    ),
  );
}
```

## Provider-Specific Details

### OpenAI
- **Streaming**: Partial chunks with index-based accumulation
- **Tool IDs**: Provided by API
- **Arguments**: Streamed as raw JSON string
- **Parsing**: Agent handles at execution time

### Anthropic
- **Streaming**: Event-based with explicit stages
- **Tool IDs**: Provided by API
- **Arguments**: Accumulated via InputJsonBlockDelta
- **Special**: ContentBlockStop triggers emission

### Google
- **Streaming**: Complete chunks per message
- **Tool IDs**: Generated by mapper (UUID)
- **Arguments**: Provided as parsed objects
- **Conversion**: Mapper converts to JSON string

### Ollama
- **Streaming**: Complete chunks
- **Tool IDs**: Generated by mapper (UUID)
- **Arguments**: Provided as parsed objects
- **Note**: Both native and OpenAI-compatible endpoints

### Cohere
- **Streaming**: Custom format with <|python_tag|>
- **Tool IDs**: Provided by API
- **Arguments**: Special parsing for "null" string
- **Edge Case**: Sends "null" for parameterless tools

## Testing and Validation

### Key Test Scenarios

1. **Streaming Integrity**: No dropped chunks or text
2. **Tool Accumulation**: Arguments built correctly across chunks
3. **ID Matching**: Tool calls and results properly paired
4. **Error Recovery**: Tool errors handled gracefully
5. **UX Features**: Newline prefixing works correctly
6. **Message History Validation**: User/model alternation maintained
7. **Tool Result Consolidation**: Multiple results in single message

### Debug Examples

```dart
// debug_streaming_tool_calls.dart
// Tests streaming with multiple tool calls

// debug_tool_accumulation.dart
// Verifies argument accumulation across chunks
```

### Edge Cases

1. **Empty Arguments**: Some providers send `arguments: {}`
2. **Parameterless Tools**: Cohere sends `"null"` string
3. **Multiple Same Tools**: Ensure IDs differentiate calls
4. **Streaming Interruption**: Partial tool calls handled

## Key Design Principles

1. **Streaming First**: Optimize for real-time user experience
2. **Orchestrator Coordination**: Complex workflows handled by specialized orchestrators
3. **State Encapsulation**: All mutable state isolated in StreamingState
4. **Strategy Pattern**: Pluggable MessageAccumulator and ToolExecutor implementations
5. **Provider Abstraction**: Agent and orchestrators agnostic to provider details
6. **Resource Management**: Guaranteed cleanup through try/finally patterns
7. **Error Transparency**: Tool errors returned to LLM with full context
8. **Clean Separation**: Each layer has focused responsibilities

## Architecture Benefits

### Compared to Previous Monolithic Design

1. **Maintainability**: 56% reduction in Agent complexity (1,091 → 475 lines)
2. **Testability**: Each component can be tested in isolation
3. **Extensibility**: New orchestrators and executors can be added without changing core logic
4. **Debugging**: Clear layer boundaries make issue isolation easier
5. **Resource Safety**: Centralized lifecycle management prevents leaks
6. **Provider Isolation**: Quirks contained in implementation layers

### Orchestrator Advantages

1. **Workflow Specialization**: Different orchestrators for different use cases
2. **Provider Agnostic**: Same orchestrator works across all providers
3. **Streaming Optimization**: Purpose-built for streaming coordination
4. **State Management**: Clean state transitions and isolation
5. **UX Enhancement**: Consistent streaming experience across providers

## Migration Notes

### Architectural Changes

1. **Agent Role**: Transformed from monolithic executor to thin coordinator
2. **Orchestration Layer**: New layer for business logic and workflow management
3. **State Encapsulation**: Mutable state isolated in StreamingState
4. **Tool Execution**: Centralized in ToolExecutor with strategy pattern
5. **Message Accumulation**: Provider-specific strategies via MessageAccumulator
6. **Resource Management**: Direct model creation and disposal

### Backward Compatibility

- **Public API**: No breaking changes to Agent's public interface
- **Provider Integration**: Existing providers work without modification
- **Tool Interface**: Existing Tool implementations unchanged
- **Message Semantics**: Same message flow and consolidation patterns

### Performance Improvements

1. **Streaming Efficiency**: Better chunk processing and state management
2. **Memory Management**: Proper resource cleanup and state isolation
3. **Error Handling**: Faster error recovery with structured exception hierarchy
4. **Provider Optimization**: Strategy patterns allow provider-specific optimizations

## Future Considerations

### Planned Enhancements

1. **Parallel Tool Execution**: ParallelToolExecutor for concurrent tool calls
2. **Custom Orchestrators**: Provider-specific orchestrators for unique workflows
3. **Advanced State Management**: Persistent state across conversations
4. **Performance Monitoring**: Built-in metrics and monitoring hooks
5. **Caching Integration**: Smart caching strategies in orchestration layer

### Extension Points

1. **New Orchestrators**: Specialized workflows (e.g., multi-step reasoning)
2. **Custom Executors**: Provider-specific tool execution strategies
3. **Message Accumulators**: Novel streaming patterns and optimizations
4. **State Managers**: Advanced state persistence and recovery
5. **Lifecycle Hooks**: Custom resource management and cleanup logic

## Implementation Guidance

### Adding New Orchestrators

```dart
class CustomStreamingOrchestrator implements StreamingOrchestrator {
  @override
  String get providerHint => 'custom';
  
  @override
  void initialize(StreamingState state) {
    // Custom initialization logic
  }
  
  @override
  Stream<StreamingIterationResult> processIteration(
    ChatModel<ChatModelOptions> model,
    StreamingState state, {
    JsonSchema? outputSchema,
  }) async* {
    // Custom streaming workflow
  }
  
  @override
  void finalize(StreamingState state) {
    // Custom cleanup logic
  }
}
```

### Adding Custom Tool Executors

```dart
class ParallelToolExecutor implements ToolExecutor {
  @override
  String get providerHint => 'parallel';
  
  @override
  Future<List<ToolExecutionResult>> executeBatch(
    List<ToolPart> toolCalls,
    Map<String, Tool> toolMap,
  ) async {
    // Execute tools in parallel using Future.wait
    final futures = toolCalls.map((call) => executeSingle(call, toolMap));
    return await Future.wait(futures);
  }
}
```

### Custom Message Accumulators

```dart
class OptimizedMessageAccumulator implements MessageAccumulator {
  @override
  String get providerHint => 'optimized';
  
  @override
  ChatMessage accumulate(ChatMessage existing, ChatMessage newChunk) {
    // Provider-specific accumulation optimizations
  }
  
  @override
  ChatMessage consolidate(ChatMessage accumulated) {
    // Final message processing and optimization
  }
}