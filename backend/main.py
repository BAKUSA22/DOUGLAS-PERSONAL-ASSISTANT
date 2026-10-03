import os
import re
import sqlite3
from urllib.parse import urlparse
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

import requests
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent
MEMORY_DB = BASE_DIR / "douglas_memory.db"

APP_NAME = "DOUGLAS AI Backend"
JWT_SECRET = os.getenv("DOUGLAS_JWT_SECRET", "").strip()
SMART_ENV = os.getenv("SMART_ENV", "development").strip().lower()
if SMART_ENV == "production" and (not JWT_SECRET or JWT_SECRET == "CHANGE_THIS_LOCAL_SECRET_BEFORE_PRODUCTION"):
    raise RuntimeError("DOUGLAS_JWT_SECRET must be set to a strong secret in production")
if not JWT_SECRET:
    JWT_SECRET = "CHANGE_THIS_LOCAL_SECRET_BEFORE_PRODUCTION"
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

app = FastAPI(title=APP_NAME)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in os.getenv("CORS_ORIGINS", "*").split(",") if origin.strip()],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# DATABASE
# ---------------------------------------------------------------------------

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()


class DatabaseConnection:
    def __init__(self, connection):
        self.connection = connection

    def execute(self, sql, params=()):
        if DATABASE_URL:
            import psycopg2
            sql = sql.replace("?", "%s")
            sql = sql.replace("INTEGER PRIMARY KEY AUTOINCREMENT", "SERIAL PRIMARY KEY")
            sql = sql.replace("INTEGER PRIMARY KEY", "SERIAL PRIMARY KEY")
            sql = sql.replace("CURRENT_TIMESTAMP", "CURRENT_TIMESTAMP")
            return self.connection.cursor_factory(psycopg2.extras.RealDictCursor).execute(sql, params)
        return self.connection.execute(sql, params)


def get_db():
    if DATABASE_URL:
        import psycopg2
        import psycopg2.extras
        conn = psycopg2.connect(DATABASE_URL)
        return PostgresConnection(conn)
    conn = sqlite3.connect(MEMORY_DB)
    conn.row_factory = sqlite3.Row
    return SQLiteConnection(conn)


class SQLiteConnection:
    def __init__(self, connection):
        self.connection = connection

    def execute(self, sql, params=()):
        return self.connection.execute(sql, params)

    def commit(self):
        self.connection.commit()

    def close(self):
        self.connection.close()


class PostgresResult:
    def __init__(self, cursor):
        self.cursor = cursor
        self._lastrowid = None

    @property
    def lastrowid(self):
        if self._lastrowid is None:
            row = self.cursor.fetchone()
            if row is not None:
                self._lastrowid = row.get("id")
        return self._lastrowid

    def fetchone(self):
        row = self.cursor.fetchone()
        if row is None:
            return None
        return row

    def fetchall(self):
        return self.cursor.fetchall()


class PostgresConnection:
    def __init__(self, connection):
        self.connection = connection

    def execute(self, sql, params=()):
        import psycopg2.extras
        sql = sql.replace("?", "%s")
        sql = sql.replace("INTEGER PRIMARY KEY AUTOINCREMENT", "SERIAL PRIMARY KEY")

        is_user_insert = sql.lstrip().upper().startswith("INSERT INTO USERS")
        if is_user_insert and "RETURNING" not in sql.upper():
            sql = sql.rstrip().rstrip(";") + " RETURNING id"

        cursor = self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cursor.execute(sql, params)
        return PostgresResult(cursor)

    def commit(self):
        self.connection.commit()

    def close(self):
        self.connection.close()


