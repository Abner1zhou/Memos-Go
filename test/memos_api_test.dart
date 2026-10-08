import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:memos_go/data/api/memos_api.dart';
import 'package:memos_go/data/api/memos_api_client.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/memo_repository.dart' show buildMemoFilter;

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late MemosApi api;

  setUp(() {
    dio = createMemosDio(baseUrl: 'http://localhost:5230', token: 'tok');
    adapter = DioAdapter(dio: dio);
    api = MemosApi(dio, baseUrl: 'http://localhost:5230');
  });

  test('sends bearer header and parses listMemos', () async {
    adapter.onGet(
      '/memos',
      (server) => server.reply(200, {
        'memos': [
          {'name': 'memos/a', 'content': 'hi', 'visibility': 'PRIVATE'}
        ],
        'nextPageToken': 'tok2',
      }),
      headers: {'Authorization': 'Bearer tok'},
    );

    final page = await api.listMemos(pageSize: 50, pageToken: '');
    expect(page.memos.single.content, 'hi');
    expect(page.nextPageToken, 'tok2');
  });

  test('createMemo posts memo body at /memos', () async {
    adapter.onPost(
      '/memos',
      (server) => server.reply(200, {
        'name': 'memos/new',
        'content': 'body',
        'visibility': 'PROTECTED',
      }),
      data: {'content': 'body', 'visibility': 'PROTECTED'},
    );

    final memo = await api.createMemo(
        content: 'body', visibility: MemoVisibility.protected);
    expect(memo.uid, 'new');
    expect(memo.visibility, MemoVisibility.protected);
  });

  test('updateMemo sends updateMask query param', () async {
    RequestOptions? captured;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        captured = options;
        handler.next(options);
      },
    ));
    adapter.onPatch(
      '/memos/abc',
      (server) => server.reply(200, {'name': 'memos/abc', 'content': 'new'}),
      data: {
        'name': 'memos/abc',
        'content': 'new',
        'visibility': 'PRIVATE',
        'pinned': false,
      },
    );

    const memo = Memo(name: 'memos/abc', content: 'new');
    final updated =
        await api.updateMemo(memo, ['content', 'visibility', 'pinned']);
    expect(updated.content, 'new');
    expect(captured!.path, endsWith('/memos/abc'));
    expect(captured!.queryParameters['updateMask'], 'content,visibility,pinned');
  });

  test('signInWithPassword posts nested credentials', () async {
    adapter.onPost(
      '/auth/signin',
      (server) => server.reply(200, {
        'user': {'name': 'users/1', 'username': 'abner'},
        'accessToken': 'jwt',
      }),
      data: {
        'passwordCredentials': {'username': 'abner', 'password': 'pw'}
      },
    );

    final (user, token) = await api.signInWithPassword('abner', 'pw');
    expect(user.uid, '1');
    expect(token, 'jwt');
  });

  test('createPersonalAccessToken returns one-time token', () async {
    adapter.onPost(
      '/users/1/personalAccessTokens',
      (server) => server.reply(200, {
        'personalAccessToken': {'name': 'users/1/personalAccessTokens/9'},
        'token': 'memos_pat_xyz',
      }),
      data: {'description': 'MemosGo', 'expiresInDays': 0},
    );

    final token = await api.createPersonalAccessToken('1', 'MemosGo');
    expect(token, 'memos_pat_xyz');
  });

  test('getCurrentUser falls back to /users/me on 404', () async {
    adapter
      ..onGet('/auth/me', (server) => server.throws(
            404,
            DioException(
              requestOptions: RequestOptions(path: '/auth/me'),
              response: Response(
                requestOptions: RequestOptions(path: '/auth/me'),
                statusCode: 404,
              ),
            ),
          ))
      ..onGet(
        '/users/me',
        (server) => server.reply(200, {'name': 'users/2', 'username': 'u2'}),
      );

    final user = await api.getCurrentUser();
    expect(user.uid, '2');
  });

  test('server error surfaces MemosApiException with message', () async {
    adapter.onGet(
      '/memos',
      (server) => server.throws(
        500,
        DioException(
          requestOptions: RequestOptions(path: '/memos'),
          response: Response(
            requestOptions: RequestOptions(path: '/memos'),
            statusCode: 500,
            data: {'message': 'boom'},
          ),
        ),
      ),
    );

    await expectLater(
      api.listMemos,
      throwsA(isA<MemosApiException>()
          .having((e) => e.message, 'message', 'boom')
          .having((e) => e.statusCode, 'statusCode', 500)),
    );
  });

  test('buildMemoFilter combines query and tag', () {
    expect(buildMemoFilter(query: 'a b', tag: 't'),
        'content.contains("a b") && "t" in tags');
    expect(buildMemoFilter(), '');
    expect(buildMemoFilter(query: 'say "hi"'),
        r'content.contains("say \"hi\"")');
  });
}
