import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/event_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../qr_scanner_screen.dart';

class JoinEventScreen extends StatefulWidget {
  const JoinEventScreen({super.key});

  @override
  State<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends State<JoinEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final eventProvider = context.read<EventProvider>();
    final success = await eventProvider.joinEvent(_codeController.text.trim());

    if (success && mounted) {
      _showSuccess('Join request sent! Waiting for approval.');
      Navigator.of(context).pop();
    } else if (mounted) {
      _showError(eventProvider.error ?? 'Failed to join event');
    }
  }

  Future<void> _scanQRCode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QRScannerScreen()));

    if (code != null) {
      _codeController.text = code;
      _joinEvent();
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Event'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, _) {
          return LoadingOverlay(
            isLoading: eventProvider.isLoading,
            message: 'Joining event...',
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppPadding.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header illustration
                      Container(
                        padding: const EdgeInsets.all(AppPadding.xl),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.group_add,
                              size: 60,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Join an Event',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter the event code or scan QR code',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Code entry section
                      Text(
                        'Enter Event Code',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _codeController,
                        hintText: 'e.g., ABC123',
                        prefixIcon: Icons.tag,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an event code';
                          }
                          if (value.trim().length !=
                              AppConfig.eventCodeLength) {
                            return 'Event code must be ${AppConfig.eventCodeLength} characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      GradientButton(text: 'Join Event', onPressed: _joinEvent),
                      const SizedBox(height: 32),
                      // Or divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // QR scan section
                      Text(
                        'Scan QR Code',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _scanQRCode,
                        child: Container(
                          padding: const EdgeInsets.all(AppPadding.xl),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tap to scan QR code',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Point your camera at the event QR code',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
