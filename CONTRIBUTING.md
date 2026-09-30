# Contributing

Thanks for helping! Bug reports, translations and pull requests are all welcome.

## Reporting a bug

Open an [issue](https://github.com/diyar4772/obsidian-calendar-plasmoid/issues/new/choose)
using the bug template. The most useful details are:

- your Plasma, KDE Frameworks and Qt versions (`plasmashell --version`,
  `kinfo` or *System Settings → About this System*),
- which Obsidian plugins manage your daily notes (core Daily notes, Periodic
  Notes, Calendar) and your daily note format and folder,
- what *Configure → Notes → Detected* shows,
- messages from the widget: `journalctl --user -b | grep -i obsidiancalendar`.

Please don't attach your vault or real notes. If a file name matters, describe
its pattern instead.

## Development setup

Everything is plain QML and JavaScript; nothing needs compiling. On Fedora:

```bash
sudo dnf install plasma-sdk qt6-qtdeclarative-devel nodejs gettext
npm test                  # unit and end-to-end tests (Node 22+, no dependencies)
npm run lint              # qmllint with zero warnings + translation template check
scripts/smoke-test.sh     # loads the installed widget offscreen and fails on QML errors
npm run fixtures          # fictional demo vaults in tests/fixtures/
```

Try your changes with `plasmoidviewer -a package`, or install them with
`kpackagetool6 -t Plasma/Applet -u package` and restart Plasma
(`systemctl --user restart plasma-plasmashell`). Only installed packages load
translations.

Never test with your personal vault in bug reports or screenshots; the fixture
vaults exist for that.

## Guidelines

- Keep the widget **read-only**. Shell commands are fixed templates in
  `package/contents/code/paths.js`; every user-supplied path goes through
  `shellQuote()`, and output is NUL-separated. New commands need tests in
  `tests/paths.test.mjs` that run them against hostile file names.
- Put logic in `package/contents/code/*.js` (`.pragma library`, no QML access)
  and test it in `tests/`. QML files should stay thin.
- Use `Kirigami.Theme` colors and `Kirigami.Units` sizes; no hard-coded colors or
  pixel sizes.
- Wrap user-visible strings in `i18nc()` with a context, then run
  `scripts/i18n.sh extract`. In the calendar (everything outside the settings
  pages) use a `Translator`'s `ui18nc()` / `ui18ncp()` instead, so the
  widget's language setting applies.
- Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`,
  `fix:`, `docs:` …) and keep commits small.
- Mind older Plasma 6 releases: guard QML API newer than Qt 6.6 / KDE Frameworks
  6.0 (see how `Flickable.acceptedButtons` and `Units.cornerRadius` are handled).

## Translations

See [Translations](README.md#translations) in the README. Translation-only pull
requests are very welcome.
