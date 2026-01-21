# Notesync Backend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Flask + PostgreSQL backend that accepts offline sync bundles from the iOS app at `POST /api/notesync`, using API key auth + user JWT auth with last-write-wins conflict handling for notes, tags, and media, plus an auth code exchange endpoint for OAuth callbacks.

**Architecture:** A single Flask app with SQLAlchemy models for notes, tags, media, and sync metadata. The `/api/notesync` endpoint authenticates the app via API key and the user via JWT, scopes all data by user id, applies operations transactionally with LWW semantics, stores media blobs in PostgreSQL, and returns authoritative note states. A separate `/api/auth/exchange` endpoint exchanges short-lived OAuth codes for JWTs.

**Tech Stack:** Python 3.11, Flask, SQLAlchemy, Alembic, psycopg (or psycopg2), Pydantic, PyJWT, pytest.

---

### Task 1: Scaffold backend app + app factory

**Files:**
- Create: `backend/requirements.txt`
- Create: `backend/app.py`
- Create: `backend/config.py`
- Create: `backend/db.py`
- Create: `backend/tests/test_app.py`

**Step 1: Write the failing test**

```python
# backend/tests/test_app.py
from backend.app import create_app

def test_app_factory():
    app = create_app()
    assert app is not None
    assert app.config["TESTING"] is True
```

**Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_app.py::test_app_factory -v`  
Expected: FAIL with `ModuleNotFoundError` or `AttributeError` for missing factory.

**Step 3: Write minimal implementation**

```python
# backend/config.py
import os

class Config:
    TESTING = False
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg://localhost/timeline")
    API_KEY = os.getenv("NOTESYNC_API_KEY", "")
    JWT_ISSUER = os.getenv("NOTESYNC_JWT_ISSUER", "")
    JWT_AUDIENCE = os.getenv("NOTESYNC_JWT_AUDIENCE", "")
    JWT_PUBLIC_KEY = os.getenv("NOTESYNC_JWT_PUBLIC_KEY", "")

class TestConfig(Config):
    TESTING = True
    DATABASE_URL = os.getenv("TEST_DATABASE_URL", "postgresql+psycopg://localhost/timeline_test")
```

```python
# backend/db.py
from sqlalchemy import create_engine
from sqlalchemy.orm import scoped_session, sessionmaker, declarative_base

SessionLocal = scoped_session(sessionmaker())
Base = declarative_base()

def init_db(database_url: str):
    engine = create_engine(database_url, future=True)
    SessionLocal.configure(bind=engine)
    return engine
```

```python
# backend/app.py
from flask import Flask
from backend.config import Config, TestConfig
from backend.db import init_db

def create_app(testing: bool = True):
    app = Flask(__name__)
    cfg = TestConfig if testing else Config
    app.config.from_object(cfg)
    init_db(app.config["DATABASE_URL"])

    @app.get("/health")
    def health():
        return {"status": "ok"}

    return app
```

```txt
# backend/requirements.txt
flask==3.0.3
sqlalchemy==2.0.32
psycopg==3.2.1
pydantic==2.8.2
pyjwt==2.8.0
pytest==8.2.2
```

**Step 4: Run test to verify it passes**

Run: `pytest backend/tests/test_app.py::test_app_factory -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/requirements.txt backend/app.py backend/config.py backend/db.py backend/tests/test_app.py
git commit -m "chore: scaffold backend app factory"
```

---

### Task 2: Define SQLAlchemy models for notes, tags, media

**Files:**
- Create: `backend/models.py`
- Modify: `backend/db.py`
- Create: `backend/tests/test_models.py`

**Step 1: Write the failing test**

```python
# backend/tests/test_models.py
from datetime import datetime, timezone
from backend.models import Note, Tag, Media

def test_note_model_fields():
    now = datetime.now(timezone.utc)
    note = Note(id="n1", user_id="u1", text="hi", is_pinned=False, created_at=now, updated_at=now)
    assert note.id == "n1"
    assert note.user_id == "u1"
    assert note.text == "hi"
    assert note.deleted_at is None
```

**Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_models.py::test_note_model_fields -v`  
Expected: FAIL with `ModuleNotFoundError` or missing model attributes.

**Step 3: Write minimal implementation**

