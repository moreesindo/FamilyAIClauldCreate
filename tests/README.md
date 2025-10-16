# FamilyAI Tests

## Test Structure

- `test_gateway.py` - Gateway routing logic tests
- `test_services.py` - Integration tests for services

## Running Tests

### Unit Tests
```bash
pytest tests/test_gateway.py
```

### Integration Tests
```bash
# Ensure services are running first
docker-compose up -d

# Run integration tests
pytest tests/ -m integration
```

### All Tests
```bash
pytest tests/ -v
```

## Requirements

```bash
pip install pytest requests
```

## Test Markers

- `@pytest.mark.integration` - Requires running services
- No marker - Unit test, can run standalone

## Coverage

```bash
pytest tests/ --cov=gateway --cov-report=html
```

## CI/CD

Tests are automatically run on:
- Pull requests
- Commits to main branch
- Weekly schedule

See `.github/workflows/test.yml` for CI configuration.
