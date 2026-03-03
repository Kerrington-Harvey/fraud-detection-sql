-- ============================================================
-- Custie Platform -- Detection Query Variations & Practice
-- Built from: 04_fraud_detection_queries.sql
-- Purpose: Hands-on modifications after running base queries in
--          MySQL Workbench -- adjusting filters, date ranges,
--          adding conditions, and extending detection logic.
-- ============================================================


-- ── VARIATION 1a (base: Fraud Query 1) ───────────────────────
-- Original: All currently flagged accounts
-- Modified: Narrowed to providers only, added days-since-onboarding
-- Rationale: Providers represent higher trust surface area --
--   wanted to isolate them and see how long flags have been sitting open
-- -------------------------------------------------------------
SELECT
    p.participant_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS participant_name,
    p.provider_subtype,
    p.email,
    p.account_status,
    p.flag_reason,
    a.decision_at                           AS onboarded_date,
    DATEDIFF(NOW(), a.decision_at)          AS days_since_onboarding,
    COUNT(c.complaint_id)                   AS total_complaints,
    MAX(c.submitted_at)                     AS most_recent_complaint
FROM participants p
JOIN applications a ON p.participant_id = a.participant_id
LEFT JOIN complaints c ON p.participant_id = c.reported_participant
WHERE p.flagged = 1
  AND p.participant_type = 'provider'
GROUP BY
    p.participant_id, p.first_name, p.last_name,
    p.provider_subtype, p.email, p.account_status,
    p.flag_reason, a.decision_at
ORDER BY total_complaints DESC, days_since_onboarding DESC;


-- ── VARIATION 1b ─────────────────────────────────────────────
-- Extended: Flagged accounts where NO account action has been taken
-- Gap detection -- flagged but no enforcement response on record
-- -------------------------------------------------------------
SELECT
    p.participant_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS participant_name,
    p.participant_type,
    p.account_status,
    p.flag_reason,
    COUNT(c.complaint_id)                   AS complaints_on_file
FROM participants p
LEFT JOIN complaints c     ON p.participant_id = c.reported_participant
LEFT JOIN account_actions aa ON p.participant_id = aa.participant_id
WHERE p.flagged = 1
  AND aa.action_id IS NULL
GROUP BY
    p.participant_id, p.first_name, p.last_name,
    p.participant_type, p.account_status, p.flag_reason
ORDER BY complaints_on_file DESC;


-- ── VARIATION 2a (base: Fraud Query 2) ───────────────────────
-- Original: Escalation trigger -- HAVING > 1 complaint OR 1 high-risk
-- Modified: Tightened to 2+ high-risk complaints only
-- Rationale: Running the base query showed single medium-risk complaints
--   flooding the queue -- raised threshold to surface real escalations
-- -------------------------------------------------------------
SELECT
    p.participant_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS reported_participant,
    p.participant_type,
    p.account_status,
    COUNT(c.complaint_id)                   AS total_complaints,
    SUM(CASE WHEN c.risk_level = 'high'   THEN 1 ELSE 0 END) AS high_risk_count,
    SUM(CASE WHEN c.risk_level = 'medium' THEN 1 ELSE 0 END) AS medium_risk_count,
    MIN(c.submitted_at)                     AS first_complaint_date,
    MAX(c.submitted_at)                     AS latest_complaint_date,
    DATEDIFF(MAX(c.submitted_at), MIN(c.submitted_at)) AS complaint_span_days
FROM participants p
JOIN complaints c ON p.participant_id = c.reported_participant
GROUP BY
    p.participant_id, p.first_name, p.last_name,
    p.participant_type, p.account_status
HAVING SUM(CASE WHEN c.risk_level = 'high' THEN 1 ELSE 0 END) >= 2
ORDER BY high_risk_count DESC;


-- ── VARIATION 2b ─────────────────────────────────────────────
-- Extended: Escalation logic filtered to active accounts only
-- More actionable -- suspended/removed accounts are already handled
-- -------------------------------------------------------------
SELECT
    p.participant_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS reported_participant,
    p.participant_type,
    p.account_status,
    COUNT(c.complaint_id)                   AS total_complaints,
    SUM(CASE WHEN c.risk_level = 'high'   THEN 1 ELSE 0 END) AS high_risk_count
FROM participants p
JOIN complaints c ON p.participant_id = c.reported_participant
WHERE p.account_status = 'active'
GROUP BY
    p.participant_id, p.first_name, p.last_name,
    p.participant_type, p.account_status
HAVING COUNT(c.complaint_id) > 1
   OR SUM(CASE WHEN c.risk_level = 'high' THEN 1 ELSE 0 END) >= 1
ORDER BY high_risk_count DESC, total_complaints DESC;


-- ── VARIATION 3a (base: Fraud Query 3) ───────────────────────
-- Original: Rolling 7-day complaint monitor
-- Modified: Extended to 30-day window
-- Rationale: 7-day window was too narrow for catching emerging patterns --
--   30 days surfaces behavior trends without losing the recency signal
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
WHERE c.submitted_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY
    FIELD(c.risk_level, 'high', 'medium', 'low'),
    c.submitted_at DESC;