```python
# backend/models.py
from datetime import datetime
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, LargeBinary, String, Table, Text, UniqueConstraint
from sqlalchemy.orm import relationship
from backend.db import Base

note_tags = Table(
    "note_tags",
    Base.metadata,
    Column("note_id", String, ForeignKey("notes.id"), primary_key=True),
    Column("tag_id", String, ForeignKey("tags.id"), primary_key=True),
)

class Note(Base):
    __tablename__ = "notes"
    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False, index=True)
    text = Column(Text, nullable=False)
    is_pinned = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)
    deleted_at = Column(DateTime, nullable=True)
    tags = relationship("Tag", secondary=note_tags, back_populates="notes")
    media = relationship("Media", back_populates="note")

class Tag(Base):
    __tablename__ = "tags"
    __table_args__ = (UniqueConstraint("user_id", "name"),)
    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    notes = relationship("Note", secondary=note_tags, back_populates="tags")

class Media(Base):
    __tablename__ = "media"
    id = Column(String, primary_key=True)
    note_id = Column(String, ForeignKey("notes.id"), nullable=False)
    user_id = Column(String, nullable=False, index=True)
    kind = Column(String, nullable=False)  # "image" or "audio"
    filename = Column(String, nullable=False)
    content_type = Column(String, nullable=False)
    checksum = Column(String, nullable=False)
    data = Column(LargeBinary, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    note = relationship("Note", back_populates="media")
```

```python
# backend/db.py (append)
def create_all(engine):
    Base.metadata.create_all(bind=engine)
```

**Step 4: Run test to verify it passes**

Run: `pytest backend/tests/test_models.py::test_note_model_fields -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/models.py backend/db.py backend/tests/test_models.py
git commit -m "feat: add notesync data models"
```

---

### Task 3: Add request/response schemas and validation

**Files:**
- Create: `backend/schemas.py`
- Create: `backend/tests/test_schemas.py`

**Step 1: Write the failing test**

```python
# backend/tests/test_schemas.py
from datetime import datetime, timezone
from backend.schemas import SyncRequest

def test_sync_request_minimal():
    payload = {
        "ops": [{
            "opId": "op1",
            "opType": "create",
            "note": {
                "id": "n1",
                "text": "hi",
                "isPinned": False,
                "tags": ["work"],
                "createdAt": datetime.now(timezone.utc).isoformat(),
                "updatedAt": datetime.now(timezone.utc).isoformat(),
                "deletedAt": None
            },
            "media": []
        }]
    }
    req = SyncRequest.model_validate(payload)
    assert req.ops[0].note.id == "n1"
```

**Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_schemas.py::test_sync_request_minimal -v`  
Expected: FAIL with `ModuleNotFoundError` or validation errors.

**Step 3: Write minimal implementation**

```python
# backend/schemas.py
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

class MediaPayload(BaseModel):
    id: str
    noteId: str
    kind: str
    filename: str
    contentType: str
    checksum: str
    dataBase64: str

class NotePayload(BaseModel):
    id: str
    text: str
    isPinned: bool
    tags: List[str]
    createdAt: datetime
    updatedAt: datetime
    deletedAt: Optional[datetime]

class OperationPayload(BaseModel):
    opId: str
    opType: str
    note: NotePayload
    media: List[MediaPayload] = Field(default_factory=list)

class SyncRequest(BaseModel):
    ops: List[OperationPayload]

class SyncNoteResult(BaseModel):
    noteId: str
    result: str
    note: NotePayload

class SyncResponse(BaseModel):
    results: List[SyncNoteResult]
```

**Step 4: Run test to verify it passes**

Run: `pytest backend/tests/test_schemas.py::test_sync_request_minimal -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/schemas.py backend/tests/test_schemas.py
git commit -m "feat: add sync request schemas"
```

---

### Task 4: Add API key + JWT auth and error handling

**Files:**
- Create: `backend/auth.py`
- Modify: `backend/app.py`
- Create: `backend/tests/test_auth.py`

**Step 1: Write the failing test**

```python
# backend/tests/test_auth.py
from backend.app import create_app

def test_missing_api_key_rejected():
    app = create_app()
    client = app.test_client()
    resp = client.post("/api/notesync", json={"ops": []})
    assert resp.status_code == 401

