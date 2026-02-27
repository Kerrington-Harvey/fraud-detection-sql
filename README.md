# Fraud Detection SQL - Custie Platform

SQL queries and database schema for fraud operations, trust and safety, and risk reporting use cases. Built on a simulated MySQL database reflecting the architecture and data structure of Custie, a B2B/B2C pet-care platform.

This project demonstrates how a fraud operations function would query platform data directly - for onboarding review, post-onboarding risk monitoring, KPI reporting, and chargeback investigation.

---

## Background

At Custie, participant data was stored in a MySQL database on AWS RDS. The fraud operations function interacted with this data through a proprietary internal admin portal. This SQL project simulates the underlying queries that would power that monitoring - the kind of data pulls that in production would be routed through engineering or surfaced via a BI layer.

---

## Database Schema

Six tables reflecting the Custie platform data model:

| Table | Description |
|---|---|
| `participants` | All onboarded users - providers and consumers |
| `applications` | Onboarding submissions, decisions, and TTD |
| `transactions` | Payments processed through Stripe |
| `complaints` | Participant abuse reports and platform flags |
| `disputes` | Chargeback and payment disputes via Stripe |
| `account_actions` | Warnings, suspensions, and removals |

---

## Query Files

### `03_onboarding_review_queries.sql`
KYC/KYB application review and decision tracking.

| Query | Use Case |
|---|---|
| Pending review queue | Daily FIFO queue management for application review |
| Weekly volume and decision summary | KPI tracker input - applications, approvals, TTD |
| Provider ID verification audit | Surfaces providers approved without confirmed ID check |
| Brick and mortar KYB check | Verifies business docs were reviewed for registered entities |
| TTD distribution | Tracks time-to-decision across all reviewed applications |
| Month-over-month summary | Onboarding activity trend across the pilot period |

---

### `04_fraud_detection_queries.sql`
Post-onboarding risk signal detection and account monitoring.

| Query | Use Case |
|---|---|
| Flagged account queue | Daily fraud ops review queue - all currently flagged accounts |
| High-risk complaint volume | Surfaces participants with multiple or high-risk complaints |
| 7-day rolling complaint monitor | Immediate escalation trigger per the escalation framework |
| Duplicate account detection | New account fraud signal - same email across multiple records |
| Suspended and removed accounts | Pattern analysis and repeat offender identification |
| Open complaints by type | Daily queue prioritization by risk level |
| Off-platform payment detection | Platform policy violation and revenue bypass signal |

---

### `05_kpi_reporting_queries.sql`
Weekly fraud operations KPI reporting and leadership summaries.

| Query | Use Case |
|---|---|
| Full KPI summary | Monthly TPR, FPR, approval rate, TTD, fraud incidents |
| TTD improvement measurement | Quantifies 33% reduction from data minimization control |
| Complaint resolution rate | Measures escalation workflow effectiveness |
| Account action summary | Leadership view of enforcement activity |
| Executive pilot snapshot | Single-row top-line summary for leadership reporting |

---

### `06_chargeback_dispute_queries.sql`
Stripe dispute management and friendly fraud detection.

| Query | Use Case |
|---|---|
| Open disputes by deadline | Prioritized view of disputes requiring Stripe response |
| Friendly fraud signal detection | Dispute ratio analysis and pattern behavior identification |
| Dispute outcomes by type | Win/loss rate by chargeback category |
| Provider dispute exposure | Identifies providers with disputed transaction history |
| New account + dispute correlation | Detects disputes filed within 30 days of account approval |

---

## Key Context

- All data is simulated and fictional — for portfolio demonstration only
- Schema reflects the actual MySQL structure used at Custie during the pilot
- Queries are written in standard MySQL syntax
- No third-party fraud tooling was used at Custie — all detection logic was manual and process-driven
- The SQL project demonstrates the data layer that would underpin the operational framework documented in [custie-fraud-framework](https://github.com/Kerrington-Harvey/custie-fraud-framework)

---

## Skills Demonstrated

`MySQL` · `Fraud Detection Logic` · `Risk Signal Querying` · `KPI Reporting` · `Chargeback Analysis` · `Trust & Safety Operations` · `Platform Risk`


