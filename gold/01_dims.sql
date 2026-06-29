 CREATE TABLE IF NOT EXISTS gold.dim_user (
    user_sk       INTEGER      PRIMARY KEY,
    user_id       INTEGER      NOT NULL,
    country       CHAR(2),
    plan_code     VARCHAR(30)  NOT NULL,
    monthly_price NUMERIC(6,2) NOT NULL,
    valid_from    TIMESTAMPTZ  NOT NULL,
    valid_to      TIMESTAMPTZ,
    is_current    BOOLEAN      NOT NULL,
    CHECK (valid_to IS NULL OR valid_to > valid_from)
);

 CREATE TABLE IF NOT EXISTS gold.dim_content (
    content_sk       INTEGER      PRIMARY KEY,
    content_id       INTEGER      NOT NULL,
    title            VARCHAR(300) NOT NULL,
    content_type     VARCHAR(20)  NOT NULL,
    artist_name      VARCHAR(200),
    duration_seconds INTEGER      NOT NULL CHECK (duration_seconds > 0),
    release_date     DATE         NOT NULL,
    is_explicit      BOOLEAN      NOT NULL
);

 CREATE TABLE IF NOT EXISTS gold.dim_device (
    device_sk    INTEGER     PRIMARY KEY,
    device_id    INTEGER     NOT NULL,
    device_type  VARCHAR(20) NOT NULL,
    os_version   VARCHAR(50)
);


 CREATE TABLE IF NOT EXISTS gold.dim_date (
    date_key   INTEGER PRIMARY KEY,           -- YYYYMMDD
    full_date  DATE    NOT NULL,
    year       INTEGER NOT NULL,
    month      INTEGER NOT NULL,
    iso_week   INTEGER NOT NULL,
    weekday    TEXT    NOT NULL
);
