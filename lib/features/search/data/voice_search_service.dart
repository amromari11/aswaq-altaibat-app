import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text for the search box. An interface so screens and tests don't
/// depend on the microphone plugin.
abstract class VoiceSearchService {
  bool get isListening;

  /// Starts listening. [onWords] gets the words heard so far ([finished] once
  /// the phrase is complete); [onStopped] fires when listening ends for any
  /// reason. Returns false when speech recognition isn't available (no
  /// permission, unsupported browser or device).
  Future<bool> start({
    required void Function(String words, bool finished) onWords,
    required void Function() onStopped,
  });

  Future<void> stop();
}

class SpeechVoiceSearchService implements VoiceSearchService {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  void Function()? _onStopped;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> start({
    required void Function(String words, bool finished) onWords,
    required void Function() onStopped,
  }) async {
    _onStopped = onStopped;
    if (!_ready) {
      try {
        _ready = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') _onStopped?.call();
          },
          onError: (_) => _onStopped?.call(),
        );
      } catch (_) {
        _ready = false;
      }
    }
    if (!_ready) return false;

    // Prefer Jordanian Arabic, then any Arabic, then the device's own language.
    String? localeId;
    try {
      final locales = await _speech.locales();
      final ids = locales.map((l) => l.localeId).toList();
      localeId = ids.firstWhere(
        (id) => id.replaceAll('-', '_').toLowerCase() == 'ar_jo',
        orElse: () => ids.firstWhere((id) => id.toLowerCase().startsWith('ar'), orElse: () => ''),
      );
      if (localeId.isEmpty) localeId = null;
    } catch (_) {}

    await _speech.listen(
      onResult: (result) => onWords(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true, localeId: localeId),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}
