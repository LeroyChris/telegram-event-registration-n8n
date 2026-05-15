-- Stores the two faculties: FIK and FEB
CREATE TABLE faculties (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(150) NOT NULL,          -- Full name in Bahasa
    code        VARCHAR(10)  NOT NULL UNIQUE,   -- Short code: FIK, FEB
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  faculties       IS 'Master list of college faculties';
COMMENT ON COLUMN faculties.code  IS 'Short identifier used in booking codes, e.g. FIK';

-- One row per workshop/event
drop table if exists events;
CREATE TABLE events (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    faculty_id    UUID         NOT NULL REFERENCES faculties(id) ON DELETE RESTRICT,
    title         VARCHAR(255) NOT NULL,
    description   TEXT,
    event_date    TIMESTAMPTZ  NOT NULL,
    location      VARCHAR(255),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  events            IS 'Workshop/event listings per faculty';
COMMENT ON COLUMN events.is_active  IS 'Set FALSE to close registrations without deleting data';

-- Each event has 2 categories: with certificate and without certificate
CREATE TABLE ticket_categories (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id         UUID         NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name             VARCHAR(100) NOT NULL,   -- 'Dengan Sertifikat' / 'Tanpa Sertifikat'
    slug             VARCHAR(50)  NOT NULL,   -- 'with_cert' / 'without_cert'
    price            NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_seats      INT          NOT NULL CHECK (total_seats > 0),
    available_seats  INT          NOT NULL,

    CONSTRAINT available_seats_non_negative CHECK (available_seats >= 0),
    CONSTRAINT available_lte_total          CHECK (available_seats <= total_seats),
    CONSTRAINT unique_slug_per_event        UNIQUE (event_id, slug)
);

COMMENT ON TABLE  ticket_categories                  IS 'Seat tiers per event';
COMMENT ON COLUMN ticket_categories.slug             IS 'Machine-readable: with_cert or without_cert';
COMMENT ON COLUMN ticket_categories.available_seats  IS 'Decremented atomically on each successful booking';
COMMENT ON COLUMN ticket_categories.price            IS 'Price in IDR (Rupiah). 0 = free';

-- One row per unique registrant (identified by email)
CREATE TABLE students (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nim         VARCHAR(50),                   -- Nomor Induk Mahasiswa
    full_name   VARCHAR(255) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE,
    faculty_id  UUID         REFERENCES faculties(id) ON DELETE SET NULL,
    phone       VARCHAR(25),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  students           IS 'Student/registrant master data';
COMMENT ON COLUMN students.nim       IS 'Student ID number (NIM). Optional for external guests.';
COMMENT ON COLUMN students.email     IS 'Natural unique key — used to prevent duplicate accounts';

-- One row per seat reservation
CREATE TABLE bookings (
    id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id           UUID         NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
    ticket_category_id   UUID         NOT NULL REFERENCES ticket_categories(id) ON DELETE RESTRICT,
    booking_code         VARCHAR(30)  NOT NULL UNIQUE,
    status               VARCHAR(20)  NOT NULL DEFAULT 'confirmed'
                             CHECK (status IN ('confirmed','cancelled')),
    booked_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    cancelled_at         TIMESTAMPTZ,
    notes                TEXT,

    -- Prevent a student from booking the same category twice
    CONSTRAINT one_booking_per_student_per_category UNIQUE (student_id, ticket_category_id)
);

COMMENT ON TABLE  bookings               IS 'Seat reservations. Each row = one confirmed seat.';
COMMENT ON COLUMN bookings.booking_code  IS 'Human-readable code sent to student, e.g. FIK-WS-2025-0042';
COMMENT ON COLUMN bookings.status        IS 'confirmed = active seat. cancelled = seat returned to pool.';

-- Stores in-progress registration state per Telegram chat
-- One row per user, auto-replaced on /start
CREATE TABLE bot_sessions (
    chat_id      BIGINT        PRIMARY KEY,   -- Telegram chat ID (unique per user)
    state        VARCHAR(50)   NOT NULL DEFAULT 'no_session',
    -- state values:
    --   no_session    → user hasn't selected a category yet
    --   awaiting_name → category chosen, waiting for full name
    --   awaiting_nim  → name saved, waiting for NIM
    --   awaiting_email→ NIM saved, waiting for email
    category_id  UUID          REFERENCES ticket_categories(id) ON DELETE SET NULL,
    full_name    VARCHAR(255),
    nim          VARCHAR(50),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  bot_sessions IS 'Temporary state for Telegram bot registration flow. Cleared after successful booking.';
COMMENT ON COLUMN bot_sessions.chat_id IS 'Telegram chat ID. Unique per user — same as their user ID in private chats.';
COMMENT ON COLUMN bot_sessions.state   IS 'Current step in the registration funnel.';