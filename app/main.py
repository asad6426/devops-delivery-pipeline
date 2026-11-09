"""A small service with the endpoints a platform needs to run it safely."""
import os

from flask import Flask, Response, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, CollectorRegistry, Counter, generate_latest


def create_app() -> Flask:
    app = Flask(__name__)
    registry = CollectorRegistry()
    requests_total = Counter(
        "app_requests_total", "HTTP requests by path and status", ["path", "status"], registry=registry
    )

    @app.after_request
    def count_request(response: Response) -> Response:
        requests_total.labels(request.path, str(response.status_code)).inc()
        return response

    @app.get("/")
    def index():
        return jsonify(
            service="delivery-api",
            version=os.environ.get("APP_VERSION", "dev"),
            environment=os.environ.get("APP_ENVIRONMENT", "local"),
        )

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok")

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(registry), mimetype=CONTENT_TYPE_LATEST)

    return app


app = create_app()
