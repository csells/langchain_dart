// ignore_for_file: avoid_print

import 'package:example/example.dart';
import 'package:json_schema/json_schema.dart';
import 'package:langchain_compat/langchain_compat.dart';

/// An example of how to add and use a custom provider.
void main() async {
  print('Adding the "echo" provider');
  ChatProvider.providerMap['echo'] = EchoProvider();

  print('Using the echo provider');
  final agent = Agent('echo');
  const prompt = 'Hello, world!';
  final response = await agent.run(prompt);

  print('Prompt: "$prompt"');
  print('Response: "${response.output}"');
  print('');
  dumpMessages(response.messages);
  print('');
  print('Successfully echoed the prompt!');
}

class EchoModelOptions extends ChatModelOptions {
  const EchoModelOptions();
}

/// A mock model that echos back the prompt.
class EchoModel extends ChatModel<EchoModelOptions> {
  EchoModel({required super.name, required super.defaultOptions});

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    EchoModelOptions? options,
    JsonSchema? outputSchema,
  }) {
    assert(messages.isNotEmpty);
    assert(messages.last.role == MessageRole.user);
    return Stream.fromIterable([
      ChatResult<ChatMessage>(
        output: ChatMessage.fromJson(
          messages.last.toJson()..['role'] = 'model',
        ),
      ),
    ]);
  }

  @override
  EchoModelOptions get defaultOptions => const EchoModelOptions();

  @override
  void dispose() {}

  @override
  String get name => 'echo';
}

/// A chat provider that provides an [EchoModel].
class EchoProvider implements ChatProvider<EchoModelOptions> {
  @override
  String get name => 'echo';

  @override
  Set<ProviderCaps> get caps => {ProviderCaps.chat};

  @override
  ChatModel<EchoModelOptions> createModel({
    String? name,
    String? systemPrompt,
    double? temperature,
    List<Tool>? tools,
    EchoModelOptions? options,
  }) => EchoModel(
    name: name ?? defaultModelName,
    defaultOptions: options ?? const EchoModelOptions(),
  );

  @override
  Stream<ModelInfo> listModels() => Stream.fromIterable([
    ModelInfo(
      name: 'echo',
      providerName: 'echo',
      kinds: const {ModelKind.chat},
    ),
  ]);

  @override
  List<String> get aliases => [];

  @override
  String get apiKeyName => '';

  @override
  String get defaultBaseUrl => '';

  @override
  String get defaultModelName => 'echo';

  @override
  String get displayName => 'Echo';
}
