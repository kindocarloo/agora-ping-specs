# 13 — Dependencies

**Purpose:** Dependency selection policy, confirmed platform stack and external services, upgrade traps, and deliberate rejections.

**Confidence note:** verified against updated `agora-ping-specs/business-logic-v1.0.md` on 2026-11-22. **Zero package manifests (`package.json`, `build.gradle*`, etc.) exist in any repo yet**, so this records confirmed stack/service choices from `business-logic-v1.0.md` and dependency policy. Populate exact versions and library upgrade traps when repos are scaffolded. The code wins (see 16 #7).

---

## Policy

1. **No dependency without a reason.** Justify every runtime library in PR review and document cross-repo coupling, security surface, or upgrade traps here.
2. **Respect privacy by design (`business-logic-v1.0.md`):** Reject third-party analytics, telemetry, or location SDKs that automatically record per-user movement trails or transmit raw GPS coordinates/identifiers without Data Privacy Act compliance and consent (see 09, 16 #3).
3. **Offline-first Android requirement:** Core trait logging, validation, and CSV/JSON export in `agora-ping-android` must never require a network-dependent SDK at runtime.
4. **Commit scope:** Use `deps:` only for cross-repo dependency updates; use `<product>:` for single-repo dependency updates (`git-guidelines.md` lines 94–113).

---

## Confirmed Stack & External Dependencies (Verified from `business-logic-v1.0.md` & Git Config)

| Dependency / Platform | Surface | Why It Exists | Status / Notes |
|---|---|---|---|
| **Kotlin** | `agora-ping-android` | Chosen Android language for offline-first field wizard, QR labeling/scanning, & CSV/JSON export | Confirmed in `business-logic-v1.1.md`; Gradle manifest TBD. |
| **Next.js** | `agora-ping-web` | Chosen Web framework for community explorer, moderation UI, and regulatory/aggregated trait portal | Confirmed in `business-logic-v1.1.md`; `package.json` TBD. |
| **TypeScript (Node/Edge API)** | `agora-ping-api` | Confirmed API runtime sharing Zod/TS schemas with Next.js and Supabase SDK | Confirmed in `business-logic-v1.1.md`; `package.json` TBD. |
| **Supabase** | `agora-ping-api` (backend data layer) | Backing persistence/platform for synced anonymized samples, versioned trait decks, moderation hits, and aggregated regional data | Confirmed in `business-logic-v1.1.md`; keep service-role keys strictly server-side (see 09). |
| **Google Sign-In** | `agora-ping-web`, `agora-ping-android`, `agora-ping-api` | Mandated user authentication for online sync, publishing, flagging, and admin actions | Confirmed in `business-logic-v1.0.md`; verify ID tokens server-side. |
| **Statistical Export Targets (R, Weka, STAR)** | `agora-ping-android` output format | Target downstream statistical tools for exported CSV/JSON tables | Format compatibility constraint (not runtime libraries); encode categorical descriptors consistently. |
| **GitHub (`kindocarloo/agora-ping-*`)** | All 4 repos | Source control, SSH remotes, release tags | Active; initial `main` branches pushed on 2026-11-22. |

---

## Upgrade Traps & Deliberate Rejections

- **Upgrade traps:** None recorded yet (0 package manifests installed).
- **Deliberate rejections (verified from `business-logic-v1.1.md`):**
  - **Non-Web / non-Android client platforms** — Excluded by `Allowed Platforms: Web, Android`.
  - **Custom Bluetooth / thermal printer SDKs** — Rejected for MVP; all printable PNG/PDF QR labels use Android's native share/print sheet.
  - **Crop photo storage / ML classification SDKs** — Rejected for MVP; camera permission is QR-scanning only.
  - **Payment / credit / reward SDKs** — Banned by the **Zero Financial Bait** constraint.
  - **Public reputation / gamification leaderboard tooling** — Banned by private guideline-hit moderation rules.
