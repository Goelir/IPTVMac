import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/natural_sort.dart';

void main() {
  test('names sort the way a person expects', () {
    List<String> sorted(List<String> l) => [...l]..sort(compareNames);
    expect(sorted(['Channel 10', 'channel 2', 'Channel 1']), ['Channel 1', 'channel 2', 'Channel 10']);
    expect(sorted(['beta', 'Alpha', 'alpha 2', 'alpha']), ['Alpha', 'alpha', 'alpha 2', 'beta']);
    expect(sorted(['ב', 'א', 'z', 'A']), ['A', 'z', 'א', 'ב']);
    expect(compareNames('x', 'x'), 0);
    expect(compareNames('99999999999999999999', '100000000000000000000'), isNegative, reason: 'very long numbers do not overflow');
  });
}
