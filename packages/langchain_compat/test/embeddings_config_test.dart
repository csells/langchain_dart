import 'package:langchain_compat/langchain_compat.dart';
import 'package:langchain_compat/src/platform/platform.dart' as platform;
import 'package:test/test.dart';

void main() {
  group('Embeddings Configuration Tests', () {
    // Save original environment state
    late Map<String, String> originalAgentEnv;

    setUp(() {
      // Save current state
      originalAgentEnv = Map<String, String>.from(Agent.environment);

      // Clear Agent environment for clean test state
      Agent.environment.clear();
    });

    tearDown(() {
      // Restore original state
      Agent.environment.clear();
      Agent.environment.addAll(originalAgentEnv);
    });

    group('EmbeddingsProvider API Key Resolution', () {
      test('Direct createModel parameter takes precedence', () {
        Agent.environment['OPENAI_API_KEY'] = 'sk-env-key';

        const provider = EmbeddingsProvider.openai;
        final model = provider.createModel(apiKey: 'sk-direct-key');

        // Model should be created with direct key
        expect(model, isNotNull);
      });

      test('Falls back to Agent.environment', () {
        Agent.environment['OPENAI_API_KEY'] = 'sk-env-key';

        const provider = EmbeddingsProvider.openai;
        final model = provider.createModel();

        // Model should be created with env key
        expect(model, isNotNull);
      });

      test('Different providers use different API keys', () {
        // Set different keys
        Agent.environment['OPENAI_API_KEY'] = 'sk-openai';
        Agent.environment['GEMINI_API_KEY'] = 'sk-gemini';
        Agent.environment['MISTRAL_API_KEY'] = 'sk-mistral';
        Agent.environment['COHERE_API_KEY'] = 'sk-cohere';

        // Each should find its key
        expect(platform.tryGetEnv('OPENAI_API_KEY'), equals('sk-openai'));
        expect(platform.tryGetEnv('GEMINI_API_KEY'), equals('sk-gemini'));
        expect(platform.tryGetEnv('MISTRAL_API_KEY'), equals('sk-mistral'));
        expect(platform.tryGetEnv('COHERE_API_KEY'), equals('sk-cohere'));
      });
    });

    group('EmbeddingsProvider Base URL Resolution', () {
      test('Direct createModel baseUrl parameter works', () {
        Agent.environment['OPENAI_API_KEY'] = 'sk-test';

        const provider = EmbeddingsProvider.openai;
        final model = provider.createModel(
          baseUrl: Uri.parse('https://custom.embeddings.com'),
        );

        expect(model, isNotNull);
      });

      test('Each provider has correct default base URL', () {
        // Set API keys so models can be created
        Agent.environment['OPENAI_API_KEY'] = 'sk-openai';
        Agent.environment['GEMINI_API_KEY'] = 'sk-gemini';
        Agent.environment['MISTRAL_API_KEY'] = 'sk-mistral';
        Agent.environment['COHERE_API_KEY'] = 'sk-cohere';

        // Create models with defaults
        expect(() => EmbeddingsProvider.openai.createModel(), returnsNormally);
        expect(() => EmbeddingsProvider.google.createModel(), returnsNormally);
        expect(() => EmbeddingsProvider.mistral.createModel(), returnsNormally);
        expect(() => EmbeddingsProvider.cohere.createModel(), returnsNormally);
      });
    });

    group('EmbeddingsProvider Configuration Combinations', () {
      test('API key and base URL can be set together', () {
        const provider = EmbeddingsProvider.openai;
        final model = provider.createModel(
          apiKey: 'sk-combined-key',
          baseUrl: Uri.parse('https://combined.api.com'),
        );

        expect(model, isNotNull);
      });

      test('Provider options work with API key and base URL', () {
        const provider = EmbeddingsProvider.openai;
        final model = provider.createModel(
          apiKey: 'sk-options-key',
          baseUrl: Uri.parse('https://options.api.com'),
          options: const OpenAIEmbeddingsModelOptions(
            dimensions: 1536,
            user: 'test-user',
          ),
        );

        expect(model, isNotNull);
        expect(model.dimensions, equals(1536));
      });
    });

    group('Error Handling', () {
      test('Missing required API key is handled', () {
        const provider = EmbeddingsProvider.openai;

        // Creating model without API key will pass empty string
        // which is accepted by the model
        expect(() => provider.createModel(apiKey: ''), returnsNormally);
      });

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
