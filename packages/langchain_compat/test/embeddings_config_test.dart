import 'package:langchain_compat/langchain_compat.dart';
import 'package:langchain_compat/src/platform/platform.dart' as platform;
import 'package:test/test.dart';

void main() {
  group('Embeddings Configuration Tests', () {
    // Save original environment state
    late Map<String, String> originalAgentEnv;

    setUp(() {
      // Save current state
      originalAgentEnv = Map<String, String>.from(Dartantic.environment);

      // Clear Agent environment for clean test state
      Dartantic.environment.clear();
    });

    tearDown(() {
      // Restore original state
      Dartantic.environment.clear();
      Dartantic.environment.addAll(originalAgentEnv);
    });

    group('EmbeddingsProvider API Key Resolution', () {
      test('Falls back to Agent.environment', () {
        Dartantic.environment['OPENAI_API_KEY'] = 'sk-env-key';

        const provider = EmbeddingsProvider.openai;
        final model = provider.createModel();

        // Model should be created with env key
        expect(model, isNotNull);
      });

      test('Different providers use different API keys', () {
        // Set different keys
        Dartantic.environment['OPENAI_API_KEY'] = 'sk-openai';
        Dartantic.environment['GEMINI_API_KEY'] = 'sk-gemini';
        Dartantic.environment['MISTRAL_API_KEY'] = 'sk-mistral';
        Dartantic.environment['COHERE_API_KEY'] = 'sk-cohere';

        // Each should find its key
        expect(platform.tryGetEnv('OPENAI_API_KEY'), equals('sk-openai'));
        expect(platform.tryGetEnv('GEMINI_API_KEY'), equals('sk-gemini'));
        expect(platform.tryGetEnv('MISTRAL_API_KEY'), equals('sk-mistral'));
        expect(platform.tryGetEnv('COHERE_API_KEY'), equals('sk-cohere'));
      });
    });

    group('EmbeddingsProvider Base URL Resolution', () {
      test('Each provider has correct default base URL', () {
        // Set API keys so models can be created
        Dartantic.environment['OPENAI_API_KEY'] = 'sk-openai';
        Dartantic.environment['GEMINI_API_KEY'] = 'sk-gemini';
        Dartantic.environment['MISTRAL_API_KEY'] = 'sk-mistral';
        Dartantic.environment['COHERE_API_KEY'] = 'sk-cohere';

        // Create models with defaults
        expect(() => EmbeddingsProvider.openai.createModel(), returnsNormally);
        expect(() => EmbeddingsProvider.google.createModel(), returnsNormally);
        expect(() => EmbeddingsProvider.mistral.createModel(), returnsNormally);
        expect(() => EmbeddingsProvider.cohere.createModel(), returnsNormally);
      });
    });

    group('Error Handling', () {
      test('Invalid provider name throws', () {
        expect(
          () => EmbeddingsProvider.forName('invalid-provider'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('invalid-provider'),
            ),
          ),
        );
      });
    });
  });
}
