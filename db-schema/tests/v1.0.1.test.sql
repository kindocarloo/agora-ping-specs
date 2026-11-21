-- ============================================================================
-- agora-ping — Reproducible PostgreSQL Validation Suite for v1.0.0 -> v1.0.1
-- ============================================================================
-- Usage (against an ISOLATED disposable test database — NEVER run on prod):
--   psql "$TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f agora-ping-specs/db-schema/tests/v1.0.1.test.sql
--
-- Covers:
--   T1. Fresh install (`v1.0.0.sql` + `v1.0.1.sql`) and idempotent reruns.
--   T2. Existing-data upgrade behavior (pre-v1.0.1 verified vs staging rows).
--   T3. Published-deck immutability, reparenting, missing parent, delete, & retirement.
--   T4. Five-sample bucket with only 1 non-null trait observation + skipped rows.
--   T5. Invalid and below-minimum `min_aggregation_k` settings + hard floor k >= 5.
--   T6. Incompatible deck versions & units (kg vs g) split + reapplied k >= 5.
--   T7. Anonymous & authenticated reads of draft catalogs, base tables, & public views.
--   T8. Expired staging exclusion, 7-day expiry enforcement, & bounded cleanup tombstones.
--   T9. Integrity safeguards: out-of-order sync, deck mismatch on verify, consent
--       withdrawal propagation, 3-flag auto-hide + private hit + 3-hit hold, & revision guard.
-- ============================================================================

\set ON_ERROR_STOP on

-- Ensure Supabase-equivalent roles exist in a vanilla disposable PostgreSQL test DB.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- T1 & T2: Fresh v1.0.0 install -> seed pre-upgrade rows -> apply v1.0.1 -> rerun
-- ----------------------------------------------------------------------------
\i agora-ping-specs/db-schema/v1.0.0.sql

-- Simulate pre-v1.0.1 existing data (one live row with NULL expires_at,
-- one staging row with expires_at set, and a pre-existing broken setting).
DO $$
DECLARE
  v_crop_cas  uuid;
  v_zone      uuid := '00000000-0000-4000-8000-000000000101';
  v_deck      uuid := '00000000-0000-4000-8000-000000000201';
  v_desc      uuid := '00000000-0000-4000-8000-000000000301';
  v_s_live    uuid := '00000000-0000-4000-8000-000000000401';
  v_s_stage   uuid := '00000000-0000-4000-8000-000000000402';
  v_old_stamp timestamptz := '2026-10-01T00:00:00Z';
BEGIN
  SELECT uuid INTO v_crop_cas FROM public.crop WHERE code = 'CAS' AND archived_at IS NULL;

  INSERT INTO public.zone (uuid, code, name, region_name)
  VALUES (v_zone, 'TEST-Z1', 'Baybay Test Zone', 'Region VIII')
  ON CONFLICT (uuid) DO NOTHING;

  INSERT INTO public.trait_deck (uuid, crop_uuid, crop_code, version, source_guide, published_at)
  VALUES (v_deck, v_crop_cas, 'CAS', '0.9-pre', 'Upgrade Test Guide', now())
  ON CONFLICT (uuid) DO NOTHING;

  INSERT INTO public.sample (
    uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
    observed_date, qr_payload, revision, consent_status, moderation_status,
    expires_at, created_at, updated_at
  ) VALUES (
    v_s_live, v_crop_cas, 'CAS', v_deck, '0.9-pre', v_zone,
    '2026-10-01', 'AP1|' || v_s_live || '|CAS|2026-10-01', 1, 'opted_in', 'visible',
    NULL, v_old_stamp, v_old_stamp
  ) ON CONFLICT (uuid) DO NOTHING;

  INSERT INTO public.sample (
    uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
    observed_date, qr_payload, revision, consent_status, moderation_status,
    expires_at, created_at, updated_at
  ) VALUES (
    v_s_stage, v_crop_cas, 'CAS', v_deck, '0.9-pre', v_zone,
    '2026-10-01', 'AP1|' || v_s_stage || '|CAS|2026-10-01', 1, 'opted_in', 'visible',
    now() + interval '3 days', v_old_stamp, v_old_stamp
  ) ON CONFLICT (uuid) DO NOTHING;

  -- Corrupt min_aggregation_k before upgrade to verify safe normalization.
  UPDATE public.system_setting
  SET    value = '2'
  WHERE  feature = 'privacy' AND name = 'min_aggregation_k' AND archived_at IS NULL;
