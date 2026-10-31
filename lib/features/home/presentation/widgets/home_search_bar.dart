import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Rounded search pill with a voice button and a barcode-scan button.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.onChanged,
    required this.onSubmitted,
    this.controller,
    this.onVoice,
    this.onScan,
    this.listening = false,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  /// Lets the page show a search that something else started (e.g. a banner).
  final TextEditingController? controller;

  /// Start/stop voice search; the button is hidden when null.
  final VoidCallback? onVoice;

  /// Open the barcode scanner; the button is hidden when null.
  final VoidCallback? onScan;

  /// True while the microphone is listening (the button turns red).
  final bool listening;

  static const voiceKey = ValueKey('search-voice');
  static const scanKey = ValueKey('search-scan');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'ابحث عن "حليب"، "أرز"، أو الباركود...',
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          suffixIcon: (onVoice == null && onScan == null)
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onVoice != null)
                      IconButton(
                        key: voiceKey,
                        tooltip: listening ? 'إيقاف الاستماع' : 'بحث صوتي',
                        onPressed: onVoice,
                        icon: Icon(
                          listening ? Icons.mic : Icons.mic_none,
                          color: listening ? AppColors.accent : AppColors.primary,
                        ),
                      ),
                    if (onVoice != null && onScan != null)
                      Container(width: 1, height: 22, color: AppColors.border),
                    if (onScan != null)
                      IconButton(
                        key: scanKey,
                        tooltip: 'مسح الباركود',
                        onPressed: onScan,
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                      ),
                  ],
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
