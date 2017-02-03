#!/usr/bin/env bash

#VS_ORGANIZATION=$1
#VS_CREDENTIAL=$2


VS_ORGANIZATION="envizio"
VS_CREDENTIAL="vasyliev@mynfo.com:cf2j2ksf6bhurs2tjz7aycw7jewqa4xx725a4b6ql4sh5ces5kea"
CHECK_ONLY="$1"
RAISE_ERROR="$CHECK_ONLY"
CURL_VERBOSE_FLAG="-s"
#"-v"

TASK_TYPE_NAME="Task"
BUG_TYPE_NAME="Bug"
BI_TYPE_NAME="Product Backlog Item"

IMPLEMENTED_ITEM_STATE_FROM="In Progress"
#IMPLEMENTED_ITEM_STATE_FROM="Committed"

IMPLEMENTED_TASK_STATE_TO="Done"
#IMPLEMENTED_BUG_STATE_TO="Implemented"
IMPLEMENTED_BUG_STATE_TO="Done"
IMPLEMENTED_BI_STATE_TO="Done"

ALL_TASKS_STATES_TO_CLOSE_BI='"Removed","Done"'
ALL_BUGS_STATES_TO_CLOSE_BI='"Removed","Done"'

# ===================

function exit_with_message() {

local MESSAGE
MESSAGE="$1"

local EXIT_CODE
if [[ "$2" ]]; then
EXIT_CODE="$2"
else
EXIT_CODE=0
fi

if [[ "$EXIT_CODE" != "0" ]]; then
    echo "-> $MESSAGE" >&2
else
    echo "-> $MESSAGE"
fi

if [[ "$RAISE_ERROR" != 0 ]]; then
  exit "$EXIT_CODE"
else
#TODO: if $EXIT_CODE != 0 notify to committer about it
  exit 0
fi
}

function update_work_item_state() {
local ITEM_ID
ITEM_ID="$1"
local NEW_ITEM_STATE
NEW_ITEM_STATE=$2

REQUEST_DATA="[{\"op\": \"add\",\"path\": \"/fields/System.State\", \"value\": \"$NEW_ITEM_STATE\"}]"
IMPLEMENTED_ITEM="$(curl $CURL_VERBOSE_FLAG -u $VS_CREDENTIAL -X PATCH 'https://'$VS_ORGANIZATION'.VisualStudio.com/DefaultCollection/_apis/wit/workitems/'$ITEM_ID'?api-version=1.0' -H 'Content-Type: application/json-patch+json' -d "$REQUEST_DATA")"

echo "-> State of item '$ITEM_ID' changed to '$NEW_ITEM_STATE'"
}

