-- ============================================================
-- Custie Platform -- Chargeback & Dispute Queries
-- Use case: Stripe dispute management and friendly fraud detection
-- ============================================================

-- ── QUERY 1 ──────────────────────────────────────────────────
-- All open disputes requiring response within deadline
-- Prioritized by response deadline -- critical for Stripe SLA
-- -------------------------------------------------------------
SELECT
    d.dispute_id,
    d.dispute_type,
    d.amount,
    d.opened_at,
    d.response_deadline,
    DATEDIFF(d.response_deadline, NOW())    AS days_until_deadline,
    CONCAT(c.first_name, ' ', c.last_name)  AS consumer_name,
    CONCAT(pr.first_name, ' ', pr.last_name) AS provider_name,
    t.service_type,
    d.stripe_dispute_id
FROM disputes d
JOIN participants c  ON d.consumer_id  = c.participant_id
JOIN participants pr ON d.provider_id  = pr.participant_id
JOIN transactions t  ON d.transaction_id = t.transaction_id
WHERE d.status = 'open'
ORDER BY d.response_deadline ASC;


-- ── QUERY 2 ──────────────────────────────────────────────────
-- Friendly fraud signal detection
-- Flags consumers with dispute history and continued platform activity
-- -------------------------------------------------------------
SELECT
    c.participant_id,
    CONCAT(c.first_name, ' ', c.last_name)  AS consumer_name,
    c.email,
    c.account_status,
    COUNT(d.dispute_id)                     AS total_disputes,
    SUM(d.amount)                           AS total_disputed_amount,
    SUM(CASE WHEN d.dispute_type = 'friendly_fraud' THEN 1 ELSE 0 END) AS friendly_fraud_count,
    COUNT(t.transaction_id)                 AS total_transactions,
    -- Dispute ratio: high ratio signals potential pattern behavior
    ROUND(
        COUNT(d.dispute_id)
        / NULLIF(COUNT(t.transaction_id), 0) * 100, 1
    )                                       AS dispute_ratio_pct,
    MIN(d.opened_at)                        AS first_dispute_date,
    MAX(d.opened_at)                        AS most_recent_dispute_date
FROM participants c
JOIN disputes d      ON c.participant_id = d.consumer_id
JOIN transactions t  ON c.participant_id = t.consumer_id
WHERE c.participant_type = 'consumer'
GROUP BY c.participant_id, c.first_name, c.last_name, c.email, c.account_status
HAVING COUNT(d.dispute_id) >= 1
ORDER BY friendly_fraud_count DESC, total_disputes DESC;


-- ── QUERY 3 ──────────────────────────────────────────────────
-- Dispute outcomes by type -- win/loss rate analysis
-- Used to evaluate rebuttal effectiveness by dispute category
-- -------------------------------------------------------------
SELECT
    d.dispute_type,
    COUNT(*)                                AS total_disputes,
    SUM(CASE WHEN d.status = 'won'          THEN 1 ELSE 0 END) AS won,
    SUM(CASE WHEN d.status = 'lost'         THEN 1 ELSE 0 END) AS lost,
    SUM(CASE WHEN d.status = 'withdrawn'    THEN 1 ELSE 0 END) AS withdrawn,
    SUM(CASE WHEN d.status = 'open'         THEN 1 ELSE 0 END) AS open,
    ROUND(
        SUM(CASE WHEN d.status = 'won' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN d.status IN ('won','lost') THEN 1 ELSE 0 END), 0)
        * 100, 1
    )                                       AS win_rate_pct,
    SUM(d.amount)                           AS total_amount_disputed,
    SUM(CASE WHEN d.status = 'won'
        THEN d.amount ELSE 0 END)           AS amount_recovered
FROM disputes d
GROUP BY d.dispute_type
ORDER BY total_disputes DESC;


-- ── QUERY 4 ──────────────────────────────────────────────────
-- Provider dispute exposure -- providers with disputed transactions
-- Identifies providers who may be at risk or involved in fraud
-- -------------------------------------------------------------
SELECT
    pr.participant_id,
    CONCAT(pr.first_name, ' ', pr.last_name) AS provider_name,
    pr.provider_subtype,
    pr.account_status,
    COUNT(d.dispute_id)                     AS disputes_against_provider,
    SUM(d.amount)                           AS total_disputed_amount,
    SUM(CASE WHEN d.dispute_type = 'provider_fraud' THEN 1 ELSE 0 END) AS provider_fraud_flags,
    COUNT(t.transaction_id)                 AS total_transactions
FROM participants pr
JOIN disputes d     ON pr.participant_id = d.provider_id
JOIN transactions t ON pr.participant_id = t.provider_id
WHERE pr.participant_type = 'provider'
GROUP BY
    pr.participant_id, pr.first_name, pr.last_name,
    pr.provider_subtype, pr.account_status
ORDER BY disputes_against_provider DESC;


-- ── QUERY 5 ──────────────────────────────────────────────────
-- New account + dispute correlation
-- Detects consumers who disputed shortly after account creation
-- High-risk new account fraud signal
-- -------------------------------------------------------------
SELECT
    c.participant_id,
    CONCAT(c.first_name, ' ', c.last_name)  AS consumer_name,
    c.email,
    a.decision_at                           AS account_approved_date,
    d.opened_at                             AS dispute_opened_date,
    DATEDIFF(d.opened_at, a.decision_at)    AS days_since_approval,
    d.dispute_type,
    d.amount,
    d.status                                AS dispute_status
FROM participants c
JOIN applications a ON c.participant_id = a.participant_id
JOIN disputes d     ON c.participant_id = d.consumer_id
WHERE c.participant_type = 'consumer'
  AND DATEDIFF(d.opened_at, a.decision_at) <= 30 -- dispute within 30 days of approval
ORDER BY days_since_approval ASC;