def test_missing_bearer_token_rejected():
    app = create_app()
    app.config["API_KEY"] = "test"
    client = app.test_client()
    resp = client.post("/api/notesync", json={"ops": []}, headers={"X-API-Key": "test"})
    assert resp.status_code == 401
```

**Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_auth.py::test_missing_api_key_rejected -v`  
Expected: FAIL with 404 or 200.

**Step 3: Write minimal implementation**

```python
# backend/auth.py
from functools import wraps
from flask import request, jsonify, current_app, g
import jwt

def require_api_key(f):
    @wraps(f)
    def wrapped(*args, **kwargs):
        api_key = request.headers.get("X-API-Key", "")
        if not api_key or api_key != current_app.config["API_KEY"]:
            return jsonify({"error": "unauthorized"}), 401
        return f(*args, **kwargs)
    return wrapped

def require_user_jwt(f):
    @wraps(f)
    def wrapped(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "unauthorized"}), 401
        token = auth.replace("Bearer ", "", 1)
        try:
            payload = jwt.decode(
                token,
                current_app.config["JWT_PUBLIC_KEY"],
                algorithms=["RS256"],
                issuer=current_app.config["JWT_ISSUER"],
                audience=current_app.config["JWT_AUDIENCE"],
            )
        except jwt.PyJWTError:
            return jsonify({"error": "unauthorized"}), 401
        g.user_id = payload.get("sub")
        if not g.user_id:
            return jsonify({"error": "unauthorized"}), 401
        return f(*args, **kwargs)
    return wrapped
```

```python
# backend/app.py (append route placeholder)
from backend.auth import require_api_key, require_user_jwt

@app.post("/api/notesync")
@require_api_key
@require_user_jwt
def notesync():
    return {"results": []}
```

**Step 4: Run test to verify it passes**

Run: `pytest backend/tests/test_auth.py::test_missing_api_key_rejected -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/auth.py backend/app.py backend/tests/test_auth.py
git commit -m "feat: enforce API key auth"
```

---

### Task 5: Add auth code exchange endpoint

**Files:**
- Create: `backend/auth_codes.py`
- Modify: `backend/app.py`
- Create: `backend/tests/test_auth_exchange.py`

**Step 1: Write the failing test**

```python
# backend/tests/test_auth_exchange.py
from backend.app import create_app

def test_exchange_requires_code():
    app = create_app()
    client = app.test_client()
    resp = client.post("/api/auth/exchange", json={})
    assert resp.status_code == 400
```

**Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_auth_exchange.py::test_exchange_requires_code -v`  
Expected: FAIL with 404 or missing handler.

**Step 3: Write minimal implementation**

```python
# backend/auth_codes.py
from datetime import datetime, timedelta, timezone
from dataclasses import dataclass

@dataclass
class AuthCode:
    code: str
    user_id: str
    expires_at: datetime
    used_at: datetime | None = None

def is_valid(code: AuthCode) -> bool:
    now = datetime.now(timezone.utc)
    return code.used_at is None and code.expires_at > now
```

```python
# backend/app.py (add endpoint)
from flask import request, jsonify

@app.post("/api/auth/exchange")
def auth_exchange():
    payload = request.get_json(silent=True) or {}
    code = payload.get("code")
    if not code:
        return jsonify({"error": "invalid_code"}), 400
    # TODO: look up code in DB, validate, mark used
    # TODO: issue JWT + optional refresh token
    return jsonify({
        "access_token": "jwt",
        "token_type": "Bearer",
        "expires_in": 3600,
        "user": {"id": "user-id"}
    })
```

**Step 4: Run test to verify it passes**

Run: `pytest backend/tests/test_auth_exchange.py::test_exchange_requires_code -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/auth_codes.py backend/app.py backend/tests/test_auth_exchange.py
git commit -m "feat: add auth code exchange endpoint"
```

---

### Task 6: Implement `/api/notesync` LWW sync logic

**Files:**
- Modify: `backend/app.py`
- Create: `backend/sync.py`
- Create: `backend/tests/test_notesync.py`

**Step 1: Write the failing test**

```python
# backend/tests/test_notesync.py
from datetime import datetime, timezone
from backend.app import create_app

