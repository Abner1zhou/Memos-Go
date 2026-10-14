import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:memos_go/data/api/llm_api.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late LlmApi api;

  setUp(() {
    dio = createLlmDio(baseUrl: 'https://llm.example.com/v1', apiKey: 'sk-x');
    adapter = DioAdapter(dio: dio);
    api = LlmApi(dio);
  });

  test('chat posts messages and parses assistant content', () async {
    adapter.onPost(
      '/chat/completions',
      (server) => server.reply(200, {
        'choices': [
          {
            'message': {'role': 'assistant', 'content': '你好，摘要在这里。'}
          }
        ],
      }),
      data: {
        'model': 'deepseek-chat',
        'messages': [
          {'role': 'system', 'content': '你是摘要助手'},
          {'role': 'user', 'content': '总结这些笔记'},
        ],
        'max_tokens': 512,
      },
      headers: {'Authorization': 'Bearer sk-x'},
    );

    final text = await api.chat(
      model: 'deepseek-chat',
      messages: const [
        LlmChatMessage(role: 'system', content: '你是摘要助手'),
        LlmChatMessage(role: 'user', content: '总结这些笔记'),
      ],
      maxTokens: 512,
    );

    expect(text, '你好，摘要在这里。');
  });

  test('chat without optional params omits them from the body', () async {
    adapter.onPost(
      '/chat/completions',
      (server) => server.reply(200, {
        'choices': [
          {'message': {'content': ''}}
        ],
      }),
      data: {
        'model': 'm',
        'messages': [
          {'role': 'user', 'content': 'hi'}
        ],
      },
    );
    expect(
      await api.chat(
          model: 'm',
          messages: const [LlmChatMessage(role: 'user', content: 'hi')]),
      '',
    );
  });

  test('chat with missing choices yields empty string', () async {
    adapter.onPost(
      '/chat/completions',
      (server) => server.reply(200, <String, dynamic>{}),
      data: Matchers.isA<Map>(),
    );
    expect(
      await api.chat(
          model: 'm',
          messages: const [LlmChatMessage(role: 'user', content: 'hi')]),
      '',
    );
  });

  test('embeddings posts inputs and parses one vector per input', () async {
    adapter.onPost(
      '/embeddings',
      (server) => server.reply(200, {
        'data': [
          {
            'object': 'embedding',
            'embedding': [0.1, 0.2, 0.3],
          },
          {
            'object': 'embedding',
            'embedding': [0.4, 0.5],
          },
        ],
      }),
      data: {
        'model': 'text-embedding-3-small',
        'input': ['你好', 'hello'],
      },
      headers: {'Authorization': 'Bearer sk-x'},
    );

    final vectors = await api.embeddings(
      model: 'text-embedding-3-small',
      inputs: ['你好', 'hello'],
    );

    expect(vectors, [
      [0.1, 0.2, 0.3],
      [0.4, 0.5],
    ]);
  });

  test('embeddings with non-list data yields empty list', () async {
    adapter.onPost(
      '/embeddings',
      (server) => server.reply(200, {'data': 'nope'}),
      data: Matchers.isA<Map>(),
    );
    expect(
      await api.embeddings(model: 'm', inputs: ['x']),
      isEmpty,
    );
  });

  test('OpenAI-style error body maps to LlmApiException', () async {
    adapter.onPost(
      '/chat/completions',
      (server) => server.throws(
        401,
        DioException(
          requestOptions: RequestOptions(path: '/chat/completions'),
          response: Response(
            requestOptions: RequestOptions(path: '/chat/completions'),
            statusCode: 401,
            data: {
              'error': {'message': 'Incorrect API key provided'}
            },
          ),
        ),
      ),
      data: Matchers.isA<Map>(),
    );

    await expectLater(
      api.chat(
          model: 'm',
          messages: const [LlmChatMessage(role: 'user', content: 'hi')]),
      throwsA(isA<LlmApiException>()
          .having((e) => e.message, 'message', 'Incorrect API key provided')
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('bare gateway error still carries the HTTP status', () async {
    adapter.onPost(
      '/chat/completions',
      (server) => server.throws(
        404,
        DioException(
          requestOptions: RequestOptions(path: '/chat/completions'),
          response: Response(
            requestOptions: RequestOptions(path: '/chat/completions'),
            statusCode: 404,
          ),
        ),
      ),
      data: Matchers.isA<Map>(),
    );

    await expectLater(
      api.chat(
          model: 'm',
          messages: const [LlmChatMessage(role: 'user', content: 'hi')]),
      throwsA(isA<LlmApiException>()
          .having((e) => e.message, 'message', 'HTTP 404 Request failed')
          .having((e) => e.statusCode, 'statusCode', 404)),
    );
  });

  test('normalizeLlmBaseUrl adds scheme and strips slashes', () {
    expect(normalizeLlmBaseUrl('llm.example.com/v1/'),
        'https://llm.example.com/v1');
    expect(normalizeLlmBaseUrl('http://10.0.2.2:11434/v1'),
        'http://10.0.2.2:11434/v1');
    expect(llmBaseUrlInvalid('https://api.example.com/v1'), isFalse);
    expect(llmBaseUrlInvalid('not a url'), isTrue);
    expect(llmBaseUrlInvalid(''), isTrue);
  });

  test('asLlmApiError unwraps nested exceptions', () {
    const direct = LlmApiException('x');
    expect(asLlmApiError(direct), same(direct));
    expect(
      asLlmApiError(DioException(
        requestOptions: RequestOptions(path: '/'),
        error: direct,
      )),
      same(direct),
    );
    expect(asLlmApiError(StateError('x')), isNull);
  });
}