END $$;

-- Apply v1.0.1 twice to prove upgrade + idempotency.
\i agora-ping-specs/db-schema/v1.0.1.sql
\i agora-ping-specs/db-schema/v1.0.1.sql

-- All remaining assertions run inside a single rolled-back transaction so the
-- test database stays completely clean after verification.
BEGIN;

-- Verify T2 upgrade results:
DO $$
DECLARE
  v_live_status   public.staging_status;
  v_live_updated  timestamptz;
  v_stage_status  public.staging_status;
  v_k             integer;
BEGIN
  SELECT staging_status, updated_at INTO v_live_status, v_live_updated
  FROM public.sample WHERE uuid = '00000000-0000-4000-8000-000000000401';
  IF v_live_status <> 'verified' THEN
    RAISE EXCEPTION 'T2 FAILED: pre-upgrade non-expiring sample must backfill to verified (got %)', v_live_status;
  END IF;
  IF v_live_updated <> '2026-10-01T00:00:00Z'::timestamptz THEN
    RAISE EXCEPTION 'T2 FAILED: backfill must not clobber updated_at (got %)', v_live_updated;
  END IF;

  SELECT staging_status INTO v_stage_status
  FROM public.sample WHERE uuid = '00000000-0000-4000-8000-000000000402';
  IF v_stage_status <> 'staging' THEN
    RAISE EXCEPTION 'T2 FAILED: pre-upgrade expiring sample must remain staging (got %)', v_stage_status;
  END IF;

  SELECT public.effective_min_aggregation_k() INTO v_k;
  IF v_k <> 5 THEN
    RAISE EXCEPTION 'T2 FAILED: corrupted min_aggregation_k=2 must normalize to 5 (got %)', v_k;
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- T3: Published-deck immutability, reparenting, missing parent, delete, retire
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_crop_cas    uuid;
  v_deck_pub    uuid := '10000000-0000-4000-8000-000000000001';
  v_deck_draft  uuid := '10000000-0000-4000-8000-000000000002';
  v_desc_pub    uuid := '10000000-0000-4000-8000-000000000011';
  v_desc_draft  uuid := '10000000-0000-4000-8000-000000000012';
  v_opt_pub     uuid := '10000000-0000-4000-8000-000000000021';
  v_blocked     boolean;
