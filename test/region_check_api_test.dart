import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:time_to_go_app/data/remote/backend_api.dart';
import 'package:time_to_go_app/domain/models/region_check.dart';

void main() {
  test(
    'checkRegion parses a warning response from the public endpoint',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url,
          Uri.parse('https://example.com/settings/region-check'),
        );
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers, isNot(contains('Authorization')));

        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'check_status': 'success',
              'country_code': 'DE',
              'is_in_russia': false,
              'vpn_detected': true,
              'proxy_detected': false,
              'tor_detected': false,
              'should_warn': true,
              'warning_reasons': ['outside_russia', 'anonymizer_detected'],
              'warning_message': 'Показываем предупреждение',
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = BackendApi(
        baseUrl: 'https://example.com',
        accessToken: 'secret',
        client: client,
      );
      addTearDown(api.dispose);

      final response = await api.checkRegion();

      expect(response.checkStatus, RegionCheckStatus.success);
      expect(response.shouldShowWarning, isTrue);
      expect(response.warningMessage, 'Показываем предупреждение');
      expect(response.warningReasons, [
        'outside_russia',
        'anonymizer_detected',
      ]);
    },
  );

  test('unavailable response never requests a warning', () {
    final response = RegionCheckResponse.fromJson({
      'check_status': 'unavailable',
      'should_warn': false,
      'warning_reasons': <String>[],
    });

    expect(response.checkStatus, RegionCheckStatus.unavailable);
    expect(response.shouldShowWarning, isFalse);
    expect(response.warningMessage, isNull);
  });

  test('successful response in Russia does not request a warning', () {
    final response = RegionCheckResponse.fromJson({
      'check_status': 'success',
      'country_code': 'RU',
      'is_in_russia': true,
      'vpn_detected': false,
      'proxy_detected': false,
      'tor_detected': false,
      'should_warn': false,
      'warning_reasons': <String>[],
      'warning_message': null,
    });

    expect(response.shouldShowWarning, isFalse);
  });
}
