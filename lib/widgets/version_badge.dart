import 'package:flutter/material.dart';

import '../config/version.dart';

/// Displays the current build version and codename.
/// Can be placed in app header, drawer, or as a persistent badge.
class VersionBadge extends StatelessWidget {
  /// Display size: 'small' (tooltip), 'normal' (header), 'large' (info screen)
  final String size;

  /// Show full details or compact view
  final bool showDetails;

  /// Optional callback when tapped (can open About screen)
  final VoidCallback? onTap;

  const VersionBadge({
    super.key,
    this.size = 'normal',
    this.showDetails = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (size == 'small') {
      return _buildSmall();
    } else if (size == 'large') {
      return _buildLarge();
    }
    return _buildNormal();
  }

  /// Tooltip-size badge for placement in header/corner
  Widget _buildSmall() {
    return Tooltip(
      message: AppVersion.displayVersion,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF195DE6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: const Color(0xFF195DE6).withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            AppVersion.shortVersion,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF195DE6),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// Standard size for header or session config screen
  Widget _buildNormal() {
    return Tooltip(
      message: 'Tap to see build details',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF195DE6).withValues(alpha: 0.1),
                const Color(0xFF195DE6).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF195DE6).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: const Color(0xFF195DE6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppVersion.compactVersion,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF195DE6),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Large detailed display for About/Info screen
  Widget _buildLarge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF195DE6).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF195DE6).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.category_outlined,
                size: 18,
                color: const Color(0xFF195DE6),
              ),
              const SizedBox(width: 8),
              const Text(
                'Build Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Version', AppVersion.semanticVersion),
          _infoRow('Build Codename', AppVersion.currentCodename),
          _infoRow('Build Number', '#${AppVersion.buildNumber}'),
          _infoRow('Full Version', AppVersion.fullVersion),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              AppVersion.displayVersion,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Courier',
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF195DE6),
            ),
          ),
        ],
      ),
    );
  }
}
