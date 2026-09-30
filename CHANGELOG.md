# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Language setting (*General → Language*): System default, English or Türkçe
  for month and day names, dates and the calendar's texts.
- Subtle animations: jumping to today slides and fades the month in, the
  month title fades, days and week numbers react to hover and press, new
  word-count dots and heatmap tints fade in, and today's marker settles in
  when first shown. They follow Plasma's animation speed.

### Fixed

- Obsidian comes to the front when a day is clicked instead of opening the
  note in the background (KWin is asked to activate its window).

## [0.1.0] - 2026-09-30

First release.

### Added

- Month calendar of Obsidian daily notes for the Plasma 6 desktop and panels.
- Reads daily and weekly note settings from Periodic Notes (0.x and 1.0 beta),
  the core Daily notes plugin and the Calendar plugin, honoring which plugins
  are enabled; every value can be overridden.
- Word-count dots like the Calendar plugin (words per dot, up to five), or dots
  by file size.
- Week-number column that opens weekly notes.
- Click a day to open its note; today without a note goes through
  `obsidian://daily` so Obsidian applies the template (when the widget uses
  Obsidian's daily folder and format); creating empty notes for other days is
  optional.
- Two designs: Plasma Native and Journal (heatmap tiles).
- Appearance settings: any installed KDE color scheme for the widget, custom
  accent color with automatic contrast, Plasma/translucent/solid/no background
  with opacity, text size, spacing and day shape.
- Notes this month and current streak.
- Scrolling like Plasma's calendar (touchpad, wheel, keyboard, buttons),
  keyboard navigation across months, accessible names and tooltips.
- Vault picker listing the vaults Obsidian knows (native, Flatpak and Snap).
- Clear messages for a missing vault, a folder without `.obsidian`, a relative
  path, a vault that doesn't respond, links Obsidian couldn't open, broken
  config files and unsupported formats.
- English and Turkish translations.

[Unreleased]: https://github.com/diyar4772/obsidian-calendar-plasmoid/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/diyar4772/obsidian-calendar-plasmoid/releases/tag/v0.1.0
