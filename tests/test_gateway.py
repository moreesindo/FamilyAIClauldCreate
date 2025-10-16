"""
Tests for FamilyAI Gateway
"""

import pytest
import requests
from unittest.mock import Mock, patch

# Test gateway routing logic
def test_select_code_model_traditional():
    """Test that short code queries route to traditional model"""
    from gateway.router import select_code_model
    from gateway.router import Message

    messages = [Message(role="user", content="Fix this bug in my code")]
    model = select_code_model(messages)
    assert model == "code_traditional"

def test_select_code_model_agentic():
    """Test that long context queries route to agentic model"""
    from gateway.router import select_code_model
    from gateway.router import Message

    # Long context message
    long_message = "Analyze this entire codebase: " + "x" * 10000
    messages = [Message(role="user", content=long_message)]
    model = select_code_model(messages)
    assert model == "code_agentic"

def test_select_chat_model_light():
    """Test simple queries route to light model"""
    from gateway.router import select_chat_model
    from gateway.router import Message

    messages = [Message(role="user", content="Hi")]
    model = select_chat_model(messages)
    assert model == "chat_light"

def test_select_chat_model_advanced():
    """Test complex queries route to advanced model"""
    from gateway.router import select_chat_model
    from gateway.router import Message

    long_query = "Explain in detail " + "x" * 1000
    messages = [Message(role="user", content=long_query)]
    model = select_chat_model(messages)
    assert model == "chat_advanced"

@pytest.mark.integration
def test_gateway_health_endpoint():
    """Test gateway health endpoint"""
    response = requests.get("http://localhost:8080/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"

@pytest.mark.integration
def test_gateway_models_endpoint():
    """Test models listing endpoint"""
    response = requests.get("http://localhost:8080/v1/models")
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert len(data["data"]) > 0

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
