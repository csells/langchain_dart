import '../embeddings_model_options.dart';

/// Options for Mistral embeddings models.
class MistralEmbeddingsModelOptions extends EmbeddingsModelOptions {
  /// Creates new Mistral embeddings model options.
  const MistralEmbeddingsModelOptions({
    super.dimensions,
    super.batchSize,
    this.encodingFormat,
  });

  /// The encoding format for the embeddings.
  /// Can be 'float' or 'base64'.
  final String? encodingFormat;
}
