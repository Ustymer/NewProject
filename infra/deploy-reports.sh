#!/usr/bin/env bash
set -euo pipefail
main() {
  cd "$(dirname "$0")/.."
  source infra/common.sh
  : "${REPORT_EMAIL:?Set REPORT_EMAIL in .env}"
  fn="$PROJECT_NAME-backend"
  image="$(aws lambda get-function --function-name "$fn" --query Code.ImageUri --output text)"
  cfg="$(aws lambda get-function-configuration --function-name "$fn" --query Environment.Variables --output json)"
  var() { echo "$cfg" | python3 -c "import json,sys; print(json.load(sys.stdin)['$1'])"; }
  aws cloudformation deploy \
    --stack-name "$PROJECT_NAME-reports" \
    --template-file infra/reports.yaml \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
      "ProjectName=$PROJECT_NAME" "ImageUri=$image" "ReportEmail=$REPORT_EMAIL" \
      "DatabaseUrl=$(var DATABASE_URL)" "CorsOrigins=$(var CORS_ORIGINS)" \
      "CognitoUserPoolId=$(var COGNITO_USER_POOL_ID)" "CognitoClientId=$(var COGNITO_CLIENT_ID)" \
      "CognitoJwks=$(var COGNITO_JWKS)" \
      "VpcId=$(output "$BACKEND_STACK" VpcId)" \
      "SubnetA=$(output "$BACKEND_STACK" PrivateSubnetAId)" \
      "SubnetB=$(output "$BACKEND_STACK" PrivateSubnetBId)" \
      "SecurityGroupId=$(output "$BACKEND_STACK" FunctionSecurityGroupId)" \
      "ScheduleExpression=${SCHEDULE_EXPRESSION:-cron(0 7 ? * MON *)}" \
      "FailWeek=${FAIL_WEEK:-}" \
    --tags "${STACK_TAGS[@]}" \
    --no-fail-on-empty-changeset
  echo "Done. Click the SES verification link sent to $REPORT_EMAIL."
}
main "$@"