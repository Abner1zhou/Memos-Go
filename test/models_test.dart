import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/api/memos_api_client.dart';
import 'package:memos_go/data/models/models.dart';

void main() {
  group('Memo', () {
    test('parses a full v0.31 payload', () {
      final memo = Memo.fromJson({
        'name': 'memos/abc123',
        'state': 'NORMAL',
        'creator': 'users/1',
        'content': 'hello #world',
        'visibility': 'PUBLIC',
        'pinned': true,
        'tags': ['world'],
        'createTime': '2026-10-01T10:00:00Z',
        'updateTime': '2026-10-02T10:00:00Z',
        'attachments': [
          {
            'name': 'attachments/uid1',
            'filename': 'pic.png',
            'type': 'image/png',
            'size': 1234,
          }
        ],
      });
      expect(memo.uid, 'abc123');
      expect(memo.visibility, MemoVisibility.public);
      expect(memo.pinned, isTrue);
      expect(memo.tags, ['world']);
      expect(memo.attachments.single.uid, 'uid1');
      expect(memo.attachments.single.isImage, isTrue);
      expect(memo.createTime, isNotNull);
    });

    test('tolerates missing fields from older servers', () {
      final memo = Memo.fromJson({'name': 'memos/x'});
      expect(memo.content, '');
      expect(memo.visibility, MemoVisibility.private);
      expect(memo.tags, isEmpty);
      expect(memo.attachments, isEmpty);
      expect(memo.createTime, isNull);
    });

    test('toCreateJson uses proto enum names', () {
      const memo =
          Memo(name: 'memos/m', content: 'x', visibility: MemoVisibility.protected);
      expect(memo.toCreateJson(),
          {'content': 'x', 'visibility': 'PROTECTED'});
    });
  });

  group('Attachment', () {
    test('parses size encoded as protojson int64 string', () {
      // grpc-gateway serializes int64 fields as strings; the upload response
      // from a real server is e.g. {"size":"70"}.
      final attachment = Attachment.fromJson({
        'name': 'attachments/n8M6wTfchZ7SpAjdbDyeHu',
        'filename': 'test.png',
        'type': 'image/png',
        'size': '70',
      });
      expect(attachment.size, 70);
      expect(attachment.uid, 'n8M6wTfchZ7SpAjdbDyeHu');
      expect(attachment.isImage, isTrue);
    });

    test('parses size as JSON number and tolerates junk', () {
      expect(Attachment.fromJson({'name': 'a/b', 'size': 42}).size, 42);
      expect(Attachment.fromJson({'name': 'a/b', 'size': 'n/a'}).size, 0);
      expect(Attachment.fromJson({'name': 'a/b'}).size, 0);
    });
  });

  group('normalizeBaseUrl', () {
    test('adds scheme and strips suffixes', () {
      expect(normalizeBaseUrl('memos.example.com'),
          'https://memos.example.com');
      expect(normalizeBaseUrl('http://host:5230/'),
          'http://host:5230');
      expect(normalizeBaseUrl('https://host/api/v1'),
          'https://host');
      expect(normalizeBaseUrl('  https://host//  '), 'https://host');
    });
  });

  group('UserStats', () {
    test('parses tagCount map', () {
      final stats = UserStats.fromJson({
        'tagCount': {'work': 3, 'life': 1}
      });
      expect(stats.tagCounts['work'], 3);
    });

    test('empty json yields empty map', () {
      expect(UserStats.fromJson({}).tagCounts, isEmpty);
    });
  });
}
