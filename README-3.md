# Serverless Smart Notify: Event-Driven Notification Engine on AWS

> A fully serverless, event-driven notification system — no servers to manage, real emails delivered, built entirely on managed AWS services.

---

## What This Is

This project is a production-style notification engine built entirely on AWS serverless infrastructure. It accepts notification requests through a REST API, processes them with Lambda, delivers real emails through SNS, logs every event to DynamoDB, and exposes the full notification history through a queryable API — all without a single server to manage.

It also includes a browser-based simulator dashboard hosted on S3, so the entire system can be demonstrated end-to-end in a real browser.

Think of it as the backend that powers the "Your order has been placed" or "Unusual login detected" emails you get from every serious app — built from scratch, on AWS, with zero servers.

---

## Why I Built This

Every application eventually needs to notify its users. But building a notification system that's reliable, scalable, decoupled, and auditable is a real engineering problem. This project taught me how to solve it the modern way — using managed services, event-driven architecture, and serverless compute instead of standing up and babysitting servers.

These are the exact patterns used in e-commerce platforms, SaaS products, and banking apps.

---

## Architecture

```
                        ┌─────────────────────────┐
                        │   S3 Static Frontend     │
                        │   (Simulator Dashboard)  │
                        └────────────┬────────────┘
                                     │
                          POST /notify │ GET /notifications
                                     ▼
                        ┌─────────────────────────┐
                        │      API Gateway         │
                        │  (REST API, CORS-enabled) │
                        └────────┬────────┬────────┘
                                 │        │
                    POST /notify │        │ GET /notifications
                                 ▼        ▼
                   ┌─────────────────┐  ┌──────────────────┐
                   │ NotifyProcessor │  │  NotifyQuery      │
                   │   (Lambda)      │  │   (Lambda)        │
                   └────────┬────────┘  └────────┬─────────┘
                            │                    │
               ┌────────────┼────────────┐       │
               │            │            │       │
               ▼            ▼            ▼       ▼
        ┌────────────┐ ┌─────────┐ ┌──────────────────────┐
        │  SNS Topic │ │DynamoDB │ │      DynamoDB         │
        │(NotifyTopic│ │  Write  │ │  NotificationLog      │
        └─────┬──────┘ └─────────┘ │  (Read / History)    │
              │                    └──────────────────────┘
     ┌────────┴────────┐
     │                 │
     ▼                 ▼
┌─────────┐     ┌────────────┐
│  Email  │     │ SQS Queue  │
│Delivery │     │(NotifyQueue│
│(to user)│     │ retry buf) │
└─────────┘     └────────────┘
```

---

## How It Works — End to End

1. Engineer opens the simulator dashboard hosted on S3
2. Selects an event type (`order_placed`, `security_alert`, `system_warning`), enters a recipient email and message, clicks Send
3. Frontend calls `POST /notify` on API Gateway
4. API Gateway triggers `NotifyProcessor` Lambda
5. Lambda generates a unique notification ID, publishes the event to SNS, and writes the log to DynamoDB
6. SNS fans out to two subscribers simultaneously:
   - Recipient receives a real email
   - SQS queue receives the message as a decoupled buffer for retry/audit
7. Frontend calls `GET /notifications` on API Gateway
8. API Gateway triggers `NotifyQuery` Lambda
9. Lambda reads all records from DynamoDB and returns them
10. Frontend renders the full Notification History table

Every step is logged automatically to CloudWatch.

---

## What Gets Built

### Frontend (S3 Static Website)
- `index.html` hosted on S3 static website hosting
- Form to select event type, enter recipient email and message
- Sends notification via `POST /notify`
- Displays full notification history via `GET /notifications`
- No backend server — just a browser talking directly to API Gateway

### API Layer (API Gateway)
| Endpoint | Method | What It Does |
|----------|--------|-------------|
| `/notify` | POST | Receives notification request, triggers NotifyProcessor Lambda |
| `/notifications` | GET | Queries DynamoDB, returns all logged events |

Both endpoints are CORS-enabled for browser access.

### Serverless Processing (Lambda)

`NotifyProcessor`
- Parses the incoming event
- Generates a unique notification ID
- Publishes the event to SNS
- Writes the event log to DynamoDB

`NotifyQuery`
- Reads all records from the DynamoDB `NotificationLog` table
- Returns them as a structured JSON response to the frontend

