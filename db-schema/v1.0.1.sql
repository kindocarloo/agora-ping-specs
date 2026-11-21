-- ============================================================================
-- agora-ping — Forward Migration v1.0.1 (Supabase PostgreSQL)
-- ============================================================================
-- Applied on top of: agora-ping-specs/db-schema/v1.0.0.sql
-- Baseline spec    : agora-ping-specs/business-logic-v1.1.md
-- Design guide     : agora-ping-specs/db-design-choices.md
-- Versioning       : Patch bump (v1.0.0 -> v1.0.1) — additive, idempotent
--                    forward migration; never edits applied v1.0.0.sql.
--
-- Findings & integrity safeguards addressed:
--   1. Published-deck immutability (trait_deck + trait_descriptor + trait_option):
--      protects published decks from identity/version/published_at mutation,
--      validates both OLD and NEW parents with FOR SHARE locking to prevent
--      reparenting, missing-parent, deletion, and concurrent-publish bypasses,
--      and adds explicit deck retirement (`retired_at` / `retired_by`).
--   2. Aggregation privacy (k >= 5 unbreakable floor):
--      validates `system_setting` values on write, safely parses with hard
--      floor `GREATEST(5, ...)` in `effective_min_aggregation_k()`, and gates
--      every reported trait/statistic on distinct non-null contributing
--      specimens (skipped/null values never inflate counts).
--   3. Statistical compatibility:
--      groups `v_regional_trait_summary` strictly by immutable deck and
--      descriptor identity (`trait_deck_uuid`, `deck_version`,
--      `trait_descriptor_uuid`, `input_type`, `unit`), enforces `k >= 5` after
--      splitting groups, and emits numeric vs categorical stats only for
--      matching descriptor `input_type`.
--   4. Public catalog access & column protection:
--      tightens RLS policies to check the full published parent chain, revokes
--      direct base-table access from `PUBLIC`/`anon`/`authenticated` so server
--      `id` and private attribution columns (`created_by`, `published_by`,
--      `retired_by`) are never exposed via PostgREST, and grants `SELECT` only
--      on column-restricted public views.
--   5. Staging & retention lifecycle:
--      adds explicit `staging_status` (`staging` | `verified`), enforces
--      7-day staging expiry, gates Explorer and summary views strictly on
--      verified non-expired records, and provides a bounded, repeatable
--      `cleanup_expired_staging()` function with tombstone propagation and
--      delayed physical purge.
--   6. Related DB integrity safeguards (preserving out-of-order offline sync):
--      - Immutable `created_by` & non-regressing `revision` on `sample`.
--      - Automatic `consent_record` withdrawal propagation to `sample`
--        (including when consent revocation arrives before the sample).
--      - Atomic `sample_flag` self-flag guard, `flag_count` maintenance,
--        threshold auto-hide + private `guideline_hit` creation, and
--        3-confirmed-hit private publishing hold on `account`.
--      - Descriptor/type/range/option validation on `sample_trait_value` plus
--        deck-membership verification when promoting `sample` to `verified`,
--        without blocking out-of-order `sample_trait_value` arrival in staging.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. NEW ENUM & ADDITIVE COLUMNS (Idempotent Upgrade + Safe Backfill)
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE public.staging_status AS ENUM (
    'staging',
    'verified'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 1a. Explicit deck retirement columns on `trait_deck` (Finding 1).
ALTER TABLE public.trait_deck
  ADD COLUMN IF NOT EXISTS retired_at timestamptz,
  ADD COLUMN IF NOT EXISTS retired_by uuid;

CREATE INDEX IF NOT EXISTS idx_trait_deck_active_published
  ON public.trait_deck (crop_code, published_at DESC)
  WHERE archived_at IS NULL AND published_at IS NOT NULL AND retired_at IS NULL;

-- 1b. Explicit staging/verification lifecycle columns on `field_session` and
--     `sample` (Finding 5).
ALTER TABLE public.field_session
  ADD COLUMN IF NOT EXISTS staging_status public.staging_status NOT NULL DEFAULT 'staging',
  ADD COLUMN IF NOT EXISTS verified_at    timestamptz,
  ADD COLUMN IF NOT EXISTS verified_by    uuid;

ALTER TABLE public.sample
  ADD COLUMN IF NOT EXISTS staging_status public.staging_status NOT NULL DEFAULT 'staging',
  ADD COLUMN IF NOT EXISTS verified_at    timestamptz,
  ADD COLUMN IF NOT EXISTS verified_by    uuid;

-- Upgrade backfill for existing v1.0.0 rows (without bumping `updated_at` so
-- offline client dirty-sync checks remain clean; db-design-choices.md §9):
--   - Existing rows without `expires_at` were already accepted verified rows.
--   - Existing rows with `expires_at IS NOT NULL` remain in `'staging'`.
UPDATE public.field_session
SET    staging_status = 'verified',
       verified_at    = COALESCE(verified_at, updated_at, created_at, now())
WHERE  staging_status = 'staging'
  AND  expires_at IS NULL
  AND  verified_at IS NULL;

UPDATE public.sample
SET    staging_status = 'verified',
       verified_at    = COALESCE(verified_at, updated_at, created_at, now())
WHERE  staging_status = 'staging'
  AND  expires_at IS NULL
  AND  verified_at IS NULL;

-- Normalize any pre-existing invalid `min_aggregation_k` before enforcing
-- strict setting validation (Finding 2).
UPDATE public.system_setting
SET    value = '5'
WHERE  feature = 'privacy'
  AND  name = 'min_aggregation_k'
  AND  archived_at IS NULL
  AND  (value !~ '^[0-9]+$' OR value::integer < 5);

-- Constraints enforcing staging/expiry invariants on `field_session` & `sample`.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_field_session_staging_expiry'
      AND conrelid = 'public.field_session'::regclass
  ) THEN
    ALTER TABLE public.field_session
      ADD CONSTRAINT chk_field_session_staging_expiry CHECK (
        (staging_status = 'staging'  AND expires_at IS NOT NULL)
        OR
        (staging_status = 'verified' AND verified_at IS NOT NULL AND expires_at IS NULL)
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_sample_staging_expiry'
      AND conrelid = 'public.sample'::regclass
  ) THEN
    ALTER TABLE public.sample
      ADD CONSTRAINT chk_sample_staging_expiry CHECK (
        (staging_status = 'staging'  AND expires_at IS NOT NULL)
        OR
        (staging_status = 'verified' AND verified_at IS NOT NULL AND expires_at IS NULL)
      );
  END IF;
END $$;

-- Constraints on `trait_deck`: retirement requires publication.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_trait_deck_retired_requires_published'
      AND conrelid = 'public.trait_deck'::regclass
  ) THEN
    ALTER TABLE public.trait_deck
      ADD CONSTRAINT chk_trait_deck_retired_requires_published CHECK (
        retired_at IS NULL OR published_at IS NOT NULL
      );
  END IF;
END $$;

-- Rebuild partial Explorer & staging cleanup indexes to include `staging_status`.
DROP INDEX IF EXISTS public.idx_sample_crop_zone_visible;
CREATE INDEX IF NOT EXISTS idx_sample_crop_zone_visible
  ON public.sample (crop_code, zone_uuid, observed_date DESC)
  WHERE archived_at IS NULL
    AND staging_status = 'verified'
    AND consent_status = 'opted_in'
    AND moderation_status IN ('visible', 'restored');

CREATE INDEX IF NOT EXISTS idx_sample_staging_expired
  ON public.sample (expires_at ASC)
  WHERE archived_at IS NULL AND staging_status = 'staging';