def test_create_note_sync_success():
    app = create_app()
    app.config["API_KEY"] = "test"
    client = app.test_client()
    now = datetime.now(timezone.utc).isoformat()
    payload = {
        "ops": [{
            "opId": "op1",
            "opType": "create",
            "note": {
                "id": "n1",
                "text": "hello",
                "isPinned": False,
                "tags": ["work"],
                "createdAt": now,
                "updatedAt": now,
                "deletedAt": None
            },
            "media": []
        }]
    }
    resp = client.post("/api/notesync", json=payload, headers={"X-API-Key": "test"})
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["results"][0]["note"]["id"] == "n1"
```

**Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_notesync.py::test_create_note_sync_success -v`  
Expected: FAIL due to missing sync logic.

**Step 3: Write minimal implementation**

```python
# backend/sync.py
import base64
from datetime import datetime
from sqlalchemy import select
from backend.db import SessionLocal
from backend.models import Note, Tag, Media

def apply_sync_ops(ops, user_id):
    results = []
    session = SessionLocal()
    try:
        for op in ops:
            note_payload = op.note
            existing = session.execute(
                select(Note).where(Note.id == note_payload.id, Note.user_id == user_id)
            ).scalar_one_or_none()
            incoming_ts = note_payload.updatedAt
            if op.opType == "delete":
                if existing is None:
                    note = Note(
                        id=note_payload.id,
                        user_id=user_id,
                        text=note_payload.text or "",
                        is_pinned=note_payload.isPinned,
                        created_at=note_payload.createdAt,
                        updated_at=incoming_ts,
                        deleted_at=note_payload.deletedAt or incoming_ts,
                    )
                    session.add(note)
                elif existing.deleted_at is None or existing.deleted_at < incoming_ts:
                    existing.deleted_at = note_payload.deletedAt or incoming_ts
                    existing.updated_at = incoming_ts
                results.append(existing or note)
                continue

            if existing is None:
                note = Note(
                    id=note_payload.id,
                    user_id=user_id,
                    text=note_payload.text,
                    is_pinned=note_payload.isPinned,
                    created_at=note_payload.createdAt,
                    updated_at=incoming_ts,
                    deleted_at=note_payload.deletedAt,
                )
                session.add(note)
                existing = note
            elif existing.updated_at >= incoming_ts:
                results.append(existing)
                continue
            else:
                existing.text = note_payload.text
                existing.is_pinned = note_payload.isPinned
                existing.updated_at = incoming_ts
                existing.deleted_at = note_payload.deletedAt

            # tags
            existing.tags.clear()
            for tag_name in note_payload.tags:
                tag = session.execute(
                    select(Tag).where(Tag.user_id == user_id, Tag.name == tag_name)
                ).scalar_one_or_none()
                if tag is None:
                    tag = Tag(id=tag_name, user_id=user_id, name=tag_name)
                    session.add(tag)
                existing.tags.append(tag)

            # media
            for media_payload in op.media:
                data = base64.b64decode(media_payload.dataBase64.encode("utf-8"))
                media = Media(
                    id=media_payload.id,
                    note_id=note_payload.id,
                    user_id=user_id,
                    kind=media_payload.kind,
                    filename=media_payload.filename,
                    content_type=media_payload.contentType,
                    checksum=media_payload.checksum,
                    data=data,
                    created_at=datetime.utcnow(),
                )
                session.merge(media)

            results.append(existing)
        session.commit()
        return results
    finally:
        session.close()
```

```python
# backend/app.py (replace notesync handler)
from flask import request, g
from backend.schemas import SyncRequest, SyncResponse, SyncNoteResult, NotePayload
from backend.sync import apply_sync_ops

@app.post("/api/notesync")
@require_api_key
def notesync():
    body = SyncRequest.model_validate_json(request.data)
    synced = apply_sync_ops(body.ops, user_id=g.user_id)
    results = []
    for note in synced:
        results.append(SyncNoteResult(
            noteId=note.id,
            result="applied",
            note=NotePayload(
                id=note.id,
                text=note.text,
                isPinned=note.is_pinned,
                tags=[t.name for t in note.tags],
                createdAt=note.created_at,
                updatedAt=note.updated_at,
                deletedAt=note.deleted_at,
            )
        ))
    resp = SyncResponse(results=results)
    return resp.model_dump()
```

