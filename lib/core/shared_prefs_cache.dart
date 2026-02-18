import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences>? _cachedPrefsFuture;

Future<SharedPreferences> getSharedPreferencesCached() {
  _cachedPrefsFuture ??= SharedPreferences.getInstance();
  return _cachedPrefsFuture!;
}
