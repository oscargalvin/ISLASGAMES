import 'package:geolocator/geolocator.dart';

import 'isla_client.dart';

/// Asks the browser for permission, then keeps only the rough area.
///
/// Returns null if location is turned off or permission is refused.
Future<ApproxArea?> askForApproxArea() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
  );
  // Rounded straight away, so the exact spot never leaves this function.
  return ApproxArea(position.latitude, position.longitude);
}
