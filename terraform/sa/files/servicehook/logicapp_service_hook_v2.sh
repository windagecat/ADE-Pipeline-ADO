#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

script_path=$(dirname "$0")
CACHE_FILE="$script_path/cache.json"

if [ -f "$CACHE_FILE" ]; then
  cat "$CACHE_FILE" | jq
else
  # Extract "foo" and "baz" arguments from the input into
  # FOO and BAZ shell variables.
  # jq will ensure that the values are properly quoted
  # and escaped for consumption by the shell.
  eval "$(jq -r '@sh "ado_projectId=\(.ado_projectId) ado_team_group_id=\(.ado_team_group_id) ado_repo_id=\(.ado_repo_id) webhook_url=\(.webhook_url) pat=\(.pat) orgnization=\(.orgnization)"')"

  # JSONデータを作成
  json_data=$(cat <<EOF
  {
    "publisherId": "tfs",
    "eventType": "git.pullrequest.merged",
    "resourceVersion": "1.0",
    "consumerId": "webHooks",
    "consumerActionId": "httpRequest",
    "publisherInputs": {
      "branch": "main",
      "mergeResult": "Succeeded",
      "projectId": "$ado_projectId",
      "pullrequestCreatedBy": "$ado_team_group_id",
      "pullrequestReviewersContains": "$ado_team_group_id",
      "repository": "$ado_repo_id"
    },
    "consumerInputs": {
      "url": "$webhook_url"
    }
}
EOF
)

  # curlコマンドを実行
  subscriptionid=`curl -s -X POST -H "Content-Type: application/json" -u ":${pat}" "https://dev.azure.com/${orgnization}/_apis/hooks/subscriptions?api-version=7.1" -d "$json_data" | jq -r .id`
  # subscriptionid変数の値をチェック
  if [ -z "$subscriptionid" ] || [ "$subscriptionid" == "null" ]; then
    echo "Error: subscriptionid is null or empty"
    exit 1
  fi
    jq -n --arg subscriptionid "$subscriptionid" '{"subscriptionid":$subscriptionid}' >> $CACHE_FILE
    jq -n --arg subscriptionid "$subscriptionid" '{"subscriptionid":$subscriptionid}'
fi
