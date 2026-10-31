import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/voice_search_service.dart';

final voiceSearchServiceProvider = Provider<VoiceSearchService>((ref) => SpeechVoiceSearchService());
