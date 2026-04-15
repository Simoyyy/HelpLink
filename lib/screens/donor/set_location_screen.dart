import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:helplink/models/help_request_model.dart';
import 'package:helplink/services/auth_service.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/screens/donor/request_detail_screen.dart';
import 'package:helplink/utils/app_theme.dart';

class SetLocationScreen extends StatefulWidget {
  const SetLocationScreen({super.key});

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  final _searchController = TextEditingController();
  GoogleMapController? _mapController;

  double _radiusKm = 2.5;
  double? _currentLat;
  double? _currentLng;
  String _locationText = '';
  bool _isLoadingLocation = true;
  List<_NearbyRequest> _nearbyRequests = [];

  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Category helpers ──────────────────────────────────────────────────────

  double _categoryHue(RequestCategory cat) {
    switch (cat) {
      case RequestCategory.food:
        return BitmapDescriptor.hueBlue;
      case RequestCategory.medical:
        return BitmapDescriptor.hueRed;
      case RequestCategory.education:
        return BitmapDescriptor.hueGreen;
      case RequestCategory.transportation:
        return BitmapDescriptor.hueOrange;
      case RequestCategory.housing:
        return BitmapDescriptor.hueViolet;
      default:
        return BitmapDescriptor.hueRose;
    }
  }

  // ── Map update ────────────────────────────────────────────────────────────

  void _updateMap() {
    if (_currentLat == null || _currentLng == null) return;

    final center = LatLng(_currentLat!, _currentLng!);
    final markers = <Marker>{};
    final circles = <Circle>{};

    // User location marker
    markers.add(Marker(
      markerId: const MarkerId('user_location'),
      position: center,
      icon:
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(
        title: 'Your Location',
        snippet: _locationText.isNotEmpty ? _locationText : null,
      ),
      zIndexInt: 2,
    ));

    // Radius circle
    circles.add(Circle(
      circleId: const CircleId('search_radius'),
      center: center,
      radius: _radiusKm * 1000,
      fillColor: AppTheme.primaryBlue.withValues(alpha: 0.08),
      strokeColor: AppTheme.primaryBlue.withValues(alpha: 0.5),
      strokeWidth: 2,
    ));

    // Request markers — colour-coded by category
    for (final item in _nearbyRequests) {
      final r = item.request;
      if (r.latitude == null || r.longitude == null) continue;
      markers.add(Marker(
        markerId: MarkerId(r.id),
        position: LatLng(r.latitude!, r.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(_categoryHue(r.category)),
        infoWindow: InfoWindow(
          title: r.title,
          snippet: '${r.categoryLabel} • '
              '${item.distanceKm != null ? '${item.distanceKm!.toStringAsFixed(1)} km' : ''}',
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RequestDetailScreen(request: r)),
        ),
      ));
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });

    // Pan camera to user location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        center,
        _radiusKm <= 2 ? 14.5 : _radiusKm <= 10 ? 13 : 11,
      ),
    );
  }

  // ── Location loading ──────────────────────────────────────────────────────

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useStoredLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useStoredLocation();
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _useStoredLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      _currentLat = position.latitude;
      _currentLng = position.longitude;

      try {
        final placemarks =
            await placemarkFromCoordinates(_currentLat!, _currentLng!);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          _locationText =
              '${p.name ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}'
                  .replaceAll(RegExp(r'^, |, $'), '');
          _searchController.text = _locationText;
        }
      } catch (_) {}

      await _filterNearbyRequests();
    } catch (_) {
      _useStoredLocation();
    }

    if (mounted) setState(() => _isLoadingLocation = false);
  }

  void _useStoredLocation() {
    final user =
        Provider.of<AuthService>(context, listen: false).userModel;
    if (user != null && user.latitude != null && user.longitude != null) {
      _currentLat = user.latitude;
      _currentLng = user.longitude;
      _locationText = user.location ?? '';
      _searchController.text = _locationText;
      _filterNearbyRequests();
    }
    if (mounted) setState(() => _isLoadingLocation = false);
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        _currentLat = locations.first.latitude;
        _currentLng = locations.first.longitude;
        _locationText = query;
        await _filterNearbyRequests();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location not found. Please try a different search.'),
          backgroundColor: AppTheme.errorRed,
        ));
      }
    }
  }

  Future<void> _filterNearbyRequests() async {
    if (_currentLat == null || _currentLng == null) return;

    final fs = Provider.of<FirestoreService>(context, listen: false);
    final requests = await fs.getAvailableRequests().first;
    final nearby = <_NearbyRequest>[];

    for (final r in requests) {
      if (r.latitude != null && r.longitude != null) {
        final dist = Geolocator.distanceBetween(
                _currentLat!, _currentLng!, r.latitude!, r.longitude!) /
            1000;
        if (dist <= _radiusKm) {
          nearby.add(_NearbyRequest(request: r, distanceKm: dist));
        }
      } else if (_radiusKm >= 50) {
        nearby.add(_NearbyRequest(request: r, distanceKm: null));
      }
    }

    nearby.sort((a, b) {
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });

    if (mounted) {
      setState(() => _nearbyRequests = nearby);
      _updateMap();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          // Blue gradient header with search bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(0, 48, 0, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.donorGradientStart, AppTheme.donorGradientEnd],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Text(
                        'Set Location',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _searchLocation(),
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textMuted),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Map ──
                  SizedBox(
                    width: double.infinity,
                    height: 240,
                    child: _isLoadingLocation
                        ? const Center(child: CircularProgressIndicator())
                        : _currentLat == null
                            ? const Center(
                                child: Text('Enable location to see map',
                                    style: TextStyle(
                                        color: AppTheme.textMuted)),
                              )
                            : GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(_currentLat!, _currentLng!),
                                  zoom: 14,
                                ),
                                onMapCreated: (controller) {
                                  _mapController = controller;
                                  _updateMap();
                                },
                                markers: _markers,
                                circles: _circles,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: true,
                                mapToolbarEnabled: false,
                              ),
                  ),

                  // ── Category legend ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _legendChip('Food', Colors.blue),
                        _legendChip('Medical', AppTheme.errorRed),
                        _legendChip('Education', AppTheme.successGreen),
                        _legendChip('Transport', AppTheme.warningOrange),
                        _legendChip('Housing', AppTheme.primaryPurple),
                      ],
                    ),
                  ),

                  // ── Radius slider ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Browse listings within',
                                style: TextStyle(
                                    fontSize: 15, color: AppTheme.textDark)),
                            Text(
                              '${_radiusKm.toStringAsFixed(1)}km',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primaryBlue,
                            inactiveTrackColor: const Color(0xFFE2E8F0),
                            thumbColor: AppTheme.primaryBlue,
                            trackHeight: 6,
                          ),
                          child: Slider(
                            min: 0.5,
                            max: 100,
                            value: _radiusKm,
                            onChanged: (v) => setState(() => _radiusKm = v),
                            onChangeEnd: (_) => _filterNearbyRequests(),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('0.5 KM',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                            Text('100 KM',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_nearbyRequests.length} requests found',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // ── Nearby Requests list ──
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Text('Nearby Requests',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                  ),

                  if (_nearbyRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          _currentLat == null
                              ? 'Set your location to find nearby requests.'
                              : 'No requests found within '
                                  '${_radiusKm.toStringAsFixed(1)} km.\n'
                                  'Try increasing the distance.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _nearbyRequests.length,
                      itemBuilder: (context, index) =>
                          _buildNearbyCard(_nearbyRequests[index]),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _legendChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildNearbyCard(_NearbyRequest item) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RequestDetailScreen(request: item.request)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.request.title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
            const SizedBox(height: 4),
            Text(item.request.description,
                style:
                    const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildCategoryTag(item.request.categoryLabel),
                const SizedBox(width: 12),
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  item.distanceKm != null
                      ? '${item.distanceKm!.toStringAsFixed(1)}km away'
                      : 'Distance unknown',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.request.location ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTag(String label) {
    Color color;
    switch (label.toLowerCase()) {
      case 'food':
        color = AppTheme.primaryBlue;
        break;
      case 'medical':
        color = AppTheme.errorRed;
        break;
      case 'education':
        color = AppTheme.successGreen;
        break;
      case 'transportation':
        color = AppTheme.warningOrange;
        break;
      case 'housing':
        color = AppTheme.primaryPurple;
        break;
      default:
        color = AppTheme.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

class _NearbyRequest {
  final HelpRequest request;
  final double? distanceKm;
  _NearbyRequest({required this.request, this.distanceKm});
}
