/// X-05..X-10: the sync decision table, isolated as a pure function.
///
/// This is the single most dangerous piece of logic in NoteNest. Getting it
/// wrong resurrects deleted notes. Keeping it pure means it can be tested
/// exhaustively without a network, a database or a UI (see
/// test/sync_decision_test.dart).
enum SyncAction {
  /// A tombstone exists and the local copy has no unsynced work (X-08).
  deleteLocal,

  /// A tombstone exists but the local copy has unsynced edits (X-09).
  recoverConflictCopy,

  /// A tombstone exists and there is nothing local to do (X-06).
  skipTombstoned,

  /// Genuinely new local entry.
  uploadNew,

  /// Remote has something we do not.
  pullRemote,

  /// Local changed, remote did not.
  pushLocal,

  /// Both sides changed (G-09).
  conflictCopy,

  /// Synced before, remote file vanished, no tombstone explains it (X-10).
  remoteDeleteConflict,

  /// Nothing to do.
  noop,
}

class SyncInput {
  const SyncInput({
    required this.hasTombstone,
    required this.hasLocal,
    required this.hasRemote,
    required this.localDirty,
    required this.syncedBefore,
    required this.remoteChanged,
  });

  final bool hasTombstone;
  final bool hasLocal;
  final bool hasRemote;

  /// Local row has edits that were never pushed.
  final bool localDirty;

  /// This entry has been successfully synced at least once.
  final bool syncedBefore;

  /// Remote sha differs from the sha we recorded at the last sync.
  final bool remoteChanged;
}

class SyncDecision {
  SyncDecision._();

  /// Resolves what to do with one entry id.
  ///
  /// The tombstone branch comes first and returns unconditionally. That
  /// ordering IS the anti-resurrection guarantee: no path below it can ever
  /// produce an upload for a tombstoned id.
  static SyncAction decide(SyncInput input) {
    // X-05: tombstone beats the note file, the local row, and the images.
    if (input.hasTombstone) {
      if (input.hasLocal && input.localDirty) {
        // X-09: never destroy real offline work, but never reuse the id.
        return SyncAction.recoverConflictCopy;
      }
      if (input.hasLocal) return SyncAction.deleteLocal;
      return SyncAction.skipTombstoned;
    }

    if (input.hasLocal && !input.hasRemote) {
      if (!input.syncedBefore) return SyncAction.uploadNew;
      // X-10: the file was there and is not any more. Something deleted it
      // without leaving a tombstone, so we refuse to silently recreate it.
      return SyncAction.remoteDeleteConflict;
    }

    if (!input.hasLocal && input.hasRemote) {
      return SyncAction.pullRemote;
    }

    if (input.hasLocal && input.hasRemote) {
      if (input.localDirty && input.remoteChanged) return SyncAction.conflictCopy;
      if (input.localDirty) return SyncAction.pushLocal;
      if (input.remoteChanged) return SyncAction.pullRemote;
      return SyncAction.noop;
    }

    return SyncAction.noop;
  }

  /// Actions that write the same id back to GitHub. Used by the invariant
  /// test that proves a tombstoned id can never be uploaded.
  static const Set<SyncAction> uploadActions = {
    SyncAction.uploadNew,
    SyncAction.pushLocal,
  };
}
