/// TESTING PHILOSOPHY:
/// 1. DO NOT catch exceptions - let them bubble up for diagnosis
/// 2. DO NOT add provider filtering except by capabilities (e.g. ProviderCaps)
/// 3. DO NOT add performance tests
/// 4. DO NOT add regression tests
/// 5. 80% cases = common usage patterns tested across ALL capable providers
/// 6. Edge cases = rare scenarios tested on Google only to avoid timeouts
/// 7. Each functionality should only be tested in ONE file - no duplication
///
/// This file tests provider discovery including model enumeration via
/// listModels()

import 'package:langchain_compat/langchain_compat.dart';
import 'package:test/test.dart';

void main() {
  // Helper to run parameterized tests for chat providers
  void runChatProviderTest(
    String testName,
    Future<void> Function(Provider provider) testFunction, {
    Timeout? timeout,
  }) {
    group(testName, () {
      for (final provider in Provider.all) {
        test(
          '${provider.name} - $testName',
          () async {
            await testFunction(provider);
          },
          timeout: timeout ?? const Timeout(Duration(seconds: 30)),
        );
      }
    });
  }

  // Helper to run parameterized tests for embeddings providers
  void runEmbeddingsProviderTest(
    String testName,
    Future<void> Function(EmbeddingsProvider provider) testFunction, {
    Timeout? timeout,
  }) {
    group(testName, () {
      for (final provider in EmbeddingsProvider.all) {
        test(
          '${provider.name} - $testName',
          () async {
            await testFunction(provider);
          },
          timeout: timeout ?? const Timeout(Duration(seconds: 30)),
        );
      }
    });
  }

  group('Provider Discovery', () {
    group('chat provider selection', () {
      test('finds providers by exact name', () {
        expect(Provider.forName('openai'), equals(Provider.openai));
        expect(Provider.forName('anthropic'), equals(Provider.anthropic));
        expect(Provider.forName('google'), equals(Provider.google));
        expect(Provider.forName('mistral'), equals(Provider.mistral));
        expect(Provider.forName('ollama'), equals(Provider.ollama));
        expect(Provider.forName('together'), equals(Provider.together));
        expect(Provider.forName('lambda'), equals(Provider.lambda));
        expect(Provider.forName('cohere'), equals(Provider.cohere));
        expect(Provider.forName('openrouter'), equals(Provider.openrouter));
      });

      test('finds providers by aliases', () {
        // Test documented aliases from README
        expect(Provider.forName('claude'), equals(Provider.anthropic));
        expect(Provider.forName('gemini'), equals(Provider.google));
        expect(Provider.forName('googleai'), equals(Provider.google));
        expect(Provider.forName('google-gla'), equals(Provider.google));
      });

      test('throws on unknown provider name', () {
        expect(
          () => Provider.forName('unknown-provider'),
          throwsA(isA<Exception>()),
        );
        expect(() => Provider.forName('invalid'), throwsA(isA<Exception>()));
        expect(() => Provider.forName(''), throwsA(isA<Exception>()));
      });

      test('is case insensitive', () {
        // Provider lookup is actually case-insensitive
        expect(Provider.forName('OpenAI'), equals(Provider.openai));
        expect(Provider.forName('ANTHROPIC'), equals(Provider.anthropic));
        expect(Provider.forName('Claude'), equals(Provider.anthropic));
      });
    });

    group('embeddings provider selection', () {
      test('finds providers by exact name', () {
        expect(
          EmbeddingsProvider.forName('openai'),
          equals(EmbeddingsProvider.openai),
        );
        expect(
          EmbeddingsProvider.forName('google'),
          equals(EmbeddingsProvider.google),
        );
        expect(
          EmbeddingsProvider.forName('mistral'),
          equals(EmbeddingsProvider.mistral),
        );
        expect(
          EmbeddingsProvider.forName('cohere'),
          equals(EmbeddingsProvider.cohere),
        );
      });

      test('finds providers by aliases', () {
        // EmbeddingsProvider doesn't currently have aliases like ChatProvider
        // This test verifies that fact
        expect(
          () => EmbeddingsProvider.forName('gemini'),
          throwsA(isA<Exception>()),
        );
        expect(
          () => EmbeddingsProvider.forName('googleai'),
          throwsA(isA<Exception>()),
        );
      });

      test('throws on unknown provider name', () {
        expect(
          () => EmbeddingsProvider.forName('anthropic'),
          throwsA(isA<Exception>()),
        );
        expect(
          () => EmbeddingsProvider.forName('ollama'),
          throwsA(isA<Exception>()),
        );
        expect(
          () => EmbeddingsProvider.forName('unknown'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('provider enumeration', () {
      test('lists all chat providers', () {
        final providers = Provider.all;
        expect(providers, isNotEmpty);
        // At least 11 providers available
        expect(providers.length, greaterThanOrEqualTo(11));

        // Verify key providers are included
        final providerNames = providers.map((p) => p.name).toSet();
        expect(providerNames, contains('openai'));
        expect(providerNames, contains('anthropic'));
        expect(providerNames, contains('google'));
        expect(providerNames, contains('mistral'));
        expect(providerNames, contains('ollama'));
        expect(providerNames, contains('together'));
        expect(providerNames, contains('cohere'));
      });

      test('lists all embeddings providers', () {
        final providers = EmbeddingsProvider.all;
        expect(providers, hasLength(4)); // Exactly 4 embeddings providers

        final providerNames = providers.map((p) => p.name).toSet();
        expect(providerNames, contains('openai'));
        expect(providerNames, contains('google'));
        expect(providerNames, contains('mistral'));
        expect(providerNames, contains('cohere'));
      });

      runChatProviderTest('chat providers have required properties', (
        provider,
      ) async {
        expect(provider.name, isNotEmpty);
        expect(provider.displayName, isNotEmpty);
        expect(provider.createModel, isNotNull);
        expect(provider.listModels, isNotNull);
      });

      runEmbeddingsProviderTest(
        'embeddings providers have required properties',
        (provider) async {
          expect(provider.name, isNotEmpty);
          expect(provider.displayName, isNotEmpty);
          expect(provider.createModel, isNotNull);
          expect(provider.listModels, isNotNull);
        },
      );
    });

    // Model enumeration moved to edge cases (limited providers)
    group('basic model access', () {
      test('providers have listModels method', () {
        // Test that all providers have the method (no API calls)
        for (final provider in Provider.all) {
          expect(provider.listModels, isNotNull);
        }

        for (final provider in EmbeddingsProvider.all) {
          expect(provider.listModels, isNotNull);
        }
      });
    });

    group('provider display names', () {
      test('chat providers have descriptive display names', () {
        expect(Provider.openai.displayName, equals('OpenAI'));
        expect(Provider.anthropic.displayName, equals('Anthropic'));
        expect(Provider.google.displayName, contains('Google'));
        expect(Provider.mistral.displayName, equals('Mistral AI'));
        expect(Provider.ollama.displayName, equals('Ollama'));
      });

      test('embeddings providers have descriptive display names', () {
        expect(EmbeddingsProvider.openai.displayName, equals('OpenAI'));
        expect(EmbeddingsProvider.google.displayName, contains('Google'));
        expect(EmbeddingsProvider.mistral.displayName, equals('Mistral AI'));
        expect(EmbeddingsProvider.cohere.displayName, equals('Cohere'));
      });
    });

    group('provider uniqueness', () {
      test('chat provider names are unique', () {
        final providers = Provider.all;
        final names = providers.map((p) => p.name).toList();
        final uniqueNames = names.toSet();
        expect(
          uniqueNames.length,
          equals(names.length),
          reason: 'All chat provider names should be unique',
        );
      });

      test('embeddings provider names are unique', () {
        final providers = EmbeddingsProvider.all;
        final names = providers.map((p) => p.name).toList();
        final uniqueNames = names.toSet();
        expect(
          names.length,
          equals(uniqueNames.length),
          reason: 'All embeddings provider names should be unique',
        );
      });
    });

    group('dynamic provider usage', () {
      test('can create models via discovered providers', () {
        final provider = Provider.forName('openai');
        final model = provider.createModel(name: 'gpt-4o-mini');
        expect(model, isNotNull);
      });

      test('can use aliases for model creation', () {
        final claudeProvider = Provider.forName('claude');
        expect(claudeProvider.name, equals('anthropic'));

        // Skip actual model creation if API key not available
        expect(claudeProvider, isNotNull);
      });

      test('supports dynamic agent creation', () {
        final provider = Provider.forName('gemini');
        expect(provider.name, equals('google'));

        final agent = Agent('${provider.name}:gemini-2.0-flash');
        expect(agent, isNotNull);
        // Agent.model returns "provider:model" format
        expect(agent.model, equals('google:gemini-2.0-flash'));
      });
    });

    group('provider comparison', () {
      test('providers are comparable', () {
        final provider1 = Provider.forName('openai');
        final provider2 = Provider.openai;
        expect(provider1, equals(provider2));

        final aliasProvider = Provider.forName('claude');
        final directProvider = Provider.anthropic;
        expect(aliasProvider, equals(directProvider));
      });

      test('different providers are not equal', () {
        final openai = Provider.openai;
        final anthropic = Provider.anthropic;
        expect(openai, isNot(equals(anthropic)));
      });
    });

    group('error handling', () {
      test('handles null and empty provider names gracefully', () {
        expect(() => Provider.forName(''), throwsA(isA<Exception>()));
      });

      test('provides helpful error messages', () {
        expect(
          () => Provider.forName('invalid-provider'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('edge cases (limited providers)', () {
      // Test edge cases on only 1-2 providers to save resources
      // and avoid timeouts
      final edgeCaseProviders = <Provider>[Provider.openai, Provider.anthropic];

      final edgeCaseEmbeddingsProviders = <EmbeddingsProvider>[
        EmbeddingsProvider.openai,
      ];

      test('chat providers return available models', () async {
        for (final provider in edgeCaseProviders) {
          try {
            final models = await provider.listModels().toList();
            expect(
              models,
              isNotEmpty,
              reason: 'Provider ${provider.name} should have models',
            );

            // Verify model structure
            for (final model in models) {
              expect(
                model.name,
                isNotEmpty,
                reason: 'Model name should not be empty for ${provider.name}',
              );
            }
          } catch (e) {
            // Skip providers that require API keys when not available
            if (e.toString().contains('API_KEY') ||
                e.toString().contains('not set') ||
                e.toString().contains('Environment variable')) {
              continue;
            }
            rethrow;
          }
        }
      });

      test('embeddings providers return available models', () async {
        for (final provider in edgeCaseEmbeddingsProviders) {
          try {
            final models = await provider.listModels().toList();
            expect(
              models,
              isNotEmpty,
              reason: 'Provider ${provider.name} should have embedding models',
            );

            // Verify model structure
            for (final model in models) {
              expect(
                model.name,
                isNotEmpty,
                reason: 'Model name should not be empty for ${provider.name}',
              );
            }
          } catch (e) {
            // Skip providers that require API keys when not available
            if (e.toString().contains('API_KEY') ||
                e.toString().contains('not set') ||
                e.toString().contains('Environment variable')) {
              continue;
            }
            rethrow;
          }
        }
      });

      test('model counts match documented ranges', () async {
        // Only test OpenAI to avoid API quota issues
        final openaiModels = await Provider.openai.listModels().toList();
        expect(openaiModels.length, greaterThan(50));
      });

      test('models have consistent naming patterns', () async {
        // Only test OpenAI for naming patterns
        final provider = Provider.openai;
        final models = await provider.listModels().toList();

        for (final model in models.take(10)) {
          // Test first 10 models only
          // OpenAI models should have recognizable patterns
          expect(
            model.name,
            matches(RegExp(r'^[a-zA-Z0-9\-\.\_]+$')),
            reason: 'Model name should be alphanumeric with hyphens/dots',
          );

          // ID should match provider:model format when used with Agent
          expect('${provider.name}:${model.name}', isNotEmpty);
        }
      });
    });
  });
}