def init_memory():
    conn = get_db()
    try:
        if DATABASE_URL:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username TEXT NOT NULL UNIQUE,
                    password_hash TEXT NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    active INTEGER NOT NULL DEFAULT 1
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS conversation_memory (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER,
                    role TEXT NOT NULL,
                    message TEXT NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS personal_memory (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER,
                    memory TEXT NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """
            )
        else:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT NOT NULL UNIQUE,
                    password_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    active INTEGER NOT NULL DEFAULT 1
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS conversation_memory (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER,
                    role TEXT NOT NULL,
                    message TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS personal_memory (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER,
                    memory TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """
            )

        conn.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_personal_memory_user_memory
            ON personal_memory(user_id, memory)
            """
        )

        conn.commit()
    finally:
        conn.close()


init_memory()


# ---------------------------------------------------------------------------
# MODELS
# ---------------------------------------------------------------------------

class RegisterRequest(BaseModel):
    username: str
    password: str


class LoginRequest(BaseModel):
    username: str
    password: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    username: str
    user_id: int


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    response: str


class PersonalMemoryRequest(BaseModel):
    memory: str



def automatic_memory(user_id: int, message: str):
    text = message.strip()
    if not text:
        return

    lowered = text.lower()

    memory_triggers = (
        "remember that ",
        "remember my ",
        "my name is ",
        "i am ",
        "i'm ",
        "i live in ",
        "i work at ",
        "i work for ",
        "my goal is ",
        "i like ",
        "i prefer ",
    )

    if not lowered.startswith(memory_triggers):
        return

    add_personal_memory(user_id, text)



# ---------------------------------------------------------------------------
# AUTHENTICATION
# ---------------------------------------------------------------------------

def normalize_username(username: str) -> str:
    value = username.strip().lower()

    if not re.fullmatch(r"[a-z0-9_.-]{3,50}", value):
        raise HTTPException(
            status_code=400,
            detail="Username must be 3-50 characters using letters, numbers, dot, underscore or hyphen.",
        )

    return value


def hash_password(password: str) -> str:
    if len(password) < 8:
        raise HTTPException(
            status_code=400,
            detail="Password must contain at least 8 characters.",
        )

    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return pwd_context.verify(password, password_hash)
    except Exception:
        return False


def create_access_token(user_id: int, username: str) -> str:
    now = datetime.now(timezone.utc)

    payload = {
        "sub": str(user_id),
        "username": username,
        "iat": int(now.timestamp()),
        "exp": int(
            (now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)).timestamp()
        ),
    }

    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def get_current_user(authorization: Optional[str] = Header(default=None)):
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    scheme, _, token = authorization.partition(" ")

    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Use Authorization: Bearer <token>.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM],
        )

        user_id = int(payload.get("sub", "0"))
        username = str(payload.get("username", "")).strip()

        if user_id <= 0 or not username:
            raise ValueError("Invalid token subject.")

    except (JWTError, ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    conn = get_db()
    try:
        row = conn.execute(
            """
            SELECT id, username, active
            FROM users
            WHERE id = ?
            """,
            (user_id,),
        ).fetchone()
    finally:
        conn.close()

    if not row or not row["active"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is inactive or no longer exists.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return {
        "id": int(row["id"]),
        "username": str(row["username"]),
    }


# ---------------------------------------------------------------------------
# USER ROUTES
# ---------------------------------------------------------------------------

@app.post("/api/auth/register", response_model=AuthResponse)
def register(request: RegisterRequest):
    username = normalize_username(request.username)
    password_hash = hash_password(request.password)

    conn = get_db()

    try:
        existing = conn.execute(
            "SELECT id FROM users WHERE username = ?",
            (username,),
        ).fetchone()

        if existing:
            raise HTTPException(
                status_code=409,
                detail="Username is already registered.",
            )

        cursor = conn.execute(
            """
            INSERT INTO users(username, password_hash)
            VALUES (?, ?)
            """,
            (username, password_hash),
        )

        user_id = int(cursor.lastrowid)
        conn.commit()

    finally:
        conn.close()

    token = create_access_token(user_id, username)

    return AuthResponse(
        access_token=token,
        username=username,
        user_id=user_id,
    )


@app.post("/api/auth/login", response_model=AuthResponse)
def login(request: LoginRequest):
    username = normalize_username(request.username)

    conn = get_db()

    try:
        row = conn.execute(
            """
            SELECT id, username, password_hash, active
            FROM users
            WHERE username = ?
            """,
            (username,),
        ).fetchone()
    finally:
        conn.close()

    if not row or not row["active"] or not verify_password(
        request.password,
        row["password_hash"],
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(int(row["id"]), str(row["username"]))

    return AuthResponse(
        access_token=token,
        username=str(row["username"]),
        user_id=int(row["id"]),
    )


@app.get("/api/auth/me")
def current_user(user=Depends(get_current_user)):
    return {
        "user_id": user["id"],
        "username": user["username"],
    }


# ---------------------------------------------------------------------------
# CONVERSATION MEMORY
# ---------------------------------------------------------------------------

def save_memory(user_id: int, role: str, message: str):
    conn = get_db()
    try:
        conn.execute(
            """
            INSERT INTO conversation_memory(user_id, role, message)
            VALUES (?, ?, ?)
            """,
            (user_id, role, message),
        )
        conn.commit()
    finally:
        conn.close()


def load_memory(user_id: int, limit: int = 20):
    conn = get_db()
    try:
        rows = conn.execute(
            """
            SELECT role, message, created_at
            FROM conversation_memory
            WHERE user_id = ?
            ORDER BY id DESC
            LIMIT ?
            """,
            (user_id, limit),
        ).fetchall()
    finally:
        conn.close()

    return list(reversed([dict(row) for row in rows]))


# ---------------------------------------------------------------------------
# PERSONAL MEMORY
# ---------------------------------------------------------------------------

def load_personal_memory(user_id: int, limit: int = 50):
    conn = get_db()
    try:
        rows = conn.execute(
            """
            SELECT id, memory, created_at, updated_at
            FROM personal_memory
            WHERE user_id = ?
            ORDER BY updated_at DESC, id DESC
            LIMIT ?
            """,
            (user_id, limit),
        ).fetchall()
    finally:
        conn.close()

    return [dict(row) for row in rows]


def save_personal_memory(user_id: int, memory: str):
    text = memory.strip()

    if not text:
        return

    conn = get_db()

    try:
        existing = conn.execute(
            """
            SELECT id
            FROM personal_memory
            WHERE user_id = ? AND memory = ?
            """,
            (user_id, text),
        ).fetchone()

        if existing:
            conn.execute(
                """
                UPDATE personal_memory
                SET updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (existing["id"],),
            )
        else:
            conn.execute(
                """
                INSERT INTO personal_memory(user_id, memory)
                VALUES (?, ?)
                """,
                (user_id, text),
            )

        conn.commit()

    finally:
        conn.close()


