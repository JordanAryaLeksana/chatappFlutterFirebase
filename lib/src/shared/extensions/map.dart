
import 'package:chatty/src/shared/shared.dart';

extension XMap on Map<String, dynamic>? {
  String? error(String key) {
    return this?[key] != null ? this![key].toString().trimList : null;
  }
}
