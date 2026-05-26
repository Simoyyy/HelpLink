import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMapPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? label;

  const LocationMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
  });

  Future<void> _openInMaps() async {
    final query = label != null ? Uri.encodeComponent(label!) : '$latitude,$longitude';
    final uri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($query)');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to Google Maps web URL
      await launchUrl(
        Uri.parse('https://maps.google.com/?q=$latitude,$longitude'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = LatLng(latitude, longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 160,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: position,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('loc'),
                      position: position,
                    ),
                  },
                  liteModeEnabled: true,
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                ),
                // Transparent overlay to capture tap without interfering with the map
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openInMaps,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _openInMaps,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.open_in_new_rounded,
                  size: 14, color: Color(0xFF6366F1)),
              const SizedBox(width: 4),
              const Text(
                'Open in Maps',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
