void main() {
  bool isRelease = true;
  assert(() {
    isRelease = false;
    print("DEBUG_HOOK_SECRET_STRING_12345");
    return true;
  }());

  if (isRelease) {
    print("Running in RELEASE mode (asserts stripped).");
  } else {
    print("Running in DEBUG mode.");
  }
}
