#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

#######################################
# Load configuration from external file
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/gitea-github-mirror.conf" ]]; then
  source "${SCRIPT_DIR}/gitea-github-mirror.conf"
  echo "[INFO] Loaded configuration from ${SCRIPT_DIR}/gitea-github-mirror.conf"
else
  echo "[ERROR] Config file not found: ${SCRIPT_DIR}/gitea-github-mirror.conf" >&2
  exit 1
fi

#######################################
# Validate required configuration
#######################################

REQUIRED_VARS=(GITEA_URL GITEA_TOKEN GITEA_ORG GITHUB_OWNER GITHUB_TOKEN)

for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "[ERROR] Required variable $var is not set in gitea-github-mirror.conf" >&2
    exit 1
  fi
done

echo "[INFO] Configuration validation passed"

#######################################
# FUNCTIONS
#######################################

# Function: fetch repos from GitHub (org or user) without jq
function get_github_repos() {
    STATUS=$(curl --max-time 15 --connect-timeout 5 -k -s -H "Authorization: token $GITHUB_TOKEN" \
        -o /dev/null -w "%{http_code}" "https://api.github.com/orgs/$GITHUB_OWNER")

    REPOS_LIST=""
    if [ "$STATUS" -eq 200 ]; then
        [ "$DEBUG" = true ] && echo "[DEBUG] GitHub owner is an organization" >&2
        REPOS_LIST=$(curl --max-time 15 --connect-timeout 5 -k -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/orgs/$GITHUB_OWNER/repos?per_page=100" \
            | awk '
                BEGIN{inobj=0}
                /^\s*{\s*$/ {inobj=1}
                inobj && /"name":/ {gsub(/[",]/,"",$2); print $2; inobj=0}
            ')
    else
        [ "$DEBUG" = true ] && echo "[DEBUG] GitHub owner is a user" >&2
        REPOS_LIST=$(curl --max-time 15 --connect-timeout 5 -k -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/users/$GITHUB_OWNER/repos?per_page=100" \
            | awk '
                BEGIN{inobj=0}
                /^\s*{\s*$/ {inobj=1}
                inobj && /"name":/ {gsub(/[",]/,"",$2); print $2; inobj=0}
            ')
    fi

    echo "$REPOS_LIST"
}

# Function: ensure Gitea organization exists
function ensure_gitea_org() {
    HTTP_CODE=$(curl --max-time 15 --connect-timeout 5 -k -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $GITEA_TOKEN" \
        "$GITEA_URL/api/v1/orgs/$GITEA_ORG")

    if [ "$HTTP_CODE" -eq 404 ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would create Gitea organization: $GITEA_ORG"
        else
            curl --max-time 15 --connect-timeout 5 -k -s -X POST -H "Content-Type: application/json" \
                 -H "Authorization: token $GITEA_TOKEN" \
                 -d "{\"username\":\"$GITEA_ORG\",\"full_name\":\"GitHub Mirrors\"}" \
                 "$GITEA_URL/api/v1/orgs"
            echo "[OK] Created Gitea organization: $GITEA_ORG"
        fi
    else
        [ "$DEBUG" = true ] && echo "[DEBUG] Gitea organization $GITEA_ORG exists (HTTP $HTTP_CODE)" >&2
    fi
}

# Function: list existing Gitea repos in the org (for debug)
function list_gitea_repos() {
    curl --max-time 15 --connect-timeout 5 -k -s -H "Authorization: token $GITEA_TOKEN" \
        "$GITEA_URL/api/v1/orgs/$GITEA_ORG/repos?limit=100" \
        | grep -oE '"name": "[^"]+"' | cut -d'"' -f4
}

# Ensure Gitea org exists before mirroring
ensure_gitea_org

# Fetch repositories from GitHub
REPOS=$(get_github_repos)

# Debug: list GitHub and Gitea repos separately
if [ "$DEBUG" = true ]; then
    echo "[DEBUG] GitHub repositories:" >&2
    for r in $REPOS; do
        echo "  - $r" >&2
    done

    echo "[DEBUG] Existing Gitea repositories in $GITEA_ORG:" >&2
    for r in $(list_gitea_repos); do
        echo "  - $r" >&2
    done
fi

# Loop through GitHub repos and mirror using migrate endpoint
for repo in $REPOS; do
    # Apply filter
    if [[ "$FILTER_MODE" == "include" ]]; then
        if [[ ! " ${INCLUDE_REPOS[@]} " =~ " $repo " ]]; then
            echo "[SKIP] $repo (not in include list)"
            continue
        fi
    else
        if [[ " ${EXCLUDE_REPOS[@]} " =~ " $repo " ]]; then
            echo "[SKIP] $repo (in exclude list)"
            continue
        fi
    fi

    # Check if repo exists in Gitea org via HTTP status code
    HTTP_CODE=$(curl --max-time 15 --connect-timeout 5 -k -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $GITEA_TOKEN" \
        "$GITEA_URL/api/v1/repos/$GITEA_ORG/$repo")

    if [ "$HTTP_CODE" -eq 404 ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would migrate GitHub repo $repo as mirror in org $GITEA_ORG"
        else
            curl --max-time 15 --connect-timeout 5 -k -s -X POST -H "Content-Type: application/json" \
                -H "Authorization: token $GITEA_TOKEN" \
                -d "{
                      \"clone_addr\": \"https://github.com/$GITHUB_OWNER/$repo.git\",
                      \"repo_name\": \"$repo\",
                      \"repo_owner\": \"$GITEA_ORG\",
                      \"mirror\": true,
                      \"mirror_interval\": \"$MIRROR_INTERVAL\",
                      \"auth_token\": \"$GITHUB_TOKEN\",
                      \"wiki\": $CLONE_WIKI,
                      \"service\": \"github\"
                    }" \
                "$GITEA_URL/api/v1/repos/migrate"
            echo "[OK] Migrated GitHub repo $repo as mirror in org $GITEA_ORG"
        fi
    elif [ "$HTTP_CODE" -eq 200 ]; then
        echo "[SKIP] $repo already exists in Gitea org $GITEA_ORG"
    else
        echo "[WARN] Could not check $repo in Gitea (HTTP $HTTP_CODE)"
    fi
done
