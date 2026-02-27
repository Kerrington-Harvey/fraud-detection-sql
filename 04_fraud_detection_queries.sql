-- ============================================================
-- Custie Platform -- Fraud Detection Queries
-- Use case: Post-onboarding risk signal detection and flagging
-- ============================================================

-- ── QUERY 1 ──────────────────────────────────────────────────
-- Identify all currently flagged accounts
-- Core queue for fraud operations daily review
-- -------------------------------------------------------------
SELECT
    p.participant_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS participant_name,
    p.participant_type,
    p.email,
    p.account_status,
    p.flag_reason,
    a.decision_at                           AS onboarded_date,
    COUNT(c.complaint_id)                   AS total_complaints
FROM participants p
JOIN applications a ON p.participant_id = a.participant_id
LEFT JOIN complaints c ON p.participant_id = c.reported_participant
WHERE p.flagged = 1
GROUP BY
    p.participant_id, p.first_name, p.last_name,
    p.participant_type, p.email, p.account_status,
    p.flag_reason, a.decision_at
ORDER BY total_complaints DESC;


-- ── QUERY 2 ──────────────────────────────────────────────────
-- High-risk complaint volume by participant
-- Surfaces participants with multiple complaints -- escalation trigger
-- -------------------------------------------------------------
SELECT
    p.participant_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS reported_participant,
    p.participant_type,
    p.account_status,
    COUNT(c.complaint_id)                   AS total_complaints,
    SUM(CASE WHEN c.risk_level = 'high'     THEN 1 ELSE 0 END) AS high_risk_complaints,
    SUM(CASE WHEN c.risk_level = 'medium'   THEN 1 ELSE 0 END) AS medium_risk_complaints,
    MIN(c.submitted_at)                     AS first_complaint_date,
    MAX(c.submitted_at)                     AS most_recent_complaint_date
FROM participants p
JOIN complaints c ON p.participant_id = c.reported_participant
GROUP BY
    p.participant_id, p.first_name, p.last_name,
    p.participant_type, p.account_status
HAVING COUNT(c.complaint_id) > 1
   OR SUM(CASE WHEN c.risk_level = 'high' THEN 1 ELSE 0 END) >= 1
ORDER BY high_risk_complaints DESC, total_complaints DESC;


-- ── QUERY 3 ──────────────────────────────────────────────────
-- Complaints filed within last 7 days -- rolling risk monitor
-- Immediate escalation trigger per the escalation framework
-- -------------------------------------------------------------
SELECT
    c.complaint_id,
    c.submitted_at,
    c.complaint_type,
    c.risk_level,
    CONCAT(r.first_name, ' ', r.last_name)  AS reported_by,
    CONCAT(p.first_name, ' ', p.last_name)  AS reported_participant,
    p.participant_type,
    p.account_status,
    c.status                                AS complaint_status
FROM complaints c
JOIN participants r ON c.reported_by = r.participant_id
JOIN participants p ON c.reported_participant = p.participant_id
WHERE c.submitted_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY
    FIELD(c.risk_level, 'high', 'medium', 'low'),
    c.submitted_at DESC;


-- ── QUERY 4 ──────────────────────────────────────────────────
-- Duplicate account detection -- same email across multiple records
-- New account fraud signal: previously rejected actor re-registering
-- -------------------------------------------------------------
SELECT
    p.email,
    COUNT(p.participant_id)                 AS account_count,
    GROUP_CONCAT(p.participant_id)          AS participant_ids,
    GROUP_CONCAT(p.account_status)          AS account_statuses,
    GROUP_CONCAT(
        CONCAT(p.first_name, ' ', p.last_name)
        ORDER BY p.created_at
    )                                       AS names_on_record
FROM participants p
GROUP BY p.email
HAVING COUNT(p.participant_id) > 1
ORDER BY account_count DESC;


-- ── QUERY 5 ──────────────────────────────────────────────────
-- Suspended and removed accounts with full action history
-- Used for pattern analysis and repeat offender identification
-- -------------------------------------------------------------
SELECT
    p.participant_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS participant_name,
    p.participant_type,
    p.email,
    p.account_status,
    aa.action_type,
    aa.reason,
    aa.actioned_at,
    aa.actioned_by,
    COUNT(c.complaint_id)                   AS total_complaints_on_record
FROM participants p
JOIN account_actions aa ON p.participant_id = aa.participant_id
LEFT JOIN complaints c ON p.participant_id = c.reported_participant
WHERE p.account_status IN ('suspended', 'removed')
GROUP BY
    p.participant_id, p.first_name, p.last_name,
    p.participant_type, p.email, p.account_status,
    aa.action_type, aa.reason, aa.actioned_at, aa.actioned_by
ORDER BY aa.actioned_at DESC;


-- ── QUERY 6 ──────────────────────────────────────────────────
-- Open complaints by type and risk level -- operations dashboard view
-- Used to prioritize the daily review queue
-- -------------------------------------------------------------
SELECT
    c.complaint_type,
    c.risk_level,
    COUNT(*)                                AS open_count,
    MIN(c.submitted_at)                     AS oldest_open,
    MAX(c.submitted_at)                     AS newest_open
FROM complaints c
WHERE c.status = 'open'
GROUP BY c.complaint_type, c.risk_level
ORDER BY
    FIELD(c.risk_level, 'high', 'medium', 'low'),
    open_count DESC;


-- ── QUERY 7 ──────────────────────────────────────────────────
-- Off-platform payment request detection
-- Signals potential platform policy violation and revenue bypass
-- -------------------------------------------------------------
SELECT
    c.complaint_id,
    c.submitted_at,
    CONCAT(reporter.first_name, ' ', reporter.last_name) AS reported_by,
    reporter.participant_type                AS reporter_type,
    CONCAT(reported.first_name, ' ', reported.last_name) AS reported_participant,
    reported.participant_type                AS offending_party_type,
    c.risk_level,
    c.description,
    c.status
FROM complaints c
JOIN participants reporter ON c.reported_by = reporter.participant_id
JOIN participants reported ON c.reported_participant = reported.participant_id
WHERE c.complaint_type = 'off_platform_payment'
ORDER BY c.submitted_at DESC;
