import 'dart:convert';

enum CalendlyBookingSource { accountDeletion, settingsSupport }

class CalendlyBookingRequest {
  const CalendlyBookingRequest({required this.source, required this.uri});

  final CalendlyBookingSource source;
  final Uri uri;
}

class CalendlyBookingCompletionGuard {
  bool _completed = false;

  bool get completed => _completed;

  bool markCompletedOnce() {
    if (_completed) return false;
    _completed = true;
    return true;
  }
}

const String kChaputHelpCalendlyUrl =
    'https://calendly.com/hello-goktigin/chaput-1-1-help';

Uri buildChaputHelpCalendlyUri({
  required String fullName,
  required String email,
}) {
  return Uri.parse(
    kChaputHelpCalendlyUrl,
  ).replace(queryParameters: {'name': fullName.trim(), 'email': email.trim()});
}

String? calendlyEventNameFromMessage(String message) {
  try {
    final decoded = jsonDecode(message);
    if (decoded is Map) {
      return decoded['event']?.toString();
    }
  } catch (_) {
    return null;
  }
  return null;
}

bool isCalendlyScheduledEventMessage(String message) {
  return calendlyEventNameFromMessage(message) == 'calendly.event_scheduled';
}

bool isCalendlyLifecycleEventMessage(String message) {
  final eventName = calendlyEventNameFromMessage(message);
  return eventName != null && eventName.startsWith('calendly.');
}

String buildCalendlyEmbedHtml(Uri uri) {
  final escapedUrl = const HtmlEscape().convert(uri.toString());
  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background: #EEF2F6;
      overflow: hidden;
    }
    .calendly-inline-widget {
      min-width: 320px;
      width: 100%;
      height: 100vh;
    }
  </style>
</head>
<body>
  <div class="calendly-inline-widget" data-url="$escapedUrl"></div>
  <script>
    (function () {
      if (window.__chaputCalendlyBridgeInstalled) return;
      window.__chaputCalendlyBridgeInstalled = true;
      window.addEventListener('message', function (event) {
        try {
          var data = event.data || {};
          if (!data.event || typeof ChaputCalendly === 'undefined') return;
          ChaputCalendly.postMessage(JSON.stringify({ event: data.event }));
        } catch (error) {}
      });
    })();
  </script>
  <script src="https://assets.calendly.com/assets/external/widget.js" async></script>
</body>
</html>
''';
}
