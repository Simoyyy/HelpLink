import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:provider/provider.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/screens/beneficiary/location_picker.dart';
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
  bool _isLoadingLocation = false;
  bool _showMap = true;

  double? _selectedLat;
  double? _selectedLng;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  static const LatLng _defaultCenter = LatLng(1.4582, 110.4387);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.request.title);
    _descriptionController =
        TextEditingController(text: widget.request.description);
    _locationController =
        TextEditingController(text: widget.request.location ?? '');
    _selectedCategory = widget.request.category;
    _isAnonymous = widget.request.isAnonymous;

    if (widget.request.latitude != null && widget.request.longitude != null) {
      _selectedLat = widget.request.latitude;
      _selectedLng = widget.request.longitude;
      _showMap = true;
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: LatLng(_selectedLat!, _selectedLng!),
        ),
      };
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location helpers ─────────────────────────────────────────────────────────

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
        _showSnack(
            'Location permission permanently denied. Enable it in Settings.',
            isError: true);
        return;
      }

      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          setState(() {
            _selectedLat = last.latitude;
            _selectedLng = last.longitude;
            _showMap = true;
            _markers = {
              Marker(
                markerId: const MarkerId('selected'),
                position: LatLng(last.latitude, last.longitude),
              ),
            };
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
                LatLng(last.latitude, last.longitude), 15),
          );
        }
      } catch (_) {}

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final address =
          await _reverseGeocode(position.latitude, position.longitude);

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

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoadingLocation = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        _showSnack('Location not found. Try a more specific address.',
            isError: true);
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
          CameraUpdate.newLatLngZoom(
              LatLng(loc.latitude, loc.longitude), 15),
        );
      }
    } catch (e) {
      _showSnack('Could not find that location. Try a different address.',
          isError: true);
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

  Future<void> _openFullScreenMap() async {
    final result = await Navigator.push<MapPickResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenMapPicker(
          initialPosition: _selectedLat != null
              ? LatLng(_selectedLat!, _selectedLng!)
              : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedLat = result.latLng.latitude;
      _selectedLng = result.latLng.longitude;
      _locationController.text = result.address;
      _showMap = true;
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: result.latLng,
        ),
      };
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(result.latLng, 15),
    );
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

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
      latitude: _selectedLat,
      longitude: _selectedLng,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        _showSnack(error, isError: true);
      } else {
        _showSnack('Request updated successfully!');
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
          // ── Purple header ─────────────────────────────────────────────────
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Edit Help Request',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        'Update your request details',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    _buildLabel('Category *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RequestCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.local_offer_outlined,
                            color: AppTheme.textMuted),
                      ),
                      items: RequestCategory.values.map((cat) {
                        final label = cat == RequestCategory.other
                            ? 'Others'
                            : cat.name[0].toUpperCase() + cat.name.substring(1);
                        return DropdownMenuItem(
                            value: cat, child: Text(label));
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCategory = v!),
                    ),

                    const SizedBox(height: 16),

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

                    _buildLabel('Location *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationController,
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: _searchLocation,
                      decoration: InputDecoration(
                        hintText: 'e.g., UNIMAS, Kota Samarahan, Sarawak',
                        prefixIcon: const Icon(Icons.location_on_outlined,
                            color: AppTheme.primaryPurple),
                        suffixIcon: IconButton(
                          icon: _isLoadingLocation
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Lottie.asset(
                                      'assets/lottie/loading.json',
                                      fit: BoxFit.contain),
                                )
                              : const Icon(Icons.search,
                                  color: AppTheme.primaryPurple),
                          onPressed: () =>
                              _searchLocation(_locationController.text),
                          tooltip: 'Search location',
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

                    const SizedBox(height: 20),

                    // Anonymous toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: Lottie.asset(
                                    'assets/lottie/loading.json',
                                    fit: BoxFit.contain))
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
          InkWell(
            onTap: _isLoadingLocation ? null : _useCurrentLocation,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_isLoadingLocation)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Lottie.asset('assets/lottie/loading.json',
                          fit: BoxFit.contain),
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
          Stack(
            children: [
              SizedBox(
                height: 220,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: _selectedLat != null ? 15 : 11,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: _markers,
                  onTap: (_) => _openFullScreenMap(),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: _openFullScreenMap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_full_rounded,
                            size: 14, color: AppTheme.primaryPurple),
                        SizedBox(width: 4),
                        Text('Tap to expand',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryPurple,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
