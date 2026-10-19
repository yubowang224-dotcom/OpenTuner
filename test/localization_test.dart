import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every English user message has an explicit non-empty Chinese translation',
    () {
      Map<String, dynamic> read(String locale) =>
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final english = read('en');
      final chinese = read('zh');
      final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
      expect(chinese.keys.where((key) => !key.startsWith('@')).toSet(), keys);
      for (final key in keys) {
        expect(chinese[key], isA<String>(), reason: key);
        expect((chinese[key] as String).trim(), isNotEmpty, reason: key);
      }
    },
  );
}
