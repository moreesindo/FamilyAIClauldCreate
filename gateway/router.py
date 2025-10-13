#!/usr/bin/env python3
"""
FamilyAI Intelligent Routing Gateway
Routes requests to the most appropriate model based on task type and context
"""

import os
import logging
import yaml
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel
import httpx
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s"}'
)
logger = logging.getLogger(__name__)

# Load configuration
with open("/app/config.yaml", "r") as f:
    CONFIG = yaml.safe_load(f)

# Expand environment variables
def expand_env_vars(config):
    """Recursively expand environment variables in configuration"""
    if isinstance(config, dict):
        return {k: expand_env_vars(v) for k, v in config.items()}
    elif isinstance(config, str) and config.startswith("${") and config.endswith("}"):
        var_name = config[2:-1]
        return os.getenv(var_name, config)
    return config

CONFIG = expand_env_vars(CONFIG)

# Initialize FastAPI app
app = FastAPI(title="FamilyAI Gateway", version="1.0.0")

# Rate limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Models
class Message(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    model: str
    messages: List[Message]
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = None
    stream: Optional[bool] = False

# Helper functions
def estimate_tokens(text: str) -> int:
    """Rough token estimation (1 token ≈ 4 chars)"""
    return len(text) // 4

def select_code_model(messages: List[Message]) -> str:
    """Select appropriate code model based on context"""
    # Concatenate all messages
    full_context = " ".join([m.content for m in messages])
    context_tokens = estimate_tokens(full_context)

    # Check for agentic tasks
    agentic_keywords = CONFIG["routing"]["code"]["agentic_tasks"]
    if any(keyword in full_context.lower() for keyword in agentic_keywords):
        logger.info(f"Routing to code-agentic (agentic task detected)")
        return "code_agentic"

    # Check context length
    if context_tokens > CONFIG["routing"]["code"]["context_threshold"]:
        logger.info(f"Routing to code-agentic (context: {context_tokens} tokens)")
        return "code_agentic"

    logger.info(f"Routing to code-traditional (context: {context_tokens} tokens)")
    return "code_traditional"

def select_chat_model(messages: List[Message]) -> str:
    """Select appropriate chat model based on message complexity"""
    last_message = messages[-1].content if messages else ""
    message_tokens = estimate_tokens(last_message)

    # Simple query -> lightweight model
    if message_tokens < CONFIG["routing"]["chat"]["simple_max_tokens"]:
        logger.info(f"Routing to chat-light ({message_tokens} tokens)")
        return "chat_light"

    # Complex query -> advanced model
    if message_tokens > CONFIG["routing"]["chat"]["complex_min_tokens"]:
        logger.info(f"Routing to chat-advanced ({message_tokens} tokens)")
        return "chat_advanced"

    # Default -> fast model
    logger.info(f"Routing to chat-fast ({message_tokens} tokens)")
    return "chat_fast"

def get_backend_url(service: str) -> str:
    """Get backend service URL"""
    return CONFIG["backends"][service]["url"]

# Authentication
async def verify_api_key(request: Request):
    """Verify API key if authentication is enabled"""
    if not CONFIG["auth"]["enabled"]:
        return True

    api_key = request.headers.get("Authorization", "").replace("Bearer ", "")
    if api_key != CONFIG["auth"]["api_key"]:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return True

# Routes
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "familyai-gateway"}

@app.get("/v1/models")
async def list_models(auth: bool = Depends(verify_api_key)):
    """List available models"""
    models = [
        {"id": "auto", "object": "model", "owned_by": "familyai"},
        {"id": "code-traditional", "object": "model", "owned_by": "familyai"},
        {"id": "code-agentic", "object": "model", "owned_by": "familyai"},
        {"id": "chat-advanced", "object": "model", "owned_by": "familyai"},
        {"id": "chat-fast", "object": "model", "owned_by": "familyai"},
        {"id": "chat-light", "object": "model", "owned_by": "familyai"},
        {"id": "vision", "object": "model", "owned_by": "familyai"},
    ]
    return {"object": "list", "data": models}

@app.post("/v1/chat/completions")
@limiter.limit(f"{CONFIG['rate_limit']['requests_per_minute']}/minute")
async def chat_completions(
    request: Request,
    chat_request: ChatRequest,
    auth: bool = Depends(verify_api_key)
):
    """Handle chat completion requests with intelligent routing"""

    # Determine backend service
    model = chat_request.model.lower()

    if model == "auto":
        # Auto-select based on content
        first_message = chat_request.messages[0].content if chat_request.messages else ""
        if any(keyword in first_message.lower() for keyword in ["code", "function", "class", "bug", "refactor"]):
            service = select_code_model(chat_request.messages)
        else:
            service = select_chat_model(chat_request.messages)
    elif model in ["code", "code-traditional"]:
        service = "code_traditional"
    elif model == "code-agentic":
        service = "code_agentic"
    elif model in ["chat", "chat-advanced"]:
        service = "chat_advanced"
    elif model == "chat-fast":
        service = "chat_fast"
    elif model == "chat-light":
        service = "chat_light"
    elif model == "vision":
        service = "vision"
    else:
        service = select_chat_model(chat_request.messages)

    backend_url = get_backend_url(service)

    # Forward request to backend
    async with httpx.AsyncClient(timeout=300.0) as client:
        try:
            response = await client.post(
                f"{backend_url}/v1/chat/completions",
                json=chat_request.dict(),
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()

            if chat_request.stream:
                async def generate():
                    async for chunk in response.aiter_bytes():
                        yield chunk
                return StreamingResponse(generate(), media_type="text/event-stream")
            else:
                return JSONResponse(content=response.json())

        except httpx.HTTPError as e:
            logger.error(f"Backend error: {e}")
            raise HTTPException(status_code=502, detail=f"Backend service error: {str(e)}")

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint (placeholder)"""
    # TODO: Implement actual metrics collection
    return {"message": "Metrics endpoint - to be implemented"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level=CONFIG["logging"]["level"].lower())
