# MathOps Microservice

Backend-only FastAPI service that queues math operations to a Celery worker via RabbitMQ and stores results in PostgreSQL.

## Tech stack
- Python 3.11
  - FastAPI async API
  - Celery worker (separate process/container)
  - PostgreSQL persistence
  - Alembic migrations
- Docker-ready
- Minikube-compliant

## Project layout
```
app/
  api/         # HTTP routes
  core/        # config + exception handlers
  db/          # session + base
  models/      # SQLAlchemy models
  schemas/     # Pydantic schemas
  services/    # business logic
  tasks/       # Celery app + tasks
```

## Local development (docker-compose)
1) Create a local `.env` file:
```bash
cp .env.example .env
```
2) Start the stack:
```bash
docker compose up --build
```
3) Run migrations (external tool, not runtime-managed):
```bash
docker compose exec api alembic upgrade head
```
4) Open the API docs:
```
http://localhost:8000/docs
```

Adminer is available at `http://localhost:8080` for safe DB access (no direct DB port exposure).

## Local development (no Docker)
You need RabbitMQ and PostgreSQL running locally. Then:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

alembic upgrade head
python -m app.server
```
In another terminal:
```bash
celery -A app.tasks.celery_app:celery_app worker --loglevel=info
```
Docs: `http://localhost:8000/docs`.

## Build and deploy on Windows
Prerequisites:
- Docker, Minikube, Kubectl installed

Run:
```cmd
runDeploy.bat
```
The script will build the image, apply Kubernetes resources, run migrations, and open `/docs`.

## Build and deploy on Linux distros
Prerequisites:
- Docker, Minikube, Kubectl installed

Run:
```bash
./UbuntuDeploy.sh
```
The script will build the image, apply Kubernetes resources, run migrations, and open `/docs`.

## Kubernetes notes
- `math-deployment.yaml` includes the API, worker, RabbitMQ, and PostgreSQL deployments.
- Configuration is driven via `math-config.yaml` (ConfigMap).
- The API service is exposed via NodePort; open `/docs` for the Swagger UI.
- Migrations are run via the `math-migrate-job.yaml` Job.

## Kubernetes workflow (manual)
```bash
minikube start
docker build -t mathcontainer:latest .
minikube image load mathcontainer:latest
kubectl apply -f math-config.yaml -f math-deployment.yaml
kubectl rollout status deployment/math-api --timeout=120s
kubectl delete job math-migrate --ignore-not-found
kubectl apply -f math-migrate-job.yaml
kubectl wait --for=condition=complete job/math-migrate --timeout=120s
minikube service math-calculator-service --url
```

## Endpoints
- `POST /calculate` -> returns a job ID (string)
- `GET /result/{job_id}` -> returns `{ status, result }`

## Database access tools
Use DBeaver or Adminer. Adminer via container is safer; exposing the DB port directly is not recommended.
