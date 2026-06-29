-- SCD2 dim_user_hist: one row per plan period from subscriptions, valid_to via LEAD().
CREATE TABLE IF NOT EXISTS silver.dim_user_hist (
      user_id       INTEGER      NOT NULL,
      country       CHAR(2),
      plan_code     VARCHAR(30)  NOT NULL,
      monthly_price NUMERIC(6,2) NOT NULL,
      valid_from    TIMESTAMPTZ  NOT NULL,
      valid_to      TIMESTAMPTZ,
      is_current    BOOLEAN      NOT NULL,
      PRIMARY KEY (user_id, valid_from)  -- One row per user per period start
  );

TRUNCATE silver.dim_user_hist;

INSERT INTO silver.dim_user_hist
      (user_id, country, plan_code, monthly_price, valid_from, valid_to, is_current)
WITH periods AS (
    SELECT
          s.user_id,
          u.country,
          p.plan_code,
          p.monthly_price,
          s.started_at                              AS valid_from,
          LEAD(s.started_at) OVER (
              PARTITION BY s.user_id ORDER BY s.started_at
          )                                          AS valid_to
    FROM public.subscriptions s
    JOIN public.plans p ON p.plan_id = s.plan_id
    JOIN public.users u ON u.user_id = s.user_id
)
SELECT
    user_id,
    country,
    plan_code,
    monthly_price,
    valid_from,
    valid_to,
    valid_to is NULL AS is_current   -- Open period = current
FROM periods;