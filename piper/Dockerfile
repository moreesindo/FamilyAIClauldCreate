FROM python:3.10-slim

# Accept proxy build args
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG http_proxy
ARG https_proxy
ARG NO_PROXY
ARG no_proxy

# Set proxy environment variables for build
ENV HTTP_PROXY=$HTTP_PROXY \
    HTTPS_PROXY=$HTTPS_PROXY \
    http_proxy=$http_proxy \
    https_proxy=$https_proxy \
    NO_PROXY=$NO_PROXY \
    no_proxy=$no_proxy

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies with flexible versions
RUN pip install --no-cache-dir \
    piper-tts>=1.2.0 \
    fastapi>=0.104.1,<1.0.0 \
    uvicorn[standard]>=0.24.0,<1.0.0 \
    python-multipart>=0.0.6 \
    pydantic>=2.5,<3.0 \
    pyyaml>=6.0.0

# Copy configuration and application code
COPY config.yaml /app/config.yaml
COPY app.py /app/app.py

# Create models directory
RUN mkdir -p /models

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["python3", "app.py"]
