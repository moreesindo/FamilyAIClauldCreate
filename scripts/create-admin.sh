#!/bin/bash
# FamilyAI Web UI Admin Account Creator
# Creates an admin account for Open WebUI without using the web interface

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FamilyAI Web UI Admin Creator${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if web-ui container is running
if ! docker ps | grep -q familyai-webui; then
    echo -e "${RED}Error: Web UI container is not running${NC}"
    echo ""
    echo "Please start the Web UI first:"
    echo "  docker-compose --profile full up -d web-ui"
    exit 1
fi

echo -e "${BLUE}This script will create an admin account for FamilyAI Web UI${NC}"
echo ""

# Prompt for admin details
read -p "Enter admin email: " ADMIN_EMAIL
read -p "Enter admin username: " ADMIN_USERNAME
read -sp "Enter admin password: " ADMIN_PASSWORD
echo ""
read -sp "Confirm admin password: " ADMIN_PASSWORD_CONFIRM
echo ""

# Validate passwords match
if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Error: Passwords do not match${NC}"
    exit 1
fi

# Validate inputs
if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}Error: All fields are required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Creating admin account...${NC}"

# Create admin account using Open WebUI API
# Note: This requires Open WebUI to have signup enabled temporarily
RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/auths/signup \
    -H "Content-Type: application/json" \
    -d "{
        \"email\": \"$ADMIN_EMAIL\",
        \"name\": \"$ADMIN_USERNAME\",
        \"password\": \"$ADMIN_PASSWORD\"
    }")

# Check if successful
if echo "$RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✅ Admin account created successfully!${NC}"
    echo ""
    echo -e "${GREEN}Login credentials:${NC}"
    echo -e "  Email: ${BLUE}$ADMIN_EMAIL${NC}"
    echo -e "  Username: ${BLUE}$ADMIN_USERNAME${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Now disable signup for security${NC}"
    echo "1. Edit .env file and set: WEBUI_ENABLE_SIGNUP=false"
    echo "2. Restart Web UI: docker-compose restart web-ui"
    echo ""
    echo "Access Web UI at: http://localhost:3000"
else
    echo -e "${RED}✗ Failed to create admin account${NC}"
    echo ""
    echo "Response: $RESPONSE"
    echo ""
    echo -e "${YELLOW}Possible reasons:${NC}"
    echo "1. Signup is disabled (WEBUI_ENABLE_SIGNUP=false)"
    echo "2. User already exists"
    echo "3. Web UI is not properly configured"
    echo ""
    echo "Please check your .env file and ensure WEBUI_ENABLE_SIGNUP=true"
    exit 1
fi