BEGIN
  SELECT uuid INTO v_crop_cas FROM public.crop WHERE code = 'CAS' AND archived_at IS NULL;

  -- Inserting pre-published deck must fail.
  v_blocked := false;
  BEGIN
    INSERT INTO public.trait_deck (uuid, crop_uuid, crop_code, version, source_guide, published_at)
    VALUES (gen_random_uuid(), v_crop_cas, 'CAS', 'bad-1.0', 'Test', now());
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: direct insert of published deck should fail'; END IF;

  -- Create draft deck + descriptor + option, then publish.
  INSERT INTO public.trait_deck (uuid, crop_uuid, crop_code, version, source_guide)
  VALUES (v_deck_pub, v_crop_cas, 'CAS', '1.0-t3', 'IITA 2010'),
         (v_deck_draft, v_crop_cas, 'CAS', '1.1-draft', 'IITA Draft');

  -- Publishing empty deck must fail.
  v_blocked := false;
  BEGIN
    UPDATE public.trait_deck SET published_at = now() WHERE uuid = v_deck_pub;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: publishing empty deck should fail'; END IF;

  INSERT INTO public.trait_descriptor (uuid, trait_deck_uuid, plant_part, code, label, input_type, rank)
  VALUES (v_desc_pub, v_deck_pub, 'foliage', 'leaf_color', 'Leaf Color', 'single_choice', 1),
         (v_desc_draft, v_deck_draft, 'foliage', 'leaf_color', 'Leaf Color Draft', 'single_choice', 1);

  -- Publishing single_choice deck without options must fail.
  v_blocked := false;
  BEGIN
    UPDATE public.trait_deck SET published_at = now() WHERE uuid = v_deck_pub;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: publishing single_choice deck without options should fail'; END IF;

  INSERT INTO public.trait_option (uuid, trait_descriptor_uuid, research_code, label, rank)
  VALUES (v_opt_pub, v_desc_pub, 3, 'Dark Green', 1);

  UPDATE public.trait_deck SET published_at = now() WHERE uuid = v_deck_pub;

  -- Attempt 1: clear published_at -> MUST FAIL.
  v_blocked := false;
  BEGIN
    UPDATE public.trait_deck SET published_at = NULL WHERE uuid = v_deck_pub;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: clearing published_at must fail'; END IF;

  -- Attempt 2: mutate version/source_guide -> MUST FAIL.
  v_blocked := false;
  BEGIN
    UPDATE public.trait_deck SET version = '9.9' WHERE uuid = v_deck_pub;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: mutating published deck version must fail'; END IF;

  -- Attempt 3: delete published deck -> MUST FAIL.
  v_blocked := false;
  BEGIN
    DELETE FROM public.trait_deck WHERE uuid = v_deck_pub;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: deleting published deck must fail'; END IF;

  -- Attempt 4: reparent descriptor from published deck to draft deck -> MUST FAIL.
  v_blocked := false;
  BEGIN
    UPDATE public.trait_descriptor SET trait_deck_uuid = v_deck_draft WHERE uuid = v_desc_pub;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: reparenting descriptor out of published deck must fail'; END IF;

  -- Attempt 5: reparent descriptor from draft deck into published deck -> MUST FAIL.
  v_blocked := false;
  BEGIN
    UPDATE public.trait_descriptor SET trait_deck_uuid = v_deck_pub WHERE uuid = v_desc_draft;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: reparenting descriptor into published deck must fail'; END IF;

  -- Attempt 6: reparent option out of published descriptor to draft descriptor -> MUST FAIL.
  v_blocked := false;
  BEGIN
    UPDATE public.trait_option SET trait_descriptor_uuid = v_desc_draft WHERE uuid = v_opt_pub;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: reparenting option out of published deck must fail'; END IF;

  -- Attempt 7: missing parent descriptor/deck -> MUST FAIL.
  v_blocked := false;
  BEGIN
    INSERT INTO public.trait_descriptor (uuid, trait_deck_uuid, plant_part, code, label, input_type)
    VALUES (gen_random_uuid(), gen_random_uuid(), 'foliage', 'orphan', 'Orphan', 'numeric');
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: missing parent trait_deck must fail'; END IF;

  -- Attempt 8: deliberate retirement -> MUST SUCCEED, then unretire -> MUST FAIL.
  UPDATE public.trait_deck SET retired_at = now(), updated_at = now() WHERE uuid = v_deck_pub;
  v_blocked := false;
  BEGIN
    UPDATE public.trait_deck SET retired_at = NULL WHERE uuid = v_deck_pub;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T3 FAILED: clearing retired_at must fail'; END IF;
END $$;

-- ----------------------------------------------------------------------------
-- T4, T5 & T6: Privacy floor (k >= 5), per-trait suppression, invalid settings,
--              and incompatible deck versions/units (kg vs g)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_crop_cas   uuid;
  v_zone_agg   uuid := '20000000-0000-4000-8000-000000000001';
  v_deck_v1    uuid := '20000000-0000-4000-8000-000000000011';
  v_deck_v2    uuid := '20000000-0000-4000-8000-000000000012';
  v_d1_yield   uuid := '20000000-0000-4000-8000-000000000021';
  v_d1_color   uuid := '20000000-0000-4000-8000-000000000022';
  v_d2_yield   uuid := '20000000-0000-4000-8000-000000000023';
  v_s_uuid     uuid;
  v_cnt        integer;
  v_avg        numeric;
  v_blocked    boolean;
  i            integer;
