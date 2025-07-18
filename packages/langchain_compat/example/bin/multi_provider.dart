// ignore_for_file: avoid_print

import 'package:example/example.dart';
import 'package:langchain_compat/langchain_compat.dart';

void main() async {
  print('Multi-Provider Conversation Demo\n');
  final history = <ChatMessage>[];

  // Step 1: Start with Gemini (fast and cheap)
  print('═══ Step 1: Starting with Gemini ═══');
  final gemini = Agent('google');
  final result1 = await gemini.run(
    'Hi! My name is Alice and I work as a software engineer in Seattle. '
    'I love hiking and coffee.',
  );
  history.addAll(result1.messages);
  print('Gemini: ${result1.output}\n');

  // Step 2: Continue with Claude (good at reasoning)
  print('═══ Step 2: Switching to Claude ═══');
  final claude = Agent('anthropic');
  final result2 = await claude.run(
    'What do you remember about me?',
    history: history,
  );
  history.addAll(result2.messages);
  print('Claude: ${result2.output}\n');

  // Step 3: Use OpenAI with tools
  print('═══ Step 3: OpenAI with Tools ═══');
  final openai = Agent('openai', tools: [weatherTool, temperatureTool]);
  final result3 = await openai.run(
    'Can you check the weather where I live?',
    history: history,
  );
  history.addAll(result3.messages);
  print('OpenAI: ${result3.output}\n');

  // Step 4: Back to Gemini to reference the tool results
  print('═══ Step 4: Back to Gemini ═══');
  final gemini2 = Agent('google');
  final result4 = await gemini2.run(
    'Based on the weather, what outdoor activities would you recommend '
    'for someone who loves hiking?',
    history: history,
  );
  history.addAll(result4.messages);
  print('Gemini: ${result4.output}\n');

  // Step 5: Use Claude for a final summary
  print('═══ Step 5: Claude for Summary ═══');
  final claude2 = Agent('anthropic');
  final result5 = await claude2.run(
    'Can you summarize our entire conversation, including what you '
    'learned about me and any information we looked up?',
    history: history,
  );
  history.addAll(result5.messages);
  print('Claude: ${result5.output}\n');

  // Show the complete message history
  print('═══ Complete Message History ═══');
  dumpMessages(history);

  print('Total messages: ${history.length}');
  print('Provider sequence:');
  var lastProvider = '';
  for (var i = 0; i < history.length; i += 2) {
    if (i < result1.messages.length) {
      if (lastProvider != 'Gemini') print('  → Gemini');
      lastProvider = 'Gemini';
    } else if (i < result1.messages.length + result2.messages.length) {
      if (lastProvider != 'Claude') print('  → Claude');
      lastProvider = 'Claude';
    } else if (i <
        result1.messages.length +
            result2.messages.length +
            result3.messages.length) {
      if (lastProvider != 'OpenAI') print('  → OpenAI (with tools)');
      lastProvider = 'OpenAI';
    } else if (i <
        result1.messages.length +
            result2.messages.length +
            result3.messages.length +
            result4.messages.length) {
      if (lastProvider != 'Gemini') print('  → Gemini');
      lastProvider = 'Gemini';
    } else {
      if (lastProvider != 'Claude') print('  → Claude');
      lastProvider = 'Claude';
    }
  }
}