function close_work_item() {

local IMPLEMENTED_ITEM_ID
IMPLEMENTED_ITEM_ID="$1"

local CHECK_ONLY
CHECK_ONLY="$2"

IMPLEMENTED_ITEM="$(curl $CURL_VERBOSE_FLAG -u $VS_CREDENTIAL 'https://'$VS_ORGANIZATION'.VisualStudio.com/DefaultCollection/_apis/wit/workitems/'$IMPLEMENTED_ITEM_ID'?$expand=all&api-version=1.0')"

IMPLEMENTED_ITEM_TYPE="$(echo $IMPLEMENTED_ITEM | jq -r '.fields."System.WorkItemType"')"

declare IMPLEMENTED_ITEM_STATE_TO

if [[ "$IMPLEMENTED_ITEM_TYPE" == "$TASK_TYPE_NAME" ]]; then
IMPLEMENTED_ITEM_STATE_TO=$IMPLEMENTED_TASK_STATE_TO
elif [[ "$IMPLEMENTED_ITEM_TYPE" == "$BUG_TYPE_NAME" ]]; then
IMPLEMENTED_ITEM_STATE_TO=$IMPLEMENTED_BUG_STATE_TO
else
exit_with_message "Item '$IMPLEMENTED_ITEM_ID' has not valid type '$IMPLEMENTED_ITEM_TYPE'. Valid types to close the item are '$TASK_TYPE_NAME' and '$BUG_TYPE_NAME'." 1
fi

IMPLEMENTED_ITEM_STATE="$(echo $IMPLEMENTED_ITEM | jq -r '.fields."System.State"')"
if [[ "$IMPLEMENTED_ITEM_STATE" != "$IMPLEMENTED_ITEM_STATE_FROM" ]]; then
exit_with_message "$IMPLEMENTED_ITEM_TYPE '$IMPLEMENTED_ITEM_ID' has not valid state '$IMPLEMENTED_ITEM_STATE'. Valid state to close $IMPLEMENTED_ITEM_TYPE is '$IMPLEMENTED_ITEM_STATE_FROM'." 1
fi

if [[ "$CHECK_ONLY" != "0" ]]; then
echo "-> $IMPLEMENTED_ITEM_TYPE '$IMPLEMENTED_ITEM_ID' will be closed if the buil is successful."
return
fi


#TODO: Add a build (may be a commit hash too) id to the work item
update_work_item_state "$IMPLEMENTED_ITEM_ID" "$IMPLEMENTED_ITEM_STATE_TO"

#exit_with_message "OK!"

# ------- Close becklog Item

PARENT_ITEM_ID="$(echo $IMPLEMENTED_ITEM | jq -r '.relations[] | select(.rel | contains("System.LinkTypes.Hierarchy-Reverse")) | .url | capture("/(?<n>[0-9]+$)") | .n')"

if [[ "$PARENT_ITEM_ID" == "" ]]; then
exit_with_message "$IMPLEMENTED_ITEM_TYPE '$IMPLEMENTED_ITEM_ID' has not parent Work Item."
fi


PARENT_ITEM="$(curl $CURL_VERBOSE_FLAG -u $VS_CREDENTIAL 'https://'$VS_ORGANIZATION'.VisualStudio.com/DefaultCollection/_apis/wit/workitems/'$PARENT_ITEM_ID'?$expand=relations&api-version=1.0')"

CHILD_ITEMS_IDS="$(echo $PARENT_ITEM | jq -r '[. | select(.fields."System.WorkItemType" == "Product Backlog Item") | .relations[] | select(.rel | contains("System.LinkTypes.Hierarchy-Forward")) | .url | capture("/(?<n>[0-9]+$)") | .n] | join(",")')"

CHILD_ITEMS="$(curl $CURL_VERBOSE_FLAG -u $VS_CREDENTIAL 'https://'$VS_ORGANIZATION'.visualstudio.com/DefaultCollection/_apis/wit/workitems?ids='$CHILD_ITEMS_IDS'&api-version=1.0')"

JQ_FILTER_NOT_IMPLEMENTED_CHILD_ITEMS_COUNT='[.value[] | select(((.fields."System.WorkItemType" == "'$TASK_TYPE_NAME'") and (.fields."System.State" as $state | ['$ALL_TASKS_STATES_TO_CLOSE_BI'] | index($state) < 0)) or ((.fields."System.WorkItemType" == "'$BUG_TYPE_NAME'") and (.fields."System.State" as $state | ['$ALL_BUGS_STATES_TO_CLOSE_BI'] | index($state) < 0)) )] | length'

NOT_IMPLEMENTED_CHILD_ITEMS_COUNT=$(echo $CHILD_ITEMS | jq -r "$JQ_FILTER_NOT_IMPLEMENTED_CHILD_ITEMS_COUNT")

if [ "$NOT_IMPLEMENTED_CHILD_ITEMS_COUNT" == "0" ];
then
update_work_item_state "$PARENT_ITEM_ID" "$IMPLEMENTED_BI_STATE_TO"
fi
}

# =====================

set -e

COMMIT_COMMENT="$(git show --pretty=format:"%s" -s)"

echo "$COMMIT_COMMENT" | grep -o '#[[:digit:]][[:digit:]]*' | while read line
do
close_work_item "$(echo "$line" | sed 's|#||')" "$CHECK_ONLY"
done


set +e