import Foundation

/// Seed data ported from the design system's UI kit. No real database behind
/// any of it — this exists so every designed state is reachable in the UI.
enum MockData {
    static let servers: [DatabaseServer] = [
        DatabaseServer(
            id: "prod", name: "prod-readonly", engine: "PostgreSQL",
            host: "db.internal:5432", user: "readonly", color: .blue,
            databases: [
                ServerDatabase(name: "app_production"),
                ServerDatabase(name: "app_billing", user: "billing_ro"),
            ]
        ),
        DatabaseServer(
            id: "stg", name: "staging", engine: "PostgreSQL",
            host: "stg.internal:5432", user: "deploy", color: .orange,
            databases: [ServerDatabase(name: "app_staging")]
        ),
        DatabaseServer(
            id: "an", name: "analytics", engine: "ClickHouse",
            host: "ch.internal:9000", user: "analyst", color: .purple,
            databases: [
                ServerDatabase(name: "events"),
                ServerDatabase(name: "warehouse", user: "etl_ro"),
            ]
        ),
        DatabaseServer(
            id: "metrics", name: "metrics", engine: "MySQL",
            host: "mysql.internal:3306", user: "grafana", color: .green,
            databases: [ServerDatabase(name: "metrics")]
        ),
    ]

    static let queries: [SavedQuery] = [
        SavedQuery(
            id: "signups", name: "Daily signups",
            serverName: "prod-readonly", database: "app_production",
            sql: """
            -- new pro signups today
            SELECT count(*) AS signups
            FROM users
            WHERE created_at >= current_date
              AND plan = 'pro';
            """,
            lastRun: "2m ago", duration: "42 ms", rowsLabel: "1 row"
        ),
        SavedQuery(
            id: "mrr", name: "MRR snapshot",
            serverName: "prod-readonly", database: "app_billing",
            sql: """
            SELECT round(sum(amount)/100.0, 0) AS mrr_usd
            FROM subscriptions
            WHERE status = 'active';
            """,
            lastRun: "1h ago", duration: "61 ms", rowsLabel: "1 row"
        ),
        SavedQuery(
            id: "top", name: "Top accounts by MRR",
            serverName: "analytics", database: "warehouse",
            sql: """
            SELECT name, mrr_usd
            FROM accounts
            ORDER BY mrr_usd DESC
            LIMIT 25;
            """,
            lastRun: "yesterday", duration: "203 ms", rowsLabel: "25 rows"
        ),
        SavedQuery(
            id: "subs", name: "Active subscribers (full export)",
            serverName: "prod-readonly", database: "app_production",
            sql: """
            SELECT u.id,
                   u.email,
                   u.full_name,
                   u.plan,
                   u.seats,
                   u.mrr_usd,
                   u.country,
                   u.signup_date,
                   u.last_seen,
                   u.trial_ends,
                   u.verified,
                   u.churn_risk
            FROM users u
            JOIN subscriptions s ON s.user_id = u.id
            WHERE s.status = 'active'
            ORDER BY u.mrr_usd DESC
            LIMIT 50;
            """,
            lastRun: "30m ago", duration: "212 ms", rowsLabel: "50 rows"
        ),
        SavedQuery(
            id: "churn", name: "Churn cohort (90d)",
            serverName: "analytics", database: "events",
            sql: """
            -- monthly churn by signup cohort
            WITH cohorts AS (
              SELECT id,
                     date_trunc('month', created_at) AS cohort
              FROM users
              WHERE created_at >= now() - interval '90 days'
            )
            SELECT c.cohort,
                   count(*)                                  AS total,
                   count(*) FILTER (WHERE s.status = 'canceled') AS churned,
                   round(100.0 * count(*) FILTER (WHERE s.status = 'canceled')
                         / nullif(count(*), 0), 1)            AS churn_pct
            FROM cohorts c
            LEFT JOIN subscriptions s ON s.user_id = c.id
            GROUP BY c.cohort
            ORDER BY c.cohort DESC;
            """,
            lastRun: "3h ago", duration: "318 ms", rowsLabel: "3 rows"
        ),
        SavedQuery(
            id: "err", name: "Error rate (5m)",
            serverName: "staging", database: "app_staging",
            sql: """
            SELECT count(*) FILTER (WHERE level = 'error') * 100.0
                 / nullif(count(*), 0) AS pct
            FROM logs
            WHERE ts >= now() - interval '5 minutes';
            """,
            lastRun: "just now", duration: "118 ms", rowsLabel: "1 row"
        ),
    ]
}
