import 'dart:convert' as convert;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:memos_go/data/api/asr_api.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AsrApi api;

  setUp(() {
    dio = createAsrDio(baseUrl: 'https://asr.example.com/v1', apiKey: 'sk-x');
    adapter = DioAdapter(dio: dio);
    api = AsrApi(dio);
  });

  FormData formOf(Map<String, dynamic> fields) => FormData.fromMap(fields);

  test('transcribe posts multipart form and parses text', () async {
    adapter.onPost(
      '/audio/transcriptions',
      (server) => server.reply(200, {'text': '你好世界'}),
      // Matching FormData compares fields plus file name/type/length.
      data: formOf({
        'file': MultipartFile.fromBytes([1, 2, 3],
            filename: 'voice.m4a',
            contentType: DioMediaType.parse('audio/mp4')),
        'model': 'whisper-1',
        'language': 'zh',
      }),
      headers: {'Authorization': 'Bearer sk-x'},
    );

    final text = await api.transcribe(
      model: 'whisper-1',
      bytes: [1, 2, 3],
      filename: 'voice.m4a',
      language: 'zh',
    );

    expect(text, '你好世界');
  });

  test('empty language hint is omitted from the form', () async {
    adapter.onPost(
      '/audio/transcriptions',
      (server) => server.reply(200, {'text': ''}),
      data: formOf({
        'file': MultipartFile.fromBytes([0], filename: 'v.m4a'),
        'model': 'm',
      }),
    );

    expect(await api.transcribe(model: 'm', bytes: [0], filename: 'v.m4a'), '');
  });

  test('missing text field yields empty string', () async {
    adapter.onPost(
      '/audio/transcriptions',
      (server) => server.reply(200, <String, dynamic>{}),
      data: Matchers.isA<FormData>(),
    );
    expect(
        await api.transcribe(model: 'm', bytes: [0], filename: 'v.m4a'), '');
  });

  test('OpenAI-style error body maps to AsrApiException', () async {
    adapter.onPost(
      '/audio/transcriptions',
      (server) => server.throws(
        401,
        DioException(
          requestOptions: RequestOptions(path: '/audio/transcriptions'),
          response: Response(
            requestOptions: RequestOptions(path: '/audio/transcriptions'),
            statusCode: 401,
            data: {
              'error': {'message': 'Incorrect API key provided'}
            },
          ),
        ),
      ),
      data: Matchers.isA<FormData>(),
    );

    await expectLater(
      api.transcribe(model: 'm', bytes: [0], filename: 'v.m4a'),
      throwsA(isA<AsrApiException>()
          .having((e) => e.message, 'message', 'Incorrect API key provided')
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('dashscope dialect posts input_audio chat completion', () async {
    adapter.onPost(
      '/chat/completions',
      (server) => server.reply(200, {
        'choices': [
          {
            'message': {'role': 'assistant', 'content': '你好，世界。'},
          }
        ],
      }),
      data: {
        'model': 'qwen3-asr-flash',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {
                  'data': 'data:audio/mpeg;base64,QUJD',
                },
              },
            ],
          },
        ],
        'asr_options': {'language': 'zh', 'enable_itn': true},
      },
      headers: {'Authorization': 'Bearer sk-x'},
    );

    final text = await api.transcribe(
      model: 'qwen3-asr-flash',
      bytes: convert.utf8.encode('ABC'),
      filename: 'voice.mp3',
      mimeType: 'audio/mpeg',
      language: 'zh',
      dialect: AsrDialect.dashscope,
    );

    expect(text, '你好，世界。');
  });

  test('dashscope dialect omits language when unset', () async {
    adapter.onPost(
      '/chat/completions',
      (server) => server.reply(200, {
        'choices': [
          {'message': {'content': ''}}
        ],
      }),
      data: Matchers.isA<Map>(),
    );
    final text = await api.transcribe(
      model: 'qwen3-asr-flash',
      bytes: [0],
      filename: 'voice.m4a',
      dialect: AsrDialect.dashscope,
    );
    expect(text, '');
  });

  test('dashscope native dialect posts input.messages and parses output',
      () async {
    adapter.onPost(
      '/api/v1/services/aigc/multimodal-generation/generation',
      (server) => server.reply(200, {
        'output': {
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {
                'role': 'assistant',
                'content': [
                  {'text': '你好，世界。'}
                ],
              },
            }
          ],
        },
        'usage': {'input_tokens_details': {'text_tokens': 0}, 'seconds': 1},
        'request_id': 'req-1',
      }),
      data: {
        'model': 'qwen3-asr-flash',
        'input': {
          'messages': [
            {
              'role': 'user',
              'content': [
                {'audio': 'data:audio/mpeg;base64,QUJD'},
              ],
            },
          ],
        },
        'parameters': {
          'asr_options': {'language': 'zh', 'enable_itn': true},
        },
      },
      headers: {'Authorization': 'Bearer sk-x'},
    );

    final text = await api.transcribe(
      model: 'qwen3-asr-flash',
      bytes: convert.utf8.encode('ABC'),
      filename: 'voice.mp3',
      mimeType: 'audio/mpeg',
      language: 'zh',
      dialect: AsrDialect.dashscopeNative,
    );

    expect(text, '你好，世界。');
  });

  test('dashscope native dialect joins multi-part content', () async {
    adapter.onPost(
      '/api/v1/services/aigc/multimodal-generation/generation',
      (server) => server.reply(200, {
        'output': {
          'choices': [
            {
              'message': {
                'content': [
                  {'text': '第一段'},
                  {'text': '第二段'},
                ],
              },
            }
          ],
        },
      }),
      data: Matchers.isA<Map>(),
    );
    expect(
        await api.transcribe(
            model: 'm', bytes: [0], filename: 'v.m4a',
            dialect: AsrDialect.dashscopeNative),
        '第一段第二段');
  });

  test('normalizeAsrBaseUrl adds scheme and strips slashes', () {
    expect(normalizeAsrBaseUrl('asr.example.com/v1/'),
        'https://asr.example.com/v1');
    expect(normalizeAsrBaseUrl('http://10.0.2.2:8080/v1'),
        'http://10.0.2.2:8080/v1');
    expect(asrBaseUrlInvalid('https://api.example.com/v1'), isFalse);
    expect(asrBaseUrlInvalid('not a url'), isTrue);
    expect(asrBaseUrlInvalid(''), isTrue);
  });

  test('dashscope dialect rewrites the native /api/v1 prefix', () {
    // Copied from the Model Studio console: DashScope native protocol.
    expect(
        normalizeAsrBaseUrl(
            'https://llm-xxx.cn-beijing.maas.aliyuncs.com/api/v1',
            dialect: AsrDialect.dashscope),
        'https://llm-xxx.cn-beijing.maas.aliyuncs.com/compatible-mode/v1');
    expect(
        normalizeAsrBaseUrl('https://dashscope.aliyuncs.com/api/v1',
            dialect: AsrDialect.dashscope),
        'https://dashscope.aliyuncs.com/compatible-mode/v1');
    // Already-correct input is untouched.
    expect(
        normalizeAsrBaseUrl(
            'https://dashscope.aliyuncs.com/compatible-mode/v1',
            dialect: AsrDialect.dashscope),
        'https://dashscope.aliyuncs.com/compatible-mode/v1');
    // Other dialects keep the pasted path.
    expect(normalizeAsrBaseUrl('https://x.example.com/api/v1'),
        'https://x.example.com/api/v1');
  });

  test('dashscope native dialect collapses to the host root', () {
    expect(
        normalizeAsrBaseUrl('https://llm-xxx.cn-beijing.maas.aliyuncs.com/api/v1',
            dialect: AsrDialect.dashscopeNative),
        'https://llm-xxx.cn-beijing.maas.aliyuncs.com');
    expect(
        normalizeAsrBaseUrl('https://dashscope.aliyuncs.com/compatible-mode/v1',
            dialect: AsrDialect.dashscopeNative),
        'https://dashscope.aliyuncs.com');
    expect(normalizeAsrBaseUrl('https://dashscope.aliyuncs.com',
        dialect: AsrDialect.dashscopeNative),
        'https://dashscope.aliyuncs.com');
  });

  test('bare gateway error still carries the HTTP status', () async {
    adapter.onPost(
      '/audio/transcriptions',
      (server) => server.throws(
        404,
        DioException(
          requestOptions: RequestOptions(path: '/audio/transcriptions'),
          response: Response(
            requestOptions: RequestOptions(path: '/audio/transcriptions'),
            statusCode: 404,
          ),
        ),
      ),
      data: Matchers.isA<FormData>(),
    );

    await expectLater(
      api.transcribe(model: 'm', bytes: [0], filename: 'v.m4a'),
      throwsA(isA<AsrApiException>()
          .having((e) => e.message, 'message', 'HTTP 404 Request failed')
          .having((e) => e.statusCode, 'statusCode', 404)),
    );
  });

  test('silentWav produces a parseable RIFF header', () {
    final wav = silentWav(seconds: 1);
    expect(wav.length, 44 + 16000 * 2);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
  });
}
