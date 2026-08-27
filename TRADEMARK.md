# NoteNest — name and branding

NoteNest's **code** is MIT-licensed; see [LICENSE](/LICENSE). This file covers the
two things that licence deliberately does not hand out.

## Not licensed

1. The project name **"NoteNest"**.
2. The **"N" monogram** and the icon artwork in `assets/icon/`.

Both are excluded from the MIT grant, meaning: you may not use them to name,
brand or market a product, whether or not it derives from this codebase.

## What you may do

* Fork, rename, re-icon and ship it commercially — that is encouraged. Pick a
  name you own, replace `assets/icon/`, change `name:` / `--org` in
  `pubspec.yaml` and `tool/setup.*`, update the window title in `lib/app/`,
  and the MIT licence is the only obligation (keep the copyright notice in the
  source you redistribute).
* Write about it, screenshot it, link to it, and say your app is
  "inspired by NoteNest" or "NoteNest-compatible" descriptively.
* Keep this repository's name in your fork's GitHub URL — a fork is not a
  product name.

## Why this is a separate file

Putting the exclusion inside `LICENSE` breaks GitHub's licence classifier, which
matches the file against the canonical MIT text. A licence it cannot recognise
shows up as "Other", which in turn hides the repository from every
MIT-licensed-by-licence filter on GitHub, gets flagged by automated licence
compliance tooling, and makes a human reviewer read your licence twice.

Standard MIT text in `LICENSE`, the addition spelled out here.
