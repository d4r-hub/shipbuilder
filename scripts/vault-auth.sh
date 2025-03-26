#!/bin/bash

set -euo pipefail

# Default values
VAULT_ADDR=${VAULT_ADDR:-"https://vault.example.com"}
VAULT_PATH=${VAULT_PATH:-"auth/ldap/login"}
ARTIFACTORY_PATH=${ARTIFACTORY_PATH:-"secret/artifactory"}
TOKEN_FILE=${TOKEN_FILE:-"${HOME}/.vault-token"}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -u, --username USERNAME    LDAP username"
    echo "  -p, --password PASSWORD    LDAP password"
    echo "  -a, --addr ADDRESS         Vault address (default: ${VAULT_ADDR})"
    echo "  -t, --token-file FILE      Token file location (default: ${TOKEN_FILE})"
    echo "  -h, --help                 Show this help message"
    echo
    echo "Environment variables:"
    echo "  VAULT_ADDR         Vault server address"
    echo "  VAULT_PATH         Vault LDAP auth path"
    echo "  ARTIFACTORY_PATH   Path to Artifactory secrets"
    echo "  TOKEN_FILE         Location to store the token"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -a|--addr)
            VAULT_ADDR="$2"
            shift 2
            ;;
        -t|--token-file)
            TOKEN_FILE="$2"
            shift 2
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

# Check if username and password are provided
if [[ -z "${USERNAME:-}" ]] || [[ -z "${PASSWORD:-}" ]]; then
    echo "Error: Username and password are required"
    show_help
    exit 1
fi

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

# Function to make Vault API calls
vault_api() {
    local method=$1
    local path=$2
    local data=$3
    local token=${4:-""}
    
    local headers=()
    if [[ -n "$token" ]]; then
        headers+=(-H "X-Vault-Token: $token")
    fi
    
    curl -s -X "$method" \
        -H "Content-Type: application/json" \
        "${headers[@]}" \
        -d "$data" \
        "${VAULT_ADDR}/v1/${path}"
}

# Authenticate with Vault
echo "Authenticating with Vault..."
AUTH_RESPONSE=$(vault_api "POST" "$VAULT_PATH" "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

# Check for authentication errors
if echo "$AUTH_RESPONSE" | jq -e '.errors' >/dev/null 2>&1; then
    echo "Error: Authentication failed"
    echo "$AUTH_RESPONSE" | jq -r '.errors[]'
    exit 1
fi

# Extract the client token
CLIENT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token')

if [[ -z "$CLIENT_TOKEN" ]] || [[ "$CLIENT_TOKEN" == "null" ]]; then
    echo "Error: Failed to get client token"
    exit 1
fi

# Save the token to file
echo "$CLIENT_TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
echo "Token saved to $TOKEN_FILE"

# Get Artifactory credentials
echo "Retrieving Artifactory credentials..."
ARTIFACTORY_RESPONSE=$(vault_api "GET" "$ARTIFACTORY_PATH" "{}" "$CLIENT_TOKEN")

# Check for errors in response
if echo "$ARTIFACTORY_RESPONSE" | jq -e '.errors' >/dev/null 2>&1; then
    echo "Error: Failed to get Artifactory credentials"
    echo "$ARTIFACTORY_RESPONSE" | jq -r '.errors[]'
    exit 1
fi

# Extract and display Artifactory credentials
echo "Artifactory credentials retrieved successfully:"
echo "$ARTIFACTORY_RESPONSE" | jq -r '.data | "ARTIFACTORY_USER=\(.username)\nARTIFACTORY_PASS=\(.password)"'

# Export credentials to environment
export ARTIFACTORY_USER=$(echo "$ARTIFACTORY_RESPONSE" | jq -r '.data.username')
export ARTIFACTORY_PASS=$(echo "$ARTIFACTORY_RESPONSE" | jq -r '.data.password')

echo "Credentials exported to environment variables" 