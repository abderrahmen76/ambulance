enum Environment { development, production }

bool _isAllowedDevelopmentHttpUrl(String value) {
  return value.startsWith('http://127.0.0.1') ||
      value.startsWith('http://10.') ||
      value.startsWith('http://192.168.') ||
      value.startsWith('http://localhost');
}

String _validateEndpointUrl(String value, {required bool allowDevelopmentHttp}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw StateError('Backend URL is not configured.');
  }

  if (trimmed.startsWith('https://')) {
    return trimmed;
  }

  if (allowDevelopmentHttp && _isAllowedDevelopmentHttpUrl(trimmed)) {
    return trimmed;
  }

  throw StateError('Insecure backend URL is not allowed: $trimmed');
}

class EnvironmentConfig {
  static const Environment currentEnvironment = Environment.production;

  static String get notificationBackendUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return _validateEndpointUrl(
          'http://192.168.56.1:3000',
          allowDevelopmentHttp: true,
        );
      case Environment.production:
        return _validateEndpointUrl(
          'https://notification-server-test.onrender.com',
          allowDevelopmentHttp: false,
        );
    }
  }

  static String get backendName {
    switch (currentEnvironment) {
      case Environment.development:
        return 'Development';
      case Environment.production:
        return 'Production';
    }
  }
}