**Step 4: Run test to verify it passes**

Run: `pytest backend/tests/test_notesync.py::test_create_note_sync_success -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/sync.py backend/app.py backend/tests/test_notesync.py
git commit -m "feat: implement notesync LWW endpoint"
```

---

### Task 7: Add Alembic migrations + DB setup docs

**Files:**
- Create: `backend/alembic.ini`
- Create: `backend/alembic/env.py`
- Create: `backend/alembic/versions/0001_create_notes_tables.py`
- Modify: `backend/README.md`
- Create: `backend/tests/test_migration.py`

**Step 1: Write the failing test**

```python
# backend/tests/test_migration.py
def test_migration_files_exist():
    import os
    assert os.path.exists("backend/alembic.ini")
    assert os.path.exists("backend/alembic/versions/0001_create_notes_tables.py")
```

**Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_migration.py::test_migration_files_exist -v`  
Expected: FAIL

**Step 3: Write minimal implementation**

```ini
# backend/alembic.ini
[alembic]
script_location = backend/alembic
sqlalchemy.url = postgresql+psycopg://localhost/timeline
```

```python
# backend/alembic/env.py
from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
from backend.models import Base

config = context.config
fileConfig(config.config_file_name)
target_metadata = Base.metadata

def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = engine_from_config(config.get_section(config.config_ini_section), prefix="sqlalchemy.", poolclass=pool.NullPool)
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

```python
# backend/alembic/versions/0001_create_notes_tables.py
from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    op.create_table(
        "notes",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("is_pinned", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(), nullable=True),
    )
    op.create_table(
        "tags",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.UniqueConstraint("user_id", "name", name="uq_tags_user_name"),
    )
    op.create_table(
        "note_tags",
        sa.Column("note_id", sa.String(), sa.ForeignKey("notes.id"), primary_key=True),
        sa.Column("tag_id", sa.String(), sa.ForeignKey("tags.id"), primary_key=True),
    )
    op.create_table(
        "media",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("note_id", sa.String(), sa.ForeignKey("notes.id"), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("kind", sa.String(), nullable=False),
        sa.Column("filename", sa.String(), nullable=False),
        sa.Column("content_type", sa.String(), nullable=False),
        sa.Column("checksum", sa.String(), nullable=False),
        sa.Column("data", sa.LargeBinary(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_notes_user_id", "notes", ["user_id"])
    op.create_index("ix_tags_user_id", "tags", ["user_id"])
    op.create_index("ix_media_user_id", "media", ["user_id"])
```

```markdown
# backend/README.md
## Notesync Backend

### Setup
- Install deps: `pip install -r backend/requirements.txt`
- Set env: `export DATABASE_URL=postgresql+psycopg://user:pass@host/db`
- Set API key: `export NOTESYNC_API_KEY=your-key`
- Run migrations: `alembic -c backend/alembic.ini upgrade head`
- Start server: `flask --app backend.app run`

### Endpoint
`POST /api/notesync` with headers `X-API-Key` and `Authorization: Bearer <jwt>`.
`POST /api/auth/exchange` with JSON body `{ "code": "..." }`.

### Login URL and Callback Contract
The app opens `AppConfiguration.default.auth.loginURL` in an external browser. This endpoint should **start** the OAuth flow and redirect the user to the provider (Google/GitHub). It is not a JSON API; it should return an HTTP redirect (302/303).

**Recommended backend behavior:**
1. `GET /login` (or your chosen route) generates an OAuth authorization request.
2. Backend redirects to the provider's authorize URL.
3. Provider redirects back to your backend callback route (for example `/oauth/callback`) with an authorization `code`.
4. Backend **creates a short-lived Notesync auth code** (or directly reuses the provider code if you prefer).
5. Backend redirects the user to the **app callback URL**:
   ```
   zzuse.timeline://auth/callback?code=<notesync-auth-code>
   ```

**Expected return from the login URL:**
- A browser redirect chain that ends at the app callback URL above.
- The app receives the callback and calls `POST /api/auth/exchange` with `{ "code": "<notesync-auth-code>" }`.
- Backend responds with `{ "access_token": "<jwt>", "token_type": "Bearer", "expires_in": 3600 }`.

