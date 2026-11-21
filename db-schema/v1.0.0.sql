-- ============================================================================
-- agora-ping — MVP Database Schema v1.0.0 (Supabase PostgreSQL)
-- ============================================================================
-- Baseline spec : agora-ping-specs/business-logic-v1.1.md
-- Design guide  : agora-ping-specs/db-design-choices.md
-- Versioning    : Forward migrations bump patch (v1.0.0 -> v1.0.1 -> v1.0.2)
--                 Full Supabase exports bump minor (v1.0.0 -> v1.1.0 -> v1.2.0)
--
-- Core invariants:
--   1. Every table has a server-only surrogate PK (`id bigint GENERATED ALWAYS
--      AS IDENTITY`) used strictly for B-tree indexing and arrival order; never
--      exposed in sync payloads.
--   2. Every table has a global `uuid uuid NOT NULL UNIQUE` minted offline by
--      clients (or server for admin rows). All relationships use `*_uuid`
--      columns with indexes and NO declared `REFERENCES` on offline-synced
--      tables so out-of-order batches never fail.
--   3. Soft deletes use `archived_at timestamptz`; live uniqueness uses partial
--      unique indexes (`WHERE archived_at IS NULL`).
--   4. Privacy by design: NO exact GPS coordinates or enumerator movement paths
--      are stored; samples link only to coarse `zone_uuid` polygons, regional
--      summaries enforce `k >= 5`, and `guideline_hit` rows remain strictly
--      private (zero public reputation scores).
--   5. 100% idempotent: safe to re-run against an existing Supabase database.
-- ============================================================================

BEGIN;