BEGIN
  SELECT uuid INTO v_crop_cas FROM public.crop WHERE code = 'CAS' AND archived_at IS NULL;

  -- T5: Invalid & below-minimum privacy settings must be rejected on write.
  FOREACH v_avg IN ARRAY ARRAY[4, 0, -1] LOOP
    v_blocked := false;
    BEGIN
      UPDATE public.system_setting SET value = v_avg::text
      WHERE feature = 'privacy' AND name = 'min_aggregation_k' AND archived_at IS NULL;
    EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
    IF NOT v_blocked THEN RAISE EXCEPTION 'T5 FAILED: min_aggregation_k=% must be rejected', v_avg; END IF;
  END LOOP;

  v_blocked := false;
  BEGIN
    UPDATE public.system_setting SET value = 'not-a-number'
    WHERE feature = 'privacy' AND name = 'min_aggregation_k' AND archived_at IS NULL;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T5 FAILED: non-numeric min_aggregation_k must be rejected'; END IF;

  INSERT INTO public.zone (uuid, code, name, region_name)
  VALUES (v_zone_agg, 'TEST-AGG', 'Agg Test Zone', 'Region VIII');

  -- Deck v1 (root_yield in kg + leaf_color choice) and Deck v2 (root_yield in g).
  INSERT INTO public.trait_deck (uuid, crop_uuid, crop_code, version, source_guide)
  VALUES (v_deck_v1, v_crop_cas, 'CAS', '1.0-agg', 'Guide v1'),
         (v_deck_v2, v_crop_cas, 'CAS', '2.0-agg', 'Guide v2');

  INSERT INTO public.trait_descriptor (uuid, trait_deck_uuid, plant_part, code, label, input_type, unit, min_value, max_value, rank)
  VALUES (v_d1_yield, v_deck_v1, 'storage_root_corm', 'root_yield', 'Root Yield', 'numeric', 'kg', 0, 100, 1),
         (v_d1_color, v_deck_v1, 'foliage',           'leaf_color', 'Leaf Color', 'single_choice', NULL, NULL, NULL, 2),
         (v_d2_yield, v_deck_v2, 'storage_root_corm', 'root_yield', 'Root Yield', 'numeric', 'g',  0, 100000, 1);

  INSERT INTO public.trait_option (uuid, trait_descriptor_uuid, research_code, label, rank)
  VALUES (gen_random_uuid(), v_d1_color, 3, 'Dark Green', 1);

  UPDATE public.trait_deck SET published_at = now() WHERE uuid IN (v_deck_v1, v_deck_v2);

  -- T4: Insert 5 verified specimens on Deck v1:
  --   All 5 observe leaf_color = 3 -> MUST appear in summary (contributing_sample_count = 5).
  --   Only 1 observes root_yield = 10 kg; 4 skip root_yield (is_skipped = true) -> MUST BE SUPPRESSED!
  FOR i IN 1..5 LOOP
    v_s_uuid := gen_random_uuid();
    INSERT INTO public.sample (
      uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
      observed_date, qr_payload, revision, consent_status, moderation_status,
      staging_status, verified_at
    ) VALUES (
      v_s_uuid, v_crop_cas, 'CAS', v_deck_v1, '1.0-agg', v_zone_agg,
      '2026-11-22', 'AP1|' || v_s_uuid || '|CAS|2026-11-22', 1, 'opted_in', 'visible',
      'verified', now()
    );

    INSERT INTO public.sample_trait_value (
      uuid, sample_uuid, trait_descriptor_uuid, descriptor_code, plant_part, research_code, is_skipped
    ) VALUES (
      gen_random_uuid(), v_s_uuid, v_d1_color, 'leaf_color', 'foliage', 3, false
    );

    IF i = 1 THEN
      INSERT INTO public.sample_trait_value (
        uuid, sample_uuid, trait_descriptor_uuid, descriptor_code, plant_part, numeric_value, is_skipped
      ) VALUES (
        gen_random_uuid(), v_s_uuid, v_d1_yield, 'root_yield', 'storage_root_corm', 10.0, false
      );
    ELSE
      INSERT INTO public.sample_trait_value (
        uuid, sample_uuid, trait_descriptor_uuid, descriptor_code, plant_part, is_skipped
      ) VALUES (
        gen_random_uuid(), v_s_uuid, v_d1_yield, 'root_yield', 'storage_root_corm', true
      );
    END IF;
  END LOOP;

  -- T6: Insert 4 verified specimens on Deck v2 with root_yield = 9000 g.
  --   Combined across v1 (1) + v2 (4) would equal 5 if improperly merged,
  --   but MUST stay split by deck/unit and BOTH stay suppressed (< 5 each)!
  FOR i IN 1..4 LOOP
    v_s_uuid := gen_random_uuid();
    INSERT INTO public.sample (
      uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
      observed_date, qr_payload, revision, consent_status, moderation_status,
      staging_status, verified_at
    ) VALUES (
      v_s_uuid, v_crop_cas, 'CAS', v_deck_v2, '2.0-agg', v_zone_agg,
      '2026-11-22', 'AP1|' || v_s_uuid || '|CAS|2026-11-22', 1, 'opted_in', 'visible',
      'verified', now()
    );

    INSERT INTO public.sample_trait_value (
      uuid, sample_uuid, trait_descriptor_uuid, descriptor_code, plant_part, numeric_value, is_skipped
    ) VALUES (
      gen_random_uuid(), v_s_uuid, v_d2_yield, 'root_yield', 'storage_root_corm', 9000.0, false
    );
  END LOOP;

  -- Assert leaf_color appears with count = 5 and modal_research_code = 3.
  SELECT COUNT(*) INTO v_cnt
  FROM public.v_regional_trait_summary
  WHERE zone_uuid = v_zone_agg AND trait_descriptor_uuid = v_d1_color AND contributing_sample_count = 5 AND modal_research_code = 3;
  IF v_cnt <> 1 THEN RAISE EXCEPTION 'T4 FAILED: leaf_color (5 observations) must appear in summary'; END IF;

  -- Assert root_yield is suppressed for BOTH v1 (1 non-null) and v2 (4 non-null).
  SELECT COUNT(*) INTO v_cnt
  FROM public.v_regional_trait_summary
  WHERE zone_uuid = v_zone_agg AND descriptor_code = 'root_yield';
  IF v_cnt <> 0 THEN RAISE EXCEPTION 'T4/T6 FAILED: root_yield must be suppressed (1 in kg, 4 in g; got % rows)', v_cnt; END IF;

  -- Add 5th specimen on Deck v2 (9000 g) -> now ONLY Deck v2 (g) should appear with avg = 9000, NEVER mixed with 10 kg!
  v_s_uuid := gen_random_uuid();
  INSERT INTO public.sample (
    uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
    observed_date, qr_payload, revision, consent_status, moderation_status,
    staging_status, verified_at
  ) VALUES (
    v_s_uuid, v_crop_cas, 'CAS', v_deck_v2, '2.0-agg', v_zone_agg,
    '2026-11-22', 'AP1|' || v_s_uuid || '|CAS|2026-11-22', 1, 'opted_in', 'visible',
    'verified', now()
  );
  INSERT INTO public.sample_trait_value (
    uuid, sample_uuid, trait_descriptor_uuid, descriptor_code, plant_part, numeric_value, is_skipped
  ) VALUES (
    gen_random_uuid(), v_s_uuid, v_d2_yield, 'root_yield', 'storage_root_corm', 9000.0, false
  );

  SELECT avg_numeric_value INTO v_avg
  FROM public.v_regional_trait_summary
  WHERE zone_uuid = v_zone_agg AND trait_descriptor_uuid = v_d2_yield AND unit = 'g';
  IF v_avg IS DISTINCT FROM 9000.0 THEN
    RAISE EXCEPTION 'T6 FAILED: Deck v2 root_yield average must be 9000.0 g (uncontaminated by kg; got %)', v_avg;
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- T7: Anonymous / authenticated reads of draft catalogs, base tables, & views
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_role    text;
  v_blocked boolean;
  v_cnt     integer;
