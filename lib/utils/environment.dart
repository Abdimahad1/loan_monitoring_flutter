class Environment {
  // Environment types
  static const String development = 'development';
  static const String production = 'production';

  // Current environment - change this when deploying
  static const String current = development;

  // Base URLs for different environments
  static const Map<String, String> baseUrls = {
    development: 'http://192.168.100.25:5000',  // Your local IP
    production: 'https://api.yourproduction.com',
  };

  // Get current base URL
  static String get baseUrl => baseUrls[current]!;

  // Check environment
  static bool get isDevelopment => current == development;
  static bool get isProduction => current == production;
}