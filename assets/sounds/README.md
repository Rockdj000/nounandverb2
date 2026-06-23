# Luscious soundboard clips

Audio for the soundboard on `luscious.html`. Drop clips here and point the
`PHRASES` array in `luscious.html` at them.

## Naming convention

`luscious-<kebab-case-phrase>.<ext>` — e.g.

- `luscious-brick.m4a`
- `luscious-dont-do-it-little-girl.m4a`

## Formats

Use a web-friendly, broadly-supported format:

- `.m4a` (AAC) — preferred, small and high quality (matches the existing site audio)
- `.mp3` — universal fallback
- `.ogg` — fine for modern browsers

## Tips

- Trim to just the phrase (no dead air at the start, or it feels laggy on tap).
- Keep clips short (≈0.5–3 s) and roughly level-matched so no pad is much
  louder than the others.
- These are served same-origin, so the page CSP (`media-src 'self'`) already
  allows them — no CSP change needed.
