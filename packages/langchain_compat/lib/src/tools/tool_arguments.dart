/// Type-safe wrapper for tool arguments
library;

import 'package:meta/meta.dart';

/// Provides type-safe access to tool arguments with validation
@immutable
class ToolArguments {
  /// Creates a new ToolArguments instance from a map
  const ToolArguments(this._args);

  /// Creates a new ToolArguments instance from a dynamic value
  factory ToolArguments.from(dynamic value) {
    if (value is Map<String, Object?>) {
      return ToolArguments(value);
    } else if (value is Map) {
      // Convert to Map<String, Object?>
      return ToolArguments(Map<String, Object?>.from(value));
    } else if (value == null) {
      return const ToolArguments({});
    } else {
      throw ArgumentError(
        'Cannot create ToolArguments from ${value.runtimeType}',
      );
    }
  }

  final Map<String, Object?> _args;

  /// Gets a required argument of type T
  ///
  /// Throws [ArgumentError] if the argument is missing or of wrong type
  T get<T>(String key) {
    if (!_args.containsKey(key)) {
      throw ArgumentError('Missing required argument: $key');
    }

    final value = _args[key];
    if (value is! T) {
      throw ArgumentError(
        'Argument $key has type ${value.runtimeType} but expected $T',
      );
    }

    return value;
  }

  /// Gets an optional argument of type T
  ///
  /// Returns null if the argument is missing
  /// Throws [ArgumentError] if present but of wrong type
  T? getOptional<T>(String key) {
    if (!_args.containsKey(key)) {
      return null;
    }

    final value = _args[key];
    if (value == null) {
      return null;
    }

    if (value is T) {
      return value as T;
    } else {
      throw ArgumentError(
        'Argument $key has type ${value.runtimeType} but expected $T',
      );
    }
  }

  /// Gets an argument with a default value if not present
  T getOrDefault<T>(String key, T defaultValue) {
    final value = getOptional<T>(key);
    return value ?? defaultValue;
  }

  /// Checks if an argument exists
  bool has(String key) => _args.containsKey(key);

  /// Gets all argument keys
  Set<String> get keys => _args.keys.toSet();

  /// Checks if arguments are empty
  bool get isEmpty => _args.isEmpty;

  /// Checks if arguments are not empty
  bool get isNotEmpty => _args.isNotEmpty;

  /// Gets the number of arguments
  int get length => _args.length;

  /// Validates that all required keys are present
  ///
  /// Throws [ArgumentError] if any required key is missing
  void validate(List<String> requiredKeys) {
    for (final key in requiredKeys) {
      if (!has(key)) {
        throw ArgumentError('Missing required argument: $key');
      }
    }
  }

  /// Validates that only allowed keys are present
  ///
  /// Throws [ArgumentError] if any key is not in the allowed list
  void validateAllowed(List<String> allowedKeys) {
    final allowedSet = allowedKeys.toSet();
    for (final key in keys) {
      if (!allowedSet.contains(key)) {
        throw ArgumentError('Unknown argument: $key');
      }
    }
  }

  /// Converts arguments to a Map
  Map<String, Object?> toMap() => Map.unmodifiable(_args);

  @override
  String toString() => 'ToolArguments($_args)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolArguments &&
          runtimeType == other.runtimeType &&
          _args.toString() == other._args.toString();

  @override
  int get hashCode => _args.hashCode;
}
