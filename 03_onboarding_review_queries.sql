-- ============================================================
-- Custie Platform -- Onboarding Review Queries
-- Use case: KYC/KYB application review and decision tracking
-- ============================================================

-- ── QUERY 1 ──────────────────────────────────────────────────
-- Pull all applications currently in pending review queue
-- Used daily by fraud operations to manage the review queue
-- -------------------------------------------------------------
SELECT
    a.application_id,
    a.submitted_at,
    p.participant_type,
    p.provider_subtype,
    CONCAT(p.first_name, ' ', p.last_name)  AS applicant_name,
    p.email,
    a.stated_purpose,
    a.services_offered,
    a.years_experience,
    DATEDIFF(NOW(), a.submitted_at)         AS days_in_queue
FROM applications a
JOIN participants p ON a.participant_id = p.participant_id
WHERE a.decision = 'pending'
ORDER BY a.submitted_at ASC; -- FIFO: oldest applications reviewed first


-- ── QUERY 2 ──────────────────────────────────────────────────
-- Weekly onboarding volume and decision summary
-- Used for KPI tracker and leadership reporting
-- -------------------------------------------------------------
SELECT
    YEARWEEK(a.submitted_at, 1)             AS week,
    COUNT(*)                                AS applications_submitted,
    SUM(CASE WHEN a.decision = 'approved'   THEN 1 ELSE 0 END) AS approved,
    SUM(CASE WHEN a.decision = 'rejected'   THEN 1 ELSE 0 END) AS rejected,
    SUM(CASE WHEN a.decision = 'pending'    THEN 1 ELSE 0 END) AS pending,
    ROUND(
        SUM(CASE WHEN a.decision = 'approved' THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 1
    )                                       AS approval_rate_pct,
    ROUND(AVG(
        CASE WHEN a.decision != 'pending'
        THEN a.time_to_decision END), 1)    AS avg_ttd_days
FROM applications a
GROUP BY YEARWEEK(a.submitted_at, 1)
ORDER BY week ASC;


-- ── QUERY 3 ──────────────────────────────────────────────────
-- Provider applications missing ID verification flag
-- Surfaces providers approved without confirmed ID check
-- -------------------------------------------------------------
SELECT
    a.application_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS provider_name,
    p.email,
    p.provider_subtype,
    a.decision,
    a.decision_at,
    a.id_verified,
    a.business_docs_verified
FROM applications a
JOIN participants p ON a.participant_id = p.participant_id
WHERE p.participant_type = 'provider'
  AND a.id_verified = 0
  AND a.decision = 'approved'
ORDER BY a.decision_at ASC;


-- ── QUERY 4 ──────────────────────────────────────────────────
-- Brick and mortar providers: verify business docs were reviewed
-- KYB check specific to registered business entities
-- -------------------------------------------------------------
SELECT
    a.application_id,
    CONCAT(p.first_name, ' ', p.last_name)  AS business_name,
    p.email,
    a.decision,
    a.id_verified,
    a.business_docs_verified,
    a.reviewer_notes
FROM applications a
JOIN participants p ON a.participant_id = p.participant_id
WHERE p.participant_type = 'provider'
  AND p.provider_subtype = 'brick_and_mortar'
ORDER BY a.submitted_at ASC;


-- ── QUERY 5 ──────────────────────────────────────────────────
-- Time-to-decision distribution across all reviewed applications
-- Used to track TTD improvement after data minimization control
-- -------------------------------------------------------------
SELECT
    a.time_to_decision                      AS ttd_days,
    COUNT(*)                                AS application_count,
    p.participant_type
FROM applications a
JOIN participants p ON a.participant_id = p.participant_id
WHERE a.decision != 'pending'
GROUP BY a.time_to_decision, p.participant_type
ORDER BY a.time_to_decision ASC;


-- ── QUERY 6 ──────────────────────────────────────────────────
-- Month-over-month onboarding summary
-- Tracks the bell curve of pilot onboarding activity
-- -------------------------------------------------------------
SELECT
    DATE_FORMAT(a.submitted_at, '%Y-%m')    AS month,
    COUNT(*)                                AS total_applications,
    SUM(CASE WHEN p.participant_type = 'provider' THEN 1 ELSE 0 END) AS providers,
    SUM(CASE WHEN p.participant_type = 'consumer' THEN 1 ELSE 0 END) AS consumers,
    SUM(CASE WHEN a.decision = 'approved'   THEN 1 ELSE 0 END) AS approved,
    ROUND(AVG(a.time_to_decision), 1)       AS avg_ttd_days
FROM applications a
JOIN participants p ON a.participant_id = p.participant_id
GROUP BY DATE_FORMAT(a.submitted_at, '%Y-%m')
ORDER BY month ASC;