def clear_memory(user_id: int):
    conn = get_db()
    try:
        conn.execute(
            "DELETE FROM conversation_memory WHERE user_id = ?",
            (user_id,),
        )
        conn.commit()
    finally:
        conn.close()


def clear_personal_memory(user_id: int):
    conn = get_db()
    try:
        conn.execute(
            "DELETE FROM personal_memory WHERE user_id = ?",
            (user_id,),
        )
        conn.commit()
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# AUTOMATIC MEMORY
# ---------------------------------------------------------------------------

def extract_automatic_memories(message: str):
    text = message.strip()
    memories = []

    patterns = [
        (
            r"^(?:my name is|i am called|i'm called)\s+(.{1,80})[.!?]?$",
            lambda m: f"My name is {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:call me)\s+(.{1,80})[.!?]?$",
            lambda m: f"I prefer to be called {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:i (?:like|love|enjoy))\s+(.{2,140})[.!?]?$",
            lambda m: f"I like {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:i (?:prefer|would rather))\s+(.{2,140})[.!?]?$",
            lambda m: f"I prefer {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:i (?:am working on|work on))\s+(.{2,180})[.!?]?$",
            lambda m: f"I am working on {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:i am building|i'm building)\s+(.{2,180})[.!?]?$",
            lambda m: f"I am building {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:remember that|please remember)\s+(.{2,220})[.!?]?$",
            lambda m: f"Remember that {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:don't forget that|do not forget that)\s+(.{2,220})[.!?]?$",
            lambda m: f"Remember that {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:my favorite)\s+(.{2,120})\s+is\s+(.{1,100})[.!?]?$",
            lambda m: f"My favorite {m.group(1).strip()} is {m.group(2).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:i want you to always)\s+(.{2,180})[.!?]?$",
            lambda m: f"I want DOUGLAS AI to always {m.group(1).strip().rstrip('.!?')}.",
        ),
        (
            r"^(?:i always want you to)\s+(.{2,180})[.!?]?$",
            lambda m: f"I want DOUGLAS AI to always {m.group(1).strip().rstrip('.!?')}.",
        ),
    ]

    for pattern, builder in patterns:
        match = re.match(pattern, text, flags=re.IGNORECASE)
        if match:
            memory = builder(match).strip()

            if 5 <= len(memory) <= 260:
                memories.append(memory)

            break

    return memories