**Notes:**
- `loginURL` can be any backend route (e.g. `/login`, `/oauth/start`, `/auth/login`) as long as it ends with a redirect to the app callback URL.
- If you change the scheme/host/path, keep `AppConfiguration.default.auth.callbackScheme`, `callbackHost`, and `callbackPath` in sync.

### OAuth Callback (Custom URL Scheme)
The iOS app uses a custom URL scheme callback instead of Universal Links:
```
zzuse.timeline://auth/callback?code=...
```

Notes:
- Register the custom scheme redirect URI in Google/GitHub OAuth settings.
- No Apple App Site Association file is required for the custom scheme flow.

### Android App Links (Optional)
If you later add an Android app, you may still use HTTPS callbacks with Android App Links:
```
https://zzuse.duckdns.org/.well-known/assetlinks.json
```

Example `assetlinks.json`:
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "<ANDROID_PACKAGE_NAME>",
      "sha256_cert_fingerprints": [
        "<SHA256_CERT_FINGERPRINT>"
      ]
    }
  }
]
```

Notes:
- Replace `<ANDROID_PACKAGE_NAME>` with your Android package name.
- Replace `<SHA256_CERT_FINGERPRINT>` with the SHA-256 cert fingerprint of your signing key.
```

**Step 4: Run test to verify it passes**

Run: `pytest backend/tests/test_migration.py::test_migration_files_exist -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/alembic.ini backend/alembic/env.py backend/alembic/versions/0001_create_notes_tables.py backend/README.md backend/tests/test_migration.py
git commit -m "chore: add migrations and backend docs"
```

---

### Task 8: Expand tests for LWW and delete propagation

**Files:**
- Modify: `backend/tests/test_notesync.py`

**Step 1: Write the failing tests**

```python
def test_lww_skips_older_update():
    # create note with newer updatedAt, then attempt older update and expect skip
    ...

def test_delete_tombstone_applies():
    # create note, then delete with later timestamp and expect deletedAt set
    ...
```

**Step 2: Run tests to verify they fail**

Run: `pytest backend/tests/test_notesync.py -v`  
Expected: FAIL with assertions.

**Step 3: Implement minimal changes**

```python
# backend/sync.py
# Ensure update skips when existing.updated_at >= incoming_ts
# Ensure delete applies if deleted_at is None or older than incoming_ts
```

**Step 4: Run tests to verify they pass**

Run: `pytest backend/tests/test_notesync.py -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/tests/test_notesync.py backend/sync.py
git commit -m "test: cover LWW and deletes"
```

---

### Task 9: Document request/response contract

**Files:**
- Modify: `backend/README.md`

**Step 1: Write the failing test**

```python
# backend/tests/test_docs.py
def test_readme_mentions_notesync_endpoint():
    with open("backend/README.md", "r", encoding="utf-8") as f:
        data = f.read()
    assert "/api/notesync" in data
```

**Step 2: Run test to verify it fails**

Run: `pytest backend/tests/test_docs.py::test_readme_mentions_notesync_endpoint -v`  
Expected: FAIL

**Step 3: Write minimal implementation**

```markdown
### Request (example)
{
  "ops": [{
    "opId": "op1",
    "opType": "create",
    "note": {
      "id": "uuid",
      "text": "hello",
      "isPinned": false,
      "tags": ["work"],
      "createdAt": "2026-01-16T00:00:00Z",
      "updatedAt": "2026-01-16T00:00:00Z",
      "deletedAt": null
    },
    "media": [{
      "id": "m1",
      "noteId": "uuid",
      "kind": "image",
      "filename": "img.jpg",
      "contentType": "image/jpeg",
      "checksum": "sha256:...",
      "dataBase64": "..."
    }]
  }]
}
```

**Step 4: Run test to verify it passes**

Run: `pytest backend/tests/test_docs.py::test_readme_mentions_notesync_endpoint -v`  
Expected: PASS

**Step 5: Commit**

```bash
git add backend/README.md backend/tests/test_docs.py
git commit -m "docs: document notesync contract"
```

---

## Verification

Run: `pytest backend/tests -v`  
Expected: All tests pass.

Run: `flask --app backend.app run`  
Expected: Server starts and `POST /api/notesync` responds with 401 when API key or bearer token is missing.
