#!/bin/bash

# --- Configuration ---
DEPLOYMENT_FILE="./math-deployment.yaml"
CONFIG_FILE="./math-config.yaml"
CONTAINER_IMAGE="mathcontainer:latest"
DEPLOYMENT_NAME="math-api"
SERVICE_NAME="math-calculator-service"
MIGRATION_JOB_FILE="./math-migrate-job.yaml"
TIMEOUT="120s"

# Function for error handling
handle_error() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- 1. Docker Build ---
echo "1. Building Docker image: ${CONTAINER_IMAGE} (always rebuild)..."
docker build -t "${CONTAINER_IMAGE}" . || handle_error "Docker build failed. Ensure Docker is running."

# --- 2. Start Minikube (Conditional) ---
echo -e "\n2. Checking Minikube status..."
if minikube status -f '{{.Host}}' | grep -q 'Running'; then
    echo "   Minikube is already running."
else
    echo "   Minikube is not running. Starting Minikube..."
    # Note: Using the 'none' driver is common on Linux for running Minikube without a VM,
    # but the default 'docker' or 'kvm2' is often better if available.
    minikube start || handle_error "Minikube failed to start."
fi

# --- 3. Load Image into Minikube's Environment ---
echo -e "\n3. Loading image ${CONTAINER_IMAGE} into Minikube's Docker daemon..."
IMAGE_TAR="$(mktemp /tmp/mathcontainer.XXXXXX.tar)" || handle_error "Failed to create temp image archive."
docker save -o "${IMAGE_TAR}" "${CONTAINER_IMAGE}" || handle_error "Failed to export image."
minikube image load "${IMAGE_TAR}" --overwrite=true || handle_error "Image load failed. Ensure image is built and Minikube is started."
rm -f "${IMAGE_TAR}"

# --- 4. Apply Kubernetes Resources ---
echo -e "\n4. Applying Kubernetes resources..."
kubectl apply -f "${CONFIG_FILE}" || handle_error "Config application failed."
kubectl apply -f "${DEPLOYMENT_FILE}" || handle_error "Deployment application failed."

# --- 5. Restart Deployments to Pick Up New Image ---
echo -e "\n5. Restarting deployments to pick up the new image..."
kubectl rollout restart deployment/"${DEPLOYMENT_NAME}" || handle_error "Failed to restart deployment '${DEPLOYMENT_NAME}'."
kubectl rollout restart deployment/math-worker || handle_error "Failed to restart deployment 'math-worker'."

# --- 6. Wait for Deployment Rollout ---
echo -e "\n6. Waiting for deployment '${DEPLOYMENT_NAME}' to be ready (up to ${TIMEOUT})..."
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" --timeout="${TIMEOUT}" || handle_error "Deployment rollout failed or timed out."
echo -e "\n6b. Waiting for deployment 'math-worker' to be ready (up to ${TIMEOUT})..."
kubectl rollout status deployment/math-worker --timeout="${TIMEOUT}" || handle_error "Worker rollout failed or timed out."

# --- 7. Verify Pod Status ---
echo -e "\n7. Verifying Pod status (should show Running pods):"
kubectl get pods

# --- 8. Run database migrations ---
echo -e "\n8. Running database migrations..."
kubectl delete job math-migrate --ignore-not-found=true || handle_error "Failed to delete migration job."
kubectl apply -f "${MIGRATION_JOB_FILE}" || handle_error "Migration job creation failed."
kubectl wait --for=condition=complete job/math-migrate --timeout="${TIMEOUT}" || handle_error "Migration job failed."

# --- 9. Get Service URL and Open Browser ---
echo -e "\n9. Retrieving the service URL for ${SERVICE_NAME}..."

# Get the Minikube IP
MINIKUBE_IP=$(minikube ip) || handle_error "Failed to get Minikube IP."

# Get the NodePort
# Uses NodePort, which is reliable for external access
NODE_PORT=$(kubectl get service "${SERVICE_NAME}" -o=jsonpath='{.spec.ports[0].nodePort}')
if [ -z "${NODE_PORT}" ]; then
    handle_error "Failed to get NodePort for service '${SERVICE_NAME}'. Is the service type NodePort?"
fi

FINAL_URL="http://${MINIKUBE_IP}:${NODE_PORT}/docs"

echo "Minikube IP: ${MINIKUBE_IP}"
echo "NodePort: ${NODE_PORT}"
echo "Service Base URL: http://${MINIKUBE_IP}:${NODE_PORT}"
echo "Opening browser to: ${FINAL_URL}..."

# Use xdg-open to launch the default browser on most Linux desktop environments
xdg-open "${FINAL_URL}" &

echo -e "\nDeployment complete. Check your browser for the MathOps docs."
read -p "Press Enter to close the window..."
