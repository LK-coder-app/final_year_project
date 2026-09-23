// ═══════════════════════════════════════════════════════════════════
// AgriMind Flutter — Shared Widgets
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

// ─── Glass Card ──────────────────────────────────────────────────
class AgriCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double radius;

  const AgriCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AgriColors.slate800,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        gradient: AgriColors.headerGradient,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AgriColors.emerald300,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── Status Badge ────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    switch (status.toLowerCase()) {
      case 'feasible':
        bg = AgriColors.emerald500.withOpacity(0.15);
        fg = AgriColors.emerald400;
        border = AgriColors.emerald500.withOpacity(0.3);
        break;
      case 'quoted':
        bg = const Color(0xFF7c3aed).withOpacity(0.15);
        fg = const Color(0xFFc4b5fd);
        border = const Color(0xFF7c3aed).withOpacity(0.3);
        break;
      case 'under_review':
        bg = AgriColors.amber500.withOpacity(0.15);
        fg = AgriColors.amber500;
        border = AgriColors.amber500.withOpacity(0.3);
        break;
      case 'rejected':
        bg = AgriColors.red600.withOpacity(0.15);
        fg = const Color(0xFFfca5a5);
        border = AgriColors.red600.withOpacity(0.3);
        break;
      default:
        bg = AgriColors.slate600.withOpacity(0.15);
        fg = AgriColors.slate400;
        border = AgriColors.slate600.withOpacity(0.3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Feasibility Score Bar ────────────────────────────────────────
class FeasibilityBar extends StatelessWidget {
  final double score;
  final bool showLabel;

  const FeasibilityBar({super.key, required this.score, this.showLabel = true});

  Color get _color {
    if (score >= 75) return AgriColors.emerald500;
    if (score >= 50) return AgriColors.amber500;
    return AgriColors.red600;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AgriColors.slate700,
              valueColor: AlwaysStoppedAnimation(_color),
              minHeight: 6,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Conflict Severity Chip ───────────────────────────────────────
class ConflictChip extends StatelessWidget {
  final Map<String, dynamic> conflict;

  const ConflictChip({super.key, required this.conflict});

  @override
  Widget build(BuildContext context) {
    final severity = conflict['severity'] ?? 'low';
    Color border, bg, icon;
    String emoji;
    switch (severity) {
      case 'high':
        border = AgriColors.red600.withOpacity(0.4);
        bg = AgriColors.red600.withOpacity(0.08);
        icon = const Color(0xFFfca5a5);
        emoji = '🔴';
        break;
      case 'medium':
        border = AgriColors.amber600.withOpacity(0.4);
        bg = AgriColors.amber600.withOpacity(0.08);
        icon = const Color(0xFFfcd34d);
        emoji = '🟡';
        break;
      default:
        border = AgriColors.slate600.withOpacity(0.4);
        bg = AgriColors.slate700.withOpacity(0.3);
        icon = AgriColors.slate400;
        emoji = '🔵';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (conflict['type'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: icon,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: border.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w700, color: icon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            conflict['message'] ?? '',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            '💡 ${conflict['recommendation'] ?? ''}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AgriColors.emerald400.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KPI Card ────────────────────────────────────────────────────
class KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  final Color accentColor;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.value,
    required this.label,
    required this.emoji,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AgriCard(
        borderColor: accentColor.withOpacity(0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AgriColors.slate400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Row ──────────────────────────────────────────────────
class DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool isLast;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AgriColors.slate400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value ?? 'N/A',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
      ],
    );
  }
}

// ─── Gradient Button ─────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? emoji;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? AgriColors.brandGradient : null,
        color: onPressed == null ? AgriColors.slate700 : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AgriColors.emerald500.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (emoji != null)
                  Text(emoji!, style: const TextStyle(fontSize: 16)),
                if (!isLoading && emoji != null) const SizedBox(width: 8),
                Text(
                  isLoading ? 'Please wait...' : label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
