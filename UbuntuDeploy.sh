#!/bin/bash

# --- Configuration ---
DEPLOYMENT_FILE="./math-deployment.yaml"
CONFIG_FILE="./math-config.yaml"
CONTAINER_IMAGE="mathcontainer:latest"
DEPLOYMENT_NAME="math-calculator-deployment"
SERVICE_NAME="math-calculator-service"
TIMEOUT="120s"

# Function for error handling
handle_error() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- 1. Docker Check and Build ---
echo "1. Checking for Docker image: ${CONTAINER_IMAGE}..."
if ! docker inspect --type=image "${CONTAINER_IMAGE}" &>/dev/null; then
    echo "   Image not found. Building ${CONTAINER_IMAGE}..."
    docker build -t "${CONTAINER_IMAGE}" . || handle_error "Docker build failed. Ensure Docker is running."
else
    echo "   Image ${CONTAINER_IMAGE} found locally."
fi

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
minikube image load "${CONTAINER_IMAGE}" || handle_error "Image load failed. Ensure image is built and Minikube is started."

# --- 4. Apply Kubernetes Resources ---
echo -e "\n4. Applying Kubernetes resources..."
kubectl apply -f "${CONFIG_FILE}" || handle_error "Config application failed."
kubectl apply -f "${DEPLOYMENT_FILE}" || handle_error "Deployment application failed."

# --- 5. Wait for Deployment Rollout ---
echo -e "\n5. Waiting for deployment '${DEPLOYMENT_NAME}' to be ready (up to ${TIMEOUT})..."
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" --timeout="${TIMEOUT}" || handle_error "Deployment rollout failed or timed out."

# --- 6. Verify Pod Status ---
echo -e "\n6. Verifying Pod status (should show 2 Running pods):"
kubectl get pods

# --- 7. Get Service URL and Open Browser ---
echo -e "\n7. Retrieving the service URL for ${SERVICE_NAME}..."

# Get the Minikube IP
MINIKUBE_IP=$(minikube ip) || handle_error "Failed to get Minikube IP."

# Get the NodePort
# Uses NodePort, which is reliable for external access
NODE_PORT=$(kubectl get service "${SERVICE_NAME}" -o=jsonpath='{.spec.ports[0].nodePort}')
if [ -z "${NODE_PORT}" ]; then
    handle_error "Failed to get NodePort for service '${SERVICE_NAME}'. Is the service type NodePort?"
fi

FINAL_URL="http://${MINIKUBE_IP}:${NODE_PORT}/ui"

echo "Minikube IP: ${MINIKUBE_IP}"
echo "NodePort: ${NODE_PORT}"
echo "Service Base URL: http://${MINIKUBE_IP}:${NODE_PORT}"
echo "Opening browser to: ${FINAL_URL}..."

# Use xdg-open to launch the default browser on most Linux desktop environments
xdg-open "${FINAL_URL}" &

echo -e "\nDeployment complete. Check your browser for the MathOps UI."
read -p "Press Enter to close the window..."
