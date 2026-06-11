import os
import time
import json
import logging
from datetime import datetime
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import redis
import psycopg2
from psycopg2.extras import RealDictCursor

# ── Structured JSON Logger ──────────────────────────────────────────────────#
class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_obj = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "service": "fastapi-backend",
            "message": record.getMessage(),
        }
        if record.exc_info:
            log_obj["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_obj)

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger = logging.getLogger("production-app")
logger.setLevel(logging.INFO)
logger.addHandler(handler)
logger.propagate = False

# ── App Init ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="AI Backend API",
    description="Production FastAPI service with Redis caching and PostgreSQL",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Config from Environment ─────────────────────────────────────────────────
REDIS_HOST     = os.getenv("REDIS_HOST", "redis")
REDIS_PORT     = int(os.getenv("REDIS_PORT", "6379"))
DB_HOST        = os.getenv("DB_HOST", "postgres")
DB_PORT        = int(os.getenv("DB_PORT", "5432"))
DB_NAME        = os.getenv("DB_NAME", "app_db")
DB_USER        = os.getenv("DB_USER", "app_user")
DB_PASSWORD    = os.getenv("DB_PASSWORD", "secure_password")

# ── Redis Client ────────────────────────────────────────────────────────────
try:
    cache = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True, socket_connect_timeout=3)
    logger.info(f"Redis client configured → {REDIS_HOST}:{REDIS_PORT}")
except Exception as e:
    logger.error(f"Redis init error: {e}")
    cache = None

# ── DB Helpers ──────────────────────────────────────────────────────────────
def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, database=DB_NAME,
        user=DB_USER, password=DB_PASSWORD, connect_timeout=3,
        cursor_factory=RealDictCursor,
    )

def init_db():
    """Create tables on startup."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS predictions (
                id SERIAL PRIMARY KEY,
                input_text TEXT NOT NULL,
                output_text TEXT NOT NULL,
                source VARCHAR(20) DEFAULT 'llm_model',
                created_at TIMESTAMP DEFAULT NOW()
            );
        """)
        conn.commit()
        cur.close()
        conn.close()
        logger.info("Database table 'predictions' ensured.")
    except Exception as e:
        logger.warning(f"DB init skipped (will retry): {e}")

# ── Startup Event ───────────────────────────────────────────────────────────
@app.on_event("startup")
def startup_event():
    logger.info("🚀 Application starting up...")
    init_db()

# ── Request Logging Middleware ──────────────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = round((time.time() - start) * 1000, 2)
    logger.info(f"{request.method} {request.url.path} → {response.status_code} ({duration}ms)")
    return response

# ── Health Check ─────────────────────────────────────────────────────────────
@app.get("/health", tags=["Ops"])
def health_check():
    """
    System health check — verifies Redis and PostgreSQL connectivity.
    Returns HTTP 200 if all services are UP, HTTP 503 if any are DOWN.
    """
    health = {"status": "healthy", "timestamp": datetime.utcnow().isoformat() + "Z", "checks": {}}

    # Redis
    try:
        cache.ping()
        health["checks"]["redis"] = "UP"
    except Exception as e:
        health["status"] = "unhealthy"
        health["checks"]["redis"] = f"DOWN: {str(e)}"

    # PostgreSQL
    try:
        conn = get_db_connection()
        conn.close()
        health["checks"]["postgres"] = "UP"
    except Exception as e:
        health["status"] = "unhealthy"
        health["checks"]["postgres"] = f"DOWN: {str(e)}"

    status_code = 200 if health["status"] == "healthy" else 503
    if status_code == 503:
        logger.error(f"Health check FAILED: {health['checks']}")
    return JSONResponse(status_code=status_code, content=health)

# ── Readiness Probe (K8s) ────────────────────────────────────────────────────
@app.get("/ready", tags=["Ops"])
def readiness():
    """Kubernetes readiness probe."""
    return {"status": "ready"}

# ── Root ─────────────────────────────────────────────────────────────────────
@app.get("/", tags=["General"])
def root():
    return {
        "service": "AI Backend API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }

# ── AI Predict Endpoint ───────────────────────────────────────────────────────
@app.post("/v1/predict", tags=["AI"])
def ai_predict(payload: dict):
    """
    Mock AI/LLM inference endpoint with Redis caching.
    Bonus: demonstrates AI/LLM deployment experience.

    Body: { "text": "your prompt here" }
    """
    if "text" not in payload:
        raise HTTPException(status_code=400, detail="Missing required field: 'text'")

    input_text = payload["text"].strip()
    if not input_text:
        raise HTTPException(status_code=400, detail="'text' field cannot be empty")

    cache_key = f"predict:{input_text[:100]}"

    # ── Cache Hit ──
    try:
        cached = cache.get(cache_key)
        if cached:
            logger.info(f"Cache HIT for key: {cache_key[:30]}...")
            return {"response": cached, "source": "cache", "cached": True}
    except Exception as e:
        logger.warning(f"Redis read error: {e}")

    # ── LLM Simulation ──
    logger.info(f"Cache MISS. Running inference for: {input_text[:30]}...")
    time.sleep(0.4)  # Simulate model latency
    output = f"[AI Response] Analyzed: '{input_text}' — confidence: 0.97, category: general"

    # ── Cache Write ──
    try:
        cache.setex(cache_key, 3600, output)
    except Exception as e:
        logger.warning(f"Redis write error: {e}")

    # ── Persist to DB ──
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO predictions (input_text, output_text, source) VALUES (%s, %s, %s)",
            (input_text, output, "llm_model"),
        )
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        logger.warning(f"DB write error (non-fatal): {e}")

    return {"response": output, "source": "llm_model", "cached": False}

# ── List Predictions ──────────────────────────────────────────────────────────
@app.get("/v1/predictions", tags=["AI"])
def list_predictions(limit: int = 10):
    """Fetch recent predictions from PostgreSQL."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT * FROM predictions ORDER BY created_at DESC LIMIT %s", (limit,))
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return {"predictions": [dict(r) for r in rows], "count": len(rows)}
    except Exception as e:
        logger.error(f"DB read error: {e}")
        raise HTTPException(status_code=503, detail=f"Database error: {str(e)}")
