CHART_NAME=${1}
CHART_VERSION=${2}
TARGET_REPOSITORY="rbrtbnfgl/rke2"
ISSUE_TITLE="Update ${CHART_NAME} to ${CHART_VERSION}"
issues=$(gh issue list -R ${TARGET_REPOSITORY} \
            --search "is:open ${ISSUE_TITLE}" \
            --json number --jq ".[].number" | head -n 1)
check_num='^[0-9]+$'
if ! [[ $issues =~ $check_num ]] ; then
   echo ""
else
   echo $issues
fi

