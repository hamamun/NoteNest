import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/features/sync/sync_decision.dart';

/// X-16: tests for the anti-resurrection decision table.
///
/// The final test in this file is the important one. It does not check a
/// specific scenario; it proves an invariant across every possible input
/// combination: a tombstoned id can never be uploaded.
void main() {
  SyncAction decide({
    bool tombstone = false,
    bool local = false,
    bool remote = false,
    bool dirty = false,
    bool syncedBefore = false,
    bool remoteChanged = false,
  }) =>
      SyncDecision.decide(SyncInput(
        hasTombstone: tombstone,
        hasLocal: local,
        hasRemote: remote,
        localDirty: dirty,
        syncedBefore: syncedBefore,
        remoteChanged: remoteChanged,
      ));

  group('tombstone wins (X-05, X-06, X-08)', () {
    test('clean local copy is deleted', () {
      expect(
        decide(tombstone: true, local: true, syncedBefore: true),
        SyncAction.deleteLocal,
      );
    });

    test('nothing local means nothing to do', () {
      expect(decide(tombstone: true), SyncAction.skipTombstoned);
    });

    test('a remote file that still exists does not resurrect the entry', () {
      expect(
        decide(
          tombstone: true,
          local: true,
          remote: true,
          syncedBefore: true,
          remoteChanged: true,
        ),
        SyncAction.deleteLocal,
      );
    });
  });

  group('offline edit against a tombstone (X-09, QA-12)', () {
    test('unsynced work becomes a recovered copy, not a resurrection', () {
      expect(
        decide(tombstone: true, local: true, dirty: true, syncedBefore: true),
        SyncAction.recoverConflictCopy,
      );
    });
  });

  group('missing remote file (X-10)', () {
    test('a never-synced entry uploads as new', () {
      expect(
        decide(local: true, dirty: true),
        SyncAction.uploadNew,
      );
    });

    test('a previously synced entry does NOT silently re-upload', () {
      expect(
        decide(local: true, syncedBefore: true),
        SyncAction.remoteDeleteConflict,
      );
    });

    test('even with local edits it does not blindly recreate', () {
      expect(
        decide(local: true, dirty: true, syncedBefore: true),
        SyncAction.remoteDeleteConflict,
      );
    });
  });

  group('normal two-way sync (G-08, G-09)', () {
    test('remote only pulls', () {
      expect(decide(remote: true, remoteChanged: true), SyncAction.pullRemote);
    });

    test('local only pushes', () {
      expect(
        decide(local: true, remote: true, dirty: true, syncedBefore: true),
        SyncAction.pushLocal,
      );
    });

    test('remote only changed pulls', () {
      expect(
        decide(local: true, remote: true, syncedBefore: true, remoteChanged: true),
        SyncAction.pullRemote,
      );
    });

    test('both changed makes a conflict copy, never an overwrite', () {
      expect(
        decide(
          local: true,
          remote: true,
          dirty: true,
          syncedBefore: true,
          remoteChanged: true,
        ),
        SyncAction.conflictCopy,
      );
    });

    test('nothing changed does nothing', () {
      expect(
        decide(local: true, remote: true, syncedBefore: true),
        SyncAction.noop,
      );
    });
  });

  group('invariant: a tombstoned id is never uploaded (X-06)', () {
    test('holds across all 32 input combinations', () {
      final violations = <String>[];

      for (final local in [true, false]) {
        for (final remote in [true, false]) {
          for (final dirty in [true, false]) {
            for (final synced in [true, false]) {
              for (final changed in [true, false]) {
                final action = decide(
                  tombstone: true,
                  local: local,
                  remote: remote,
                  dirty: dirty,
                  syncedBefore: synced,
                  remoteChanged: changed,
                );
                if (SyncDecision.uploadActions.contains(action)) {
                  violations.add(
                    'local=$local remote=$remote dirty=$dirty '
                    'synced=$synced changed=$changed -> $action',
                  );
                }
              }
            }
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'These inputs would resurrect a deleted note:\n'
              '${violations.join("\n")}');
    });
  });
}
