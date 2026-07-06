import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

Future<List<String>> makeRules(
  List<String> rawRules, {
  List<Rule> rules = const [],
  List<Rule> addedRules = const [],
}) async {
  final result = await makeRealProfileTask(
    MakeRealProfileState(
      profilesPath: '',
      profileId: 0,
      rawConfig: {'rules': rawRules},
      realPatchConfig: const PatchClashConfig(),
      overrideDns: false,
      appendSystemDns: false,
      proxyGroups: const [],
      rules: rules,
      addedRules: addedRules,
      defaultUA: 'FlClash-Test',
    ),
  );
  return getRulesFromYaml(result.a);
}

List<String> getRulesFromYaml(String content) {
  final rules = <String>[];
  final lines = content.split('\n');
  final rulesIndex = lines.indexOf('rules:');
  if (rulesIndex == -1) return rules;

  for (final line in lines.skip(rulesIndex + 1)) {
    if (line.isEmpty) continue;
    if (!line.startsWith(' ')) break;
    if (!line.startsWith('  - ')) continue;

    final value = line.substring(4);
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      rules.add(value.substring(1, value.length - 1));
    } else {
      rules.add(value);
    }
  }
  return rules;
}

void main() {
  group('makeRealProfileTask rule target fix', () {
    test('inserts target before no-resolve and src params', () async {
      final rules = await makeRules([
        'IP-CIDR,192.133.76.0/22,no-resolve',
        'GEOIP,cn,src',
        'MATCH,Proxy',
      ]);

      expect(rules, [
        'IP-CIDR,192.133.76.0/22,Proxy,no-resolve',
        'GEOIP,cn,Proxy,src',
        'MATCH,Proxy',
      ]);
    });

    test('matches mihomo trim and rule type casing behavior', () async {
      final rules = await makeRules([
        'IP-CIDR,192.133.76.0/22, no-resolve',
        'match,DIRECT',
      ]);

      expect(rules, [
        'IP-CIDR,192.133.76.0/22,DIRECT,no-resolve',
        'match,DIRECT',
      ]);
    });

    test('does not treat content named src as a rule param', () async {
      final rules = await makeRules([
        'DOMAIN-KEYWORD,src,DIRECT',
        'DOMAIN-SUFFIX,no-resolve,DIRECT',
      ]);

      expect(rules, [
        'DOMAIN-KEYWORD,src,DIRECT',
        'DOMAIN-SUFFIX,no-resolve,DIRECT',
      ]);
    });

    test('does not treat src target as a param for rules without params', () async {
      final rules = await makeRules(['DOMAIN,example.com,src']);

      expect(rules, ['DOMAIN,example.com,src']);
    });

    test(
      'does not change already targeted, MATCH, and SUB-RULE rules',
      () async {
        final rules = await makeRules([
          'DOMAIN,example.com,Proxy',
          'MATCH,DIRECT',
          'SUB-RULE,sub-rule-name,sub-rule-target',
        ]);

        expect(rules, [
          'DOMAIN,example.com,Proxy',
          'MATCH,DIRECT',
          'SUB-RULE,sub-rule-name,sub-rule-target',
        ]);
      },
    );

    test('does not fix manually supplied rules or added rules', () async {
      final rules = await makeRules(
        ['IP-CIDR,192.133.76.0/22,no-resolve', 'MATCH,DIRECT'],
        rules: const [
          Rule(
            ruleAction: RuleAction.IP_CIDR,
            content: '192.133.76.0/22',
            ruleTarget: 'no-resolve',
          ),
        ],
        addedRules: const [
          Rule(
            ruleAction: RuleAction.GEOIP,
            content: 'cn',
            ruleTarget: 'no-resolve',
          ),
        ],
      );

      expect(rules, ['IP-CIDR,192.133.76.0/22,no-resolve']);
    });
  });
}
