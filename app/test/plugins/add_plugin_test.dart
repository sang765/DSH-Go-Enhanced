import 'package:dsh_app/ui/plugins/add_plugin_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a spec becomes a short display name', () {
    expect(addPluginName('dsh-plugin-whale-pet'), 'dsh-plugin-whale-pet');
    expect(addPluginName('dsh-plugin-whale-pet@1.2.3'), 'dsh-plugin-whale-pet');
    expect(addPluginName('@scope/dsh-plugin@2.0.0'), '@scope/dsh-plugin');
    expect(addPluginName('https://github.com/owner/dsh-example.git'), 'dsh-example');
    expect(addPluginName('/home/u/plugins/dsh-local'), 'dsh-local');
  });

  test('custom registries are plain https origins', () {
    expect(isValidAddPluginRegistry('https://registry.npmjs.org'), isTrue);
    expect(isValidAddPluginRegistry('https://npm.example.com/'), isTrue);
    expect(isValidAddPluginRegistry('http://npm.example.com'), isFalse);
    expect(isValidAddPluginRegistry('https://npm.example.com/?x=1'), isFalse);
    expect(isValidAddPluginRegistry('https://npm.example.com/#x'), isFalse);
    expect(isValidAddPluginRegistry('not a url'), isFalse);
  });
}
