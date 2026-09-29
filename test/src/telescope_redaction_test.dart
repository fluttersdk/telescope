import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/telescope_redaction.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';

void main() {
  tearDown(() {
    TelescopeStore.resetForTesting();
  });

  group('TelescopeRedaction', () {
    group('redactParameters()', () {
      test('masks the value under a matching key at any depth', () {
        final Object? redacted = TelescopeRedaction.redactParameters(
          <String, dynamic>{
            'email': 'a@b.test',
            'password': 'hunter2',
            'data': <String, dynamic>{
              'token': 'abc',
              'devices': <dynamic>[
                <String, dynamic>{
                  'name': 'phone',
                  'secret': 's3',
                },
              ],
            },
          },
          <String>{
            'password',
            'token',
            'secret',
          },
        );

        expect(
          redacted,
          equals(<String, dynamic>{
            'email': 'a@b.test',
            'password': TelescopeRedaction.mask,
            'data': <String, dynamic>{
              'token': TelescopeRedaction.mask,
              'devices': <dynamic>[
                <String, dynamic>{
                  'name': 'phone',
                  'secret': TelescopeRedaction.mask,
                },
              ],
            },
          }),
        );
      });

      test('matches keys case-insensitively on both sides', () {
        final Object? redacted = TelescopeRedaction.redactParameters(
          <String, dynamic>{
            'Password': 'hunter2',
            'ACCESS_TOKEN': 'abc',
          },
          <String>{
            'PASSWORD',
            'access_token',
          },
        );

        expect(
          redacted,
          equals(<String, dynamic>{
            'Password': TelescopeRedaction.mask,
            'ACCESS_TOKEN': TelescopeRedaction.mask,
          }),
        );
      });

      test('masks a structured value under a matching key whole', () {
        final Object? redacted = TelescopeRedaction.redactParameters(
          <String, dynamic>{
            'token': <String, dynamic>{
              'plain': 'abc',
            },
          },
          <String>{
            'token',
          },
        );

        expect(
          redacted,
          equals(<String, dynamic>{
            'token': TelescopeRedaction.mask,
          }),
        );
      });

      test('leaves a null or empty credential visible', () {
        final Map<String, dynamic> empty = <String, dynamic>{
          'password': '',
          'token': null,
          'secret': false,
          'access_token': <dynamic>[],
          'refresh_token': <String, dynamic>{},
        };

        final Object? redacted = TelescopeRedaction.redactParameters(
          empty,
          <String>{
            'password',
            'token',
            'secret',
            'access_token',
            'refresh_token',
          },
        );

        expect(redacted, equals(empty));
      });

      test(
          'masks whatever lies past the depth it walks, and never overflows '
          'the stack', () {
        Object? nested = <String, dynamic>{
          'token': 'deep',
        };
        for (var i = 0; i < 20000; i++) {
          nested = <dynamic>[
            nested,
          ];
        }

        final Object? redacted = TelescopeRedaction.redactParameters(
          nested,
          <String>{
            'token',
          },
        );

        var depth = 0;
        Object? cursor = redacted;
        while (cursor is List) {
          cursor = cursor.single;
          depth++;
        }
        expect(depth, lessThan(20000));
        expect(cursor, equals(TelescopeRedaction.mask));
      });

      test('never mutates the input', () {
        final Map<String, dynamic> input = <String, dynamic>{
          'password': 'hunter2',
          'data': <String, dynamic>{
            'token': 'abc',
          },
          'items': <dynamic>[
            <String, dynamic>{
              'secret': 's3',
            },
          ],
        };

        final Object? redacted = TelescopeRedaction.redactParameters(
          input,
          <String>{
            'password',
            'token',
            'secret',
          },
        );

        expect(redacted, isNot(same(input)));
        expect(input['password'], equals('hunter2'));
        expect((input['data'] as Map<String, dynamic>)['token'], equals('abc'));
        expect(
          ((input['items'] as List<dynamic>).single
              as Map<String, dynamic>)['secret'],
          equals('s3'),
        );
      });

      test('returns a scalar or null unchanged', () {
        expect(
          TelescopeRedaction.redactParameters(
            'password',
            <String>{
              'password',
            },
          ),
          equals('password'),
        );
        expect(
          TelescopeRedaction.redactParameters(
            null,
            <String>{
              'password',
            },
          ),
          isNull,
        );
      });
    });

    group('redactBody()', () {
      test(
          'masks a JSON body, and keeps one it cannot read or need not '
          'touch as given', () {
        const Set<String> keys = <String>{
          'Password',
        };
        const String pretty = '{\n  "email": "a@b.test"\n}';
        const String form = 'password=hunter2';

        expect(
          TelescopeRedaction.redactBody('{"password":"hunter2"}', keys),
          equals('{"password":"********"}'),
        );
        expect(TelescopeRedaction.redactBody(pretty, keys), same(pretty));
        expect(TelescopeRedaction.redactBody(form, keys), same(form));
        expect(TelescopeRedaction.redactBody(null, keys), isNull);
      });
    });

    group('hideRequestHeaders()', () {
      test('adds to the defaults, lowercased', () {
        TelescopeRedaction.hideRequestHeaders(<String>[
          'X-Auth',
        ]);

        expect(
          TelescopeRedaction.hiddenRequestHeaders,
          containsAll(<String>[
            'authorization',
            'proxy-authorization',
            'cookie',
            'set-cookie',
            'x-api-key',
            'x-auth',
          ]),
        );
      });
    });

    group('hideRequestParameters()', () {
      test('adds to the defaults, lowercased', () {
        TelescopeRedaction.hideRequestParameters(<String>[
          'PIN',
        ]);

        expect(
          TelescopeRedaction.hiddenRequestParameters,
          containsAll(<String>[
            'password',
            'password_confirmation',
            'current_password',
            'new_password',
            'token',
            'access_token',
            'refresh_token',
            'secret',
            'client_secret',
            'authorization_code',
            'id_token',
            'two_factor_token',
            'recovery_code',
            'pin',
          ]),
        );
      });
    });

    group('hideResponseParameters()', () {
      test('adds to the defaults, lowercased', () {
        TelescopeRedaction.hideResponseParameters(<String>[
          'Backup_Key',
        ]);

        expect(
          TelescopeRedaction.hiddenResponseParameters,
          containsAll(<String>[
            'token',
            'access_token',
            'refresh_token',
            'plain_text_token',
            'secret',
            'client_secret',
            'id_token',
            'two_factor_token',
            'recovery_codes',
            'qr_url',
            'qr_svg',
            'backup_key',
          ]),
        );
      });
    });

    group('resetForTesting()', () {
      test('drops every addition and keeps the defaults', () {
        TelescopeRedaction.hideRequestHeaders(<String>[
          'x-auth',
        ]);
        TelescopeRedaction.hideRequestParameters(<String>[
          'pin',
        ]);
        TelescopeRedaction.hideResponseParameters(<String>[
          'backup_key',
        ]);

        TelescopeRedaction.resetForTesting();

        expect(
            TelescopeRedaction.hiddenRequestHeaders, isNot(contains('x-auth')));
        expect(
            TelescopeRedaction.hiddenRequestHeaders, contains('authorization'));
        expect(
            TelescopeRedaction.hiddenRequestParameters, isNot(contains('pin')));
        expect(
          TelescopeRedaction.hiddenResponseParameters,
          isNot(contains('backup_key')),
        );
      });

      test('runs as part of TelescopeStore.resetForTesting()', () {
        TelescopeRedaction.hideRequestHeaders(<String>[
          'x-auth',
        ]);

        TelescopeStore.resetForTesting();

        expect(
            TelescopeRedaction.hiddenRequestHeaders, isNot(contains('x-auth')));
      });
    });
  });
}
