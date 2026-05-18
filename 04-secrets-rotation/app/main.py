"""
Demo Application — Use Case 2: Secrets Rotation with Zero Downtime

Connects to a real PostgreSQL database using asyncpg.
The connection pool is the core of the lesson:

- The pool opens connections at startup using the credentials
  injected from the Kubernetes Secret at that moment.
- Those connections stay alive and authenticated even after
  the database password is changed.
- New connection attempts use the current credentials from
  the environment — which are stale until the pod restarts.

/healthz      — HTTP reachability (what the readiness probe checks)
/healthz/db   — Opens a NEW asyncpg connection using current environment
                credentials and runs SELECT 1. If the DB password was
                just rotated and this pod has not restarted yet, this
                fails even though /healthz returns 200 and kubectl shows
                the pod as Running.
"""

import os
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI, HTTPException

DB_HOST = os.environ.get("DB_HOST", "postgres")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_USERNAME = os.environ.get("DB_USERNAME", "appuser")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

_pool = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Opens the connection pool at startup, closes it at shutdown.
    Using the lifespan context manager (preferred over @app.on_event
    which is deprecated in FastAPI 0.95+).
    """
    global _pool
    _pool = await asyncpg.create_pool(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USERNAME,
        password=DB_PASSWORD,
        min_size=2,
        max_size=5,
        # Pool connections stay alive for up to 5 minutes of inactivity.
        # In a real app this might be much longer, keeping stale sessions
        # alive well after a credential rotation.
        max_inactive_connection_lifetime=300,
    )
    yield
    if _pool:
        await _pool.close()


app = FastAPI(lifespan=lifespan)


@app.get("/healthz")
async def healthz():
    """
    HTTP reachability check.
    Always returns 200 if the FastAPI server is alive.
    This is what the Kubernetes readiness probe validates.
    It knows nothing about whether database authentication works.
    """
    return {"status": "ok"}


@app.get("/healthz/db")
async def healthz_db():
    """
    Database authentication check.
    Opens a FRESH asyncpg connection using the credentials currently
    in the environment variables.

    If the database password was rotated and this pod has not restarted:
      - The environment still has the OLD password
      - A new connection with the old password fails authentication
      - This returns 503
      - Meanwhile /healthz returns 200 and kubectl shows Running

    That gap is the lesson.
    """
    try:
        conn = await asyncpg.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USERNAME,
            password=DB_PASSWORD,
        )
        await conn.execute("SELECT 1")
        await conn.close()
        return {"status": "ok", "db": "authenticated", "user": DB_USERNAME}

    except asyncpg.exceptions.InvalidPasswordError:
        raise HTTPException(
            status_code=503,
            detail=(
                f"Authentication failed for user '{DB_USERNAME}'. "
                "The database password may have been rotated. "
                "The readiness probe does not check this."
            ),
        ) from None
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Database connection failed: {str(e)}",
        ) from e


@app.get("/query")
async def query():
    """
    Uses the connection pool (opened at startup with original credentials).
    After rotation, pool connections may still succeed if old sessions
    are alive — this shows the mixed success/failure pattern alongside
    the /healthz/db failure.
    """
    try:
        async with _pool.acquire() as conn:
            result = await conn.fetchval("SELECT current_user")
            return {"status": "ok", "current_user": result}
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
