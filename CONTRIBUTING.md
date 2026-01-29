# Contributing to OVH HTTP2SMS

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Set up the development environment:

```bash
# With Docker (recommended)
docker compose run --rm dev

# Without Docker
bin/setup
```

## Development Workflow

### Running Tests

```bash
# With Docker
docker compose run --rm test

# Without Docker
bundle exec rspec
```

### Running Linter

```bash
# With Docker
docker compose run --rm lint

# Without Docker
bundle exec rubocop
```

### Code Coverage

Tests must maintain 95% minimum code coverage. Coverage reports are generated in the `coverage/` directory.

## Pull Request Process

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/my-feature
   ```

2. Make your changes following the code style guidelines

3. Write tests for new functionality

4. Ensure all tests pass and linting is clean:
   ```bash
   docker compose run --rm test
   docker compose run --rm lint
   ```

5. Commit using [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `test:` for tests
   - `chore:` for maintenance

6. Push and create a Pull Request

## Code Style

- Follow the existing code patterns
- Use `frozen_string_literal: true` in all Ruby files
- Add YARD documentation for public methods
- Keep methods small and focused

## Reporting Issues

When reporting issues, please include:

- Ruby version
- Gem version
- Steps to reproduce
- Expected vs actual behavior
- Error messages and stack traces

## Questions?

Open an issue for questions or discussions about the project.