BEGIN
  FOREACH v_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    EXECUTE format('SET LOCAL ROLE %I', v_role);

    -- Direct base-table reads MUST fail (hides server `id`, `created_by`, drafts, private tables).
    v_blocked := false;
    BEGIN EXECUTE 'SELECT id FROM public.trait_descriptor LIMIT 1'; EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END;
    IF NOT v_blocked THEN RAISE EXCEPTION 'T7 FAILED: % must not SELECT public.trait_descriptor directly', v_role; END IF;

    v_blocked := false;
    BEGIN EXECUTE 'SELECT id FROM public.guideline_hit LIMIT 1'; EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END;
    IF NOT v_blocked THEN RAISE EXCEPTION 'T7 FAILED: % must not SELECT public.guideline_hit directly', v_role; END IF;

    v_blocked := false;
    BEGIN EXECUTE 'SELECT id, created_by FROM public.crop LIMIT 1'; EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END;
    IF NOT v_blocked THEN RAISE EXCEPTION 'T7 FAILED: % must not SELECT public.crop directly (exposes id/created_by)', v_role; END IF;

    v_blocked := false;
    BEGIN EXECUTE 'SELECT * FROM public.cleanup_expired_staging()'; EXCEPTION WHEN insufficient_privilege THEN v_blocked := true; END;
    IF NOT v_blocked THEN RAISE EXCEPTION 'T7 FAILED: % must not EXECUTE cleanup_expired_staging', v_role; END IF;

    -- Safe public views MUST succeed and exclude draft deck `1.1-draft`.
    SELECT COUNT(*) INTO v_cnt FROM public.v_public_crop;
    IF v_cnt < 4 THEN RAISE EXCEPTION 'T7 FAILED: % should read v_public_crop', v_role; END IF;

    SELECT COUNT(*) INTO v_cnt FROM public.v_public_trait_descriptor WHERE deck_version = '1.1-draft';
    IF v_cnt <> 0 THEN RAISE EXCEPTION 'T7 FAILED: draft descriptors leaked to % in v_public_trait_descriptor', v_role; END IF;

    RESET ROLE;
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- T8 & T9: Staging expiry & cleanup, out-of-order sync, consent withdrawal,
--          moderation auto-hide + private hit + 3-hit hold, & revision guard
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_crop_cas   uuid;
  v_zone_t8    uuid := '20000000-0000-4000-8000-000000000001';
  v_deck_v1    uuid := '20000000-0000-4000-8000-000000000011';
  v_d1_color   uuid := '20000000-0000-4000-8000-000000000022';
  v_acct_owner uuid := '30000000-0000-4000-8000-000000000001';
  v_acct_f1    uuid := '30000000-0000-4000-8000-000000000002';
  v_acct_f2    uuid := '30000000-0000-4000-8000-000000000003';
  v_acct_f3    uuid := '30000000-0000-4000-8000-000000000004';
  v_s_expired  uuid := '30000000-0000-4000-8000-000000000101';
  v_s_ooo      uuid := '30000000-0000-4000-8000-000000000102';
  v_s_mod      uuid := '30000000-0000-4000-8000-000000000103';
  v_res        record;
  v_cnt        integer;
  v_status     public.moderation_status;
  v_consent    public.consent_status;
  v_blocked    boolean;
