import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

class EditRequestScreen extends StatefulWidget {
  final HelpRequest request;
  const EditRequestScreen({super.key, required this.request});

  @override
  State<EditRequestScreen> createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends State<EditRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late RequestCategory _selectedCategory;
  late bool _isAnonymous;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.request.title);
    _descriptionController =
        TextEditingController(text: widget.request.description);
    _locationController =
        TextEditingController(text: widget.request.location ?? '');
    _selectedCategory = widget.request.category;
    _isAnonymous = widget.request.isAnonymous;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final fs = Provider.of<FirestoreService>(context, listen: false);
    final error = await fs.updateHelpRequest(
      requestId: widget.request.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      location: _locationController.text.trim(),
      isAnonymous: _isAnonymous,
      latitude: widget.request.latitude,
      longitude: widget.request.longitude,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.errorRed),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request updated successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // ── Purple header ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.beneficiaryGradientStart,
                  AppTheme.beneficiaryGradientEnd,
                ],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Help Request',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      'Update your request details',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Form ────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Request Title
                    _buildLabel('Request Title *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.description_outlined,
                            color: AppTheme.textMuted),
                        hintText: 'e.g., Need food supplies',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter a title'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Category
                    _buildLabel('Category *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RequestCategory>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.local_offer_outlined,
                            color: AppTheme.textMuted),
                      ),
                      items: RequestCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.name[0].toUpperCase() +
                              cat.name.substring(1)),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCategory = v!),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    _buildLabel('Description *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Describe what kind of help you need...',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter a description'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Location
                    _buildLabel('Location *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_outlined,
                            color: AppTheme.primaryPurple),
                        hintText: 'e.g., UNIMAS, Kota Samarahan, Sarawak',
                        suffixIcon: Icon(Icons.navigation,
                            color: AppTheme.primaryPurple, size: 18),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your location'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // Anonymous toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_off_outlined,
                              color: AppTheme.textMuted, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Post Anonymously',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark)),
                                Text('Your name will be hidden',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isAnonymous,
                            onChanged: (v) =>
                                setState(() => _isAnonymous = v),
                            activeThumbColor: AppTheme.primaryPurple,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Update button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : const Text(
                                'Update Request',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Make sure all information is accurate before updating',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark));
}
