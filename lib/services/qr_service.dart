import 'dart:math';
import '../core/constants.dart';

class QRService {
  static final Random _random = Random.secure();
  
  /// Generate a random alphanumeric event code
  String generateEventCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluding confusing chars
    return List.generate(
      AppConfig.eventCodeLength,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// Create QR code data from event code
  String createQRData(String eventCode) {
    return '${AppConfig.qrPrefix}${eventCode.toUpperCase()}';
  }

  /// Parse event code from QR data
  String? parseQRData(String data) {
    if (data.startsWith(AppConfig.qrPrefix)) {
      final code = data.substring(AppConfig.qrPrefix.length);
      if (code.length == AppConfig.eventCodeLength) {
        return code.toUpperCase();
      }
    }
    return null;
  }

  /// Validate event code format
  bool isValidEventCode(String code) {
    if (code.length != AppConfig.eventCodeLength) return false;
    return RegExp(r'^[A-Z0-9]+$').hasMatch(code.toUpperCase());
  }

  /// Format event code for display (add spacing)
  String formatEventCode(String code) {
    final upper = code.toUpperCase();
    if (upper.length <= 3) return upper;
    return '${upper.substring(0, 3)} ${upper.substring(3)}';
  }

  /// Clean event code input
  String cleanEventCode(String input) {
    return input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }
}
