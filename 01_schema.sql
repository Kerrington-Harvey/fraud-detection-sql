-- ============================================================
-- Custie Platform -- Fraud Operations Database Schema
-- Simulated MySQL database reflecting B2B/B2C platform structure
-- ============================================================

-- Participants table: all onboarded users (providers + consumers)
CREATE TABLE participants (
    participant_id      VARCHAR(20)     PRIMARY KEY,
    participant_type    ENUM('provider','consumer') NOT NULL,
    provider_subtype    ENUM('sole_proprietor','brick_and_mortar') NULL,
    first_name          VARCHAR(50)     NOT NULL,
    last_name           VARCHAR(50)     NOT NULL,
    email               VARCHAR(100)    NOT NULL,
    phone               VARCHAR(20),
    address             VARCHAR(200),
    city                VARCHAR(50),
    state               VARCHAR(2),
    zip                 VARCHAR(10),
    created_at          DATETIME        NOT NULL,
    account_status      ENUM('pending_review','active','suspended','rejected','removed') NOT NULL DEFAULT 'pending_review',
    flagged             TINYINT(1)      NOT NULL DEFAULT 0,
    flag_reason         VARCHAR(200)    NULL
);

-- Applications table: onboarding submissions and decisions
CREATE TABLE applications (
    application_id      VARCHAR(20)     PRIMARY KEY,
    participant_id      VARCHAR(20)     NOT NULL,
    submitted_at        DATETIME        NOT NULL,
    decision_at         DATETIME        NULL,
    decision            ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    rejection_reason    VARCHAR(200)    NULL,
    time_to_decision    INT             NULL COMMENT 'Days from submission to decision',
    id_verified         TINYINT(1)      NOT NULL DEFAULT 0,
    business_docs_verified TINYINT(1)  NOT NULL DEFAULT 0,
    stated_purpose      TEXT            NULL,
    services_offered    VARCHAR(200)    NULL,
    years_experience    INT             NULL,
    reviewer_notes      TEXT            NULL,
    FOREIGN KEY (participant_id) REFERENCES participants(participant_id)
);

-- Transactions table: payments processed through Stripe
CREATE TABLE transactions (
    transaction_id      VARCHAR(20)     PRIMARY KEY,
    consumer_id         VARCHAR(20)     NOT NULL,
    provider_id         VARCHAR(20)     NOT NULL,
    amount              DECIMAL(10,2)   NOT NULL,
    currency            VARCHAR(3)      NOT NULL DEFAULT 'USD',
    stripe_charge_id    VARCHAR(50)     NULL,
    transaction_status  ENUM('completed','refunded','disputed','failed') NOT NULL,
    created_at          DATETIME        NOT NULL,
    service_type        VARCHAR(100)    NULL,
    FOREIGN KEY (consumer_id) REFERENCES participants(participant_id),
    FOREIGN KEY (provider_id) REFERENCES participants(participant_id)
);

-- Complaints table: participant reports and abuse flags
CREATE TABLE complaints (
    complaint_id        VARCHAR(20)     PRIMARY KEY,
    reported_by         VARCHAR(20)     NOT NULL,
    reported_participant VARCHAR(20)    NOT NULL,
    complaint_type      ENUM('abuse','harassment','misrepresentation','off_platform_payment','safety_concern','fraud_suspected','other') NOT NULL,
    risk_level          ENUM('high','medium','low') NOT NULL,
    description         TEXT            NULL,
    submitted_at        DATETIME        NOT NULL,
    status              ENUM('open','under_review','resolved','unfounded') NOT NULL DEFAULT 'open',
    resolved_at         DATETIME        NULL,
    resolution          VARCHAR(200)    NULL,
    FOREIGN KEY (reported_by) REFERENCES participants(participant_id),
    FOREIGN KEY (reported_participant) REFERENCES participants(participant_id)
);

-- Disputes table: chargeback and payment disputes via Stripe
CREATE TABLE disputes (
    dispute_id          VARCHAR(20)     PRIMARY KEY,
    transaction_id      VARCHAR(20)     NOT NULL,
    consumer_id         VARCHAR(20)     NOT NULL,
    provider_id         VARCHAR(20)     NOT NULL,
    dispute_type        ENUM('legitimate','friendly_fraud','true_fraud','provider_fraud','duplicate_charge') NOT NULL,
    amount              DECIMAL(10,2)   NOT NULL,
    stripe_dispute_id   VARCHAR(50)     NULL,
    opened_at           DATETIME        NOT NULL,
    response_deadline   DATETIME        NULL,
    status              ENUM('open','won','lost','withdrawn') NOT NULL DEFAULT 'open',
    resolved_at         DATETIME        NULL,
    resolution_notes    TEXT            NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    FOREIGN KEY (consumer_id) REFERENCES participants(participant_id),
    FOREIGN KEY (provider_id) REFERENCES participants(participant_id)
);

-- Account actions table: warnings, suspensions, removals
CREATE TABLE account_actions (
    action_id           VARCHAR(20)     PRIMARY KEY,
    participant_id      VARCHAR(20)     NOT NULL,
    action_type         ENUM('warning','temporary_suspension','permanent_removal','reinstated') NOT NULL,
    reason              TEXT            NOT NULL,
    actioned_at         DATETIME        NOT NULL,
    actioned_by         VARCHAR(50)     NOT NULL DEFAULT 'Fraud Operations Manager',
    notes               TEXT            NULL,
    FOREIGN KEY (participant_id) REFERENCES participants(participant_id)
);
