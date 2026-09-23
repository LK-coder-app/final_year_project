import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

@JS('agrimindVoice.start')
external bool _startVoice(JSString mode);

@JS('agrimindVoice.stop')
external void _stopVoice();

class VoiceHelper {
  static bool _listenersAttached = false;
  static Function(String text, String lang)? _onResult;
  static VoidCallback? _onEnd;
  static Function(String err)? _onError;

  static void init() {
    if (!kIsWeb || _listenersAttached) return;
    _listenersAttached = true;

    web.window.addEventListener('agrimind-voice-result', (web.Event event) {
      final custom = event as web.CustomEvent;
      final detail = custom.detail as JSObject?;
      if (detail != null) {
        final textObj = detail.getProperty('text'.toJS) as JSString?;
        final langObj = detail.getProperty('lang'.toJS) as JSString?;
        final text = textObj?.toDart ?? '';
        final lang = langObj?.toDart ?? '';
        _onResult?.call(text, lang);
      }
    }.toJS);

    web.window.addEventListener('agrimind-voice-end', (web.Event event) {
      _onEnd?.call();
    }.toJS);

    web.window.addEventListener('agrimind-voice-error', (web.Event event) {
      final custom = event as web.CustomEvent;
      final err = (custom.detail as JSString?)?.toDart ?? 'Voice recognition error';
      _onError?.call(err);
    }.toJS);
  }

  static bool start({
    String mode = 'auto',
    required Function(String text, String lang) onResult,
    required VoidCallback onEnd,
    required Function(String err) onError,
  }) {
    if (!kIsWeb) {
      onError('Voice input is available in modern web browsers (Chrome, Edge).');
      return false;
    }
    init();
    _onResult = onResult;
    _onEnd = onEnd;
    _onError = onError;

    try {
      return _startVoice(mode.toJS);
    } catch (e) {
      onError('Microphone access denied or not supported.');
      return false;
    }
  }

  static void stop() {
    if (!kIsWeb) return;
    try {
      _stopVoice();
    } catch (_) {}
  }
}
