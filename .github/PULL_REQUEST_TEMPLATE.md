<!--
Short is fine. A two-line fix needs two lines here. A change to sync,
the data format, or the lock definitely needs the "why" spelled out.
-->

### What does this PR do?

### Why?
<!-- The problem it removes, or the requirement it satisfies. Reference the
     requirement IDs from docs/BUILD_CHECKLIST.md when relevant (e.g. X-03, G-17). -->

Closes #

### How to verify

```bash
flutter analyze
flutter test
```

- [ ] `flutter analyze` is clean
- [ ] `flutter test` passes, including `sync_decision_test.dart`
      (the tombstone invariant — if this fails, the change is wrong, not the test)
- [ ] `dart format lib test` run
- [ ] `CHANGELOG.md` updated under **Unreleased** (skip for docs-only changes)
- [ ] No new dependency, or the reason is stated above
- [ ] No token, passphrase or private note text in the diff, logs, or screenshots

### Screenshots / recording
<!-- Required for UI changes; delete this section otherwise. -->

### Anything a reviewer should know
<!-- Ordering constraints, migrations, or follow-up you deliberately skipped. -->
