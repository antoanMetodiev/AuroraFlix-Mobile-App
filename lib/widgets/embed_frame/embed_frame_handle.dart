typedef EmbedPost = void Function(Map<String, Object> message);

/// Lets a player section send a `postMessage` into the embed it's showing.
class EmbedFrameHandle {
  EmbedPost? _post;

  void attach(EmbedPost post) => _post = post;

  /// Only its own: a new frame attaches before the one it replaces is disposed.
  void detach(EmbedPost post) {
    if (_post == post) _post = null;
  }

  void post(Map<String, Object> message) => _post?.call(message);
}
