import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  RequestCategory _selectedCategory = RequestCategory.food;
  bool _isAnonymous = false;
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _showMap = false;

  double? _selectedLat;
  double? _selectedLng;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // Default map centre: Kota Samarahan, Sarawak
  static const LatLng _defaultCenter = LatLng(1.4582, 110.4387);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location helpers ────────────────────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied.', isError: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied. Enable it in Settings.',
            isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final address = await _reverseGeocode(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;
          _locationController.text = address;
          _showMap = true;
          _markers = {
            Marker(
              markerId: const MarkerId('selected'),
              position: LatLng(position.latitude, position.longitude),
            ),
          };
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude), 15),
        );
      }
    } catch (e) {
      _showSnack('Failed to get location: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _onMapTap(LatLng position) async {
    setState(() {
      _selectedLat = position.latitude;
      _selectedLng = position.longitude;
      _isLoadingLocation = true;
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: position,
        ),
      };
    });
    try {
      final address =
          await _reverseGeocode(position.latitude, position.longitude);
      if (mounted) setState(() => _locationController.text = address);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoadingLocation = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        _showSnack('Location not found. Try a more specific address.', isError: true);
        return;
      }
      final loc = locations.first;
      if (mounted) {
        setState(() {
          _selectedLat = loc.latitude;
          _selectedLng = loc.longitude;
          _showMap = true;
          _markers = {
            Marker(
              markerId: const MarkerId('selected'),
              position: LatLng(loc.latitude, loc.longitude),
            ),
          };
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(loc.latitude, loc.longitude), 15),
        );
      }
    } catch (e) {
      _showSnack('Could not find that location. Try a different address.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    final placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return '';
    final p = placemarks.first;
    return [p.name, p.subLocality, p.locality, p.administrativeArea, p.country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);
    final user = authService.userModel;
    if (user == null) return;

    final request = HelpRequest(
      id: '',
      beneficiaryId: user.uid,
      beneficiaryName: user.fullName,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      location: _locationController.text.trim(),
      latitude: _selectedLat,
      longitude: _selectedLng,
      isAnonymous: _isAnonymous,
      createdAt: DateTime.now(),
    );

    final error = await firestoreService.createHelpRequest(request);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        _showSnack(error, isError: true);
      } else {
        _showSnack('Help request submitted successfully!');
        Navigator.pop(context);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // ── Purple gradient header ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding:
                EdgeInsets.fromLTRB(16, topPad + 10, 16, 20),
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
                      'Create Help Request',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      'Tell us what assistance you need',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Scrollable body ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label 1 – Weekly request limit warning
                    _buildWeeklyLimitBanner(),

                    const SizedBox(height: 16),

                    // Label 2 – Submit anonymously toggle
                    _buildAnonymousToggle(),

                    const SizedBox(height: 20),

                    // Label 3 – Form fields
                    _buildLabel('Request Title'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                          hintText: 'e.g., Food Assistance Needed'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter a title'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    _buildLabel('Category'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RequestCategory>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(),
                      items: RequestCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(
                              cat.name[0].toUpperCase() + cat.name.substring(1)),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCategory = v!),
                    ),

                    const SizedBox(height: 16),

                    _buildLabel('Description'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          hintText: 'Describe what kind of help you need...'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter a description'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Label 4 – Location + Google Maps
                    _buildLabel('Location'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationController,
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: _searchLocation,
                      decoration: InputDecoration(
                        hintText: 'e.g., UNIMAS, Kota Samarahan, Sarawak',
                        prefixIcon: const Icon(Icons.location_on_outlined,
                            color: AppTheme.primaryPurple),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: _isLoadingLocation
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryPurple),
                                    )
                                  : const Icon(Icons.search,
                                      color: AppTheme.primaryPurple),
                              onPressed: () => _searchLocation(
                                  _locationController.text),
                              tooltip: 'Search location',
                            ),
                            IconButton(
                              icon: Icon(
                                  _showMap ? Icons.map : Icons.map_outlined,
                                  color: AppTheme.primaryPurple),
                              onPressed: () =>
                                  setState(() => _showMap = !_showMap),
                              tooltip: _showMap ? 'Close map' : 'Show map',
                            ),
                          ],
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your location'
                          : null,
                    ),

                    if (_showMap) ...[
                      const SizedBox(height: 10),
                      _buildMapCard(),
                    ],

                    const SizedBox(height: 28),

                    // Label 5 – Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRequest,
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
                                'Submit Request',
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
                        'Your request will be visible to donors in your area',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textMuted),
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

  // ── Sub-widgets ──────────────────────────────────────────────────────────────

  Widget _buildWeeklyLimitBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.warningOrange, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weekly Request Limit',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
                SizedBox(height: 2),
                Text(
                  'You can submit a maximum of 5 requests per week. '
                  'Requests reset every Monday at 12:00 AM.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                Text('Submit Anonymously',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
                Text('Hide your identity from donors',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v),
            activeThumbColor: AppTheme.primaryPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    final center = _selectedLat != null
        ? LatLng(_selectedLat!, _selectedLng!)
        : _defaultCenter;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // "Use current location" row
          InkWell(
            onTap: _isLoadingLocation ? null : _useCurrentLocation,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_isLoadingLocation)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryPurple),
                    )
                  else
                    const Icon(Icons.navigation,
                        size: 18, color: AppTheme.primaryPurple),
                  const SizedBox(width: 10),
                  const Text(
                    'Use current location',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryPurple),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Google Map – tap to pick location
          SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: _selectedLat != null ? 15 : 11,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              onTap: _onMapTap,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // "Close map" row
          InkWell(
            onTap: () => setState(() => _showMap = false),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                  SizedBox(width: 6),
                  Text('Close map',
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark));
  }
}
