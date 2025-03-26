#!/bin/bash

set -euo pipefail

# Default values
COMPOSER_URL=${COMPOSER_URL:-"https://image-builder.example.com/api/image-builder/v1"}
BLUEPRINT_FILE=${BLUEPRINT_FILE:-"blueprints/rhel8-baseline.json"}
OUTPUT_DIR=${OUTPUT_DIR:-"output"}
DEBUG=${DEBUG:-false}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -u, --url URL           Image Builder API URL"
    echo "  -b, --blueprint FILE    Blueprint file path"
    echo "  -o, --output DIR        Output directory"
    echo "  -d, --debug            Enable debug output"
    echo "  -h, --help             Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            COMPOSER_URL="$2"
            shift 2
            ;;
        -b|--blueprint)
            BLUEPRINT_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Debug function
debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "DEBUG: $1"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
for cmd in curl jq; do
    if ! command_exists "$cmd"; then
        echo "Error: Required command '$cmd' is not installed"
        exit 1
    fi
done

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to make API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=${3:-""}
    
    local curl_opts=(-s -X "$method" -H "Content-Type: application/json")
    if [[ -n "${COMPOSER_TOKEN:-}" ]]; then
        curl_opts+=(-H "Authorization: Bearer $COMPOSER_TOKEN")
    fi
    
    if [[ -n "$data" ]]; then
        curl_opts+=(-d "$data")
    fi
    
    curl "${curl_opts[@]}" "${COMPOSER_URL}/${endpoint}"
}

# Upload blueprint
echo "Uploading blueprint..."
BLUEPRINT_DATA=$(cat "$BLUEPRINT_FILE")
BLUEPRINT_NAME=$(echo "$BLUEPRINT_DATA" | jq -r '.blueprint.name')
BLUEPRINT_VERSION=$(echo "$BLUEPRINT_DATA" | jq -r '.blueprint.version')

UPLOAD_RESPONSE=$(api_call "POST" "blueprints" "$BLUEPRINT_DATA")
debug "Upload response: $UPLOAD_RESPONSE"

# Check for errors
if echo "$UPLOAD_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    echo "Error uploading blueprint:"
    echo "$UPLOAD_RESPONSE" | jq -r '.error'
    exit 1
fi

# Start compose for each output type
echo "Starting image builds..."
for output in $(echo "$BLUEPRINT_DATA" | jq -r '.outputs[].type'); do
    echo "Building $output image..."
    
    COMPOSE_DATA=$(cat <<EOF
{
    "blueprint_name": "$BLUEPRINT_NAME",
    "compose_type": "$output",
    "branch": "rhel-8",
    "size": 20480
}
EOF
)
    
    COMPOSE_RESPONSE=$(api_call "POST" "compose" "$COMPOSE_DATA")
    debug "Compose response: $COMPOSE_RESPONSE"
    
    # Check for errors
    if echo "$COMPOSE_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        echo "Error starting compose for $output:"
        echo "$COMPOSE_RESPONSE" | jq -r '.error'
        continue
    fi
    
    COMPOSE_ID=$(echo "$COMPOSE_RESPONSE" | jq -r '.id')
    
    # Wait for compose to finish
    while true; do
        STATUS_RESPONSE=$(api_call "GET" "compose/$COMPOSE_ID")
        STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
        
        if [[ "$STATUS" == "FINISHED" ]]; then
            echo "Compose $COMPOSE_ID finished successfully"
            break
        elif [[ "$STATUS" == "FAILED" ]]; then
            echo "Compose $COMPOSE_ID failed"
            echo "$STATUS_RESPONSE" | jq -r '.error'
            break
        fi
        
        echo "Waiting for compose $COMPOSE_ID to finish... Status: $STATUS"
        sleep 30
    done
    
    # Download the image
    if [[ "$STATUS" == "FINISHED" ]]; then
        IMAGE_URL=$(echo "$STATUS_RESPONSE" | jq -r '.result.url')
        IMAGE_NAME="${BLUEPRINT_NAME}-${output}-${BLUEPRINT_VERSION}"
        
        echo "Downloading $output image..."
        curl -L "$IMAGE_URL" -o "$OUTPUT_DIR/$IMAGE_NAME"
        
        if [[ $? -eq 0 ]]; then
            echo "Successfully downloaded $output image to $OUTPUT_DIR/$IMAGE_NAME"
        else
            echo "Failed to download $output image"
        fi
    fi
done

# Clean up blueprint
echo "Cleaning up blueprint..."
DELETE_RESPONSE=$(api_call "DELETE" "blueprints/$BLUEPRINT_NAME/$BLUEPRINT_VERSION")
debug "Delete response: $DELETE_RESPONSE"

echo "Build process completed. Images are available in $OUTPUT_DIR" 