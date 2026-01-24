import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Modern Dark Accents
  static const Color primary = Color(0xFF1A1A2E);         // Deep Navy
  static const Color accent = Color(0xFF6C63FF);          // Vibrant Purple
  static const Color secondary = Color(0xFF3D5AFE);       // Blue accent
  
  // Background Colors - Light Theme
  static const Color background = Color(0xFFF5F7FA);      // Light Gray Background
  static const Color cardBackground = Colors.white;       // Pure White Cards
  static const Color surface = Color(0xFFFFFFFF);         // White Surface
  static const Color surfaceVariant = Color(0xFFF8F9FC); // Slightly off-white
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A2E);     // Dark text
  static const Color textSecondary = Color(0xFF6B7280);   // Gray text
  static const Color textLight = Colors.white;
  static const Color textMuted = Color(0xFF9CA3AF);       // Muted gray
  
  // Status Colors
  static const Color success = Color(0xFF10B981);         // Green
  static const Color error = Color(0xFFEF4444);           // Red
  static const Color warning = Color(0xFFF59E0B);         // Amber
  static const Color info = Color(0xFF3B82F6);            // Blue
  
  // Glassmorphism
  static const Color glassWhite = Color(0xCCFFFFFF);      // 80% white
  static const Color glassBorder = Color(0x33FFFFFF);     // 20% white border
  static const Color shadowColor = Color(0x1A000000);     // Subtle shadow
  
  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF2D2D44)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient accentGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF3D5AFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const Gradient headerGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF374151)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  static List<BoxShadow> get small => [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get large => [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppPadding {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double pill = 100.0;
}

class AppConfig {
  static const String appName = 'SnapNest';
  static const int eventCodeLength = 6;
  static const String qrPrefix = 'snapnest_event_id:';
  static const Duration uploadTimeout = Duration(minutes: 5);
  static const int photoGridColumns = 3;
  static const double photoGridSpacing = 2.0;
}

class DriveConfig {
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];
  
  static String getViewUrl(String fileId) =>
      'https://drive.google.com/uc?export=view&id=$fileId';
  
  static String getDownloadUrl(String fileId) =>
      'https://drive.google.com/uc?export=download&id=$fileId';
  
  static String getThumbnailUrl(String fileId, {int size = 400}) =>
      'https://drive.google.com/thumbnail?id=$fileId&sz=w$size';
}
