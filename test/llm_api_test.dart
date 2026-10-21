import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  test('embeddings aligns vectors to inputs by index', () async {
    adapter.onPost(
      '/embeddings',
      (server) => server.reply(200, {
        'data': [
          {'index': 1, 'embedding': [0.4, 0.5]},
          {'index': 0, 'embedding': [0.1, 0.2, 0.3]},
        ],
      }),
      data: Matchers.isA<Map>(),
    );

    final vectors = await api.embeddings(model: 'm', inputs: ['a', 'b']);
    expect(vectors, [
      [0.1, 0.2, 0.3],
      [0.4, 0.5],
    ]);
  });

  test('embeddings skips malformed items and missing index falls back to order',
      () async {
    adapter.onPost(
      '/embeddings',
      (server) => server.reply(200, {
        'data': [
          {'embedding': 'not-a-list'},
          {'embedding': [0.7]},
          'garbage',
        ],
      }),
      data: Matchers.isA<Map>(),
    );

    expect(await api.embeddings(model: 'm', inputs: ['a', 'b']), [
      [0.7],
    ]);
  });

  test('error kind reflects status and transport', () async {
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
              'error': {'message': 'bad key'}
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
          .having((e) => e.kind, 'kind', LlmErrorKind.auth)),
    );
  });

  test('parseChatDeltas joins SSE deltas and stops at DONE', () async {
    final bytes = Stream.fromIterable([
      utf8.encode('data: {"choices":[{"delta":{"content":"你"}}]}\n\n'),
      utf8.encode('data: {"choices":[{"delta":{"content":"好，世界"}}]}\n\n'),
      utf8.encode('data: [DONE]\n\n'),
      utf8.encode('data: {"choices":[{"delta":{"content":"不应出现"}}]}\n\n'),
    ]);
    expect(await parseChatDeltas(bytes).join(), '你好，世界');
  });

  test('parseChatDeltas survives multi-byte chars split across chunks',
      () async {
    // 部 is a three-byte UTF-8 sequence; the split lands between its bytes
    // (the `content":"` prefix is 39 bytes), so the streaming decoder has to
    // carry the partial sequence across the chunk boundary.
    final raw = utf8.encode(
        'data: {"choices":[{"delta":{"content":"部署了"}}]}\n\n'
        'data: [DONE]\n\n');
    final bytes = Stream.fromIterable([
      raw.sublist(0, 40), // ends mid-部 (0xE9 0x83 | 0xA8 …)
      raw.sublist(40),
    ]);
    expect(await parseChatDeltas(bytes).join(), '部署了');
  });

  test('parseChatDeltas skips malformed payloads and non-content events',
      () async {
    final bytes = Stream.fromIterable([
      utf8.encode(': keep-alive comment\n\n'),
      utf8.encode('data: not json\n\n'),
      utf8.encode('data: {"choices":[]}\n\n'),
      utf8.encode('data: {"choices":[{"delta":{"role":"assistant"}}]}\n\n'),
      utf8.encode('data: {"choices":[{"delta":{"content":"ok"}}]}\n\n'),
      utf8.encode('data: [DONE]\n\n'),
    ]);
    expect(await parseChatDeltas(bytes).join(), 'ok');
  });

  test('extractSseDataLines trims the data prefix', () async {
    final bytes = Stream.fromIterable(
        [utf8.encode('data: a\n\ndata:b\n\nx\n')]);
    expect(await extractSseDataLines(bytes).toList(), ['a', 'b']);
  });

  test('chatStream posts stream:true and yields deltas', () async {
    // http_mock_adapter jsonEncodes non-Uint8List reply data under its
    // default JSON content-type, which would mangle a raw SSE body (no real
    // newlines). Passing the body as bytes hits MockResponseBody.fromBytes
    // and preserves the stream verbatim.
    final sseBody = utf8.encode(
        'data: {"choices":[{"delta":{"content":"你好"}}]}\n\n'
        'data: [DONE]\n\n');
    adapter.onPost(
      '/chat/completions',
      (server) => server.reply(200, Uint8List.fromList(sseBody)),
      data: {
        'model': 'deepseek-chat',
        'messages': [
          {'role': 'user', 'content': 'hi'}
        ],
        'max_tokens': 64,
        'stream': true,
      },
      headers: {'Authorization': 'Bearer sk-x'},
    );

    final text = await api
        .chatStream(
            model: 'deepseek-chat',
            messages: const [LlmChatMessage(role: 'user', content: 'hi')],
            maxTokens: 64)
        .join();
    expect(text, '你好');
  });

  test('parseChatDeltas flushes a trailing data line without newline',
      () async {
    // Well-behaved tail: [DONE] arrives newline-terminated, as usual.
    expect(
        await parseChatDeltas(Stream.value(utf8.encode(
                'data: {"choices":[{"delta":{"content":"早"}}]}\n\n'
                'data: [DONE]\n\n')))
            .join(),
        '早');
    // Degenerate tail: the server closes the connection right after the
    // last data line with no '\n'. The decoder's flush path must still
    // emit that delta on stream close.
    expect(
        await parseChatDeltas(Stream.value(utf8.encode(
                'data: {"choices":[{"delta":{"content":"早"}}]}\n\n'
                'data: {"choices":[{"delta":{"content":"晚"}}]}')))
            .join(),
        '早晚');
  });

  test('chatStream maps mid-stream transport failures to LlmApiException',
      () async {
    // 200 arrives, one delta streams, then the connection drops — the
    // documented contract says the stream must still error with
    // [LlmApiException], not a raw socket/Dio error.
    final brokenDio =
        createLlmDio(baseUrl: 'https://llm.example.com/v1', apiKey: 'sk-x');
    brokenDio.httpClientAdapter = _MidStreamDropAdapter();
    await expectLater(
      LlmApi(brokenDio).chatStream(
          model: 'deepseek-chat',
          messages: const [LlmChatMessage(role: 'user', content: 'hi')]),
      emitsInOrder([
        '早',
        emitsError(isA<LlmApiException>()
            .having((e) => e.kind, 'kind', LlmErrorKind.unreachable)),
        emitsDone,
      ]),
    );
  });

  test('raw socket errors mid-stream classify as unreachable', () async {
    // http_mock_adapter 无法模拟“200 后读到一半掐断连接”——那条路径由上面的
    // _MidStreamDropAdapter 覆盖。这里直接驱动兜底分类：构造流中途抛
    // SocketException 一类的原始错误时应归类为 unreachable。
    expect(kindOfRawError(const SocketException('Connection reset')),
        LlmErrorKind.unreachable);
    expect(
        kindOfRawError(const HttpException('closed')), LlmErrorKind.unreachable);
    expect(kindOfRawError(StateError('x')), LlmErrorKind.unknown);
  });
}

/// Adapter whose 200 response stream yields one delta and then dies like a
/// dropped socket.
class _MidStreamDropAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final controller = StreamController<Uint8List>();
    controller.add(
        utf8.encode('data: {"choices":[{"delta":{"content":"早"}}]}\n\n'));
    controller.addError(const SocketException('connection reset by peer'));
    controller.close();
    return Future.value(ResponseBody(controller.stream, 200));
  }

  @override
  void close({bool force = false}) {}
}
