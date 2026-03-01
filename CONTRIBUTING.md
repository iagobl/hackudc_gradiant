# Contributing to HackUDC Gradiant Vault

First off, thank you for considering contributing to this project! It's people like you that make the open-source community such an amazing place to learn, inspire, and create.

## How to Set Up the Development Environment
1. Install [Flutter](https://docs.flutter.dev/get-started/install).
2. Clone the repository: `git clone https://github.com/josef/hackudc_gradiant.git`.
3. Fetch dependencies: `flutter pub get`.
4. Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`.

## Coding Standards
- Follow the official [Dart Style Guide](https://dart.dev/guides/language/analysis-options).
- Use `flutter format .` before committing.
- Ensure all new features are covered by tests.

## Pull Request Process
1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Submit a pull request.

## Commit Conventions
We follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` for new features.
- `fix:` for bug fixes.
- `docs:` for documentation changes.
- `refactor:` for code changes that neither fix a bug nor add a feature.

## Review Expectations
- PRs will be reviewed by maintainers within a few days.
- Be open to feedback and suggestions.
