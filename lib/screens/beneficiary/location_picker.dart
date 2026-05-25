import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:helplink/utils/app_theme.dart';

class MapPickResult {
  final LatLng latLng;
  final String address;
  const MapPickResult({required this.latLng, required this.address});
}

class FullScreenMapPicker extends StatefulWidget {
  final LatLng? initialPosition;
  const FullScreenMapPicker({super.key, this.initialPosition});

  @override
  State<FullScreenMapPicker> createState() => _FullScreenMapPickerState();
}

class _FullScreenMapPickerState extends State<FullScreenMapPicker> {
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

          // Top bar
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

          // Bottom confirm
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
                              MapPickResult(latLng: _picked!, address: _address),
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      disabledBackgroundColor:
                          AppTheme.primaryPurple.withValues(alpha: 0.6),
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
