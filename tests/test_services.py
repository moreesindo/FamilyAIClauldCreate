"""
Integration tests for FamilyAI services
"""

import pytest
import requests
import time

GATEWAY_URL = "http://localhost:8080"

@pytest.mark.integration
class TestVLLMServices:
    """Test vLLM services through gateway"""

    def test_code_completion(self):
        """Test code completion with traditional model"""
        response = requests.post(
            f"{GATEWAY_URL}/v1/chat/completions",
            json={
                "model": "code-traditional",
                "messages": [
                    {"role": "user", "content": "Write a hello world in Python"}
                ],
                "max_tokens": 50,
                "temperature": 0.0
            },
            timeout=30
        )

        assert response.status_code == 200
        data = response.json()
        assert "choices" in data
        assert len(data["choices"]) > 0
        content = data["choices"][0]["message"]["content"]
        assert "print" in content.lower() or "hello" in content.lower()

    def test_chat_response(self):
        """Test chat with fast model"""
        response = requests.post(
            f"{GATEWAY_URL}/v1/chat/completions",
            json={
                "model": "chat-fast",
                "messages": [
                    {"role": "user", "content": "What is 2+2?"}
                ],
                "max_tokens": 20,
                "temperature": 0.0
            },
            timeout=30
        )

        assert response.status_code == 200
        data = response.json()
        content = data["choices"][0]["message"]["content"]
        assert "4" in content

    def test_auto_routing(self):
        """Test automatic model selection"""
        response = requests.post(
            f"{GATEWAY_URL}/v1/chat/completions",
            json={
                "model": "auto",
                "messages": [
                    {"role": "user", "content": "Write a Python function"}
                ],
                "max_tokens": 50
            },
            timeout=30
        )

        assert response.status_code == 200

@pytest.mark.integration
class TestServiceHealth:
    """Test service health endpoints"""

    SERVICES = [
        ("Gateway", "http://localhost:8080/health"),
        ("Code Traditional", "http://localhost:8001/health"),
        ("Chat Fast", "http://localhost:8004/health"),
        ("Chat Light", "http://localhost:8005/health"),
    ]

    @pytest.mark.parametrize("name,url", SERVICES)
    def test_service_health(self, name, url):
        """Test individual service health"""
        try:
            response = requests.get(url, timeout=5)
            assert response.status_code == 200, f"{name} health check failed"
        except requests.RequestException as e:
            pytest.skip(f"{name} not available: {e}")

@pytest.mark.integration
def test_concurrent_requests():
    """Test handling multiple concurrent requests"""
    import concurrent.futures

    def make_request():
        response = requests.post(
            f"{GATEWAY_URL}/v1/chat/completions",
            json={
                "model": "chat-light",
                "messages": [{"role": "user", "content": "Hi"}],
                "max_tokens": 10
            },
            timeout=30
        )
        return response.status_code == 200

    # Send 5 concurrent requests
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(make_request) for _ in range(5)]
        results = [f.result() for f in futures]

    # At least 80% should succeed
    assert sum(results) >= 4

if __name__ == "__main__":
    pytest.main([__file__, "-v", "-m", "integration"])
