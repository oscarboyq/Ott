import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/services/app_settings_service.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late AppSettingsService service;
  late String body;
  late int status;
  late List<String> methods;

  setUp(() async {
    body = '[{"value":"true"}]';
    status = 200;
    methods = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      methods.add(request.method);
      await request.drain<void>();
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(body);
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
    );
    service = AppSettingsService(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('reads completion from the database afresh', () async {
    expect(await service.isSetupCompleted(), isTrue);
    body = '[{"value":"false"}]';
    expect(await service.isSetupCompleted(), isFalse);
    expect(methods, ['GET', 'GET']);
  });

  test('missing or malformed status never means incomplete', () async {
    for (final response in [
      '[]',
      '[{"value":null}]',
      '[{"value":"unexpected"}]',
      '[{"value":true}]',
    ]) {
      body = response;
      await expectLater(service.isSetupCompleted(), throwsStateError);
    }
  });

  test('permission failure remains an error', () async {
    status = 403;
    body = '{"message":"permission denied","code":"42501"}';
    await expectLater(
      service.isSetupCompleted(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('network failure remains an error', () async {
    await server.close(force: true);
    await expectLater(service.isSetupCompleted(), throwsA(anything));
  });

  test(
    'completion calls the protected RPC and confirms database state',
    () async {
      body = '{"value":"true"}';
      await service.markSetupCompleted();
      expect(methods, ['POST', 'GET']);
    },
  );

  test('denied completion update is not treated as success', () async {
    status = 403;
    body = '{"message":"Owner access required","code":"42501"}';
    await expectLater(
      service.markSetupCompleted(),
      throwsA(isA<PostgrestException>()),
    );
    expect(methods, ['POST']);
  });
}
