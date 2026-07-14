"""
Shared pytest fixtures.

Sets required environment variables to dummy values *before* importing
app.py, so the app module can be imported in CI without needing real
AWS credentials, a real database, or a real Gemini API key. Tests mock
out the actual S3/RDS/Gemini calls individually.
"""
import os
import sys
import pytest

os.environ.setdefault("GOOGLE_API_KEY", "test-key")
os.environ.setdefault("S3_BUCKET", "test-bucket")
os.environ.setdefault("S3_REGION", "us-east-1")
os.environ.setdefault("DB_HOST", "localhost")
os.environ.setdefault("DB_NAME", "test_db")
os.environ.setdefault("DB_USER", "test_user")
os.environ.setdefault("DB_PASSWORD", "test_password")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import app as app_module  # noqa: E402


@pytest.fixture
def client():
    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as client:
        yield client
