# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and this project uses SemVer
pre-release tags for beta builds (example: `1.0.0-beta.1`).

## [Unreleased]

### Added

- _Add upcoming features here._

### Changed

- _Add upcoming behavior/UX changes here._

### Fixed

- _Add bug fixes here._

## [1.0.0-beta.5] - 2026-09-23

### Added

- Hard Mode: live check in question generation that rejects any question
  where two answer options look the same or too similar once drawn.
- Visual (pixel-level) and data-level diagnostic tests for Hard Mode.

### Changed

- Hard Mode Odd Man Out: "scaling" and "count the shapes" questions now
  vary size/shape across options so they require reasoning, and are back
  in rotation. The easy "spot the different fill" rule is retired from
  Hard Mode.

### Fixed

- Figure Series: two answer options could be pixel-identical (~20% of
  questions).
- Odd Man Out, Pattern Completion and Analogy: options that looked
  identical because of shape symmetry or faint shading differences.
- Figure Match: one wrong answer had a smaller corner square that gave it
  away; corner markers could stack on top of each other.

## [1.0.0-beta.1] - 2026-05-04

### Added

- Initial beta release pipeline and documentation.

### Changed

- Standardized beta release guidance and tagging flow.

### Fixed

- N/A

[Unreleased]: https://github.com/<owner>/<repo>/compare/v1.0.0-beta.1...HEAD

[1.0.0-beta.1]: https://github.com/<owner>/<repo>/releases/tag/v1.0.0-beta.1
