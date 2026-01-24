import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/google_drive_service.dart';
import 'services/upload_service.dart';
import 'services/qr_service.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style - Light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const SnapNestApp());
}

class SnapNestApp extends StatelessWidget {
  const SnapNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        Provider<QRService>(
          create: (_) => QRService(),
        ),
        
        // Google Drive Service (depends on AuthService)
        ProxyProvider<AuthService, GoogleDriveService>(
          update: (_, authService, __) => GoogleDriveService(authService),
        ),
        
        // Upload Service (depends on DatabaseService and GoogleDriveService)
        ProxyProvider2<DatabaseService, GoogleDriveService, UploadService>(
          update: (_, dbService, driveService, __) =>
              UploadService(dbService, driveService),
        ),
        
        // Auth Provider (depends on AuthService and DatabaseService)
        ChangeNotifierProxyProvider2<AuthService, DatabaseService, AuthProvider>(
          create: (context) => AuthProvider(
            context.read<AuthService>(),
            context.read<DatabaseService>(),
          ),
          update: (_, authService, dbService, previous) =>
              previous ?? AuthProvider(authService, dbService),
        ),
        
        // Event Provider (depends on multiple services and AuthProvider)
        ChangeNotifierProxyProvider4<
            DatabaseService,
            GoogleDriveService,
            UploadService,
            AuthProvider,
            EventProvider>(
          create: (context) => EventProvider(
            context.read<DatabaseService>(),
            context.read<GoogleDriveService>(),
            context.read<UploadService>(),
            context.read<QRService>(),
            context.read<AuthProvider>(),
          ),
          update: (_, dbService, driveService, uploadService, authProvider, previous) =>
              previous ??
              EventProvider(
                dbService,
                driveService,
                uploadService,
                QRService(),
                authProvider,
              ),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Wrapper that handles auth state and shows appropriate screen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading screen while checking auth state
        if (authProvider.status == AuthStatus.initial) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }

        // Show home screen if authenticated
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }

        // Show sign in screen if not authenticated
        return const SignInScreen();
      },
    );
  }
}
