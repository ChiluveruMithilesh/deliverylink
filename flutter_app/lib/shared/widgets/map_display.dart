import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Read-only map showing one or more pins. Used for live tracking and
/// for reviewing a trip's stops - not for picking a new location
/// (see LocationPickerMap for that).
class MapDisplay extends StatelessWidget {
  const MapDisplay({
    super.key,
    required this.markers,
    this.height = 260,
    this.initialZoom = 13,
  });

  final Set<Marker> markers;
  final double height;
  final double initialZoom;

  @override
  Widget build(BuildContext context) {
    final center = markers.isNotEmpty
        ? markers.first.position
        : const LatLng(17.385, 78.4867); // Fallback: Hyderabad, matches other placeholders in this app.

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: initialZoom),
          markers: markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
      ),
    );
  }
}