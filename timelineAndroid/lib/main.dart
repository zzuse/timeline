import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'ui/screens/timeline_screen.dart';
import 'data/notes_repository.dart';
import 'services/auth_session_manager.dart';
import 'services/sync_engine.dart';
import 'services/notesync_client.dart';
import 'services/sync_queue.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TimelineApp());
}

class TimelineApp extends StatefulWidget {
  const TimelineApp({super.key});

  @override
  State<TimelineApp> createState() => _TimelineAppState();
}

class _TimelineAppState extends State<TimelineApp> {
  static const platform = MethodChannel('com.zzuse.timeline/deeplink');
  
  late final AuthSessionManager _authManager;
  late final NotesRepository _repository;
  late final NotesyncClient _syncClient;
  late final SyncQueue _syncQueue;
  late final SyncEngine _syncEngine;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupDeepLinkListener();
  }

  void _initializeServices() {
    _authManager = AuthSessionManager();
    _repository = NotesRepository();
    _syncClient = NotesyncClient(authManager: _authManager);
    _syncQueue = SyncQueue();
    _syncEngine = SyncEngine(
      repository: _repository,
      authManager: _authManager,
      syncClient: _syncClient,
      syncQueue: _syncQueue,
    );
  }

  void _setupDeepLinkListener() {
    platform.setMethodCallHandler((call) async {
      print('MethodChannel received: ${call.method}, arguments: ${call.arguments}');
      
      if (call.method == 'onDeepLink') {
        try {
          final dynamic args = call.arguments;
          print('Arguments type: ${args.runtimeType}, value: $args');
          
          if (args == null) {
            print('ERROR: Deep link arguments are null');
            return;
          }
          
          final String url = args.toString();
          print('Parsing URL: $url');
          
          final uri = Uri.parse(url);
          print('Calling handleCallback with URI: $uri');
          
          await _authManager.handleCallback(uri);
          print('handleCallback completed');
        } catch (e, stack) {
          print('ERROR in deep link handler: $e');
          print('Stack trace: $stack');
        }
      }
    });
  }

  @override
  void dispose() {
    _syncEngine.dispose();
    _syncClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authManager),
        ChangeNotifierProvider.value(value: _syncEngine),
        Provider.value(value: _repository),
      ],
      child: MaterialApp(
        title: 'Timeline Notes',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            elevation: 4,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const TimelineScreen(),
      ),
    );
  }
}