-- ── VARIATION 3b ─────────────────────────────────────────────
-- Net new: High-risk complaints still open after 7+ days
-- Aging open complaints are an SLA risk -- surfaces stale queue items
-- -------------------------------------------------------------
SELECT
    c.complaint_id,
    c.complaint_type,
    c.risk_level,
    c.submitted_at,
    DATEDIFF(NOW(), c.submitted_at)         AS days_open,
    CONCAT(p.first_name, ' ', p.last_name)  AS reported_participant,
    p.account_status
FROM complaints c
JOIN participants p ON c.reported_participant = p.participant_id
WHERE c.risk_level = 'high'
  AND c.status = 'open'
  AND DATEDIFF(NOW(), c.submitted_at) > 7
ORDER BY days_open DESC;


-- ── VARIATION 4a (base: Fraud Query 4) ───────────────────────
-- Original: Duplicate email detection
-- Modified: Added prior rejection flag via applications join
-- Rationale: The real signal isn't just duplicate records --
--   it's a previously rejected actor re-registering under the same email
-- -------------------------------------------------------------
SELECT
    p.email,
    COUNT(p.participant_id)                 AS account_count,
    GROUP_CONCAT(p.participant_id)          AS participant_ids,
    GROUP_CONCAT(p.account_status
        ORDER BY p.created_at)              AS account_statuses,
    GROUP_CONCAT(
        CONCAT(p.first_name, ' ', p.last_name)
        ORDER BY p.created_at
    )                                       AS names_on_record,
    MAX(CASE WHEN a.decision = 'rejected'   THEN 1 ELSE 0 END) AS has_prior_rejection
FROM participants p
LEFT JOIN applications a ON p.participant_id = a.participant_id
GROUP BY p.email
HAVING COUNT(p.participant_id) > 1
ORDER BY has_prior_rejection DESC, account_count DESC;


-- ── VARIATION 5a (base: Fraud Query 5) ───────────────────────
-- Original: Suspended/removed accounts with full action history
-- Modified: Added time between onboarding approval and first enforcement action
-- Rationale: Days-approval-to-action measures how quickly the workflow
--   caught bad actors -- a direct indicator of detection effectiveness
-- -------------------------------------------------------------
SELECT
    p.participant_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS participant_name,
    p.participant_type,
    p.email,
    p.account_status,
    a.decision_at                           AS onboarded_date,
    aa.action_type,
    aa.reason,
    aa.actioned_at,
    DATEDIFF(aa.actioned_at, a.decision_at) AS days_from_approval_to_action,
    COUNT(c.complaint_id)                   AS total_complaints
FROM participants p
JOIN applications a     ON p.participant_id = a.participant_id
JOIN account_actions aa ON p.participant_id = aa.participant_id
LEFT JOIN complaints c  ON p.participant_id = c.reported_participant
WHERE p.account_status IN ('suspended', 'removed')
GROUP BY
    p.participant_id, p.first_name, p.last_name,
    p.participant_type, p.email, p.account_status,
    a.decision_at, aa.action_type, aa.reason, aa.actioned_at
ORDER BY days_from_approval_to_action ASC;


-- ── VARIATION 6a (base: Fraud Query 7) ───────────────────────
-- Original: Off-platform payment complaints
-- Modified: Added already_flagged sort to separate new vs known signals
-- Rationale: A complaint against an already-actioned participant is
--   lower priority than a net-new bad actor signal -- queue accordingly
-- -------------------------------------------------------------
SELECT
    c.complaint_id,
    c.submitted_at,
    CONCAT(reporter.first_name, ' ', reporter.last_name) AS reported_by,
    reporter.participant_type                AS reporter_type,
    CONCAT(reported.first_name, ' ', reported.last_name) AS reported_participant,
    reported.participant_type                AS offending_party_type,
    reported.account_status,
    reported.flagged                         AS already_flagged,
    c.risk_level,
    c.status
FROM complaints c
JOIN participants reporter ON c.reported_by = reporter.participant_id
JOIN participants reported ON c.reported_participant = reported.participant_id
WHERE c.complaint_type = 'off_platform_payment'
ORDER BY
    reported.flagged ASC,                   -- unflagged offenders surface first
    c.submitted_at DESC;


-- ── NET NEW QUERY ─────────────────────────────────────────────
-- Complaint-to-action pipeline: complaints that resulted in enforcement
-- Measures how effectively complaint intake drives action decisions
-- Useful for auditing the full complaint -> review -> action workflow
-- -------------------------------------------------------------
SELECT
    c.complaint_id,
    c.complaint_type,
    c.risk_level,
    c.submitted_at                          AS complaint_date,
    c.status                                AS complaint_status,
    aa.action_type,
    aa.actioned_at,
    DATEDIFF(aa.actioned_at, c.submitted_at) AS days_complaint_to_action,
    CONCAT(p.first_name, ' ', p.last_name)  AS actioned_participant
FROM complaints c
JOIN participants p     ON c.reported_participant = p.participant_id
JOIN account_actions aa ON p.participant_id = aa.participant_id
                       AND aa.actioned_at >= c.submitted_at
ORDER BY
    FIELD(c.risk_level, 'high', 'medium', 'low'),
    days_complaint_to_action ASC;
