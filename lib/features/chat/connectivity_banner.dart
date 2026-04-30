import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Global connectivity banner that shows when the device is offline.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen(_updateConnectivity);
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectivity(results);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final isOffline =
        results.length == 1 && results.first == ConnectivityResult.none;
    if (isOffline != _isOffline && mounted) {
      setState(() => _isOffline = isOffline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AnimatedCrossFade(
          firstChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: const Color(0xFF8C3D3D),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'You are offline. Messages to cloud providers will be queued.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _isOffline
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
