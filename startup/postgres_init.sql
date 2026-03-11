-- PostgreSQL init script: creates multi-tenant configuration table

CREATE TABLE IF NOT EXISTS configuration (
    config_id    SERIAL PRIMARY KEY,
    tenant_id    INTEGER     NOT NULL,
    config_key   VARCHAR(64) NOT NULL,
    config_value VARCHAR(256) NOT NULL,
    description  VARCHAR(256)
);

INSERT INTO configuration (tenant_id, config_key, config_value, description) VALUES
    -- A Inc (tenant 1)
    (1, 'max_api_requests_per_day', '10000',   'Daily API request limit'),
    (1, 'session_timeout_minutes',  '60',      'User session timeout'),
    (1, 'allowed_ip_range',         '10.0.1.0/24', 'Allowed IP range'),
    (1, 'enable_audit_log',         'true',    'Audit logging enabled'),

    -- B Inc (tenant 2)
    (2, 'max_api_requests_per_day', '50000',   'Daily API request limit'),
    (2, 'session_timeout_minutes',  '30',      'User session timeout'),
    (2, 'allowed_ip_range',         '10.1.1.0/24', 'Allowed IP range'),
    (2, 'enable_audit_log',         'true',    'Audit logging enabled'),

    -- C Inc (tenant 3)
    (3, 'max_api_requests_per_day', '5000',    'Daily API request limit'),
    (3, 'session_timeout_minutes',  '120',     'User session timeout'),
    (3, 'allowed_ip_range',         '10.2.1.0/24', 'Allowed IP range'),
    (3, 'enable_audit_log',         'false',   'Audit logging enabled');
