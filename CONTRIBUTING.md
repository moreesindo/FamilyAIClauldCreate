# Contributing to FamilyAI

Thank you for your interest in contributing to FamilyAI! This document provides guidelines for contributing to the project.

## Code of Conduct

Be respectful, inclusive, and considerate of others. We're building a family-friendly project!

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yourusername/FamilyAI/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - System information (OS, hardware, etc.)
   - Logs and error messages

### Suggesting Features

1. Check existing feature requests
2. Create a new issue with:
   - Clear description of the feature
   - Use cases and benefits
   - Potential implementation approach
   - Any drawbacks or trade-offs

### Pull Requests

#### Before You Start

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Set up your development environment (see below)

#### Development Setup

```bash
# Clone your fork
git clone https://github.com/your-username/FamilyAI.git
cd FamilyAI

# Copy environment template
cp .env.example .env

# Edit .env with your settings
nano .env

# Download models (optional for testing)
./scripts/02-pull-models.sh --model chat-light

# Start services
docker-compose up -d
```

#### Code Style

**Python**:
- Follow PEP 8
- Use type hints where appropriate
- Add docstrings for functions and classes
- Run `black` for formatting: `black gateway/`

**Shell Scripts**:
- Use `#!/bin/bash` shebang
- Add comments for complex logic
- Follow Google's Shell Style Guide

**YAML/JSON**:
- 2-space indentation
- Use comments to explain non-obvious config

#### Testing

**Run Tests Before Submitting**:
```bash
# Unit tests
pytest tests/test_gateway.py

# Integration tests (requires running services)
pytest tests/ -m integration

# All tests
pytest tests/ -v
```

**Add Tests For**:
- New features
- Bug fixes
- API changes

#### Commit Guidelines

**Format**:
```
type(scope): brief description

Detailed explanation if needed

Fixes #123
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, etc.

**Examples**:
```
feat(gateway): add support for custom model routing

fix(docker): correct vLLM startup command

docs(readme): update deployment instructions
```

#### Pull Request Process

1. **Update Documentation**:
   - Update README.md if needed
   - Add/update relevant docs in `docs/`
   - Update CLAUDE.md for AI assistant guidance

2. **Run Tests**:
   ```bash
   pytest tests/ -v
   ```

3. **Create Pull Request**:
   - Clear title and description
   - Reference related issues
   - Include screenshots/logs if applicable
   - Explain what changed and why

4. **Code Review**:
   - Address review comments
   - Keep the PR focused (one feature/fix per PR)
   - Rebase if needed: `git rebase main`

5. **Merge**:
   - Maintainers will merge after approval
   - Squash commits if needed

## Development Guidelines

### Adding New Models

1. Update `.env.example` with model configuration
2. Add model to `docker-compose.yml`
3. Update gateway routing logic if needed
4. Add to documentation
5. Test thoroughly

### Adding New Services

1. Create service directory with Dockerfile
2. Add to `docker-compose.yml`
3. Create K3s deployment manifest
4. Update gateway to route to new service
5. Add health checks
6. Document in `docs/`

### Modifying Gateway

1. Update `gateway/router.py`
2. Update `gateway/config.yaml` if needed
3. Add unit tests
4. Test routing logic manually
5. Update documentation

## Project Structure

```
FamilyAI/
├── gateway/          # API gateway code
├── vllm/            # vLLM config files
├── whisper/         # Whisper ASR service
├── piper/           # Piper TTS service
├── k3s/             # Kubernetes manifests
├── monitoring/      # Prometheus/Grafana configs
├── scripts/         # Automation scripts
├── tests/           # Test suite
└── docs/            # Documentation
```

## Getting Help

- **Questions**: Open a Discussion on GitHub
- **Bugs**: Open an Issue
- **Chat**: Join our community (link TBD)

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Acknowledged in release notes
- Eligible for maintainer role (active contributors)

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.

## First Time Contributors

Look for issues labeled `good-first-issue` or `help-wanted`. These are great starting points!

**Example First Contributions**:
- Improve documentation
- Fix typos
- Add test coverage
- Improve error messages
- Add configuration examples

Thank you for contributing to FamilyAI! 🚀
