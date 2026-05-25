import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:helplink/models/message_model.dart';
import 'package:helplink/services/firestore_service.dart';
import 'package:helplink/utils/app_theme.dart';
import 'package:intl/intl.dart';

class LocationViewScreen extends StatefulWidget {
  final ChatMessage message;

  const LocationViewScreen({super.key, required this.message});

  @override
  State<LocationViewScreen> createState() => _LocationViewScreenState();
}

class _LocationViewScreenState extends State<LocationViewScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Map<String, dynamic>?>? _liveSubscription;

  LatLng? _currentLatLng;
  bool _isActive = true;
  DateTime? _lastUpdated;
  Set<Marker> _markers = {};

  bool get _isLive =>
      widget.message.messageType == MessageType.liveLocation;

  @override
  void initState() {
    super.initState();
    _currentLatLng = LatLng(
      widget.message.latitude!,
      widget.message.longitude!,
    );
    _buildMarker(_currentLatLng!);

    if (_isLive) _subscribeToLiveLocation();
  }

  void _subscribeToLiveLocation() {
    final service = Provider.of<FirestoreService>(context, listen: false);
    _liveSubscription = service
        .getLiveLocationStream(
          widget.message.requestId,
          widget.message.liveLocationSessionId!,
        )
        .listen((data) {
      if (data == null || !mounted) return;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      final active = data['isActive'] as bool? ?? false;
      final ts = data['lastUpdated'];

      if (lat == null || lng == null) return;

      final newLatLng = LatLng(lat, lng);
      setState(() {
        _currentLatLng = newLatLng;
        _isActive = active;
        _lastUpdated = ts != null
            ? (ts as dynamic).toDate() as DateTime
            : DateTime.now();
      });
      _buildMarker(newLatLng);
      _mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));
    });
  }

  void _buildMarker(LatLng pos) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('shared_location'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _isLive ? BitmapDescriptor.hueRed : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: _isLive
                ? '${widget.message.senderName}\'s Live Location'
                : widget.message.locationName ?? 'Shared Location',
          ),
        ),
      };
    });
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  String _formatExpiry() {
    final expiry = widget.message.liveLocationExpiry;
    if (expiry == null) return '';
    final now = DateTime.now();
    if (expiry.isBefore(now)) return 'Expired';
    final diff = expiry.difference(now);
    if (diff.inMinutes < 1) return 'Expires in < 1 min';
    return 'Expires in ${diff.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(0, 48, 0, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9333EA), Color(0xFF06B6D4)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _isLive ? Icons.location_on : Icons.place,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLive
                              ? '${widget.message.senderName}\'s Live Location'
                              : 'Shared Location',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_isLive) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _isActive
                                      ? Colors.greenAccent
                                      : Colors.white54,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isActive
                                    ? _formatExpiry()
                                    : 'Sharing ended',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ] else if (widget.message.locationName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.message.locationName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map
          Expanded(
            child: _currentLatLng == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLatLng!,
                      zoom: 15,
                    ),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (ctrl) {
                      _mapController = ctrl;
                      // Show info window on the marker
                      Future.delayed(const Duration(milliseconds: 800), () {
                        ctrl.showMarkerInfoWindow(
                            const MarkerId('shared_location'));
                      });
                    },
                  ),
          ),

          // Bottom info bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: Colors.white,
            child: Row(
              children: [
                Icon(
                  _isLive ? Icons.location_on : Icons.place_outlined,
                  color: _isLive ? Colors.red : AppTheme.primaryBlue,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.locationName ??
                            (_isLive ? 'Live Location' : 'Shared Location'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (_currentLatLng != null)
                        Text(
                          '${_currentLatLng!.latitude.toStringAsFixed(5)}, '
                          '${_currentLatLng!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isLive && _lastUpdated != null)
                  Text(
                    'Updated ${DateFormat.jm().format(_lastUpdated!)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
