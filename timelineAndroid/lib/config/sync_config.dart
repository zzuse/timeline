/// Sync configuration based on iOS implementation
class SyncConfig {
  // OAuth Configuration (aligned with iOS AppConfiguration)
  static const String baseUrl = 'https://zzuse.duckdns.org';
  static const String oauthStartUrl = 'https://zzuse.duckdns.org/auth/oauth_start?client=android';
  static const String oauthExchangeUrl = 'https://zzuse.duckdns.org/api/auth/exchange';
  static const String oauthRefreshUrl = 'https://zzuse.duckdns.org/auth/refresh';
  // Callback URL: com.zzuse.timeline://auth/callback (matches iOS pattern: zzuse.timeline://auth/callback)
  static const String oauthCallbackScheme = 'com.zzuse.timeline';
  static const String oauthCallbackHost = 'auth';
  static const String oauthCallbackPath = '/callback';
  
  // API Configuration
  static const String apiKey = 'replace-me'; // UPDATE THIS
  static const String apiNotesyncEndpoint = '/api/notesync';
  static const String apiNotesEndpoint = '/api/notes';
  
  // Sync Settings
  static const Duration syncInterval = Duration(minutes: 15);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 5);
  static const int maxRequestBytes = 10 * 1024 * 1024; // 10 MB limit
  
  // Conflict Resolution
  static const bool serverWinsConflicts = true; // Server wins by default
}
