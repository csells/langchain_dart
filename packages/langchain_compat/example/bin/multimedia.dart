// ignore_for_file: avoid_print, unreachable_from_main
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:langchain_compat/langchain_compat.dart';

void main() async {
  final agent = ChatAgent('openai', systemPrompt: 'Be concise.');

  await summarizeTextFile(agent);
  await analyzeImages(agent);
  await processTextWithImages(agent);
  await multiModalConversation(agent);
  await useLinkAttachment(agent);
  exit(0);
}

Future<void> summarizeTextFile(ChatAgent agent) async {
  print('\n${agent.displayName} Summarize Text File\n');

  const path = 'bin/files/bio.txt';
  final file = XFile.fromData(await File(path).readAsBytes(), path: path);

  await agent
      .runStream(
        'Can you summarized the attached file?',
        attachments: [await DataPart.fromFile(file)],
      )
      .forEach((r) => stdout.write(r.output));
  stdout.writeln();
}

Future<void> analyzeImages(ChatAgent agent) async {
  print('\n${agent.displayName} Analyze Multiple Images');

  const fridgePath = 'bin/files/fridge.png';
  final fridgeFile = XFile.fromData(
    await File(fridgePath).readAsBytes(),
    path: fridgePath,
  );

  const cupboardPath = 'bin/files/cupboard.png';
  final cupboardFile = XFile.fromData(
    await File(cupboardPath).readAsBytes(),
    path: cupboardPath,
  );

  await agent
      .runStream(
        'I have two images from my kitchen. '
        'What meal could I make using items from both?',
        attachments: [
          await DataPart.fromFile(fridgeFile),
          await DataPart.fromFile(cupboardFile),
        ],
      )
      .forEach((r) => stdout.write(r.output));
  stdout.writeln();
}

Future<void> processTextWithImages(ChatAgent agent) async {
  print('\n${agent.displayName} Combine Text File and Image Analysis');

  const bioPath = 'bin/files/bio.txt';
  final bioFile = XFile.fromData(
    await File(bioPath).readAsBytes(),
    path: bioPath,
  );

  const fridgePath = 'bin/files/fridge.png';
  final fridgeFile = XFile.fromData(
    await File(fridgePath).readAsBytes(),
    path: fridgePath,
  );

  await agent
      .runStream(
        'What can you tell me about their lifestyle and dietary habits?',
        attachments: [
          await DataPart.fromFile(bioFile),
          await DataPart.fromFile(fridgeFile),
        ],
      )
      .forEach((r) => stdout.write(r.output));
  stdout.writeln();
}

Future<void> multiModalConversation(ChatAgent agent) async {
  print('\n${agent.displayName} Multi-modal Conversation');

  const fridgePath = 'bin/files/fridge.png';
  final fridgeFile = XFile.fromData(
    await File(fridgePath).readAsBytes(),
    path: fridgePath,
  );

  final history = <ChatMessage>[];

  // First turn: check the fridge
  await agent
      .runStream(
        'What do you see in this fridge?',
        attachments: [await DataPart.fromFile(fridgeFile)],
      )
      .forEach((r) {
        stdout.write(r.output);
        history.addAll(r.messages);
      });

  // Second turn: follow-up question
  await agent
      .runStream('Which items are the healthiest?', history: history)
      .forEach((r) {
        stdout.write(r.output);
        history.addAll(r.messages);
      });
  stdout.writeln('');
}

Future<void> useLinkAttachment(ChatAgent agent) async {
  print('\n${agent.displayName} Link Attachments');

  try {
    final imageLink = Uri.parse(
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
    );

    await agent
        .runStream(
          'Can you describe this image?',
          attachments: [LinkPart(imageLink)],
        )
        .forEach((r) => stdout.write(r.output));
    stdout.writeln();
  } on Exception catch (e) {
    print(
      'Error: $e\n'
      'NOTE: some providers require an upload to their associated servers '
      'before they can be used (e.g. google).',
    );
  }
}
