import 'package:flutter/material.dart';

enum GameToastType { info, success, warning, error }

const _kPanel = Color(0xF21B1008);
const _kBorder = Color(0xFF6E4722);
const _kGold = Color(0xFFFFD56A);
const _kRed = Color(0xFF8B1A1A);
const _kGreen = Color(0xFF3D7C45);
const _kText = Color(0xFFF4E4C6);

void showGameToast(
  BuildContext context,
  String message, {
  GameToastType type = GameToastType.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 118),
        padding: EdgeInsets.zero,
        duration: const Duration(milliseconds: 2100),
        content: _GameToast(message: message, type: type),
      ),
    );
}

Future<bool> showGameConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '취소',
  GameToastType type = GameToastType.info,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (dialogContext) {
      final accent = _accentFor(type);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                offset: const Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _PixelBadge(type: type, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _GameDialogButton(
                      label: cancelLabel,
                      color: const Color(0xFF352419),
                      borderColor: _kBorder,
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GameDialogButton(
                      label: confirmLabel,
                      color: _kRed,
                      borderColor: const Color(0xFFB56838),
                      onTap: () => Navigator.pop(dialogContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}

Future<void> showGameNoticeDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '확인',
  GameToastType type = GameToastType.info,
  bool barrierDismissible = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    builder: (dialogContext) {
      final accent = _accentFor(type);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.78),
                offset: const Offset(0, 7),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _PixelBadge(type: type, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.50),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 14,
                    height: 1.42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _GameDialogButton(
                label: confirmLabel,
                color: accent.withValues(alpha: 0.38),
                borderColor: accent,
                onTap: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GameToast extends StatelessWidget {
  final String message;
  final GameToastType type;

  const _GameToast({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(type);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.72),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          _PixelBadge(type: type, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kText,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PixelBadge extends StatelessWidget {
  final GameToastType type;
  final double size;

  const _PixelBadge({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(_iconFor(type), color: accent, size: size * 0.62),
    );
  }
}

class _GameDialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  const _GameDialogButton({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

Color _accentFor(GameToastType type) {
  return switch (type) {
    GameToastType.success => _kGreen,
    GameToastType.warning => _kGold,
    GameToastType.error => const Color(0xFFFF6B5F),
    GameToastType.info => const Color(0xFF6FB7FF),
  };
}

IconData _iconFor(GameToastType type) {
  return switch (type) {
    GameToastType.success => Icons.check,
    GameToastType.warning => Icons.priority_high,
    GameToastType.error => Icons.close,
    GameToastType.info => Icons.auto_awesome,
  };
}
