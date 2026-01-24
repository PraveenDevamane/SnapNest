import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/event_provider.dart';
import '../../widgets/custom_widgets.dart';
import 'event_detail_screen.dart';

class EventCreateScreen extends StatefulWidget {
  const EventCreateScreen({super.key});

  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _folderNameController.text = 'General'; // Default folder name
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _folderNameController.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final eventProvider = context.read<EventProvider>();
    final event = await eventProvider.createEvent(
      _eventNameController.text.trim(),
      _folderNameController.text.trim(),
    );

    if (event != null && mounted) {
      // Navigate to event detail
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      );
    } else if (mounted) {
      _showError(eventProvider.error ?? 'Failed to create event');
    }
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
        title: const Text('Create New Event'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, _) {
          return LoadingOverlay(
            isLoading: eventProvider.isLoading,
            message: 'Creating event & linking Google Drive...',
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
                              Icons.celebration,
                              size: 60,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Create Your Event',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share memories with friends & family',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Event name field
                      CustomTextField(
                        controller: _eventNameController,
                        labelText: 'Event Name',
                        hintText: 'e.g., Birthday Party, Wedding',
                        prefixIcon: Icons.event,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an event name';
                          }
                          if (value.trim().length < 3) {
                            return 'Event name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Folder name field
                      CustomTextField(
                        controller: _folderNameController,
                        labelText: 'Initial Folder Name',
                        hintText: 'e.g., General, Ceremony, Reception',
                        prefixIcon: Icons.folder,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a folder name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can add more folders later',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Info card about Google Drive
                      Container(
                        padding: const EdgeInsets.all(AppPadding.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.cloud,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Google Drive Integration',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Photos will be automatically saved to a shared Google Drive folder',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Create button
                      GradientButton(
                        text: 'Create & Link Google Drive',
                        onPressed: _createEvent,
                        icon: Icons.add_circle_outline,
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
