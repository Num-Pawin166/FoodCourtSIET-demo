import 'package:flutter_test/flutter_test.dart';
import 'package:foodcourt_siet/widgets.dart';

void main() {
  test('baht formats with thousands separator', () {
    expect(baht(155), '฿155');
    expect(baht(10685), '฿10,685');
  });

  test('thaiDateTime uses Buddhist year', () {
    expect(thaiDateTime(DateTime(2026, 10, 16, 11, 15)), '16 ต.ค. 2569 11.15 น.');
  });
}
