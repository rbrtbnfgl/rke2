#!/bin/bash

GITHUB_REPOSITORY="rbrtbnfgl/rke2"


create-issue() {
    chart_version=$?
    gh extension install valeriobelli/gh-milestone

    MILESTONES_JSON=$(gh milestone list --state open --json dueOn,title)

    TODAY=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    TARGET_MILESTONE=$(echo "$MILESTONES_JSON" | jq -r --arg today "$TODAY" '
      [ .[] | select(.title | contains("Release Cycle")) | select(.dueOn >= $today) ] 
      | sort_by(.dueOn) 
      | .[0].title
    ')

    if [ "$TARGET_MILESTONE" == "null" ] || [ -z "$TARGET_MILESTONE" ]; then
      echo "No unexpired Release Cycle milestone found."
      exit 1
    fi

    echo "Selected Milestone: $TARGET_MILESTONE"
    ISSUE_TITLE="Update CNIs for $TARGET_MILESTONE"

    issue=$(
        gh issue list \
            --repo ${GITHUB_REPOSITORY} \
            --state "open" \
            --search "${ISSUE_TITLE}" \
            --json number,body
    )
    if [[ -z "$issue" ]]; then
       number=$(gh issue create \
           --title "${ISSUE_TITLE}" \
           --body "Update CNIs for $TARGET_MILESTONE:" \
           --repo ${GITHUB_REPOSITORY} \
           --milestone "$TARGET_MILESTONE" \
	   --json number --jq '.number')
    else
       min_json=$(jq -s 'sort_by(.number) | .[0]' data.json)
       body=$(jq -s 'sort_by(.number) | .[0]' data.json | jq -r '.body')
       number=$(jq -s 'sort_by(.number) | .[0]' data.json | jq -r '.number')
       if [[ -n "$chart_version" ]]; then
          gh issue comment \
              ${number} \
              --repo ${GITHUB_REPOSITORY} \
              --body "${ISSUE_BODY}"
       fi
    fi
    return $number
}

export -f create-issue
"$@"
