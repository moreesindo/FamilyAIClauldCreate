# User Guide

## Access Methods

### Web UI (Recommended for Most Users)

1. Open browser: `http://jetson-ip:3000`
2. Create account (first time)
3. Select model from dropdown
4. Start chatting!

**Features**:
- Chat with any model
- Upload images for vision tasks
- Voice input/output
- Conversation history
- Model switching mid-conversation

### VS Code Integration

1. Install [Continue extension](https://marketplace.visualstudio.com/items?itemName=Continue.continue)

2. Configure (`~/.continue/config.json`):
```json
{
  "models": [
    {
      "title": "FamilyAI Code (Auto)",
      "provider": "openai",
      "model": "auto",
      "apiBase": "http://jetson-ip:8080/v1",
      "apiKey": "your-api-key"
    }
  ]
}
```

3. Use in VS Code:
   - `Ctrl+L`: Open chat
   - `Ctrl+I`: Inline edit
   - Select code → Right-click → Continue options

### API Access

#### Python Example
```python
import openai

openai.api_base = "http://jetson-ip:8080/v1"
openai.api_key = "your-api-key"  # if auth enabled

# Chat completion
response = openai.ChatCompletion.create(
    model="auto",  # or specific model
    messages=[
        {"role": "user", "content": "Write a quicksort in Python"}
    ],
    temperature=0.7,
    max_tokens=500
)

print(response.choices[0].message.content)

# Streaming
for chunk in openai.ChatCompletion.create(
    model="chat-fast",
    messages=[{"role": "user", "content": "Tell me a story"}],
    stream=True
):
    print(chunk.choices[0].delta.get("content", ""), end="")
```

#### curl Example
```bash
curl http://jetson-ip:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

#### Vision Example
```python
import base64

with open("image.jpg", "rb") as f:
    image_data = base64.b64encode(f.read()).decode()

response = openai.ChatCompletion.create(
    model="vision",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "What's in this image?"},
            {"type": "image_url", "image_url": f"data:image/jpeg;base64,{image_data}"}
        ]
    }]
)

print(response.choices[0].message.content)
```

## Model Selection

### Automatic (Recommended)
Use `model: "auto"` - Gateway selects best model based on:
- Task type (code vs chat)
- Context length
- Complexity

### Manual Selection
- `code-traditional`: Code completion, bug fixes
- `code-agentic`: Multi-file analysis, long context
- `chat-advanced`: Complex reasoning, creative writing
- `chat-fast`: General conversation
- `chat-light`: Quick Q&A
- `vision`: Image understanding

## Best Practices

### For Code Tasks
1. Be specific about programming language
2. Provide context (existing code, requirements)
3. Use `code-agentic` for repository-level changes
4. Use `code-traditional` for single-file tasks

### For Chat
1. Use `chat-light` for simple queries (faster)
2. Use `chat-advanced` for complex reasoning
3. Break complex tasks into steps
4. Provide examples when possible

### For Vision
1. Use clear, well-lit images
2. Ask specific questions
3. Combine with text context
4. Support multiple images per request

## Tips and Tricks

### Temperature Control
```python
# Deterministic (code, facts)
temperature=0.0

# Balanced
temperature=0.7

# Creative (stories, brainstorming)
temperature=1.0
```

### Context Management
- Models have token limits (see [Model Selection](02-model-selection.md))
- For long documents, summarize first
- Use `code-agentic` for long-context coding (256K tokens)

### Performance Optimization
- Use appropriate model for task (don't use 32B for simple queries)
- Enable streaming for better UX
- Batch similar requests
- Cache responses when possible

## Common Use Cases

### Code Assistant
```python
# Code completion
"Complete this function: def fibonacci(n):"

# Bug fixing
"Fix the bug in this code: [paste code]"

# Explanation
"Explain what this code does: [paste code]"

# Refactoring
"Refactor this code to use list comprehension: [paste code]"
```

### Document Analysis
```python
# Summarization
"Summarize this document in 3 bullet points: [text]"

# Translation
"Translate to Chinese: [text]"

# Q&A
"Based on this document: [text]\nQuestion: [question]"
```

### Creative Tasks
```python
# Writing
"Write a blog post about AI ethics"

# Brainstorming
"Give me 10 ideas for a mobile app"

# Storytelling
"Write a short story about a robot chef"
```

## Troubleshooting

### Slow Response
- Try smaller model (e.g., `chat-fast` instead of `chat-advanced`)
- Reduce `max_tokens`
- Check system load with health check

### Low Quality Output
- Try larger model
- Increase `temperature` for creativity
- Provide more context
- Rephrase prompt

### Error Messages
- `401 Unauthorized`: Check API key
- `503 Service Unavailable`: Model not loaded, wait a bit
- `429 Too Many Requests`: Rate limit hit, slow down

See [Troubleshooting Guide](05-troubleshooting.md) for more help.
