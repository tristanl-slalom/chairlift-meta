#!/bin/bash
set -e

# GitHub Projects API Integration
# Requires: gh CLI installed and authenticated

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
META_REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Project URL: https://github.com/users/tristanl-slalom/projects/1
PROJECT_OWNER="tristanl-slalom"
PROJECT_NUMBER="1"

# Function to check if gh is installed and authenticated
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
        echo "Install: brew install gh"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo -e "${RED}Error: Not authenticated with GitHub${NC}"
        echo "Run: gh auth login"
        exit 1
    fi
}

# Function to list project items
list_items() {
    echo -e "${BLUE}Fetching project items...${NC}"
    echo ""

    # Use GraphQL to fetch project items
    gh api graphql -f query='
    query($owner: String!, $number: Int!) {
      user(login: $owner) {
        projectV2(number: $number) {
          items(first: 100) {
            nodes {
              id
              fieldValues(first: 20) {
                nodes {
                  ... on ProjectV2ItemFieldTextValue {
                    text
                    field {
                      ... on ProjectV2FieldCommon {
                        name
                      }
                    }
                  }
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field {
                      ... on ProjectV2FieldCommon {
                        name
                      }
                    }
                  }
                }
              }
              content {
                ... on Issue {
                  number
                  title
                  body
                  state
                  url
                }
                ... on DraftIssue {
                  title
                  body
                }
              }
            }
          }
        }
      }
    }' -f owner="$PROJECT_OWNER" -F number="$PROJECT_NUMBER"
}

# Function to get specific item details
get_item() {
    local item_number=$1

    echo -e "${BLUE}Fetching details for item #$item_number from project...${NC}" >&2

    # Query the project to find the item by issue number
    local result=$(gh api graphql -f query='
    query($owner: String!, $number: Int!) {
      user(login: $owner) {
        projectV2(number: $number) {
          items(first: 100) {
            nodes {
              content {
                ... on Issue {
                  number
                  title
                  body
                  state
                  url
                  repository {
                    nameWithOwner
                  }
                }
              }
            }
          }
        }
      }
    }' -f owner="$PROJECT_OWNER" -F number="$PROJECT_NUMBER")

    # Filter to find the matching issue number and extract its data
    echo "$result" | jq -r --arg num "$item_number" '
      .data.user.projectV2.items.nodes[]
      | select(.content.number != null)
      | select((.content.number | tostring) == $num)
      | {
          number: .content.number,
          title: .content.title,
          body: .content.body,
          state: .content.state,
          url: .content.url,
          repository: .content.repository.nameWithOwner
        }
      | if . == null then empty else . end'
}

# Function to create draft issue in project
create_item() {
    local title=$1
    local body=$2

    echo -e "${BLUE}Creating project item...${NC}"

    gh issue create \
        --title "$title" \
        --body "$body" \
        --label "feature"
}

# Main command router
case "${1:-list}" in
    list)
        check_gh_cli
        list_items | jq -r '.data.user.projectV2.items.nodes[] | "\(.content.number // "draft")\t\(.content.title)\t\(.content.state // "draft")"' | column -t -s $'\t'
        ;;
    get)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Item number required${NC}"
            echo "Usage: $0 get <item-number>"
            exit 1
        fi
        check_gh_cli
        get_item "$2"
        ;;
    create)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: Title required${NC}"
            echo "Usage: $0 create <title> [body]"
            exit 1
        fi
        check_gh_cli
        create_item "$2" "${3:-}"
        ;;
    *)
        echo "Usage: $0 {list|get|create} [args]"
        echo ""
        echo "Commands:"
        echo "  list              - List all project items"
        echo "  get <number>      - Get details for specific item"
        echo "  create <title>    - Create new project item"
        exit 1
        ;;
esac
