# Releasing

## Checklist

1. Make sure `main` is green: `npm test`, `npm run lint`, `scripts/smoke-test.sh`.
2. Bump `KPlugin.Version` in `package/metadata.json`.
3. Move the *Unreleased* entries in `CHANGELOG.md` under a new
   `## [x.y.z] - YYYY-MM-DD` heading and update the links at the bottom.
4. If the UI changed, regenerate the screenshots: `scripts/screenshots.sh`.
5. Commit (`chore(release): x.y.z`), then tag and push:
   ```bash
   git tag -a vx.y.z -m "Calendar for Obsidian x.y.z"
   git push origin main vx.y.z
   ```
6. The *Release* workflow checks that the tag matches `metadata.json`, runs the
   tests, builds `obsidian-calendar-x.y.z.plasmoid`, checks that it installs and
   publishes a GitHub release with the changelog section as notes.
7. Upload the same `.plasmoid` to the KDE Store (below).

To build locally instead: `npm run build`, which writes `build/obsidian-calendar-<version>.plasmoid`.

## KDE Store (and Discover)

Discover and *Get New Widgets* on Plasma 6 (Fedora included) list the KDE Store's
**Plasma 6 Extensions** categories. Widgets uploaded to the old *Plasma 5*
categories don't show up there.

First upload:

1. Sign in at <https://store.kde.org> and choose **Add Product**.
2. Category: **Plasma 6 Extensions → Plasma 6 Widgets**.
3. Name: `Calendar for Obsidian`. Version: the release version.
4. License: **GPL-2.0-or-later**. Source link: the GitHub repository.
5. Upload the `.plasmoid` from the GitHub release as the file.
6. Images: `docs/screenshots/hero.png` first, then `journal-accent.png`,
   `native-scheme.png`, `periodic.png` and `tour.gif`.
7. Description: paste the text below.
8. Changelog: paste the release's section of `CHANGELOG.md`.

For later versions, edit the product, upload the new file and update the version
and changelog. Discover picks it up within a few hours.

### Store description

```text
Your Obsidian daily notes on the Plasma desktop. Works alongside the Calendar plugin.

A month calendar of the daily notes in your Obsidian vault, for the desktop or a panel. Days with a note get dots like in the Obsidian Calendar plugin; click a day to open its note in Obsidian, or click today to start today's note from your template.

• Reads your Obsidian settings: Periodic Notes, the core Daily notes plugin and the Calendar plugin (week start, words per dot, week numbers). Nested formats like YYYY/MM/YYYY-MM-DD work.
• Week-number column that opens your weekly notes.
• Two designs: Plasma Native, and Journal (a heatmap of how much you wrote).
• Follows your color scheme, accent color and fonts, or give the widget its own color scheme, accent color and a translucent or solid background.
• Notes-this-month count and current streak.
• Scrolls like Plasma's own calendar: touchpad, mouse wheel, keyboard.
• English and Turkish.

Privacy: the widget only reads files. To find your notes it runs a few fixed, read-only commands (cat, find, head) on your vault folder; this is why Discover says it runs executables. Nothing is written and nothing leaves your computer.

Needs KDE Plasma 6 and Obsidian. Unofficial community project, not affiliated with Obsidian or the authors of the Calendar and Periodic Notes plugins.

Source, documentation and bug reports: https://github.com/diyar4772/obsidian-calendar-plasmoid
```
