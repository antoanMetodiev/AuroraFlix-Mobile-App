// A third-party page (video players, YouTube) shown inside the app, the way
// the website shows it in an <iframe>: a real <iframe> in the browser build,
// a WebView hosting that same <iframe> on Android / iOS.
export 'embed_frame_native.dart' if (dart.library.js_interop) 'embed_frame_web.dart';
