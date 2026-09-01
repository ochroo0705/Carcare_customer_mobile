import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:flutter/material.dart';

class LocationPermissionBanner extends StatelessWidget {
  const LocationPermissionBanner({
    required this.state,
    required this.onRequest,
    required this.onOpenSettings,
    super.key,
  });

  final LocationAccessState state;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final permanentlyDenied = state == LocationAccessState.permanentlyDenied;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final message = Text(
      permanentlyDenied
          ? 'Байршлыг тохиргооноос зөвшөөрнө үү'
          : 'Одоогийн байршлаа харуулах уу?',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
    final action = TextButton(
      key: ValueKey(
        permanentlyDenied ? 'location-open-settings' : 'location-request-again',
      ),
      onPressed: permanentlyDenied ? onOpenSettings : onRequest,
      child: Text(permanentlyDenied ? 'Тохиргоо' : 'Зөвшөөрөх'),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: permanentlyDenied
          ? 'Байршлын зөвшөөрөл хаалттай. Аппын тохиргоог нээнэ үү.'
          : 'Байршлын зөвшөөрөл өгөөгүй байна.',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 5,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: message),
                      ],
                    ),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: message),
                    action,
                  ],
                ),
        ),
      ),
    );
  }
}
