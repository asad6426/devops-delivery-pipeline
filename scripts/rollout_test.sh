#!/usr/bin/env bash
# Exercises a release against a real cluster: deploy, upgrade, failed release, rollback.
set -euo pipefail

NS=delivery
DEPLOY=deployment/delivery-api

current_version() {
  kubectl -n "$NS" port-forward service/delivery-api 18080:80 >/dev/null 2>&1 &
  local pid=$! body="" attempt
  for attempt in $(seq 1 30); do
    body=$(curl -fsS --max-time 2 http://127.0.0.1:18080/ 2>/dev/null) && break
    sleep 1
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  python3 -c 'import json,sys; print(json.loads(sys.argv[1])["version"])' "$body"
}

expect_version() {
  local got
  got=$(current_version)
  echo "serving version: $got (expected $1)"
  [ "$got" = "$1" ]
}

ready_replicas() {
  kubectl -n "$NS" get "$DEPLOY" -o jsonpath='{.status.readyReplicas}'
}

release() {
  kubectl -n "$NS" set image "$DEPLOY" "api=delivery-api:$1"
  kubectl -n "$NS" set env "$DEPLOY" "APP_VERSION=$1"
}

echo "== 1. First release"
kubectl apply -k k8s
kubectl -n "$NS" rollout status "$DEPLOY" --timeout=120s
expect_version v1

echo "== 2. Rolling upgrade to v2"
release v2
kubectl -n "$NS" rollout status "$DEPLOY" --timeout=120s
expect_version v2

echo "== 3. Bad release: the image does not exist"
release v-broken
if kubectl -n "$NS" rollout status "$DEPLOY" --timeout=60s; then
  echo "ERROR: a broken release was reported as healthy"
  exit 1
fi
echo "rollout failed as intended; ready replicas during failure: $(ready_replicas)"
[ "$(ready_replicas)" -ge 2 ]
expect_version v2

echo "== 4. Roll back"
kubectl -n "$NS" rollout undo "$DEPLOY"
kubectl -n "$NS" rollout status "$DEPLOY" --timeout=120s
expect_version v2

echo "== 5. Metrics endpoint"
kubectl -n "$NS" port-forward service/delivery-api 18080:80 >/dev/null 2>&1 &
pid=$!
sleep 3
curl -fsS --max-time 5 http://127.0.0.1:18080/metrics | grep -m1 '^app_requests_total'
kill "$pid" 2>/dev/null || true

echo "== Final state"
kubectl -n "$NS" get deployment,pods,resourcequota
echo "ALL ROLLOUT CHECKS PASSED"
