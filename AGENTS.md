# Repository Guidelines

## Project Structure & Module Organization

This repository is a Quickshell desktop shell fork of illogical-impulse. `shell.qml` is the entry point; `panelFamilies/` assembles the shell panels. Feature interfaces live in `modules/ii/`, reusable widgets and utilities in `modules/common/`, and shared state and system integrations in `services/`.

Python and Bash helpers live in `scripts/`, grouped by function, such as `theming/` and `wallpapers/`. `assets/` contains fonts, icons, images, and sounds; `defaults/` provides bundled defaults. Locale JSON files and translation tools live in `translations/`. Automated tests currently cover icon theming in `tests/icon_theme_manager/`.

## Build, Test, and Development Commands

There is no repository-wide build step or package-manager workflow. Development requires Quickshell and the existing illogical-impulse environment described in `README.md`.

- `qs -c end4-pC`: launch the shell when this checkout is installed at `~/.config/quickshell/end4-pC`.
- `python3 -m unittest discover -s tests/icon_theme_manager -p 'test_*.py'`: run the icon-theme test suite from the repository root.
- `qmlformat -i path/to/Component.qml`: format a changed QML file using `.qmlformat.ini`.
- `bash -n scripts/path/to/script.sh`: check a changed Bash script for syntax errors.

## Coding Style & Naming Conventions

Use four spaces, Unix newlines, and a 110-column target for QML, following `.qmlformat.ini`. Preserve existing import ordering. Name QML components in PascalCase, properties and functions in camelCase, and Python functions in snake_case. Follow neighboring files for script naming. Reuse common widgets and service APIs before adding duplicate implementations.

## Testing Guidelines

Tests use Python's standard-library `unittest`; name files `test_*.py` and methods `test_*`. Add regression coverage for changes to icon-theme management, adapters, and workers. Use temporary directories and mocked environment variables to isolate filesystem operations. No numeric coverage threshold is configured. For UI changes, manually check affected panels in a running desktop and include screenshots when useful.

## Commit & Pull Request Guidelines

Recent history uses scoped Conventional Commit subjects, such as `fix(dock): ...`, `feat(dock): ...`, and `refactor(dock): ...`. Keep commits focused. Pull requests should explain the problem, resulting behavior, validation performed, and any related issue. Include before-and-after screenshots for visible changes and identify compositor-specific behavior where relevant.