def store_automatic_memories(user_id: int, message: str):
    for memory in extract_automatic_memories(message):
        save_personal_memory(user_id, memory)


# ---------------------------------------------------------------------------
# PROMPT
# ---------------------------------------------------------------------------

def build_prompt(user_id: int, message: str):
    personal = load_personal_memory(user_id, limit=20)
    conversation = load_memory(user_id, limit=10)

    sections = [
        "You are DOUGLAS AI, a helpful personal assistant.",
        "Use the user's stored personal memories when relevant.",
        "Do not invent memories.",
    ]

    if personal:
        sections.append("\nLONG-TERM PERSONAL MEMORY:")
        for item in personal:
            sections.append(f"- {item['memory']}")

    if conversation:
        sections.append("\nRECENT CONVERSATION:")
        for item in conversation:
            role = "User" if item["role"] == "user" else "DOUGLAS AI"
            sections.append(f"{role}: {item['message']}")

    sections.append(f"\nCURRENT USER MESSAGE:\n{message}")
    sections.append("\nDOUGLAS AI:")

    return "\n".join(sections)


# ---------------------------------------------------------------------------
# HEALTH
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    conn = get_db()
    try:
        users = conn.execute("SELECT COUNT(*) AS count FROM users").fetchone()["count"]
        conversations = conn.execute(
            "SELECT COUNT(*) AS count FROM conversation_memory"
        ).fetchone()["count"]
        personal = conn.execute(
            "SELECT COUNT(*) AS count FROM personal_memory"
        ).fetchone()["count"]
    finally:
        conn.close()

    return {
        "status": "ok",
        "service": APP_NAME,
        "database": "postgresql" if DATABASE_URL else "sqlite-local",
        "multi_user": True,
        "users": int(users),
        "conversation_records": int(conversations),
        "personal_memory_records": int(personal),
    }


# ---------------------------------------------------------------------------
# MEMORY API
# ---------------------------------------------------------------------------

@app.get("/api/memory")
def get_memory(user=Depends(get_current_user)):
    return {
        "memory": load_memory(user["id"]),
    }


@app.get("/api/personal-memory")
def get_personal_memory(user=Depends(get_current_user)):
    return {
        "memories": load_personal_memory(user["id"]),
    }


@app.post("/api/personal-memory")
def add_personal_memory(
    request: PersonalMemoryRequest,
    user=Depends(get_current_user),
):
    text = request.memory.strip()

    if not text:
        raise HTTPException(
            status_code=400,
            detail="Memory cannot be empty.",
        )

    save_personal_memory(user["id"], text)

    return {
        "status": "ok",
        "memory": text,
    }


@app.delete("/api/memory")
def delete_memory(user=Depends(get_current_user)):
    clear_memory(user["id"])

    return {
        "status": "ok",
        "message": "Conversation memory cleared.",
    }


@app.delete("/api/personal-memory")
def delete_personal_memory(user=Depends(get_current_user)):
    clear_personal_memory(user["id"])

    return {
        "status": "ok",
        "message": "Personal memories cleared.",
    }


# ---------------------------------------------------------------------------
# CHAT
# ---------------------------------------------------------------------------

