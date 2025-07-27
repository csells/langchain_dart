// ignore_for_file: avoid_print

import 'package:example/example.dart';
import 'package:json_schema/json_schema.dart';
import 'package:langchain_compat/langchain_compat.dart';

/// An example of how to add and use a custom provider.
void main() async {
  print('Adding the "echo" provider');
  Provider.providerMap['echo'] = EchoProvider();

  print('Using the echo provider');
  final agent = Agent('echo');
  const prompt = 'Hello, world!';
  final response = await agent.send(prompt);

  print('Prompt: "$prompt"');
  print('Response: "${response.output}"');
  print('');
  dumpMessages(response.messages);
  print('');
  print('Successfully echoed the prompt!');
}

/// A mock model that echos back the prompt.
class EchoChatModel extends ChatModel<ChatModelOptions> {
  EchoChatModel({required super.name, ChatModelOptions? defaultOptions})
    : super(defaultOptions: defaultOptions ?? const ChatModelOptions());

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    ChatModelOptions? options,
    JsonSchema? outputSchema,
  }) {
    assert(messages.isNotEmpty);
    assert(messages.last.role == ChatMessageRole.user);
    return Stream.fromIterable([
      ChatResult<ChatMessage>(
        output: ChatMessage.fromJson(
          messages.last.toJson()..['role'] = 'model',
        ),
      ),
    ]);
  }

  @override
  void dispose() {}

  @override
  String get name => 'echo';
}

/// A chat provider that provides an [EchoChatModel].
class EchoProvider extends Provider<ChatModelOptions, EmbeddingsModelOptions> {
  EchoProvider()
    : super(
        name: 'echo',
        displayName: 'Echo',
        defaultModelNames: {ModelKind.chat: 'echo'},
        caps: {ProviderCaps.chat},
      );

  @override
  String get name => 'echo';

  @override
  Set<ProviderCaps> get caps => {ProviderCaps.chat};

  @override
  Stream<ModelInfo> listModels() => Stream.fromIterable([
    ModelInfo(
      name: 'echo',
      providerName: 'echo',
      kinds: const {ModelKind.chat},
    ),
  ]);

  @override
  ChatModel<ChatModelOptions> createChatModel({
    String? name,
    List<Tool<Object>>? tools,
    double? temperature,
    String? systemPrompt,
    ChatModelOptions? options,
  }) => EchoChatModel(
    name: name ?? defaultModelNames[ModelKind.chat]!,
    defaultOptions: options,
  );

  @override
  EmbeddingsModel<EmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    EmbeddingsModelOptions? options,
  }) => throw Exception('no support for embeddings models in this provider');
}
