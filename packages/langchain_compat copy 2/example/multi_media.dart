// ignore_for_file: avoid_print
import 'dart:io';

import 'package:langchain_compat/langchain_compat.dart';

void main() async {
  // Multi-modal models that support images
  // Options: anthropic:claude-3-5-sonnet-20241022, openai:gpt-4o,
  //          google:gemini-2.0-flash, together:meta-llama/Llama-3.2-11B-Vision-Instruct-Turbo
  final agent = Agent('anthropic:claude-3-5-sonnet-20241022');

  print('=== Multi-Media Example ===\n');
  print('This example demonstrates working with text, images, and links.\n');

  // Example 1: Single image analysis
  print('=== Example 1: Single Image Analysis ===');
  await analyzeSingleImage(agent);
  print('');

  // Example 2: Multiple images analysis
  print('=== Example 2: Multiple Images Analysis ===');
  await analyzeMultipleImages(agent);
  print('');

  // Example 3: Process text file with images
  print('=== Example 3: Text + Images ===');
  await processTextWithImages(agent);
  print('');

  // Example 4: Multi-modal conversation
  print('=== Example 4: Multi-modal Conversation ===');
  await multiModalConversation(agent);
  print('');

  // Example 5: Compare images
  print('=== Example 5: Image Comparison ===');
  await compareImages(agent);
  print('');

  // Example 6: Link attachments
  print('=== Example 6: Link Attachments ===');
  await useLinkAttachment(agent);
}

Future<void> analyzeSingleImage(Agent agent) async {
  print('Analyzing a single fridge image...\n');

  final imageBytes = await File('example/files/fridge.png').readAsBytes();

  // Send to agent with image
  final response = await agent.run(
    'What items can you see in this fridge? List them by category.',
    attachments: [
      DataPart(mimeType: 'image/png', bytes: imageBytes),
    ],
  );

  print('Assistant: ${response.output}');
}

Future<void> analyzeMultipleImages(Agent agent) async {
  print('Analyzing multiple kitchen images...\n');

  final fridge = await File('example/files/fridge.png').readAsBytes();
  final cupboard = await File('example/files/cupboard.png').readAsBytes();

  // Send to agent with multiple images
  final response = await agent.run(
    'What meal could I make using items from both?',
    history: [
      ChatMessage.userParts([
        const TextPart('I have two images from my kitchen.'),
        const TextPart('\nImage 1 - Fridge:'),
        DataPart(mimeType: 'image/png', bytes: fridge),
        const TextPart('\nImage 2 - Cupboard:'),
        DataPart(mimeType: 'image/png', bytes: cupboard),
        const TextPart('\nWhat meal could I make using items from both?'),
      ]),
    ],
  );

  print('Assistant: ${response.output}');
}

Future<void> processTextWithImages(Agent agent) async {
  print('Combining text file and image analysis...\n');

  final bio = await File('example/files/bio.txt').readAsString();
  final fridge = await File('example/files/fridge.png').readAsBytes();

  // Combine text content and image
  final response = await agent.run(
    'What can you tell me about their lifestyle and dietary habits?',
    history: [
      ChatMessage.userParts([
        TextPart("Based on this person's bio:\n\n$bio\n"),
        const TextPart('And looking at their fridge contents:'),
        DataPart(mimeType: 'image/png', bytes: fridge),
        const TextPart(
          '\nWhat can you tell me about their lifestyle and dietary habits?',
        ),
      ]),
    ],
  );

  print('Assistant: ${response.output}');
}

Future<void> multiModalConversation(Agent agent) async {
  print('Starting multi-modal conversation...\n');

  final fridgeImage = await File('example/files/fridge.png').readAsBytes();
  final history = <ChatMessage>[];

  // First turn: Show image
  var result = await agent.run(
    'What do you see in this fridge?',
    history: [
      ChatMessage.userParts([
        const TextPart('What do you see in this fridge?'),
        DataPart(mimeType: 'image/png', bytes: fridgeImage),
      ]),
    ],
  );
  print('User: What do you see in this fridge? [with image]');
  print('Assistant: ${result.output}\n');
  history.addAll(result.messages);

  // Second turn: Follow-up question (no image)
  result = await agent.run('Which items are the healthiest?', history: history);
  print('User: Which items are the healthiest?');
  print('Assistant: ${result.output}\n');
  history.addAll(result.messages);

  // Third turn: Another follow-up
  result = await agent.run(
    'What about the items that might expire soon?',
    history: history,
  );
  print('User: What about the items that might expire soon?');
  print('Assistant: ${result.output}');
}

Future<void> compareImages(Agent agent) async {
  print('Comparing fridge and cupboard contents...\n');

  final fridgeImage = await File('example/files/fridge.png').readAsBytes();
  final cupboardImage = await File('example/files/cupboard.png').readAsBytes();

  final response = await agent.run(
    'Compare these two kitchen storage areas',
    history: [
      ChatMessage.userParts([
        const TextPart('Please compare these two images:'),
        const TextPart(
          "1. What's the storage strategy difference between them?",
        ),
        const TextPart('2. What types of food are in each?'),
        const TextPart('3. Any organizational suggestions?'),
        const TextPart('\nFridge:'),
        DataPart(mimeType: 'image/png', bytes: fridgeImage),
        const TextPart('\nCupboard:'),
        DataPart(mimeType: 'image/png', bytes: cupboardImage),
      ]),
    ],
  );

  print('Assistant: ${response.output}');
}

Future<void> useLinkAttachment(Agent agent) async {
  print('Demonstrating link attachments...\n');

  // Note: Link attachments require real, accessible URLs
  // This is just an example - replace with actual URLs
  try {
    final response = await agent.run(
      'Analyze the article and relate it to the fridge contents',
      history: [
        ChatMessage.userParts([
          const TextPart('Can you analyze this article about healthy eating?'),
          const LinkPart(
            url: 'https://www.example.com/healthy-eating-guide.html',
            mimeType: 'text/html',
          ),
          const TextPart('\nHow does it relate to the items in this fridge?'),
          DataPart(
            mimeType: 'image/png',
            bytes: await File('example/files/fridge.png').readAsBytes(),
          ),
        ]),
      ],
    );
    print('Assistant: ${response.output}');
  } on Exception catch (e) {
    print('Note: Link attachments require real, accessible URLs.');
    print('Error: $e');
  }
}