### Notification Delivery (SNS + SQS)
- SNS Topic (`NotifyTopic`) receives the processed event and fans it out
- Email subscription delivers a real email to the recipient
- SQS Queue (`NotifyQueue`) subscribes to SNS as a decoupled buffer — enables retry logic and dead-letter handling for failed deliveries

### Data Layer (DynamoDB)
`NotificationLog` table stores every event with:
- Notification ID (unique)
- Event type
- Recipient email
- Message
- Status
- Timestamp

Full audit trail. Powers the history view on the frontend.

### Observability (CloudWatch)
- Lambda logs stream to CloudWatch automatically
- Monitor invocation counts, error rates, and execution duration
- Basic alarm configured for Lambda errors

---

## AWS Services Used

| Service | Role |
|---------|------|
| Amazon S3 | Frontend hosting (static website) |
| Amazon API Gateway | REST API — POST /notify + GET /notifications |
| AWS Lambda | Serverless event processing and data querying |
| Amazon SNS | Managed email delivery (fan-out) |
| Amazon SQS | Decoupled message queue and retry buffer |
| Amazon DynamoDB | Durable event log and notification history |
| AWS IAM | Least-privilege permissions between all services |
| Amazon CloudWatch | Logging, monitoring, and alerting |

---

## Project Structure

```
.
├── index.html                  # Simulator dashboard (deployed to S3)
├── lambda/
│   ├── notify_processor.py     # Handles POST /notify
│   └── notify_query.py         # Handles GET /notifications
└── README.md
```

---

## Key Design Decisions

**Why SNS + SQS together?**
SNS alone delivers messages but doesn't buffer them. Adding SQS as a subscriber gives the system a retry layer — if downstream processing fails, the message stays in the queue and can be reprocessed. This is a standard pattern in production notification systems.

**Why DynamoDB?**
It's serverless, scales automatically, and has single-digit millisecond read latency. For an event log that needs to be queryable from a frontend, it's the right fit.

**Why a simulator dashboard?**
In a real system, the notification engine would be called by upstream services (an order service, an auth service, etc.). The simulator represents the tool an engineer uses to test and validate the pipeline before those upstream services are connected — which is exactly how it works in practice.

---

## Estimated Cost

| Service | Free Tier | Estimated Cost |
|---------|-----------|----------------|
| Lambda | 1M requests/month | $0.00 |
| API Gateway | 1M calls/month | $0.00 |
| DynamoDB | 25GB + 200M requests | $0.00 |
| SNS | 1M publishes/month | $0.00 |
| SQS | 1M requests/month | $0.00 |
| S3 | 5GB storage | $0.00 |
| CloudWatch | Basic monitoring | $0.00 |

Total estimated cost: **$0.00** — every service used falls within AWS Free Tier limits. New accounts also receive $200 in free credits for the first 6 months.

---

## Student Checklist

- [x] DynamoDB `NotificationLog` table created
- [x] Lambda `NotifyProcessor` deployed and tested
- [x] Lambda `NotifyQuery` deployed and tested
- [x] SNS topic created and email subscription confirmed
- [x] SQS queue created and subscribed to SNS
- [x] API Gateway configured with CORS (POST + GET)
- [x] Frontend (`index.html`) deployed to S3 static website
- [x] Full end-to-end test completed (form → email received)
- [x] CloudWatch logs reviewed
- [x] Resources cleaned up
- [x] Project documented on GitHub

---

## The Problem This Solves

Building a reliable notification system from scratch is harder than it looks:

- Notifications must be delivered instantly and reliably, even under load
- Failed deliveries need to retry automatically — no manual intervention
- Every event must be logged and auditable
- The system needs to be decoupled from the apps that call it so it can serve multiple use cases

This project solves all of that with a fully managed, serverless stack. No servers to patch, no queues to babysit, no infrastructure to scale manually.

---

## What I Learned

- How to design an event-driven system using SNS, SQS, and Lambda together
- Why decoupling matters — and how SQS as a buffer makes a system more resilient
- How API Gateway connects a static frontend to serverless backend logic
- How to use DynamoDB as a low-latency event log
- How CloudWatch gives you visibility into a system with no servers to log into

---

*Built as part of a cloud engineering curriculum. Feedback welcome.*
