import pytest

from app.main import create_app


@pytest.fixture
def client():
    return create_app().test_client()


def test_index_reports_version_and_environment(client, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "v9")
    monkeypatch.setenv("APP_ENVIRONMENT", "test")
    body = client.get("/").get_json()
    assert body == {"service": "delivery-api", "version": "v9", "environment": "test"}


def test_healthz_is_ok(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_metrics_count_requests_by_path_and_status(client):
    client.get("/healthz")
    client.get("/missing")
    text = client.get("/metrics").get_data(as_text=True)
    assert 'app_requests_total{path="/healthz",status="200"} 1.0' in text
    assert 'app_requests_total{path="/missing",status="404"} 1.0' in text
