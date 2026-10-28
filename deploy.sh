#!/usr/bin/env bash
# One-command deploy: backend (SAM) -> build React -> upload to S3 -> invalidate CloudFront.
set -euo pipefail

STACK="${STACK:-task-app}"
REGION="${AWS_REGION:-ap-south-1}"

echo "==> Deploying backend"
(cd backend && sam build && sam deploy \
  --stack-name "$STACK" --region "$REGION" --resolve-s3 \
  --capabilities CAPABILITY_IAM --no-confirm-changeset --no-fail-on-empty-changeset)

out() {
  aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
API_URL=$(out ApiUrl); SITE_BUCKET=$(out SiteBucketName); DIST_ID=$(out DistributionId); SITE_URL=$(out SiteUrl)

echo "==> Building frontend"
(cd frontend && npm install && VITE_API_URL="$API_URL" npm run build)

echo "==> Uploading to S3"
aws s3 sync frontend/dist "s3://$SITE_BUCKET" --delete --region "$REGION" \
  --cache-control "public,max-age=31536000,immutable" --exclude index.html
aws s3 cp frontend/dist/index.html "s3://$SITE_BUCKET/index.html" --region "$REGION" \
  --cache-control "no-cache"
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/index.html" >/dev/null

echo ""
echo "Live at: $SITE_URL"