BEGIN
  SELECT uuid INTO v_crop_cas FROM public.crop WHERE code = 'CAS' AND archived_at IS NULL;

  INSERT INTO public.account (uuid, role)
  VALUES (v_acct_owner, 'researcher'), (v_acct_f1, 'researcher'),
         (v_acct_f2, 'researcher'),    (v_acct_f3, 'researcher');

  -- T8: Insert expired staging sample (created 10 days ago) + dependent trait value.
  INSERT INTO public.sample (
    uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
    observed_date, qr_payload, revision, consent_status, moderation_status,
    staging_status, created_by, created_at, updated_at
  ) VALUES (
    v_s_expired, v_crop_cas, 'CAS', v_deck_v1, '1.0-agg', v_zone_t8,
    '2026-11-10', 'AP1|' || v_s_expired || '|CAS|2026-11-10', 1, 'opted_in', 'visible',
    'staging', v_acct_owner, now() - interval '10 days', now() - interval '10 days'
  );
  INSERT INTO public.sample_trait_value (
    uuid, sample_uuid, trait_descriptor_uuid, descriptor_code, plant_part, research_code, is_skipped
  ) VALUES (
    gen_random_uuid(), v_s_expired, v_d1_color, 'leaf_color', 'foliage', 3, false
  );

  -- Must NOT appear in Explorer!
  SELECT COUNT(*) INTO v_cnt FROM public.v_explorer_sample WHERE sample_uuid = v_s_expired;
  IF v_cnt <> 0 THEN RAISE EXCEPTION 'T8 FAILED: expired staging sample appeared in v_explorer_sample'; END IF;

  -- Bounded cleanup must tombstone both sample and dependent trait value.
  SELECT * INTO v_res FROM public.cleanup_expired_staging(100, 30);
  IF v_res.archived_samples < 1 OR v_res.archived_trait_values < 1 THEN
    RAISE EXCEPTION 'T8 FAILED: cleanup_expired_staging did not archive sample & trait value (%)', v_res;
  END IF;

  -- T9a: Out-of-order offline sync (trait value arrives BEFORE parent sample).
  INSERT INTO public.sample_trait_value (
    uuid, sample_uuid, trait_descriptor_uuid, descriptor_code, plant_part, research_code, is_skipped
  ) VALUES (
    gen_random_uuid(), v_s_ooo, v_d1_color, 'leaf_color', 'foliage', 3, false
  );
  INSERT INTO public.sample (
    uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
    observed_date, qr_payload, revision, consent_status, moderation_status,
    staging_status, verified_at, created_by
  ) VALUES (
    v_s_ooo, v_crop_cas, 'CAS', v_deck_v1, '1.0-agg', v_zone_t8,
    '2026-11-22', 'AP1|' || v_s_ooo || '|CAS|2026-11-22', 2, 'opted_in', 'visible',
    'verified', now(), v_acct_owner
  );

  -- Revision regression must fail.
  v_blocked := false;
  BEGIN
    UPDATE public.sample SET revision = 1 WHERE uuid = v_s_ooo;
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T9 FAILED: sample revision regression must fail'; END IF;

  -- T9b: Consent withdrawal propagation.
  INSERT INTO public.consent_record (account_uuid, sample_uuid, consent_scope, policy_version, revoked_at, revoked_by)
  VALUES (v_acct_owner, v_s_ooo, 'community_share', '1.0', now(), v_acct_owner);
  SELECT consent_status INTO v_consent FROM public.sample WHERE uuid = v_s_ooo;
  IF v_consent <> 'withdrawn' THEN RAISE EXCEPTION 'T9 FAILED: consent withdrawal did not propagate to sample'; END IF;

  -- T9c: 3 distinct peer flags auto-hide sample and issue private guideline_hit.
  INSERT INTO public.sample (
    uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
    observed_date, qr_payload, revision, consent_status, moderation_status,
    staging_status, verified_at, created_by
  ) VALUES (
    v_s_mod, v_crop_cas, 'CAS', v_deck_v1, '1.0-agg', v_zone_t8,
    '2026-11-22', 'AP1|' || v_s_mod || '|CAS|2026-11-22', 1, 'opted_in', 'visible',
    'verified', now(), v_acct_owner
  );

  -- Self-flagging must fail.
  v_blocked := false;
  BEGIN
    INSERT INTO public.sample_flag (sample_uuid, flagged_by, reason)
    VALUES (v_s_mod, v_acct_owner, 'misclassified_crop');
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T9 FAILED: owner self-flagging must fail'; END IF;

  INSERT INTO public.sample_flag (sample_uuid, flagged_by, reason) VALUES
    (v_s_mod, v_acct_f1, 'misclassified_crop'),
    (v_s_mod, v_acct_f2, 'misclassified_crop'),
    (v_s_mod, v_acct_f3, 'malformed_traits');

  SELECT moderation_status INTO v_status FROM public.sample WHERE uuid = v_s_mod;
  IF v_status <> 'auto_hidden' THEN RAISE EXCEPTION 'T9 FAILED: 3 distinct flags must auto-hide sample (got %)', v_status; END IF;

  SELECT COUNT(*) INTO v_cnt FROM public.guideline_hit WHERE sample_uuid = v_s_mod AND status = 'pending_review';
  IF v_cnt <> 1 THEN RAISE EXCEPTION 'T9 FAILED: auto-hide must issue 1 pending_review private guideline_hit'; END IF;

  -- Confirm 3 private guideline hits trigger private publishing_hold_until on account.
  UPDATE public.guideline_hit SET status = 'confirmed', reviewed_at = now() WHERE sample_uuid = v_s_mod;
  INSERT INTO public.guideline_hit (account_uuid, sample_uuid, status, reason, reviewed_at) VALUES
    (v_acct_owner, gen_random_uuid(), 'confirmed', 'Test hit 2', now()),
    (v_acct_owner, gen_random_uuid(), 'confirmed', 'Test hit 3', now());
  SELECT COUNT(*) INTO v_cnt FROM public.account
  WHERE uuid = v_acct_owner AND publishing_hold_until > now();
  IF v_cnt <> 1 THEN RAISE EXCEPTION 'T9 FAILED: 3 confirmed guideline hits must set publishing_hold_until'; END IF;

  -- T9d: Cross-deck trait mismatch must fail when verifying an out-of-order sample.
  v_blocked := false;
  BEGIN
    INSERT INTO public.sample_trait_value (
      uuid, sample_uuid, trait_descriptor_uuid, descriptor_code, plant_part, numeric_value, is_skipped
    ) VALUES (
      gen_random_uuid(), '30000000-0000-4000-8000-000000000199', '20000000-0000-4000-8000-000000000023',
      'root_yield', 'storage_root_corm', 5000.0, false
    );
    INSERT INTO public.sample (
      uuid, crop_uuid, crop_code, trait_deck_uuid, deck_version, zone_uuid,
      observed_date, qr_payload, revision, consent_status, moderation_status,
      staging_status, verified_at, created_by
    ) VALUES (
      '30000000-0000-4000-8000-000000000199', v_crop_cas, 'CAS', v_deck_v1, '1.0-agg', v_zone_t8,
      '2026-11-22', 'AP1|30000000-0000-4000-8000-000000000199|CAS|2026-11-22', 1, 'opted_in', 'visible',
      'verified', now(), v_acct_owner
    );
  EXCEPTION WHEN OTHERS THEN v_blocked := true; END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'T9 FAILED: verifying sample with cross-deck trait value must fail'; END IF;

  -- T8b: Physical purge of staging tombstones older than grace window.
  UPDATE public.sample SET archived_at = now() - interval '35 days' WHERE uuid = v_s_expired;
  SELECT * INTO v_res FROM public.cleanup_expired_staging(100, 30);
  IF v_res.purged_samples < 1 THEN
    RAISE EXCEPTION 'T8 FAILED: cleanup_expired_staging must physically purge tombstones past 30-day grace window';
  END IF;
END $$;

ROLLBACK;
