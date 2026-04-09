import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

/// Phone field with as-you-type formatting and a short country list (default +40 Romania).
class AppInternationalPhoneField extends StatefulWidget {
  const AppInternationalPhoneField({
    super.key,
    this.initialPhone,
    required this.decoration,
    this.onChanged,
    this.validator,
    this.autoValidateMode = AutovalidateMode.disabled,
  });

  /// Stored value from persistence (E.164, spaced formats, or local `07…` for RO).
  final String? initialPhone;

  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final AutovalidateMode autoValidateMode;

  static const String defaultIso = 'RO';

  /// Order matches selector list order; Romania (+40) is first.
  static const List<String> allowedCountryIsoCodes = [
    'RO',
    'HU',
    'BG',
    'MD',
    'UA',
    'RS',
    'DE',
    'AT',
    'GB',
    'IT',
    'FR',
    'ES',
  ];

  @override
  State<AppInternationalPhoneField> createState() =>
      _AppInternationalPhoneFieldState();
}

class _AppInternationalPhoneFieldState extends State<AppInternationalPhoneField> {
  final _controller = TextEditingController();
  String _resolvedIso = AppInternationalPhoneField.defaultIso;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _resolveInitial();
  }

  @override
  void didUpdateWidget(covariant AppInternationalPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPhone != widget.initialPhone) {
      _ready = false;
      _controller.clear();
      _resolveInitial();
    }
  }

  Future<void> _resolveInitial() async {
    final raw = widget.initialPhone?.trim() ?? '';
    _resolvedIso = AppInternationalPhoneField.defaultIso;

    if (raw.isEmpty) {
      if (mounted) setState(() => _ready = true);
      return;
    }

    PhoneNumber? parsed;
    try {
      parsed = await PhoneNumber.getRegionInfoFromPhoneNumber(
        raw,
        AppInternationalPhoneField.defaultIso,
      );
    } catch (_) {
      if (raw.startsWith('0') && raw.length > 1 && !raw.startsWith('+')) {
        try {
          final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');
          parsed = await PhoneNumber.getRegionInfoFromPhoneNumber(
            '+40$digits',
            'RO',
          );
        } catch (_) {}
      }
    }

    if (parsed != null) {
      final iso = (parsed.isoCode ?? '').toUpperCase();
      if (AppInternationalPhoneField.allowedCountryIsoCodes.contains(iso)) {
        _resolvedIso = iso;
      }
      try {
        _controller.text = await PhoneNumber.getParsableNumber(parsed);
      } catch (_) {
        _controller.text = raw;
      }
    } else {
      _controller.text = raw.replaceFirst(RegExp(r'^\+40\s*'), '');
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return TextField(
        enabled: false,
        decoration: widget.decoration,
      );
    }

    return InternationalPhoneNumberInput(
      countries: AppInternationalPhoneField.allowedCountryIsoCodes,
      formatInput: true,
      maxLength: 32,
      autoValidateMode: widget.autoValidateMode,
      ignoreBlank: true,
      textFieldController: _controller,
      initialValue: PhoneNumber(isoCode: _resolvedIso),
      selectorConfig: const SelectorConfig(
        selectorType: PhoneInputSelectorType.DROPDOWN,
        useEmoji: true,
        showFlags: true,
      ),
      keyboardType: TextInputType.phone,
      inputDecoration: widget.decoration,
      validator: widget.validator,
      onInputChanged: (PhoneNumber number) {
        final nationalDigits =
            _controller.text.replaceAll(RegExp(r'\D'), '');
        if (nationalDigits.isEmpty) {
          widget.onChanged?.call('');
        } else {
          widget.onChanged?.call((number.phoneNumber ?? '').trim());
        }
      },
    );
  }
}
