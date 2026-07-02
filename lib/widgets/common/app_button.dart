import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, outline, danger }

/// Bottone unico usato in tutta l'app — mai un ElevatedButton "nudo"
/// creato al volo. Garantisce che ogni azione nell'app abbia lo stesso
/// feeling tattile (dimensione minima 48px per il touch su smartphone).
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;

  /// Colore testo/icona/spinner esplicito — usato ad es. per il variant
  /// outline quando il bottone appare su sfondo scuro (es. entry screen).
  final Color? foregroundColor;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final spinnerColor =
        foregroundColor ??
        (variant == AppButtonVariant.outline
            ? AppColors.textPrimary
            : Colors.white);

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: spinnerColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: foregroundColor),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: foregroundColor != null
                    ? TextStyle(color: foregroundColor)
                    : null,
              ),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: loading ? null : onPressed,
          child: child,
        );
        break;
      case AppButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pmiBlue,
            foregroundColor: Colors.white,
          ),
          child: child,
        );
        break;
      case AppButtonVariant.outline:
        button = OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: foregroundColor != null
              ? OutlinedButton.styleFrom(
                  foregroundColor: foregroundColor,
                  side: BorderSide(
                    color: foregroundColor!.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                )
              : null,
          child: child,
        );
        break;
      case AppButtonVariant.danger:
        button = ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: child,
        );
        break;
    }

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
