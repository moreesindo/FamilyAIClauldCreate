#!/usr/bin/env python3
"""
FamilyAI Whisper ASR Service
Provides speech-to-text transcription using Faster Whisper
"""

import os
import logging
import yaml
import tempfile
from typing import Optional
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
import uvicorn
from faster_whisper import WhisperModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s"}'
)
logger = logging.getLogger(__name__)

# Load configuration
with open("/app/config.yaml", "r") as f:
    CONFIG = yaml.safe_load(f)

# Initialize FastAPI app
app = FastAPI(title="FamilyAI Whisper ASR", version="1.0.0")

# Global model variable
model = None

@app.on_event("startup")
async def load_model():
    """Load Whisper model on startup"""
    global model

    logger.info(f"Loading Whisper model: {CONFIG['model']['name']}")

    try:
        model = WhisperModel(
            CONFIG['model']['name'],
            device=CONFIG['model']['device'],
            compute_type=CONFIG['model']['compute_type'],
            download_root=CONFIG['cache']['directory']
        )
        logger.info("Whisper model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy" if model is not None else "loading",
        "service": "familyai-whisper",
        "model": CONFIG['model']['name']
    }

@app.post("/v1/audio/transcriptions")
async def transcribe_audio(
    file: UploadFile = File(...),
    language: Optional[str] = Form(None),
    task: Optional[str] = Form("transcribe"),
    temperature: Optional[float] = Form(None)
):
    """
    Transcribe audio file to text

    Args:
        file: Audio file (mp3, wav, m4a, etc.)
        language: Language code (optional, auto-detect if not specified)
        task: 'transcribe' or 'translate' (translate to English)
        temperature: Sampling temperature (0.0 = greedy)
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded yet")

    # Save uploaded file temporarily
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file.filename.split('.')[-1]}") as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_file_path = tmp_file.name

        logger.info(f"Transcribing audio file: {file.filename}")

        # Perform transcription
        segments, info = model.transcribe(
            tmp_file_path,
            language=language or CONFIG['language']['default'],
            task=task or CONFIG['language']['task'],
            beam_size=CONFIG['performance']['beam_size'],
            best_of=CONFIG['performance']['best_of'],
            temperature=temperature if temperature is not None else CONFIG['performance']['temperature'],
            vad_filter=CONFIG['performance']['vad_filter']
        )

        # Collect all segments
        full_text = ""
        segments_list = []

        for segment in segments:
            full_text += segment.text
            segments_list.append({
                "id": segment.id,
                "start": segment.start,
                "end": segment.end,
                "text": segment.text,
                "confidence": segment.avg_logprob
            })

        # Clean up temp file
        os.unlink(tmp_file_path)

        logger.info(f"Transcription completed: {len(segments_list)} segments, language: {info.language}")

        return JSONResponse(content={
            "text": full_text.strip(),
            "language": info.language,
            "duration": info.duration,
            "segments": segments_list
        })

    except Exception as e:
        logger.error(f"Transcription error: {e}")
        # Clean up temp file if it exists
        if 'tmp_file_path' in locals():
            try:
                os.unlink(tmp_file_path)
            except:
                pass
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

@app.post("/v1/audio/translations")
async def translate_audio(
    file: UploadFile = File(...),
    temperature: Optional[float] = Form(None)
):
    """
    Translate audio to English

    Args:
        file: Audio file in any language
        temperature: Sampling temperature
    """
    return await transcribe_audio(
        file=file,
        language=None,
        task="translate",
        temperature=temperature
    )

if __name__ == "__main__":
    uvicorn.run(
        app,
        host=CONFIG['api']['host'],
        port=CONFIG['api']['port'],
        workers=CONFIG['api']['workers'],
        log_level=CONFIG['api']['log_level']
    )