@app.post("/api/chat", response_model=ChatResponse)
def chat(
    request: ChatRequest,
    user=Depends(get_current_user),
):
    message = request.message.strip()

    if not message:
        return ChatResponse(
            response="Please tell me what you would like me to do."
        )

    prompt = build_prompt(user["id"], message)

    provider = os.getenv("AI_PROVIDER", "ollama").strip().lower()
    print(f"DOUGLAS AI provider selected: {provider}", flush=True)

    if provider == "ollama":
        print(
            "DOUGLAS AI Ollama runtime: "
            f"url={os.getenv('OLLAMA_URL', '<default>')} "
            f"model={os.getenv('OLLAMA_MODEL', '<default>')}",
            flush=True,
        )
    elif provider == "openai_compatible":
        print(
            "DOUGLAS AI OpenAI-compatible runtime: "
            f"url={os.getenv('AI_API_URL', '<missing>')} "
            f"model={os.getenv('AI_MODEL', '<missing>')} "
            "api_key=<hidden>",
            flush=True,
        )

    try:
        if provider == "ollama":
            ai_url = os.getenv(
                "OLLAMA_URL",
                "http://127.0.0.1:11434/api/generate",
            )
            model = os.getenv(
                "OLLAMA_MODEL",
                "qwen2.5:1.5b",
            )

            payload = {
                "model": model,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": 0.2,
                    "num_predict": 256,
                },
            }

            response = requests.post(
                ai_url,
                json=payload,
                timeout=180,
            )
            response.raise_for_status()
            data = response.json()
            reply = str(data.get("response", "")).strip()

        elif provider == "gemini":
            api_key = os.getenv("GEMINI_API_KEY", "").strip()
            model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip()

            if not api_key:
                raise HTTPException(
                    status_code=503,
                    detail="Gemini API key is not configured.",
                )

            ai_url = (
                "https://generativelanguage.googleapis.com/v1beta/models/"
                f"{model}:generateContent?key={api_key}"
            )

            import time
            gemini_started = time.perf_counter()

            response = requests.post(
                ai_url,
                headers={"Content-Type": "application/json"},
                json={
                    "system_instruction": {
                        "parts": [
                            {
                                "text": "You are DOUGLAS AI, a helpful personal assistant."
                            }
                        ]
                    },
                    "contents": [
                        {
                            "parts": [
                                {"text": prompt}
                            ]
                        }
                    ],
                    "generationConfig": {
                        "temperature": 0.2,
                        "maxOutputTokens": 128,
                    },
                },
                timeout=180,
            )

            gemini_elapsed = time.perf_counter() - gemini_started
            print(
                f"LATENCY_DIAGNOSTIC gemini_request_seconds={gemini_elapsed:.3f}",
                flush=True,
            )

            response.raise_for_status()
            data = response.json()

            candidates = data.get("candidates", [])
            if not candidates:
                reply = ""
            else:
                parts = candidates[0].get("content", {}).get("parts", [])
                reply = " ".join(
                    str(part.get("text", "")).strip()
                    for part in parts
                    if part.get("text")
                ).strip()

        elif provider == "groq":
            api_key = os.getenv("GROQ_API_KEY", "").strip()
            model = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant").strip()

            if not api_key:
                raise HTTPException(
                    status_code=503,
                    detail="Groq API key is not configured.",
                )

            response = requests.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are DOUGLAS AI, a helpful personal assistant.",
                        },
                        {
                            "role": "user",
                            "content": prompt,
                        },
                    ],
                    "temperature": 0.2,
                    "max_tokens": 128,
                },
                timeout=60,
            )
            response.raise_for_status()
            data = response.json()

            choices = data.get("choices", [])
            if not choices:
                reply = ""
            else:
                reply = str(
                    choices[0].get("message", {}).get("content", "")
                ).strip()

        elif provider == "openai_compatible":
            ai_url = os.getenv(
                "AI_API_URL",
                "",
            ).strip()
            api_key = os.getenv("AI_API_KEY", "").strip()
            model = os.getenv("AI_MODEL", "").strip()

            if not ai_url or not api_key or not model:
                raise HTTPException(
                    status_code=503,
                    detail="Production AI provider is not configured.",
                )

            response = requests.post(
                ai_url,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are DOUGLAS AI, a helpful personal assistant.",
                        },
                        {
                            "role": "user",
                            "content": prompt,
                        },
                    ],
                    "temperature": 0.2,
                    "max_tokens": 256,
                },
                timeout=180,
            )
            response.raise_for_status()
            data = response.json()

            choices = data.get("choices", [])
            if not choices:
                reply = ""
            else:
                reply = str(
                    choices[0].get("message", {}).get("content", "")
                ).strip()

        else:
            raise HTTPException(
                status_code=500,
                detail=f"Unsupported AI_PROVIDER: {provider}",
            )

    except HTTPException:
        raise
    except requests.RequestException as exc:
        raise HTTPException(
            status_code=503,
            detail=f"AI inference service unavailable: {exc}",
        )

    if not reply:
        raise HTTPException(
            status_code=502,
            detail="AI inference returned an empty response.",
        )

    save_memory(user["id"], "user", message)
    automatic_memory(user["id"], message)
    save_memory(user["id"], "assistant", reply)

    return ChatResponse(response=reply)
    return ChatResponse(response=reply)
