# Task App (React + AWS Serverless)

A simple task list with optional image attachments.

**Stack:** React (Vite) · S3 + CloudFront · API Gateway (HTTP API) · Lambda (Node 20) · DynamoDB · S3 (images). No EC2.

## Architecture

```
Browser ──► CloudFront ──► S3 (React build, private via OAC)
   │
   ├──► API Gateway ──► Lambda ──► DynamoDB   (tasks)
   │                       └────► S3 presigner (image URLs)
   └──► S3 (direct upload with a presigned URL)
```

## Deploy (one command)

Prereqs: AWS CLI configured (`aws configure`), AWS SAM CLI, Node 18+.

```bash
./deploy.sh                      # default region ap-south-1
AWS_REGION=us-east-1 ./deploy.sh # or pick another region
```

The script deploys the backend, builds React with the API URL, syncs it to S3, invalidates CloudFront and prints the live URL (the CloudFront `https://xxxx.cloudfront.net` link is what you submit).

## Run locally

```bash
cd frontend
cp .env.example .env     # paste the ApiUrl printed by deploy.sh
npm install
npm run dev
```

## API

| Method | Path | Purpose |
|---|---|---|
| GET | /tasks | List tasks (newest first) |
| POST | /tasks | Create `{ title, imageKey? }` |
| PATCH | /tasks/:id | Toggle `{ done }` |
| DELETE | /tasks/:id | Delete task and its image |
| POST | /upload-url | Get a presigned S3 PUT URL |

## Speed choices

- React build is static on S3, served from CloudFront edge locations (HTTP/2+3, compression, long-lived cache for hashed assets, `index.html` never cached).
- Lambda on arm64, SDK clients created outside the handler (reused on warm starts).
- Images upload straight from the browser to S3, so Lambda never handles large payloads.
- DynamoDB on-demand: single-digit-millisecond reads, no capacity to manage.
- Optimistic UI for toggle and delete; lazy-loaded images; system font stack (no font downloads).

## Known trade-offs (good to mention)

- `GET /tasks` uses a table scan, fine for a demo; with users I'd add a `userId` partition key and `Query`.
- No auth yet; I'd add Cognito and a JWT authorizer on the HTTP API.
- CORS is `*` for simplicity; I'd restrict it to the CloudFront domain.
