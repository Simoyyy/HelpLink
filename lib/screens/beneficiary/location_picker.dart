import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  static String get _mapsKey => dotenv.env['MAPS_API_KEY'] ?? '';

  GoogleMapController? _controller;
  final _mapReady = Completer<GoogleMapController>();
  LatLng? _picked;
  Set<Marker> _markers = {};
  String _address = '';
  bool _isGeocoding = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

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

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        setState(() => _suggestions = []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _moveToLocation(LatLng pos, {double zoom = 15.0}) async {
    final ctrl = await _mapReady.future;
    await ctrl.animateCamera(CameraUpdate.newLatLngZoom(pos, zoom));
  }

  // ── Search / autocomplete ─────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _suggestions = []; _isSearching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    if (_mapsKey.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_mapsKey'
        '&language=en',
      );
      final res = await http.get(uri);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final preds = (data['predictions'] as List?) ?? [];
        setState(() {
          _suggestions = preds
              .map((p) => {
                    'description': p['description'] as String,
                    'place_id': p['place_id'] as String,
                    'main_text':
                        (p['structured_formatting']?['main_text'] as String?) ??
                            (p['description'] as String),
                    'secondary_text':
                        (p['structured_formatting']?['secondary_text'] as String?) ?? '',
                  })
              .toList();
        });
      }
    } catch (_) {
      // silently ignore network errors
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    _searchFocus.unfocus();
    final description = suggestion['description'] as String;
    _searchController.text = description;
    setState(() { _suggestions = []; _isGeocoding = true; });

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${suggestion['place_id']}'
        '&fields=geometry,formatted_address'
        '&key=$_mapsKey',
      );
      final res = await http.get(uri);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final loc = data['result']?['geometry']?['location'];
        final addr = (data['result']?['formatted_address'] as String?) ?? description;
        if (loc != null) {
          final pos = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
          _moveToLocation(pos);
          setState(() {
            _picked = pos;
            _markers = {Marker(markerId: const MarkerId('picked'), position: pos)};
            _address = addr;
            _searchController.text = addr;
          });
        }
      }
    } catch (_) {
      // fall back to geocoding
      try {
        final locs = await locationFromAddress(description);
        if (!mounted || locs.isEmpty) return;
        final pos = LatLng(locs.first.latitude, locs.first.longitude);
        _moveToLocation(pos);
        setState(() {
          _picked = pos;
          _markers = {Marker(markerId: const MarkerId('picked'), position: pos)};
          _address = description;
        });
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  // ── Direct geocode (used when user submits text without selecting suggestion) ─

  Future<void> _searchAndMove(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _searchFocus.unfocus();
    setState(() { _isGeocoding = true; _suggestions = []; });
    try {
      if (_mapsKey.isNotEmpty) {
        final uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=${Uri.encodeComponent(q)}&key=$_mapsKey',
        );
        final res = await http.get(uri);
        if (!mounted) return;
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final results = (data['results'] as List?) ?? [];
          if (results.isNotEmpty) {
            final loc = results[0]['geometry']['location'];
            final addr = (results[0]['formatted_address'] as String?) ?? q;
            final pos = LatLng(
              (loc['lat'] as num).toDouble(),
              (loc['lng'] as num).toDouble(),
            );
            await _moveToLocation(pos);
            if (mounted) {
              setState(() {
                _picked = pos;
                _markers = {Marker(markerId: const MarkerId('picked'), position: pos)};
                _address = addr;
                _searchController.text = addr;
              });
            }
            return;
          }
        }
      }
      // Fallback: geocoding package
      final locs = await locationFromAddress(q);
      if (!mounted || locs.isEmpty) return;
      final pos = LatLng(locs.first.latitude, locs.first.longitude);
      await _moveToLocation(pos);
      if (mounted) {
        setState(() {
          _picked = pos;
          _markers = {Marker(markerId: const MarkerId('picked'), position: pos)};
          _address = q;
          _searchController.text = q;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  // ── Map tap ───────────────────────────────────────────────────────────────

  Future<void> _onTap(LatLng pos) async {
    _searchFocus.unfocus();
    setState(() {
      _picked = pos;
      _markers = {Marker(markerId: const MarkerId('picked'), position: pos)};
      _address = '';
      _isGeocoding = true;
      _suggestions = [];
    });
    _moveToLocation(pos);
    await _geocode(pos);
  }

  Future<void> _geocode(LatLng pos) async {
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (marks.isNotEmpty) {
        final p = marks.first;
        final addr = [p.name, p.subLocality, p.locality, p.administrativeArea, p.country]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
        setState(() {
          _address = addr;
          _searchController.text = addr;
        });
      }
    } catch (_) {
      if (mounted) {
        final fallback =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        setState(() {
          _address = fallback;
          _searchController.text = fallback;
        });
      }
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPosition ?? _default;
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initial,
              zoom: widget.initialPosition != null ? 15 : 11,
            ),
            onMapCreated: (c) {
              _controller = c;
              if (!_mapReady.isCompleted) _mapReady.complete(c);
            },
            markers: _markers,
            onTap: _onTap,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          ),

          // Top search bar + suggestions
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search row
                  Row(
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    size: 18, color: AppTheme.primaryPurple),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocus,
                                    onChanged: _onSearchChanged,
                                    onSubmitted: (v) {
                                      if (_suggestions.isNotEmpty) {
                                        _selectSuggestion(_suggestions.first);
                                      } else {
                                        _searchAndMove(v);
                                      }
                                    },
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Search or tap the map…',
                                      hintStyle: const TextStyle(
                                          fontSize: 13, color: AppTheme.textMuted),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(vertical: 10),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? GestureDetector(
                                              onTap: () {
                                                _searchController.clear();
                                                setState(() => _suggestions = []);
                                              },
                                              child: const Icon(Icons.close,
                                                  size: 16, color: AppTheme.textMuted),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                if (_isSearching)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppTheme.primaryPurple),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Suggestions dropdown
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 58, top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _suggestions.length > 5 ? 5 : _suggestions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 44),
                          itemBuilder: (context, i) {
                            final s = _suggestions[i];
                            return InkWell(
                              onTap: () => _selectSuggestion(s),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 18, color: AppTheme.primaryPurple),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s['main_text'] as String,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textDark),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if ((s['secondary_text'] as String).isNotEmpty)
                                            Text(
                                              s['secondary_text'] as String,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textMuted),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Zoom controls — positioned above the confirm button
          Positioned(
            right: 12,
            bottom: 104,
            child: Column(
              children: [
                _ZoomBtn(
                  icon: Icons.add,
                  onPressed: () async {
                    final ctrl = await _mapReady.future;
                    ctrl.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 4),
                _ZoomBtn(
                  icon: Icons.remove,
                  onPressed: () async {
                    final ctrl = await _mapReady.future;
                    ctrl.animateCamera(CameraUpdate.zoomOut());
                  },
                ),
              ],
            ),
          ),

          // Bottom confirm button
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
                          'Search an address or tap the map to pin your location',
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

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _ZoomBtn({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}
