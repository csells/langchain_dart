// ignore_for_file: avoid_print

import 'dart:io';

import 'package:example/example.dart';
import 'package:langchain_compat/langchain_compat.dart';

void main() async {
  final chat = Chat(
    ChatAgent('gemini', tools: [weatherTool, temperatureConverterTool]),
    history: [ChatMessage.system('You are a helpful weather assistant.')],
  );

  // multi-tool use w/ openai
  var prompt = "What's the Paris temperature in Fahrenheit?";
  print('user: $prompt');
  final result = await chat.send(prompt);
  print('${chat.displayName}: ${result.output.trim()}');
  dumpMessages(chat.history);
  print('');

  // multi-turn chat using context and streaming output w/ gemini
  chat.agent = ChatAgent('openai');
  prompt = 'Is that typical for this time of year?';
  print('user: $prompt');
  stdout.write('${chat.displayName}: ');
  await dumpStream(chat.sendStream(prompt));
  dumpMessages(chat.history);
  print('');

  // typed output and tool use w/ anthropic
  chat.agent = ChatAgent(
    'anthropic',
    tools: [weatherTool, temperatureConverterTool],
  );
  prompt = 'Can you give me the current local time and temperature?';
  print('user: $prompt');
  final typedResult = await chat.sendFor<TimeAndTemperature>(
    prompt,
    outputSchema: TimeAndTemperature.schema,
    outputFromJson: TimeAndTemperature.fromJson,
  );

  print('${chat.displayName}.time: ${typedResult.output.time}');
  print('${chat.displayName}.temperature: ${typedResult.output.temperature}°C');
  dumpMessages(chat.history);
  print('');

  exit(0);
}