CREATE INDEX IF NOT EXISTS idx_field_session_staging_expired
  ON public.field_session (expires_at ASC)
  WHERE archived_at IS NULL AND staging_status = 'staging';

CREATE INDEX IF NOT EXISTS idx_sample_trait_value_deck_agg
  ON public.sample_trait_value (trait_descriptor_uuid, sample_uuid)
  WHERE archived_at IS NULL AND is_skipped = false;

-- ============================================================================
-- 2. SAFE GOVERNANCE SETTING HELPERS & VALIDATION (Finding 2)
-- ============================================================================

-- Defense-in-depth integer setting parser with hard floor enforcement.
-- Never throws on malformed text; guarantees `k >= 5` regardless of config.
CREATE OR REPLACE FUNCTION public.get_clamped_int_setting(
  p_feature   text,
  p_name      text,
  p_default   integer,
  p_min_floor integer
)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT GREATEST(
    p_min_floor,
    COALESCE(
      (
        SELECT CASE
                 WHEN s.value ~ '^[0-9]{1,9}$' THEN s.value::integer
                 ELSE NULL
               END
        FROM   public.system_setting s
        WHERE  s.feature = p_feature
          AND  s.name = p_name
          AND  s.archived_at IS NULL
        ORDER BY s.id DESC
        LIMIT 1
      ),
      p_default
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.effective_min_aggregation_k()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.get_clamped_int_setting('privacy', 'min_aggregation_k', 5, 5);
$$;

-- Write-time validation on `system_setting` so invalid or unsafe thresholds
-- fail fast with a clear error instead of silently misconfiguring governance.
CREATE OR REPLACE FUNCTION public.validate_system_setting()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_int integer;
BEGIN
  -- Archived rows are historical tombstones; validate only live rows.
  IF NEW.archived_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.feature = 'privacy' AND NEW.name = 'min_aggregation_k' THEN
    IF NEW.value IS NULL OR NEW.value !~ '^[0-9]{1,9}$' THEN
      RAISE EXCEPTION 'system_setting privacy.min_aggregation_k must be a base-10 integer >= 5 (got %).', NEW.value;
    END IF;
    v_int := NEW.value::integer;
    IF v_int < 5 THEN
      RAISE EXCEPTION 'system_setting privacy.min_aggregation_k cannot be less than 5 (got %).', v_int;
    END IF;
  ELSIF (NEW.feature = 'moderation' AND NEW.name IN (
           'auto_hide_flag_threshold',
           'max_flags_per_user_sample',
           'confirmed_hit_hold_threshold'
         ))
     OR (NEW.feature = 'retention' AND NEW.name IN (
           'local_draft_retention_days',
           'local_draft_warn_days',
           'server_staging_retention_days'
         )) THEN
    IF NEW.value IS NULL OR NEW.value !~ '^[0-9]{1,9}$' OR NEW.value::integer < 1 THEN
      RAISE EXCEPTION 'system_setting %.% must be a positive integer >= 1 (got %).',
        NEW.feature, NEW.name, NEW.value;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_system_setting_validate ON public.system_setting;
CREATE TRIGGER trg_system_setting_validate
  BEFORE INSERT OR UPDATE ON public.system_setting
  FOR EACH ROW EXECUTE FUNCTION public.validate_system_setting();

-- ============================================================================
-- 3. PUBLISHED-DECK IMMUTABILITY & SAFE RETIREMENT (Finding 1)
-- ============================================================================

-- 3a. Guard on `trait_deck` itself:
--   - Blocks DELETE on published decks.
--   - Blocks clearing `published_at` or changing any identity/meaning column
--     (`uuid`, `crop_uuid`, `crop_code`, `version`, `source_guide`,
--     `is_core_mvp`, `published_at`, `published_by`, `created_by`,
--     `created_at`, `archived_at`) once `OLD.published_at IS NOT NULL`.
--   - Preserves deliberate retirement: on a published deck, allows setting
--     `retired_at` / `retired_by` (and `updated_at`) without unpublishing or
--     corrupting historical samples.
--   - On publication transition (`OLD.published_at IS NULL` -> `NOT NULL`),
--     validates the deck is live, references a live matching crop, has >= 1
--     live descriptor, and every live `single_choice` descriptor has >= 1 live
--     option.
CREATE OR REPLACE FUNCTION public.guard_trait_deck_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_crop_code         public.crop_code;
  v_descriptor_count  integer;
  v_empty_choice_desc uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.published_at IS NOT NULL THEN
      RAISE EXCEPTION
        'Cannot delete published trait_deck % (% v%); retire it via retired_at instead.',
        OLD.uuid, OLD.crop_code, OLD.version;
    END IF;
    RETURN OLD;
  END IF;

  -- On INSERT, do not allow inserting an already-published deck bypassing child checks.
  IF TG_OP = 'INSERT' THEN
    IF NEW.published_at IS NOT NULL THEN
      RAISE EXCEPTION
        'Insert trait_deck % as draft (published_at IS NULL), add descriptors/options, then publish via UPDATE.',
        NEW.uuid;
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE path:
  IF OLD.published_at IS NOT NULL THEN
    -- Block clearing `published_at` or changing any immutable column.
    IF NEW.published_at IS DISTINCT FROM OLD.published_at
       OR NEW.published_by IS DISTINCT FROM OLD.published_by
       OR NEW.uuid IS DISTINCT FROM OLD.uuid
       OR NEW.crop_uuid IS DISTINCT FROM OLD.crop_uuid
       OR NEW.crop_code IS DISTINCT FROM OLD.crop_code
       OR NEW.version IS DISTINCT FROM OLD.version
       OR NEW.source_guide IS DISTINCT FROM OLD.source_guide
       OR NEW.is_core_mvp IS DISTINCT FROM OLD.is_core_mvp
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR NEW.archived_at IS DISTINCT FROM OLD.archived_at THEN
      RAISE EXCEPTION
        'Published trait_deck % (% v%) is immutable; only retired_at, retired_by, and updated_at may be updated.',
        OLD.uuid, OLD.crop_code, OLD.version;
    END IF;

    -- Once retired, do not silently unretire or alter historical retirement stamp.
    IF OLD.retired_at IS NOT NULL AND NEW.retired_at IS DISTINCT FROM OLD.retired_at THEN
      RAISE EXCEPTION
        'Retired trait_deck % (% v%) cannot have retired_at altered or cleared; publish a new version instead.',
        OLD.uuid, OLD.crop_code, OLD.version;
    END IF;

    RETURN NEW;
  END IF;

  -- Transition from draft (`OLD.published_at IS NULL`) to published (`NEW.published_at IS NOT NULL`).
  -- Note: PostgreSQL already holds a row-level exclusive lock on this `trait_deck` row,
  -- serializing against `FOR SHARE` locks acquired by child descriptor/option triggers.
  IF OLD.published_at IS NULL AND NEW.published_at IS NOT NULL THEN
    IF NEW.archived_at IS NOT NULL THEN
      RAISE EXCEPTION 'Cannot publish an archived trait_deck %.', NEW.uuid;
    END IF;

    SELECT c.code
    INTO   v_crop_code
    FROM   public.crop c
    WHERE  c.uuid = NEW.crop_uuid
      AND  c.archived_at IS NULL;

    IF NOT FOUND OR v_crop_code <> NEW.crop_code THEN
      RAISE EXCEPTION
        'Cannot publish trait_deck %: crop_uuid % does not match a live crop with code %.',
        NEW.uuid, NEW.crop_uuid, NEW.crop_code;
    END IF;

    SELECT COUNT(*)
    INTO   v_descriptor_count
    FROM   public.trait_descriptor td
    WHERE  td.trait_deck_uuid = NEW.uuid
      AND  td.archived_at IS NULL;

    IF v_descriptor_count < 1 THEN
      RAISE EXCEPTION
        'Cannot publish empty trait_deck % (% v%): add at least one live trait_descriptor first.',
        NEW.uuid, NEW.crop_code, NEW.version;
    END IF;

    SELECT td.uuid
    INTO   v_empty_choice_desc
    FROM   public.trait_descriptor td
    WHERE  td.trait_deck_uuid = NEW.uuid
      AND  td.archived_at IS NULL
      AND  td.input_type = 'single_choice'
      AND  NOT EXISTS (
             SELECT 1
             FROM   public.trait_option o
             WHERE  o.trait_descriptor_uuid = td.uuid
               AND  o.archived_at IS NULL
           )
    LIMIT 1;

    IF v_empty_choice_desc IS NOT NULL THEN
      RAISE EXCEPTION
        'Cannot publish trait_deck %: single_choice descriptor % has no live trait_option rows.',
        NEW.uuid, v_empty_choice_desc;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trait_deck_lifecycle ON public.trait_deck;
CREATE TRIGGER trg_trait_deck_lifecycle
  BEFORE INSERT OR UPDATE OR DELETE ON public.trait_deck
  FOR EACH ROW EXECUTE FUNCTION public.guard_trait_deck_lifecycle();

-- 3b. Hardened child immutability guard on `trait_descriptor` & `trait_option`:
--   - Validates BOTH `OLD` and `NEW` parent chains on `UPDATE`.
--   - Rejects missing parent `trait_deck` / `trait_descriptor` on `INSERT`/`UPDATE`.
--   - Acquires `FOR SHARE` locks on referenced parent `trait_deck` rows in
--     deterministic UUID order to prevent concurrent publication bypasses and
--     avoid lock-order deadlocks.
CREATE OR REPLACE FUNCTION public.prevent_published_deck_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_old_deck_uuid       uuid;
  v_new_deck_uuid       uuid;
  v_old_descriptor_uuid uuid;
  v_new_descriptor_uuid uuid;
  v_old_desc_found      boolean := false;
  v_new_desc_found      boolean := false;
  v_deck_row            record;
  v_new_deck_found      boolean := false;
BEGIN
  IF TG_TABLE_NAME = 'trait_descriptor' THEN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
      v_old_deck_uuid := OLD.trait_deck_uuid;
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
      v_new_deck_uuid := NEW.trait_deck_uuid;
    END IF;
  ELSIF TG_TABLE_NAME = 'trait_option' THEN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
      v_old_descriptor_uuid := OLD.trait_descriptor_uuid;
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
      v_new_descriptor_uuid := NEW.trait_descriptor_uuid;
    END IF;

    -- Lock referenced descriptors in deterministic UUID order (`FOR SHARE`).
    FOR v_deck_row IN
      SELECT td.uuid AS descriptor_uuid, td.trait_deck_uuid, td.archived_at
      FROM   public.trait_descriptor td
      WHERE  td.uuid IN (v_old_descriptor_uuid, v_new_descriptor_uuid)
      ORDER BY td.uuid
      FOR SHARE
    LOOP
      IF v_deck_row.descriptor_uuid = v_old_descriptor_uuid THEN
        v_old_desc_found := true;
        v_old_deck_uuid  := v_deck_row.trait_deck_uuid;
      END IF;
      IF v_deck_row.descriptor_uuid = v_new_descriptor_uuid THEN
        v_new_desc_found := true;
        v_new_deck_uuid  := v_deck_row.trait_deck_uuid;
        IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.archived_at IS NULL AND v_deck_row.archived_at IS NOT NULL THEN
          RAISE EXCEPTION
            'Cannot attach live trait_option % to archived trait_descriptor %.',
            NEW.uuid, v_new_descriptor_uuid;
        END IF;
      END IF;
    END LOOP;

    IF TG_OP IN ('INSERT', 'UPDATE') AND NOT v_new_desc_found THEN
      RAISE EXCEPTION
        'Cannot write trait_option %: parent trait_descriptor % does not exist.',
        NEW.uuid, v_new_descriptor_uuid;
    END IF;
    IF TG_OP IN ('UPDATE', 'DELETE') AND NOT v_old_desc_found THEN
      -- Fail closed if an orphaned option's parent descriptor disappeared.
      RAISE EXCEPTION
        'Cannot modify trait_option %: original parent trait_descriptor % is missing.',
        OLD.uuid, v_old_descriptor_uuid;
    END IF;
  END IF;

  -- Lock all referenced parent decks in deterministic UUID order (`FOR SHARE`)
  -- to serialize against concurrent `UPDATE trait_deck SET published_at = ...`.
  FOR v_deck_row IN
    SELECT d.uuid, d.published_at, d.archived_at
    FROM   public.trait_deck d
    WHERE  d.uuid IN (v_old_deck_uuid, v_new_deck_uuid)
    ORDER BY d.uuid
    FOR SHARE
  LOOP
    IF v_deck_row.uuid = v_new_deck_uuid THEN
      v_new_deck_found := true;
    END IF;
    IF v_deck_row.published_at IS NOT NULL THEN
      RAISE EXCEPTION
        'Cannot % % row: parent trait_deck % is already published; create a new deck version instead.',
        TG_OP, TG_TABLE_NAME, v_deck_row.uuid;
    END IF;
  END LOOP;

  IF TG_OP IN ('INSERT', 'UPDATE') AND NOT v_new_deck_found THEN
    RAISE EXCEPTION
      'Cannot write % row: parent trait_deck % does not exist.',
      TG_TABLE_NAME, v_new_deck_uuid;
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
-- 4. STAGING RETENTION, SYNC INTEGRITY & TRAIT VALIDATION (Finding 5 + Gaps)
-- ============================================================================

-- 4a. Enforce 7-day staging expiry on `field_session` (Finding 5).
CREATE OR REPLACE FUNCTION public.enforce_field_session_staging()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_days     integer;
  v_max_exp  timestamptz;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.created_by IS NOT NULL AND NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'field_session.created_by cannot be modified once stamped.';
  END IF;

  IF NEW.staging_status = 'staging' THEN
    v_days    := public.get_clamped_int_setting('retention', 'server_staging_retention_days', 7, 1);
    v_max_exp := COALESCE(NEW.created_at, now()) + make_interval(days => v_days);
    NEW.expires_at := LEAST(COALESCE(NEW.expires_at, v_max_exp), v_max_exp);
  ELSE
    NEW.verified_at := COALESCE(NEW.verified_at, now());
    NEW.expires_at  := NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_field_session_staging_retention ON public.field_session;
CREATE TRIGGER trg_field_session_staging_retention
  BEFORE INSERT OR UPDATE ON public.field_session
  FOR EACH ROW EXECUTE FUNCTION public.enforce_field_session_staging();

-- 4b. Enforce staging expiry, revision monotonicity, `created_by` immutability,
--     prior consent-withdrawal check, and deck/trait verification on `sample`
--     (Finding 5 + related integrity gaps; preserves out-of-order staging sync).
CREATE OR REPLACE FUNCTION public.enforce_sample_integrity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_days          integer;
  v_max_exp       timestamptz;
  v_deck          record;
  v_zone_exists   boolean;
  v_bad_trait     uuid;
  v_was_revoked   boolean;
BEGIN
  -- Revision & ownership guards on UPDATE.
  IF TG_OP = 'UPDATE' THEN
    IF OLD.created_by IS NOT NULL AND NEW.created_by IS DISTINCT FROM OLD.created_by THEN
      RAISE EXCEPTION 'sample.created_by cannot be modified once stamped.';
    END IF;
    IF NEW.revision < OLD.revision THEN
      RAISE EXCEPTION
        'sample % revision cannot regress (% -> %).',
        NEW.uuid, OLD.revision, NEW.revision;
    END IF;
  END IF;

  -- Out-of-order consent safety: if a `community_share` withdrawal was already
  -- recorded for this sample_uuid (or account-wide at/after sample creation),
  -- never re-expose the sample as `opted_in`.
  IF NEW.consent_status = 'opted_in' THEN
    SELECT EXISTS (
      SELECT 1
      FROM   public.consent_record cr
      WHERE  cr.archived_at IS NULL
        AND  cr.consent_scope = 'community_share'
        AND  cr.revoked_at IS NOT NULL
        AND  (
               cr.sample_uuid = NEW.uuid
               OR (
                    cr.sample_uuid IS NULL
                    AND NEW.created_by IS NOT NULL
                    AND cr.account_uuid = NEW.created_by
                    AND cr.revoked_at >= COALESCE(NEW.created_at, now())
                  )
             )
    ) INTO v_was_revoked;

    IF v_was_revoked THEN
      NEW.consent_status := 'withdrawn';
    END IF;
  END IF;

  -- Staging vs verified lifecycle enforcement.
  IF NEW.staging_status = 'staging' THEN
    v_days         := public.get_clamped_int_setting('retention', 'server_staging_retention_days', 7, 1);
    v_max_exp      := COALESCE(NEW.created_at, now()) + make_interval(days => v_days);
    NEW.expires_at := LEAST(COALESCE(NEW.expires_at, v_max_exp), v_max_exp);
  ELSE
    NEW.verified_at := COALESCE(NEW.verified_at, now());
    NEW.expires_at  := NULL;

    -- Verify catalog & trait alignment when live sample is promoted/saved as `verified`.
    IF NEW.archived_at IS NULL THEN
      SELECT d.uuid, d.crop_uuid, d.crop_code, d.version, d.published_at, d.archived_at
      INTO   v_deck
      FROM   public.trait_deck d
      WHERE  d.uuid = NEW.trait_deck_uuid;

      IF NOT FOUND OR v_deck.archived_at IS NOT NULL OR v_deck.published_at IS NULL THEN
        RAISE EXCEPTION
          'Cannot verify sample %: trait_deck % must exist, be live, and be published.',
          NEW.uuid, NEW.trait_deck_uuid;
      END IF;

      IF v_deck.crop_uuid <> NEW.crop_uuid
         OR v_deck.crop_code <> NEW.crop_code
         OR v_deck.version <> NEW.deck_version THEN
        RAISE EXCEPTION
          'Cannot verify sample %: crop/deck snapshot (% / %) disagrees with trait_deck % (% / %).',
          NEW.uuid, NEW.crop_code, NEW.deck_version, v_deck.uuid, v_deck.crop_code, v_deck.version;
      END IF;

      SELECT EXISTS (
        SELECT 1
        FROM   public.zone z
        WHERE  z.uuid = NEW.zone_uuid
          AND  z.archived_at IS NULL
      ) INTO v_zone_exists;

      IF NOT v_zone_exists THEN
        RAISE EXCEPTION
          'Cannot verify sample %: coarse zone % does not exist or is archived.',
          NEW.uuid, NEW.zone_uuid;
      END IF;

      -- Ensure every live trait value already landed for this sample belongs
      -- to the sample's recorded `trait_deck_uuid` (closes out-of-order gap).
      SELECT tv.uuid
      INTO   v_bad_trait
      FROM   public.sample_trait_value tv
      LEFT JOIN public.trait_descriptor td
        ON td.uuid = tv.trait_descriptor_uuid
       AND td.archived_at IS NULL
      WHERE  tv.sample_uuid = NEW.uuid
        AND  tv.archived_at IS NULL
        AND  (td.uuid IS NULL OR td.trait_deck_uuid <> NEW.trait_deck_uuid)
      LIMIT 1;

      IF v_bad_trait IS NOT NULL THEN
        RAISE EXCEPTION
          'Cannot verify sample %: trait value % does not match recorded trait_deck %.',
          NEW.uuid, v_bad_trait, NEW.trait_deck_uuid;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sample_integrity ON public.sample;
CREATE TRIGGER trg_sample_integrity
  BEFORE INSERT OR UPDATE ON public.sample
  FOR EACH ROW EXECUTE FUNCTION public.enforce_sample_integrity();

-- 4c. Validate `sample_trait_value` against catalog descriptor, option, range,
--     and (when parent `sample` has already landed) recorded `trait_deck_uuid`.
--     Out-of-order offline sync is preserved: if `sample` is not yet present,
--     the row lands cleanly and is cross-checked when `sample` verifies.
CREATE OR REPLACE FUNCTION public.validate_sample_trait_value()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_desc          record;
  v_opt_uuid      uuid;
  v_sample_deck   uuid;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.created_by IS NOT NULL AND NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'sample_trait_value.created_by cannot be modified once stamped.';
  END IF;

  -- Skip strict value validation on tombstones (`archived_at IS NOT NULL`).
  IF NEW.archived_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT td.uuid, td.trait_deck_uuid, td.code, td.plant_part,
         td.input_type, td.min_value, td.max_value
  INTO   v_desc
  FROM   public.trait_descriptor td
  WHERE  td.uuid = NEW.trait_descriptor_uuid
    AND  td.archived_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'sample_trait_value % references unknown or archived trait_descriptor %.',
      NEW.uuid, NEW.trait_descriptor_uuid;
  END IF;

  IF NEW.descriptor_code <> v_desc.code OR NEW.plant_part <> v_desc.plant_part THEN
    RAISE EXCEPTION
      'sample_trait_value % snapshot (%, %) does not match trait_descriptor % (%, %).',
      NEW.uuid, NEW.descriptor_code, NEW.plant_part, v_desc.uuid, v_desc.code, v_desc.plant_part;
  END IF;

  IF NEW.is_skipped = false THEN
    IF v_desc.input_type = 'single_choice' THEN
      IF NEW.research_code IS NULL OR NEW.numeric_value IS NOT NULL THEN
        RAISE EXCEPTION
          'sample_trait_value % for single_choice descriptor % must supply research_code only.',
          NEW.uuid, v_desc.code;
      END IF;

      SELECT o.uuid
      INTO   v_opt_uuid
      FROM   public.trait_option o
      WHERE  o.trait_descriptor_uuid = v_desc.uuid
        AND  o.research_code = NEW.research_code
        AND  o.archived_at IS NULL
      LIMIT 1;

      IF NOT FOUND THEN
        RAISE EXCEPTION
          'sample_trait_value % research_code % is invalid for trait_descriptor %.',
          NEW.uuid, NEW.research_code, v_desc.code;
      END IF;

      IF NEW.trait_option_uuid IS NOT NULL AND NEW.trait_option_uuid <> v_opt_uuid THEN
        RAISE EXCEPTION
          'sample_trait_value % trait_option_uuid % does not match research_code % on descriptor %.',
          NEW.uuid, NEW.trait_option_uuid, NEW.research_code, v_desc.code;
      END IF;
      NEW.trait_option_uuid := v_opt_uuid;

    ELSIF v_desc.input_type = 'numeric' THEN
      IF NEW.numeric_value IS NULL OR NEW.research_code IS NOT NULL OR NEW.trait_option_uuid IS NOT NULL THEN
        RAISE EXCEPTION
          'sample_trait_value % for numeric descriptor % must supply numeric_value only.',
          NEW.uuid, v_desc.code;
      END IF;

      IF (v_desc.min_value IS NOT NULL AND NEW.numeric_value < v_desc.min_value)
         OR (v_desc.max_value IS NOT NULL AND NEW.numeric_value > v_desc.max_value) THEN
        RAISE EXCEPTION
          'sample_trait_value % numeric_value % is outside [%, %] for descriptor %.',
          NEW.uuid, NEW.numeric_value, v_desc.min_value, v_desc.max_value, v_desc.code;
      END IF;
    END IF;
  END IF;

  -- If parent sample already exists, enforce exact deck match immediately.
  SELECT s.trait_deck_uuid
  INTO   v_sample_deck
  FROM   public.sample s
  WHERE  s.uuid = NEW.sample_uuid
    AND  s.archived_at IS NULL;

  IF FOUND AND v_sample_deck <> v_desc.trait_deck_uuid THEN
    RAISE EXCEPTION
      'sample_trait_value % descriptor deck % does not match sample % recorded deck %.',
      NEW.uuid, v_desc.trait_deck_uuid, NEW.sample_uuid, v_sample_deck;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sample_trait_value_validate ON public.sample_trait_value;
CREATE TRIGGER trg_sample_trait_value_validate
  BEFORE INSERT OR UPDATE ON public.sample_trait_value
  FOR EACH ROW EXECUTE FUNCTION public.validate_sample_trait_value();

-- 4d. Automatic consent withdrawal propagation (`consent_record` -> `sample`).
CREATE OR REPLACE FUNCTION public.propagate_consent_withdrawal()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.archived_at IS NULL
     AND NEW.consent_scope = 'community_share'
     AND NEW.revoked_at IS NOT NULL THEN
    IF NEW.sample_uuid IS NOT NULL THEN
      UPDATE public.sample
      SET    consent_status = 'withdrawn',
             updated_at     = GREATEST(updated_at, now())
      WHERE  uuid = NEW.sample_uuid
        AND  consent_status <> 'withdrawn';
    ELSE
      -- Account-wide community_share withdrawal propagates to all owner samples.
      UPDATE public.sample
      SET    consent_status = 'withdrawn',
             updated_at     = GREATEST(updated_at, now())
      WHERE  created_by = NEW.account_uuid
        AND  consent_status <> 'withdrawn';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_consent_record_propagate_withdrawal ON public.consent_record;
CREATE TRIGGER trg_consent_record_propagate_withdrawal
  AFTER INSERT OR UPDATE OF revoked_at, consent_scope, archived_at ON public.consent_record
  FOR EACH ROW EXECUTE FUNCTION public.propagate_consent_withdrawal();

-- 4e. Moderation threshold enforcement (`sample_flag` -> `sample` -> `guideline_hit` -> `account`).
CREATE OR REPLACE FUNCTION public.guard_sample_flag_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_owner uuid;
BEGIN
  SELECT s.created_by
  INTO   v_owner
  FROM   public.sample s
  WHERE  s.uuid = NEW.sample_uuid
    AND  s.archived_at IS NULL;

  IF FOUND AND v_owner IS NOT NULL AND v_owner = NEW.flagged_by THEN
    RAISE EXCEPTION 'Account % cannot flag its own sample %.', NEW.flagged_by, NEW.sample_uuid;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sample_flag_guard ON public.sample_flag;
CREATE TRIGGER trg_sample_flag_guard
  BEFORE INSERT ON public.sample_flag
  FOR EACH ROW EXECUTE FUNCTION public.guard_sample_flag_insert();

CREATE OR REPLACE FUNCTION public.sync_sample_moderation_on_flag()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_sample_uuid     uuid;
  v_sample          record;
  v_live_flag_count integer;
  v_threshold       integer;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_sample_uuid := OLD.sample_uuid;
  ELSE
    v_sample_uuid := NEW.sample_uuid;
  END IF;

  SELECT s.uuid, s.created_by, s.moderation_status
  INTO   v_sample
  FROM   public.sample s
  WHERE  s.uuid = v_sample_uuid
  FOR UPDATE;

  -- Tolerate out-of-order sync if sample row is not present yet.
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT COUNT(DISTINCT f.flagged_by)
  INTO   v_live_flag_count
  FROM   public.sample_flag f
  WHERE  f.sample_uuid = v_sample_uuid
    AND  f.archived_at IS NULL
    AND  f.review_status IN ('pending', 'upheld');

  v_threshold := public.get_clamped_int_setting('moderation', 'auto_hide_flag_threshold', 3, 1);

  IF v_live_flag_count >= v_threshold AND v_sample.moderation_status = 'visible' THEN
    UPDATE public.sample
    SET    flag_count        = v_live_flag_count,
           moderation_status = 'auto_hidden',
           updated_at        = GREATEST(updated_at, now())
    WHERE  uuid = v_sample_uuid;

    IF v_sample.created_by IS NOT NULL THEN
      INSERT INTO public.guideline_hit (account_uuid, sample_uuid, status, reason)
      VALUES (
        v_sample.created_by,
        v_sample_uuid,
        'pending_review',
        format('Auto-hidden after reaching %s distinct peer flags.', v_live_flag_count)
      )
      ON CONFLICT (sample_uuid) WHERE archived_at IS NULL DO NOTHING;
    END IF;
  ELSE
    UPDATE public.sample
    SET    flag_count = v_live_flag_count
    WHERE  uuid = v_sample_uuid
      AND  flag_count IS DISTINCT FROM v_live_flag_count;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sample_flag_sync_moderation ON public.sample_flag;
CREATE TRIGGER trg_sample_flag_sync_moderation
  AFTER INSERT OR UPDATE OR DELETE ON public.sample_flag
  FOR EACH ROW EXECUTE FUNCTION public.sync_sample_moderation_on_flag();

CREATE OR REPLACE FUNCTION public.enforce_guideline_hit_hold()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_confirmed_hits integer;
  v_hold_threshold integer;
BEGIN
  IF NEW.archived_at IS NOT NULL OR NEW.status <> 'confirmed' THEN
    RETURN NEW;
  END IF;

  v_hold_threshold := public.get_clamped_int_setting('moderation', 'confirmed_hit_hold_threshold', 3, 1);

  SELECT COUNT(*)
  INTO   v_confirmed_hits
  FROM   public.guideline_hit gh
  WHERE  gh.account_uuid = NEW.account_uuid
    AND  gh.archived_at IS NULL
    AND  gh.status = 'confirmed';

  IF v_confirmed_hits >= v_hold_threshold THEN
    UPDATE public.account
    SET    publishing_hold_until = GREATEST(
             COALESCE(publishing_hold_until, now()),
             now() + interval '14 days'
           ),
           updated_at = GREATEST(updated_at, now())
    WHERE  uuid = NEW.account_uuid
      AND  archived_at IS NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guideline_hit_hold ON public.guideline_hit;
CREATE TRIGGER trg_guideline_hit_hold
  AFTER INSERT OR UPDATE OF status, archived_at ON public.guideline_hit
  FOR EACH ROW EXECUTE FUNCTION public.enforce_guideline_hit_hold();

-- 4f. Bounded, repeatable staging cleanup function (Finding 5).
--   Phase 1: Soft-archives up to `p_batch_size` expired staging samples and
--            cascades tombstones (`archived_at` + `updated_at`) to dependent
--            rows so offline clients learn of the expiry instead of re-pushing.
--            Also soft-archives up to `p_batch_size` expired staging sessions
--            that have no live verified samples referencing them.
--   Phase 2: Physically purges up to `p_batch_size` expired staging tombstones
--            older than `p_hard_delete_after_days` (default 30 days, matching
--            Android local draft retention) while preserving `consent_record`
--            for Data Privacy Act auditability.
CREATE OR REPLACE FUNCTION public.cleanup_expired_staging(
  p_batch_size             integer DEFAULT 500,
  p_hard_delete_after_days integer DEFAULT 30
)
RETURNS TABLE (
  archived_samples      integer,
  archived_trait_values integer,
  archived_sessions     integer,
  purged_samples        integer,
  purged_sessions       integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch          integer := GREATEST(1, LEAST(COALESCE(p_batch_size, 500), 5000));
  v_grace_days     integer := GREATEST(1, COALESCE(p_hard_delete_after_days, 30));
  v_now            timestamptz := now();
  v_sample_uuids   uuid[];
  v_purge_uuids    uuid[];
  v_arch_samples   integer := 0;
  v_arch_traits    integer := 0;
  v_arch_sessions  integer := 0;
  v_purge_samples  integer := 0;
  v_purge_sessions integer := 0;
BEGIN
  -- Phase 1a: Soft-archive expired staging samples (FOR UPDATE SKIP LOCKED).
  WITH expired AS (
    SELECT s.uuid
    FROM   public.sample s
    WHERE  s.staging_status = 'staging'
      AND  s.archived_at IS NULL
      AND  s.expires_at <= v_now
    ORDER BY s.expires_at ASC
    LIMIT v_batch
    FOR UPDATE SKIP LOCKED
  ),
  archived AS (
    UPDATE public.sample s
    SET    archived_at = v_now,
           updated_at  = GREATEST(s.updated_at, v_now)
    FROM   expired e
    WHERE  s.uuid = e.uuid
    RETURNING s.uuid
  )
  SELECT COALESCE(array_agg(uuid), ARRAY[]::uuid[])
  INTO   v_sample_uuids
  FROM   archived;

  v_arch_samples := COALESCE(array_length(v_sample_uuids, 1), 0);

  IF v_arch_samples > 0 THEN
    -- Cascade tombstones to dependent rows so clients sync deletions cleanly.
    UPDATE public.sample_trait_value tv
    SET    archived_at = v_now,
           updated_at  = GREATEST(tv.updated_at, v_now)
    WHERE  tv.sample_uuid = ANY(v_sample_uuids)
      AND  tv.archived_at IS NULL;
    GET DIAGNOSTICS v_arch_traits = ROW_COUNT;

    UPDATE public.sample_flag f
    SET    archived_at = v_now,
           updated_at  = GREATEST(f.updated_at, v_now)
    WHERE  f.sample_uuid = ANY(v_sample_uuids)
      AND  f.archived_at IS NULL;

    UPDATE public.guideline_hit gh
    SET    archived_at = v_now,
           updated_at  = GREATEST(gh.updated_at, v_now)
    WHERE  gh.sample_uuid = ANY(v_sample_uuids)
      AND  gh.archived_at IS NULL;
  END IF;

  -- Phase 1b: Soft-archive expired staging sessions with no live verified samples.
  WITH expired_sessions AS (
    SELECT fs.uuid
    FROM   public.field_session fs
    WHERE  fs.staging_status = 'staging'
      AND  fs.archived_at IS NULL
      AND  fs.expires_at <= v_now
      AND  NOT EXISTS (
             SELECT 1
             FROM   public.sample s
             WHERE  s.field_session_uuid = fs.uuid
               AND  s.archived_at IS NULL
               AND  s.staging_status = 'verified'
           )
    ORDER BY fs.expires_at ASC
    LIMIT v_batch
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.field_session fs
  SET    archived_at = v_now,
         updated_at  = GREATEST(fs.updated_at, v_now)
  FROM   expired_sessions es
  WHERE  fs.uuid = es.uuid;
  GET DIAGNOSTICS v_arch_sessions = ROW_COUNT;

  -- Phase 2a: Physically purge expired staging sample tombstones past grace window.
  WITH purgeable AS (
    SELECT s.uuid
    FROM   public.sample s
    WHERE  s.staging_status = 'staging'
      AND  s.archived_at IS NOT NULL
      AND  s.archived_at <= v_now - make_interval(days => v_grace_days)
    ORDER BY s.archived_at ASC
    LIMIT v_batch
    FOR UPDATE SKIP LOCKED
  )
  SELECT COALESCE(array_agg(uuid), ARRAY[]::uuid[])
  INTO   v_purge_uuids
  FROM   purgeable;

  IF COALESCE(array_length(v_purge_uuids, 1), 0) > 0 THEN
    DELETE FROM public.sample_trait_value WHERE sample_uuid = ANY(v_purge_uuids);
    DELETE FROM public.sample_flag        WHERE sample_uuid = ANY(v_purge_uuids);
    DELETE FROM public.guideline_hit      WHERE sample_uuid = ANY(v_purge_uuids);
    -- Note: `consent_record` rows are intentionally retained for DPA auditability.
    DELETE FROM public.sample             WHERE uuid = ANY(v_purge_uuids);
    GET DIAGNOSTICS v_purge_samples = ROW_COUNT;
  END IF;

  -- Phase 2b: Physically purge expired staging session tombstones past grace window.
  WITH purgeable_sessions AS (
    SELECT fs.uuid
    FROM   public.field_session fs
    WHERE  fs.staging_status = 'staging'
      AND  fs.archived_at IS NOT NULL
      AND  fs.archived_at <= v_now - make_interval(days => v_grace_days)
      AND  NOT EXISTS (
             SELECT 1 FROM public.sample s WHERE s.field_session_uuid = fs.uuid
           )
    ORDER BY fs.archived_at ASC
    LIMIT v_batch
    FOR UPDATE SKIP LOCKED
  )
  DELETE FROM public.field_session fs
  USING  purgeable_sessions ps
  WHERE  fs.uuid = ps.uuid;
  GET DIAGNOSTICS v_purge_sessions = ROW_COUNT;

  RETURN QUERY SELECT
    v_arch_samples,
    v_arch_traits,
    v_arch_sessions,
    v_purge_samples,
    v_purge_sessions;
END;
$$;

-- ============================================================================
-- 5. HARDENED PUBLIC VIEWS (Findings 2, 3, 4, 5)
-- ============================================================================
-- All public views omit server-only `id`, `created_by`, `published_by`,
-- `retired_by`, `archived_at`, and all moderation/hit columns.

-- 5a. Safe public catalog views (replace direct PostgREST base-table reads).
CREATE OR REPLACE VIEW public.v_public_crop AS
SELECT
  c.uuid AS crop_uuid,
  c.code,
  c.common_name,
  c.scientific_name,
  c.rank
FROM public.crop c
WHERE c.archived_at IS NULL;

CREATE OR REPLACE VIEW public.v_public_zone AS
SELECT
  z.uuid AS zone_uuid,
  z.code,
  z.name,
  z.region_name,
  z.zone_level,
  z.polygon_geojson
FROM public.zone z
WHERE z.archived_at IS NULL;

CREATE OR REPLACE VIEW public.v_public_trait_deck AS
SELECT
  d.uuid AS trait_deck_uuid,
  d.crop_uuid,
  d.crop_code,
  d.version,
  d.source_guide,
  d.is_core_mvp,
  d.published_at,
  d.retired_at
FROM public.trait_deck d
WHERE d.archived_at IS NULL
  AND d.published_at IS NOT NULL;

CREATE OR REPLACE VIEW public.v_public_trait_descriptor AS
SELECT
  td.uuid AS trait_descriptor_uuid,
  td.trait_deck_uuid,
  d.crop_code,
  d.version AS deck_version,
  td.plant_part,
  td.code,
  td.label,
  td.input_type,
  td.unit,
  td.min_value,
  td.max_value,
  td.rank,
  td.is_required,
  td.help_text
FROM public.trait_descriptor td
JOIN public.trait_deck d
  ON d.uuid = td.trait_deck_uuid
 AND d.archived_at IS NULL
 AND d.published_at IS NOT NULL
WHERE td.archived_at IS NULL;

CREATE OR REPLACE VIEW public.v_public_trait_option AS
SELECT
  o.uuid AS trait_option_uuid,
  o.trait_descriptor_uuid,
  td.trait_deck_uuid,
  o.research_code,
  o.label,
  o.rank,
  o.description
FROM public.trait_option o
JOIN public.trait_descriptor td
  ON td.uuid = o.trait_descriptor_uuid
 AND td.archived_at IS NULL
JOIN public.trait_deck d
  ON d.uuid = td.trait_deck_uuid
 AND d.archived_at IS NULL
 AND d.published_at IS NOT NULL
WHERE o.archived_at IS NULL;

CREATE OR REPLACE VIEW public.v_public_privacy_disclosure AS
SELECT
  p.uuid AS privacy_disclosure_uuid,
  p.doc_type,
  p.version,
  p.title,
  p.body_md,
  p.effective_at
FROM public.privacy_disclosure p
WHERE p.archived_at IS NULL
  AND p.effective_at <= now();

-- 5b. Hardened Explorer sample view (excludes unverified & expired staging).
DROP VIEW IF EXISTS public.v_explorer_sample;
CREATE VIEW public.v_explorer_sample AS
SELECT
  s.uuid              AS sample_uuid,
  s.crop_code,
  c.common_name       AS crop_name,
  s.trait_deck_uuid,
  s.deck_version,
  s.zone_uuid,
  z.code              AS zone_code,
  z.name              AS zone_name,
  z.region_name,
  s.observed_date,
  s.revision,
  s.updated_at
FROM public.sample s
JOIN public.trait_deck d
  ON d.uuid = s.trait_deck_uuid
 AND d.archived_at IS NULL
 AND d.published_at IS NOT NULL
LEFT JOIN public.crop c
  ON c.uuid = s.crop_uuid AND c.archived_at IS NULL
LEFT JOIN public.zone z
  ON z.uuid = s.zone_uuid AND z.archived_at IS NULL
WHERE s.archived_at IS NULL
  AND s.staging_status = 'verified'
  AND (s.expires_at IS NULL OR s.expires_at > now())
  AND s.consent_status = 'opted_in'
  AND s.moderation_status IN ('visible', 'restored');

-- 5c. Public trait profile view for Explorer filtering (non-PII, verified only).
CREATE OR REPLACE VIEW public.v_explorer_sample_trait AS
SELECT
  tv.sample_uuid,
  s.crop_code,
  s.trait_deck_uuid,
  s.deck_version,
  s.zone_uuid,
  td.uuid          AS trait_descriptor_uuid,
  td.plant_part,
  td.code          AS descriptor_code,
  td.label         AS descriptor_label,
  td.input_type,
  td.unit,
  tv.research_code,
  o.label          AS option_label,
  tv.numeric_value,
  tv.is_skipped
FROM public.sample s
JOIN public.trait_deck d
  ON d.uuid = s.trait_deck_uuid
 AND d.archived_at IS NULL
 AND d.published_at IS NOT NULL
JOIN public.sample_trait_value tv
  ON tv.sample_uuid = s.uuid
 AND tv.archived_at IS NULL
JOIN public.trait_descriptor td
  ON td.uuid = tv.trait_descriptor_uuid
 AND td.trait_deck_uuid = s.trait_deck_uuid
 AND td.archived_at IS NULL
LEFT JOIN public.trait_option o
  ON o.uuid = tv.trait_option_uuid
 AND o.trait_descriptor_uuid = td.uuid
 AND o.archived_at IS NULL
WHERE s.archived_at IS NULL
  AND s.staging_status = 'verified'
  AND (s.expires_at IS NULL OR s.expires_at > now())
  AND s.consent_status = 'opted_in'
  AND s.moderation_status IN ('visible', 'restored');

-- 5d. Hardened Regional Trait Summary View (Findings 2, 3, 5):
--   - Enforces `k >= 5` unbreakably via `public.effective_min_aggregation_k()`.
--   - Groups strictly by immutable deck + descriptor identity
--     (`trait_deck_uuid`, `deck_version`, `trait_descriptor_uuid`, `input_type`,
--     `unit`) so incompatible deck versions, meanings, or units are NEVER mixed.
--   - Counts ONLY distinct verified, non-expired, consented, visible specimens
--     with a real non-null value matching `td.input_type` (`is_skipped = false`),
--     suppressing each reported trait/statistic individually when `< min_k`.
DROP VIEW IF EXISTS public.v_regional_trait_summary;
CREATE VIEW public.v_regional_trait_summary AS
WITH threshold AS (
  SELECT public.effective_min_aggregation_k() AS min_k
),
valid_observations AS (
  SELECT
    s.uuid              AS sample_uuid,
    s.crop_code,
    s.zone_uuid,
    d.uuid              AS trait_deck_uuid,
    d.version           AS deck_version,
    td.uuid             AS trait_descriptor_uuid,
    td.plant_part,
    td.code             AS descriptor_code,
    td.label            AS descriptor_label,
    td.input_type,
    td.unit,
    CASE WHEN td.input_type = 'numeric'       THEN tv.numeric_value ELSE NULL END AS valid_numeric_value,
    CASE WHEN td.input_type = 'single_choice' THEN tv.research_code ELSE NULL END AS valid_research_code
  FROM public.sample s
  JOIN public.trait_deck d
    ON d.uuid = s.trait_deck_uuid
   AND d.archived_at IS NULL
   AND d.published_at IS NOT NULL
  JOIN public.sample_trait_value tv
    ON tv.sample_uuid = s.uuid
   AND tv.archived_at IS NULL
   AND tv.is_skipped = false
  JOIN public.trait_descriptor td
    ON td.uuid = tv.trait_descriptor_uuid
   AND td.trait_deck_uuid = d.uuid
   AND td.archived_at IS NULL
  WHERE s.archived_at IS NULL
    AND s.staging_status = 'verified'
    AND (s.expires_at IS NULL OR s.expires_at > now())
    AND s.consent_status = 'opted_in'
    AND s.moderation_status IN ('visible', 'restored')
    AND (
      (td.input_type = 'numeric'       AND tv.numeric_value IS NOT NULL)
      OR
      (td.input_type = 'single_choice' AND tv.research_code IS NOT NULL)
    )
)
SELECT
  vo.crop_code,
  vo.zone_uuid,
  z.code                       AS zone_code,
  z.name                       AS zone_name,
  z.region_name,
  vo.trait_deck_uuid,
  vo.deck_version,
  vo.trait_descriptor_uuid,
  vo.plant_part,
  vo.descriptor_code,
  vo.descriptor_label,
  vo.input_type,
  vo.unit,
  COUNT(DISTINCT vo.sample_uuid) AS contributing_sample_count,
  CASE
    WHEN vo.input_type = 'numeric'
     AND COUNT(DISTINCT vo.sample_uuid) FILTER (WHERE vo.valid_numeric_value IS NOT NULL) >= (SELECT min_k FROM threshold)
    THEN AVG(vo.valid_numeric_value)
    ELSE NULL
  END AS avg_numeric_value,
  CASE
    WHEN vo.input_type = 'numeric'
     AND COUNT(DISTINCT vo.sample_uuid) FILTER (WHERE vo.valid_numeric_value IS NOT NULL) >= (SELECT min_k FROM threshold)
    THEN MIN(vo.valid_numeric_value)
    ELSE NULL
  END AS min_numeric_value,
  CASE
    WHEN vo.input_type = 'numeric'
     AND COUNT(DISTINCT vo.sample_uuid) FILTER (WHERE vo.valid_numeric_value IS NOT NULL) >= (SELECT min_k FROM threshold)
    THEN MAX(vo.valid_numeric_value)
    ELSE NULL
  END AS max_numeric_value,
  CASE
    WHEN vo.input_type = 'single_choice'
     AND COUNT(DISTINCT vo.sample_uuid) FILTER (WHERE vo.valid_research_code IS NOT NULL) >= (SELECT min_k FROM threshold)
    THEN MODE() WITHIN GROUP (ORDER BY vo.valid_research_code)
    ELSE NULL
  END AS modal_research_code
FROM valid_observations vo
LEFT JOIN public.zone z
  ON z.uuid = vo.zone_uuid AND z.archived_at IS NULL
GROUP BY
  vo.crop_code,
  vo.zone_uuid,
  z.code,
  z.name,
  z.region_name,
  vo.trait_deck_uuid,
  vo.deck_version,
  vo.trait_descriptor_uuid,
  vo.plant_part,
  vo.descriptor_code,
  vo.descriptor_label,
  vo.input_type,
  vo.unit
HAVING COUNT(DISTINCT vo.sample_uuid) >= (SELECT min_k FROM threshold);

-- Ensure public views execute with view-owner privileges (security_invoker = false)
-- so `anon`/`authenticated` can read ONLY the filtered, column-safe views while
-- base tables remain completely revoked from direct PostgREST access.
DO $$
DECLARE
  v_name text;
BEGIN
  FOREACH v_name IN ARRAY ARRAY[
    'v_public_crop',
    'v_public_zone',
    'v_public_trait_deck',
    'v_public_trait_descriptor',
    'v_public_trait_option',
    'v_public_privacy_disclosure',
    'v_explorer_sample',
    'v_explorer_sample_trait',
    'v_regional_trait_summary'
  ] LOOP
    BEGIN
      EXECUTE format('ALTER VIEW public.%I SET (security_invoker = false)', v_name);
    EXCEPTION WHEN invalid_parameter_value OR unrecognized_configuration_parameter THEN
      NULL;
    END;
  END LOOP;
END $$;

-- ============================================================================
-- 6. RLS POLICY HARDENING & POSTGREST GRANT LOCKDOWN (Finding 4)
-- ============================================================================

-- Tighten catalog RLS policies so even if a privileged policy-checking role
-- queries base tables, draft descriptors/options and future disclosures stay hidden.
DROP POLICY IF EXISTS trait_descriptor_public_read ON public.trait_descriptor;
CREATE POLICY trait_descriptor_public_read ON public.trait_descriptor
  FOR SELECT USING (
    archived_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM   public.trait_deck d
      WHERE  d.uuid = trait_descriptor.trait_deck_uuid
        AND  d.archived_at IS NULL
        AND  d.published_at IS NOT NULL
    )
  );

DROP POLICY IF EXISTS trait_option_public_read ON public.trait_option;
CREATE POLICY trait_option_public_read ON public.trait_option
  FOR SELECT USING (
    archived_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM   public.trait_descriptor td
      JOIN   public.trait_deck d
        ON   d.uuid = td.trait_deck_uuid
      WHERE  td.uuid = trait_option.trait_descriptor_uuid
        AND  td.archived_at IS NULL
        AND  d.archived_at IS NULL
        AND  d.published_at IS NOT NULL
    )
  );

DROP POLICY IF EXISTS privacy_disclosure_public_read ON public.privacy_disclosure;
CREATE POLICY privacy_disclosure_public_read ON public.privacy_disclosure
  FOR SELECT USING (
    archived_at IS NULL
    AND effective_at <= now()
  );

-- Lock down direct base-table & maintenance-function privileges from PUBLIC,
-- `anon`, and `authenticated`, and grant SELECT strictly on safe public views.
-- Guarded by `pg_roles` checks so the migration runs cleanly on both Supabase
-- and vanilla PostgreSQL test environments.
DO $$
DECLARE
  v_role  text;
  v_table text;
  v_view  text;
BEGIN
  -- Always revoke from PUBLIC first.
  FOREACH v_table IN ARRAY ARRAY[
    'account', 'system_setting', 'zone', 'crop',
    'trait_deck', 'trait_descriptor', 'trait_option',
    'field_session', 'sample', 'sample_trait_value',
    'consent_record', 'sample_flag', 'guideline_hit', 'privacy_disclosure'
  ] LOOP
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC', v_table);
  END LOOP;

  REVOKE ALL ON FUNCTION public.cleanup_expired_staging(integer, integer) FROM PUBLIC;
  REVOKE ALL ON FUNCTION public.get_clamped_int_setting(text, text, integer, integer) FROM PUBLIC;
  REVOKE ALL ON FUNCTION public.effective_min_aggregation_k() FROM PUBLIC;

  FOREACH v_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_role) THEN
      FOREACH v_table IN ARRAY ARRAY[
        'account', 'system_setting', 'zone', 'crop',
        'trait_deck', 'trait_descriptor', 'trait_option',
        'field_session', 'sample', 'sample_trait_value',
        'consent_record', 'sample_flag', 'guideline_hit', 'privacy_disclosure'
      ] LOOP
        EXECUTE format('REVOKE ALL ON TABLE public.%I FROM %I', v_table, v_role);
      END LOOP;

      EXECUTE format('REVOKE ALL ON FUNCTION public.cleanup_expired_staging(integer, integer) FROM %I', v_role);
      EXECUTE format('REVOKE ALL ON FUNCTION public.get_clamped_int_setting(text, text, integer, integer) FROM %I', v_role);
      EXECUTE format('REVOKE ALL ON FUNCTION public.effective_min_aggregation_k() FROM %I', v_role);

      FOREACH v_view IN ARRAY ARRAY[
        'v_public_crop',
        'v_public_zone',
        'v_public_trait_deck',
        'v_public_trait_descriptor',
        'v_public_trait_option',
        'v_public_privacy_disclosure',
        'v_explorer_sample',
        'v_explorer_sample_trait',
        'v_regional_trait_summary'
      ] LOOP
        EXECUTE format('REVOKE ALL ON TABLE public.%I FROM %I', v_view, v_role);
        EXECUTE format('GRANT SELECT ON TABLE public.%I TO %I', v_view, v_role);
      END LOOP;
    END IF;
  END LOOP;

  -- Preserve explicit `service_role` access for `agora-ping-api` on Supabase.
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.cleanup_expired_staging(integer, integer) TO service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.effective_min_aggregation_k() TO service_role';
  END IF;
END $$;

COMMIT;
