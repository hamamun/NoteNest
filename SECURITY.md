# Security Policy

NoteNest is a local-first app whose whole promise is that your notes stay on
your device and in a GitHub repository you control. Security problems in it are
worth reporting quietly and fixing fast.

## Reporting a vulnerability

**Do not open a public issue for anything that could expose a user's notes,
token, or PIN.** Use one of these instead:

1. **Private vulnerability report** (preferred):
   [Report a vulnerability](https://github.com/hamamun/NoteNest/security/advisories/new)
   on the *Security* tab. GitHub keeps it hidden from public view and lets you
   collaborate on a fix privately.
2. **Encrypted email**, if the advisory form does not suit you: open a normal
   issue titled `Security contact` and the maintainer will reply with a way to
   exchange encrypted messages. Do not describe the vulnerability in that issue.

### What to include

- NoteNest version (Settings → About, e.g. `1.0.0+1`) and platform
- The affected file or subsystem (`lib/features/sync/sync_engine.dart`, …)
- Steps to reproduce, and what an attacker gains
- A proof of concept is helpful; a working exploit is not required, and please
  do not test it against repositories or devices you do not own

## Scope

**In scope**

- Theft or disclosure of a GitHub personal access token
- Notes, images or backups reaching a repository or a party their owner did not
  authorize — including via the "public repository" guard being bypassed
- A sync or delete bug that silently destroys user content
- Token or note content leaking into logs, crash dumps, or files
- PIN lock bypass that reveals hidden notes on a device that is merely unlocked
  (for example a backgrounded Android app that should be locked)
- Path traversal or code execution via a crafted repository, backup archive, or
  Markdown file imported from disk
- Backup encryption weaknesses (AES-256-GCM / PBKDF2 parameters)

**Out of scope**

- Attacks requiring physical access to an unlocked, rooted or jailbroken device —
  the SQLite file is not encrypted at rest by design, and the PIN is a
  screen-lock, not disk encryption
- Attacks where the attacker already holds the user's GitHub account, a valid
  token, or the backup passphrase
- Weak user-chosen PINs or passphrases
- Social engineering of the user
- Third-party dependency vulnerabilities without a demonstrated impact on
  NoteNest's threat model (a pull request bumping the pin is still welcome)
- The availability of GitHub itself

## Known design trade-offs

These are documented limits, not vulnerabilities:

- Note bodies sync as **plain Markdown** unless the user enables *Encrypt notes
  before upload*. Anyone with read access to the repository can therefore read
  them — that is what "your own private repository" means.
- Deleting content removes it from the latest files, but old content can remain
  in **Git history** of your repository.
- The PIN lock protects against casual shoulder-surfing on a shared device, not
  a forensic attacker with the disk.
- The PIN is not recoverable. There is no reset path and no recovery email,
  because that would require exactly the account system this app avoids.

## Response process

| Step | Target |
|------|--------|
| Acknowledge the report | within 5 business days |
| Assess severity and confirm a fix plan | within 14 days |
| Ship a patched release | varies with severity |
| Publish a GitHub Security Advisory + credit the reporter | with the release |

NoteNest is maintained by one person, on a volunteer basis. If you need a
faster response for something critical, say so in the report and it will be
prioritised; if you cannot reach anyone within a month, feel free to disclose
publicly after noting that you tried.

## Hardening checklist for users

- Use a **fine-grained** token scoped to one repository, with an **expiry date**
- Give it **Contents: Read and write** and nothing else
- Keep the repository **private** (the app enforces this, do not work around it)
- Turn on **encrypted backups** if the archive may leave your machine
- Turn on **encrypted note sync** if the repository may ever be shared
- Use a **long backup passphrase** — it is the only encryption key you control
- Enable **two-factor authentication** on the GitHub account that owns the repo
