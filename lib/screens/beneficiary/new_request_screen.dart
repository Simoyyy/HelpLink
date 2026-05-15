import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' hide Marker;
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
  final _categoryController = TextEditingController(text: 'Food');
  final _categoryFieldKey = GlobalKey();

  RequestCategory _selectedCategory = RequestCategory.food;
  bool _isAnonymous = false;
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _showMap = true;

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
    _categoryController.dispose();
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

      // Show map instantly with cached position, then refine
      Position? position;
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

      position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final address = await _reverseGeocode(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedLat = position!.latitude;
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

  // ── Full-screen map picker ───────────────────────────────────────────────────

  Future<void> _openFullScreenMap() async {
    final result = await Navigator.push<_MapPickResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenMapPicker(
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Create Help Request',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        'Tell us what assistance you need',
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
                    Theme(
                      data: Theme.of(context).copyWith(
                        popupMenuTheme: PopupMenuThemeData(
                          color: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        highlightColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                        splashColor: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      ),
                      child: Builder(
                        builder: (menuCtx) => GestureDetector(
                          onTap: () => _showCategoryMenu(menuCtx),
                          child: AbsorbPointer(
                            child: TextFormField(
                              key: _categoryFieldKey,
                              controller: _categoryController,
                              readOnly: true,
                              showCursor: false,
                              decoration: const InputDecoration(
                                hintText: 'Select a category',
                                suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                        suffixIcon: IconButton(
                          icon: _isLoadingLocation
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Lottie.asset('assets/lottie/loading.json', fit: BoxFit.contain),
                                )
                              : const Icon(Icons.search,
                                  color: AppTheme.primaryPurple),
                          onPressed: () => _searchLocation(_locationController.text),
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
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: Lottie.asset('assets/lottie/loading.json', fit: BoxFit.contain))
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
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Lottie.asset('assets/lottie/loading.json', fit: BoxFit.contain),
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

          // Google Map – tap anywhere to open full-screen picker
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
              // Expand hint overlay
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: _openFullScreenMap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_full_rounded, size: 14, color: AppTheme.primaryPurple),
                        SizedBox(width: 4),
                        Text('Tap to expand', style: TextStyle(fontSize: 11, color: AppTheme.primaryPurple, fontWeight: FontWeight.w500)),
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

  void _showCategoryMenu(BuildContext context) {
    final box =
        _categoryFieldKey.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    showMenu<RequestCategory>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        screenSize.width - offset.dx - box.size.width,
        screenSize.height - offset.dy - box.size.height,
      ),
      constraints: BoxConstraints(
        minWidth: box.size.width,
        maxWidth: box.size.width,
        maxHeight: 56.0 * 3.5,
      ),
      items: RequestCategory.values.map((cat) {
        final label = cat == RequestCategory.other
            ? 'Others'
            : cat.name[0].toUpperCase() + cat.name.substring(1);
        final isSelected = _selectedCategory == cat;
        return PopupMenuItem<RequestCategory>(
          value: cat,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? AppTheme.primaryPurple
                  : AppTheme.textDark,
            ),
          ),
        );
      }).toList(),
    ).then((cat) {
      if (cat == null) return;
      final label = cat == RequestCategory.other
          ? 'Others'
          : cat.name[0].toUpperCase() + cat.name.substring(1);
      setState(() {
        _selectedCategory = cat;
        _categoryController.text = label;
      });
    });
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark));
  }
}

// ── Full-screen map picker ────────────────────────────────────────────────────

class _MapPickResult {
  final LatLng latLng;
  final String address;
  const _MapPickResult({required this.latLng, required this.address});
}

class _FullScreenMapPicker extends StatefulWidget {
  final LatLng? initialPosition;
  const _FullScreenMapPicker({this.initialPosition});

  @override
  State<_FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<_FullScreenMapPicker> {
  static const LatLng _default = LatLng(1.4582, 110.4387);

  GoogleMapController? _controller;
  LatLng? _picked;
  Set<Marker> _markers = {};
  String _address = '';
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _picked = widget.initialPosition;
      _markers = {
        Marker(markerId: const MarkerId('picked'), position: widget.initialPosition!),
      };
      _address = 'Loading address…';
      _geocode(widget.initialPosition!);
    }
  }

  Future<void> _onTap(LatLng pos) async {
    setState(() {
      _picked = pos;
      _markers = {Marker(markerId: const MarkerId('picked'), position: pos)};
      _address = '';
      _isGeocoding = true;
    });
    await _geocode(pos);
  }

  Future<void> _geocode(LatLng pos) async {
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (marks.isNotEmpty) {
        final p = marks.first;
        setState(() {
          _address = [p.name, p.subLocality, p.locality, p.administrativeArea, p.country]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address =
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        });
      }
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPosition ?? _default;
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initial,
              zoom: widget.initialPosition != null ? 15 : 11,
            ),
            onMapCreated: (c) => _controller = c,
            markers: _markers,
            onTap: _onTap,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer()),
            },
          ),

          // Top bar: back button + address pill
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: AppTheme.primaryPurple),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _picked == null
                                    ? 'Tap the map to pin your location'
                                    : _isGeocoding
                                        ? 'Getting address…'
                                        : _address.isNotEmpty
                                            ? _address
                                            : 'Location selected',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _picked == null
                                      ? AppTheme.textMuted
                                      : AppTheme.textDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: confirm button or hint
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: _picked == null
                ? Center(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 3,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Text(
                          'Tap anywhere on the map to pin your location',
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _isGeocoding
                        ? null
                        : () => Navigator.pop(
                              context,
                              _MapPickResult(latLng: _picked!, address: _address),
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      disabledBackgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: _isGeocoding
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Confirm Location',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
