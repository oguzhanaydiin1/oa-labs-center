/// Derlenirken verilen sürüm (CI: --dart-define=APP_VERSION=0.1.0). Geliştirme derlemesinde 0.0.0.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

List<int> _parts(String v) => v
    .trim()
    .replaceFirst(RegExp(r'^v'), '')
    .split(RegExp(r'[.+\- ]'))
    .take(3)
    .map((p) => int.tryParse(p) ?? 0)
    .toList();

/// [remote] sürümü [local] sürümünden yeni mi? ("v0.20.0" ile "0.19.11" gibi)
bool isNewer(String remote, String local) {
  final a = _parts(remote), b = _parts(local);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
