-- ============================================================
-- Custie Platform -- KPI Reporting Queries
-- Use case: Weekly fraud operations KPI reporting and leadership summaries
-- ============================================================

-- ── QUERY 1 ──────────────────────────────────────────────────
-- Full KPI summary across the active pilot period
-- Mirrors the weekly Excel KPI tracker in SQL form
-- -------------------------------------------------------------
SELECT
    DATE_FORMAT(a.submitted_at, '%Y-%m')    AS month,
    COUNT(*)                                AS applications_submitted,
    SUM(CASE WHEN a.decision = 'approved'   THEN 1 ELSE 0 END) AS approved,
    SUM(CASE WHEN a.decision = 'rejected'   THEN 1 ELSE 0 END) AS rejected,
    ROUND(
        SUM(CASE WHEN a.decision = 'approved' THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 1
    )                                       AS approval_rate_pct,
    ROUND(
        SUM(CASE WHEN a.decision = 'rejected' THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 1
    )                                       AS decline_rate_pct,
    -- TPR: approved participants with zero fraud incidents
    ROUND(
        SUM(CASE WHEN a.decision = 'approved'
            AND p.flagged = 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN a.decision = 'approved' THEN 1 ELSE 0 END), 0)
        * 100, 1
    )                                       AS tpr_pct,
    ROUND(AVG(
        CASE WHEN a.decision != 'pending'
        THEN a.time_to_decision END), 1)    AS avg_ttd_days,
    -- Fraud incidents: flagged accounts with confirmed action taken
    SUM(CASE WHEN p.flagged = 1             THEN 1 ELSE 0 END) AS fraud_incidents
FROM applications a
JOIN participants p ON a.participant_id = p.participant_id
WHERE a.submitted_at BETWEEN '2025-07-01' AND '2025-11-30'
GROUP BY DATE_FORMAT(a.submitted_at, '%Y-%m')
ORDER BY month ASC;


-- ── QUERY 2 ──────────────────────────────────────────────────
-- TTD improvement measurement: before vs after data minimization
-- Quantifies the impact of the data minimization control
-- -------------------------------------------------------------
SELECT
    CASE
        WHEN a.submitted_at < '2025-08-01' THEN 'Pre-Optimization (Jul 2025)'
        ELSE 'Post-Optimization (Aug 2025 onward)'
    END                                     AS period,
    COUNT(*)                                AS applications_reviewed,
    ROUND(AVG(a.time_to_decision), 1)       AS avg_ttd_days,
    MIN(a.time_to_decision)                 AS min_ttd_days,
    MAX(a.time_to_decision)                 AS max_ttd_days
FROM applications a
WHERE a.decision != 'pending'
GROUP BY
    CASE
        WHEN a.submitted_at < '2025-08-01' THEN 'Pre-Optimization (Jul 2025)'
        ELSE 'Post-Optimization (Aug 2025 onward)'
    END
ORDER BY avg_ttd_days DESC;


-- ── QUERY 3 ──────────────────────────────────────────────────
-- Complaint resolution rate and average time to resolve
-- Measures effectiveness of the review and escalation workflow
-- -------------------------------------------------------------
SELECT
    c.risk_level,
    COUNT(*)                                AS total_complaints,
    SUM(CASE WHEN c.status = 'resolved'     THEN 1 ELSE 0 END) AS resolved,
    SUM(CASE WHEN c.status = 'unfounded'    THEN 1 ELSE 0 END) AS unfounded,
    SUM(CASE WHEN c.status = 'open'         THEN 1 ELSE 0 END) AS still_open,
    ROUND(
        SUM(CASE WHEN c.status IN ('resolved','unfounded') THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 1
    )                                       AS resolution_rate_pct,
    ROUND(AVG(
        CASE WHEN c.resolved_at IS NOT NULL
        THEN DATEDIFF(c.resolved_at, c.submitted_at) END
    ), 1)                                   AS avg_days_to_resolve
FROM complaints c
GROUP BY c.risk_level
ORDER BY FIELD(c.risk_level, 'high', 'medium', 'low');


-- ── QUERY 4 ──────────────────────────────────────────────────
-- Account action summary by action type
-- Leadership view of enforcement activity across the platform
-- -------------------------------------------------------------
SELECT
    aa.action_type,
    COUNT(*)                                AS total_actions,
    COUNT(DISTINCT aa.participant_id)       AS unique_participants,
    MIN(aa.actioned_at)                     AS first_action_date,
    MAX(aa.actioned_at)                     AS most_recent_action_date
FROM account_actions aa
GROUP BY aa.action_type
ORDER BY total_actions DESC;


-- ── QUERY 5 ──────────────────────────────────────────────────
-- Full pilot period summary -- single-row executive snapshot
-- Top-line numbers for leadership reporting
-- -------------------------------------------------------------
SELECT
    COUNT(DISTINCT p.participant_id)        AS total_participants,
    SUM(CASE WHEN p.participant_type = 'provider' THEN 1 ELSE 0 END) AS providers,
    SUM(CASE WHEN p.participant_type = 'consumer' THEN 1 ELSE 0 END) AS consumers,
    SUM(CASE WHEN a.decision = 'approved'   THEN 1 ELSE 0 END) AS total_approved,
    SUM(CASE WHEN a.decision = 'rejected'   THEN 1 ELSE 0 END) AS total_rejected,
    ROUND(AVG(a.time_to_decision), 2)       AS overall_avg_ttd,
    SUM(CASE WHEN p.flagged = 1             THEN 1 ELSE 0 END) AS fraud_incidents,
    ROUND(
        SUM(CASE WHEN a.decision = 'approved'
            AND p.flagged = 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN a.decision = 'approved' THEN 1 ELSE 0 END), 0)
        * 100, 1
    )                                       AS tpr_pct,
    0.0                                     AS fpr_pct
FROM participants p
JOIN applications a ON p.participant_id = a.participant_id;
