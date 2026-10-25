/// Jordanian mobile numbers (Zain 079, Orange 077, Umniah 078).
///
/// Phone numbers aren't OTP-verified (SMS was dropped for cost), so this
/// format check plus the double-entry confirmation in [PhoneEntryFields] is
/// the only guard against typos — it's what the driver will call.
class JordanPhone {
  const JordanPhone._();

  /// Accepts `07XXXXXXXX`, `7XXXXXXXX`, `+9627XXXXXXXX` or `009627XXXXXXXX`
  /// (spaces/dashes ignored) and returns E.164 `+9627XXXXXXXX`, or null if
  /// it isn't a valid Jordanian mobile number.
  static String? normalize(String input) {
    var digits = input.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.startsWith('+962')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('00962')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (!RegExp(r'^7[789]\d{7}$').hasMatch(digits)) return null;
    return '+962$digits';
  }

  /// `+962791234567` → `0791234567`, the way customers write it.
  static String toLocal(String e164) =>
      e164.startsWith('+962') ? '0${e164.substring(4)}' : e164;
}