-- Required extension for server-side UUID defaults on admin/seed rows.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 1. ENUM TYPES (Idempotent closed vocabularies; §7)
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE public.user_role AS ENUM (
    'system_admin',
    'admin',
    'moderator',
    'researcher'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.crop_code AS ENUM (
    'CAS',  -- Cassava (Manihot esculenta)
    'SWP',  -- Sweet Potato (Ipomoea batatas)
    'TAR',  -- Taro (Colocasia esculenta)
    'YAM'   -- Yam (Dioscorea spp.)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.plant_part AS ENUM (
    'foliage',
    'stem_vine',
    'storage_root_corm'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.trait_input_type AS ENUM (
    'single_choice',
    'numeric'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.consent_status AS ENUM (
    'opted_in',
    'withdrawn'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.consent_scope AS ENUM (
    'community_share',
    'public_dataset',
    'data_resale'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.moderation_status AS ENUM (
    'visible',
    'auto_hidden',
    'removed',
    'restored'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.flag_reason AS ENUM (
    'misclassified_crop',
    'malformed_traits',
    'impossible_values',
    'duplicate_entry',
    'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.review_status AS ENUM (
    'pending',
    'upheld',
    'dismissed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.guideline_hit_status AS ENUM (
    'pending_review',
    'confirmed',
    'dismissed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.disclosure_doc_type AS ENUM (
    'privacy_notice',
    'consent_terms',
    'retention_schedule',
    'community_guidelines'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- 2. IDENTITY, SETTINGS & COARSE ZONES
-- ============================================================================

-- Authenticated accounts (Google Sign-In / Supabase Auth).
-- Deliberately omits any public reputation score or GPS location history.
CREATE TABLE IF NOT EXISTS public.account (
  id                    bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                  uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  auth_user_uuid        uuid UNIQUE,
  role                  public.user_role NOT NULL DEFAULT 'researcher',
  display_label         text,
  publishing_hold_until timestamptz,
  created_by            uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  archived_at           timestamptz,
  CONSTRAINT account_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_account_role_live
  ON public.account (role) WHERE archived_at IS NULL;

-- Feature-scoped governance settings stored as rows (§7) so thresholds
-- change without schema migrations.
CREATE TABLE IF NOT EXISTS public.system_setting (
  id          bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid        uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  feature     text NOT NULL,
  name        text NOT NULL,
  value       text NOT NULL,
  description text,
  created_by  uuid,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  CONSTRAINT system_setting_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_system_setting_live
  ON public.system_setting (feature, name) WHERE archived_at IS NULL;

-- Coarse geographic zones (municipality/city polygon or coarse grid cell).
-- Used to generalize exact plot coordinates upon sync (zero farm pins stored).
CREATE TABLE IF NOT EXISTS public.zone (
  id              bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  code            text NOT NULL,
  name            text NOT NULL,
  region_name     text NOT NULL,
  zone_level      text NOT NULL DEFAULT 'municipality',
  polygon_geojson jsonb,
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz,
  CONSTRAINT zone_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_zone_code_live
  ON public.zone (code) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_zone_region_live
  ON public.zone (region_name) WHERE archived_at IS NULL;

-- ============================================================================
-- 3. OFFICIAL GUIDE DESCRIPTOR ENGINE (Versioned Trait Decks)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.crop (
  id              bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  code            public.crop_code NOT NULL,
  common_name     text NOT NULL,
  scientific_name text NOT NULL,
  rank            integer NOT NULL DEFAULT 0,
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz,
  CONSTRAINT crop_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_crop_code_live
  ON public.crop (code) WHERE archived_at IS NULL;

-- Immutable once published (`published_at IS NOT NULL`); bump `version` to
-- add or revise descriptors without corrupting historical research codes.
CREATE TABLE IF NOT EXISTS public.trait_deck (
  id           bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid         uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  crop_uuid    uuid NOT NULL,
  crop_code    public.crop_code NOT NULL,
  version      text NOT NULL,
  source_guide text NOT NULL,
  is_core_mvp  boolean NOT NULL DEFAULT true,
  published_at timestamptz,
  published_by uuid,
  created_by   uuid,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  archived_at  timestamptz,
  CONSTRAINT trait_deck_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_trait_deck_crop_version_live
  ON public.trait_deck (crop_code, version) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trait_deck_crop_uuid
  ON public.trait_deck (crop_uuid);

-- Ordered plant-part descriptors belonging to a specific `trait_deck`.
CREATE TABLE IF NOT EXISTS public.trait_descriptor (
  id              bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  trait_deck_uuid uuid NOT NULL,
  plant_part      public.plant_part NOT NULL,
  code            text NOT NULL,
  label           text NOT NULL,
  input_type      public.trait_input_type NOT NULL,
  unit            text,
  min_value       numeric,
  max_value       numeric,
  rank            integer NOT NULL DEFAULT 0,
  is_required     boolean NOT NULL DEFAULT false,
  help_text       text,
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz,
  CONSTRAINT trait_descriptor_pkey PRIMARY KEY (id),
  CONSTRAINT chk_trait_descriptor_range
    CHECK (min_value IS NULL OR max_value IS NULL OR min_value <= max_value)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_trait_descriptor_deck_code_live
  ON public.trait_descriptor (trait_deck_uuid, code) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trait_descriptor_deck_order
  ON public.trait_descriptor (trait_deck_uuid, plant_part, rank)
  WHERE archived_at IS NULL;

-- Official categorical choices + standardized numeric research codes.
CREATE TABLE IF NOT EXISTS public.trait_option (
  id                    bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                  uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  trait_descriptor_uuid uuid NOT NULL,
  research_code         integer NOT NULL,
  label                 text NOT NULL,
  rank                  integer NOT NULL DEFAULT 0,
  description           text,
  created_by            uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  archived_at           timestamptz,
  CONSTRAINT trait_option_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_trait_option_descriptor_code_live
  ON public.trait_option (trait_descriptor_uuid, research_code)
  WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trait_option_descriptor_rank
  ON public.trait_option (trait_descriptor_uuid, rank)
  WHERE archived_at IS NULL;

-- ============================================================================
-- 4. FIELD SESSIONS, SPECIMENS & TRAIT VALUES (Offline-First *_uuid Sync)
-- ============================================================================

-- Lightweight field session grouping (`uuid` = `session_uuid`).
-- Stores coarse `zone_uuid` only; never tracks enumerator movement paths.
CREATE TABLE IF NOT EXISTS public.field_session (
  id           bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid         uuid NOT NULL UNIQUE,
  zone_uuid    uuid,
  session_date date NOT NULL,
  title        text,
  notes        text,
  expires_at   timestamptz,
  created_by   uuid,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  archived_at  timestamptz,
  CONSTRAINT field_session_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_field_session_created_by_live
  ON public.field_session (created_by, session_date DESC)
  WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_field_session_zone
  ON public.field_session (zone_uuid);
CREATE INDEX IF NOT EXISTS idx_field_session_expires
  ON public.field_session (expires_at) WHERE expires_at IS NOT NULL AND archived_at IS NULL;

-- Synced anonymized root crop specimen (`uuid` = `sample_uuid`).
-- Deliberately omits exact GPS coordinates and personal enumerator trails.
-- `crop_code` and `deck_version` are immutable snapshots (§8) preserving
-- statistical comparability across future descriptor updates.
CREATE TABLE IF NOT EXISTS public.sample (
  id                 bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid               uuid NOT NULL UNIQUE,
  field_session_uuid uuid,
  crop_uuid          uuid NOT NULL,
  crop_code          public.crop_code NOT NULL,
  trait_deck_uuid    uuid NOT NULL,
  deck_version       text NOT NULL,
  zone_uuid          uuid NOT NULL,
  observed_date      date NOT NULL,
  qr_payload         text NOT NULL,
  revision           integer NOT NULL DEFAULT 1,
  consent_status     public.consent_status NOT NULL DEFAULT 'opted_in',
  moderation_status  public.moderation_status NOT NULL DEFAULT 'visible',
  flag_count         integer NOT NULL DEFAULT 0,
  expires_at         timestamptz,
  created_by         uuid,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  archived_at        timestamptz,
  CONSTRAINT sample_pkey PRIMARY KEY (id),
  CONSTRAINT chk_sample_revision_positive CHECK (revision >= 1),
  CONSTRAINT chk_sample_flag_count_nonneg CHECK (flag_count >= 0),
  CONSTRAINT chk_sample_qr_ap1 CHECK (qr_payload LIKE 'AP1|%')
);

CREATE INDEX IF NOT EXISTS idx_sample_session
  ON public.sample (field_session_uuid);
CREATE INDEX IF NOT EXISTS idx_sample_crop_zone_visible
  ON public.sample (crop_code, zone_uuid, observed_date DESC)
  WHERE archived_at IS NULL
    AND consent_status = 'opted_in'
    AND moderation_status IN ('visible', 'restored');
CREATE INDEX IF NOT EXISTS idx_sample_deck
  ON public.sample (trait_deck_uuid);
CREATE INDEX IF NOT EXISTS idx_sample_created_by
  ON public.sample (created_by, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_sample_moderation_queue
  ON public.sample (moderation_status, updated_at DESC)
  WHERE archived_at IS NULL AND moderation_status = 'auto_hidden';
CREATE INDEX IF NOT EXISTS idx_sample_expires
  ON public.sample (expires_at) WHERE expires_at IS NOT NULL AND archived_at IS NULL;

-- Individual trait measurement on a specimen.
-- `is_skipped = true` with `research_code IS NULL` and `numeric_value IS NULL`
-- encodes `NA` / `null` so unobservable or pre-harvest traits never become 0.
CREATE TABLE IF NOT EXISTS public.sample_trait_value (
  id                    bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid                  uuid NOT NULL UNIQUE,
  sample_uuid           uuid NOT NULL,
  trait_descriptor_uuid uuid NOT NULL,
  trait_option_uuid     uuid,
  descriptor_code       text NOT NULL,
  plant_part            public.plant_part NOT NULL,
  research_code         integer,
  numeric_value         numeric,
  is_skipped            boolean NOT NULL DEFAULT false,
  created_by            uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  archived_at           timestamptz,
  CONSTRAINT sample_trait_value_pkey PRIMARY KEY (id),
  CONSTRAINT chk_sample_trait_skip_null
    CHECK (
      (is_skipped = true AND trait_option_uuid IS NULL AND research_code IS NULL AND numeric_value IS NULL)
      OR (is_skipped = false AND (research_code IS NOT NULL OR numeric_value IS NOT NULL))
    )
);

-- Natural-key uniqueness per live specimen-descriptor pair (§3, §5).
CREATE UNIQUE INDEX IF NOT EXISTS idx_sample_trait_value_live
  ON public.sample_trait_value (sample_uuid, trait_descriptor_uuid)
  WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sample_trait_value_descriptor_code
  ON public.sample_trait_value (descriptor_code, research_code)
  WHERE archived_at IS NULL AND is_skipped = false;
CREATE INDEX IF NOT EXISTS idx_sample_trait_value_sample
  ON public.sample_trait_value (sample_uuid) WHERE archived_at IS NULL;

-- ============================================================================
-- 5. CONSENT, MODERATION & REGULATORY PORTAL
-- ============================================================================

-- Auditable Data Privacy Act opt-in & withdrawal records.
CREATE TABLE IF NOT EXISTS public.consent_record (
  id             bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid           uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  account_uuid   uuid NOT NULL,
  sample_uuid    uuid,
  consent_scope  public.consent_scope NOT NULL,
  policy_version text NOT NULL,
  granted_at     timestamptz NOT NULL DEFAULT now(),
  revoked_at     timestamptz,
  revoked_by     uuid,
  created_by     uuid,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  archived_at    timestamptz,
  CONSTRAINT consent_record_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_consent_record_account
  ON public.consent_record (account_uuid, consent_scope)
  WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_consent_record_sample
  ON public.consent_record (sample_uuid) WHERE sample_uuid IS NOT NULL;

-- Peer flags on misclassified specimens or malformed traits.
-- Partial unique index enforces max 1 live flag per authenticated user/sample.
CREATE TABLE IF NOT EXISTS public.sample_flag (
  id            bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid          uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  sample_uuid   uuid NOT NULL,
  flagged_by    uuid NOT NULL,
  reason        public.flag_reason NOT NULL,
  details       text,
  review_status public.review_status NOT NULL DEFAULT 'pending',
  reviewed_by   uuid,
  reviewed_at   timestamptz,
  created_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  archived_at   timestamptz,
  CONSTRAINT sample_flag_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sample_flag_one_per_user_live
  ON public.sample_flag (sample_uuid, flagged_by) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sample_flag_review_queue
  ON public.sample_flag (review_status, created_at ASC) WHERE archived_at IS NULL;

-- Strictly PRIVATE guideline hits (zero public reputation scores).
-- Escalates at 3 confirmed hits into a private publishing review hold.
CREATE TABLE IF NOT EXISTS public.guideline_hit (
  id           bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid         uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  account_uuid uuid NOT NULL,
  sample_uuid  uuid NOT NULL,
  status       public.guideline_hit_status NOT NULL DEFAULT 'pending_review',
  reason       text NOT NULL,
  issued_at    timestamptz NOT NULL DEFAULT now(),
  reviewed_by  uuid,
  reviewed_at  timestamptz,
  created_by   uuid,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  archived_at  timestamptz,
  CONSTRAINT guideline_hit_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_guideline_hit_sample_live
  ON public.guideline_hit (sample_uuid) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_guideline_hit_account_status
  ON public.guideline_hit (account_uuid, status) WHERE archived_at IS NULL;

-- Versioned regulatory disclosures hosted on the Web portal.
CREATE TABLE IF NOT EXISTS public.privacy_disclosure (
  id           bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uuid         uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  doc_type     public.disclosure_doc_type NOT NULL,
  version      text NOT NULL,
  title        text NOT NULL,
  body_md      text NOT NULL,
  effective_at timestamptz NOT NULL,
  published_by uuid,
  created_by   uuid,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  archived_at  timestamptz,
  CONSTRAINT privacy_disclosure_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_privacy_disclosure_type_version_live
  ON public.privacy_disclosure (doc_type, version) WHERE archived_at IS NULL;

-- ============================================================================
-- 6. IMMUTABILITY GUARD FOR PUBLISHED TRAIT DECKS (§7)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.prevent_published_deck_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_deck_uuid       uuid;
  v_descriptor_uuid uuid;
  v_published       timestamptz;
BEGIN
  IF TG_TABLE_NAME = 'trait_descriptor' THEN
    IF TG_OP = 'DELETE' THEN
      v_deck_uuid := OLD.trait_deck_uuid;
    ELSE
      v_deck_uuid := NEW.trait_deck_uuid;
    END IF;
  ELSIF TG_TABLE_NAME = 'trait_option' THEN
    IF TG_OP = 'DELETE' THEN
      v_descriptor_uuid := OLD.trait_descriptor_uuid;
    ELSE
      v_descriptor_uuid := NEW.trait_descriptor_uuid;
    END IF;

    SELECT td.trait_deck_uuid
    INTO   v_deck_uuid
    FROM   public.trait_descriptor td
    WHERE  td.uuid = v_descriptor_uuid;
  END IF;

  SELECT d.published_at
  INTO   v_published
  FROM   public.trait_deck d
  WHERE  d.uuid = v_deck_uuid;

  IF v_published IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot modify % belonging to published trait_deck %; create a new deck version instead.',
      TG_TABLE_NAME, v_deck_uuid;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trait_descriptor_freeze_published ON public.trait_descriptor;
CREATE TRIGGER trg_trait_descriptor_freeze_published
  BEFORE INSERT OR UPDATE OR DELETE ON public.trait_descriptor
  FOR EACH ROW EXECUTE FUNCTION public.prevent_published_deck_mutation();

DROP TRIGGER IF EXISTS trg_trait_option_freeze_published ON public.trait_option;
CREATE TRIGGER trg_trait_option_freeze_published
  BEFORE INSERT OR UPDATE OR DELETE ON public.trait_option
  FOR EACH ROW EXECUTE FUNCTION public.prevent_published_deck_mutation();

-- ============================================================================
-- 7. ANONYMIZED EXPLORER & THRESHOLD-GATED AGGREGATION VIEWS (k >= 5)
-- ============================================================================

-- Public anonymized sample explorer view (omits `created_by`, `flag_count`,
-- and all moderation/guideline-hit metadata).
CREATE OR REPLACE VIEW public.v_explorer_sample AS
SELECT
  s.uuid              AS sample_uuid,
  s.crop_code,
  c.common_name       AS crop_name,
  s.deck_version,
  s.zone_uuid,
  z.code              AS zone_code,
  z.name              AS zone_name,
  z.region_name,
  s.observed_date,
  s.revision,
  s.updated_at
FROM public.sample s
LEFT JOIN public.crop c
  ON c.uuid = s.crop_uuid AND c.archived_at IS NULL
LEFT JOIN public.zone z
  ON z.uuid = s.zone_uuid AND z.archived_at IS NULL
WHERE s.archived_at IS NULL
  AND s.consent_status = 'opted_in'
  AND s.moderation_status IN ('visible', 'restored');

-- Regional trait summary strictly gated by `min_aggregation_k` (default 5)
-- per `(crop_code, zone_uuid)` bucket so small groups never leak individuals.
CREATE OR REPLACE VIEW public.v_regional_trait_summary AS
WITH threshold AS (
  SELECT COALESCE(
    (
      SELECT NULLIF(value, '')::integer
      FROM   public.system_setting
      WHERE  feature = 'privacy'
        AND  name = 'min_aggregation_k'
        AND  archived_at IS NULL
      LIMIT 1
    ),
    5
  ) AS min_k
),
eligible_buckets AS (
  SELECT
    s.crop_code,
    s.zone_uuid,
    COUNT(DISTINCT s.uuid) AS sample_count
  FROM public.sample s
  WHERE s.archived_at IS NULL
    AND s.consent_status = 'opted_in'
    AND s.moderation_status IN ('visible', 'restored')
  GROUP BY s.crop_code, s.zone_uuid
  HAVING COUNT(DISTINCT s.uuid) >= (SELECT min_k FROM threshold)
)
SELECT
  eb.crop_code,
  eb.zone_uuid,
  z.code                      AS zone_code,
  z.name                      AS zone_name,
  z.region_name,
  eb.sample_count             AS bucket_sample_count,
  tv.plant_part,
  tv.descriptor_code,
  COUNT(tv.uuid)              AS observed_count,
  AVG(tv.numeric_value)       AS avg_numeric_value,
  MIN(tv.numeric_value)       AS min_numeric_value,
  MAX(tv.numeric_value)       AS max_numeric_value,
  MODE() WITHIN GROUP (ORDER BY tv.research_code) AS modal_research_code
FROM eligible_buckets eb
JOIN public.sample s
  ON s.crop_code = eb.crop_code
 AND s.zone_uuid = eb.zone_uuid
 AND s.archived_at IS NULL
 AND s.consent_status = 'opted_in'
 AND s.moderation_status IN ('visible', 'restored')
JOIN public.sample_trait_value tv
  ON tv.sample_uuid = s.uuid
 AND tv.archived_at IS NULL
 AND tv.is_skipped = false
LEFT JOIN public.zone z
  ON z.uuid = eb.zone_uuid AND z.archived_at IS NULL
GROUP BY
  eb.crop_code,
  eb.zone_uuid,
  z.code,
  z.name,
  z.region_name,
  eb.sample_count,
  tv.plant_part,
  tv.descriptor_code;

-- ============================================================================
-- 8. ROW LEVEL SECURITY (Supabase Defense-in-Depth)
-- ============================================================================
-- `agora-ping-api` uses the server-side Supabase service role and enforces full
-- RBAC (`A`–`E`). Enabling RLS with deny-by-default on private tables prevents
-- accidental exposure through Supabase PostgREST anon/authenticated keys.

ALTER TABLE public.account            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_setting     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zone               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crop               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trait_deck         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trait_descriptor   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trait_option       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_session      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sample             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sample_trait_value ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_record     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sample_flag        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guideline_hit      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.privacy_disclosure ENABLE ROW LEVEL SECURITY;

-- Public read-only reference policies (strictly non-PII catalogs & disclosures).
DROP POLICY IF EXISTS crop_public_read ON public.crop;
CREATE POLICY crop_public_read ON public.crop
  FOR SELECT USING (archived_at IS NULL);

DROP POLICY IF EXISTS zone_public_read ON public.zone;
CREATE POLICY zone_public_read ON public.zone
  FOR SELECT USING (archived_at IS NULL);

DROP POLICY IF EXISTS trait_deck_public_read ON public.trait_deck;
CREATE POLICY trait_deck_public_read ON public.trait_deck
  FOR SELECT USING (archived_at IS NULL AND published_at IS NOT NULL);

DROP POLICY IF EXISTS trait_descriptor_public_read ON public.trait_descriptor;
CREATE POLICY trait_descriptor_public_read ON public.trait_descriptor
  FOR SELECT USING (archived_at IS NULL);

DROP POLICY IF EXISTS trait_option_public_read ON public.trait_option;
CREATE POLICY trait_option_public_read ON public.trait_option
  FOR SELECT USING (archived_at IS NULL);

DROP POLICY IF EXISTS privacy_disclosure_public_read ON public.privacy_disclosure;
CREATE POLICY privacy_disclosure_public_read ON public.privacy_disclosure
  FOR SELECT USING (archived_at IS NULL);

-- ============================================================================
-- 9. IDEMPOTENT MVP SEED DATA (Crops & Confirmed v1.1 Governance Settings)
-- ============================================================================

INSERT INTO public.crop (code, common_name, scientific_name, rank)
VALUES
  ('CAS', 'Cassava',      'Manihot esculenta',   1),
  ('SWP', 'Sweet Potato', 'Ipomoea batatas',     2),
  ('TAR', 'Taro',         'Colocasia esculenta', 3),
  ('YAM', 'Yam',          'Dioscorea spp.',      4)
ON CONFLICT (code) WHERE archived_at IS NULL DO NOTHING;

INSERT INTO public.system_setting (feature, name, value, description)
VALUES
  ('privacy',    'min_aggregation_k',            '5',   'Minimum samples per (crop_code, zone_uuid) bucket before showing regional summaries'),
  ('moderation', 'auto_hide_flag_threshold',     '3',   'Distinct authenticated peer flags per sample_uuid required to auto-hide'),
  ('moderation', 'max_flags_per_user_sample',    '1',   'Maximum live flags one authenticated account may submit per sample_uuid'),
  ('moderation', 'confirmed_hit_hold_threshold', '3',   'Confirmed private guideline hits triggering temporary publishing review hold'),
  ('retention',  'local_draft_retention_days',   '30',  'Days before unsynced local Android drafts auto-expire'),
  ('retention',  'local_draft_warn_days',        '25',  'Days before warning enumerators of upcoming local draft expiry'),
  ('retention',  'server_staging_retention_days','7',   'Days before unverified server staging records auto-expire'),
  ('qr',         'payload_version',              'AP1', 'Current offline QR specimen label payload prefix (zero PII/GPS)')
ON CONFLICT (feature, name) WHERE archived_at IS NULL DO NOTHING;

COMMIT;
