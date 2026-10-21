-- =============================================================================
-- ShareGari — Migration 006: Enum additions for the matching engine
-- =============================================================================
-- WHY a separate file?
--   PostgreSQL does not allow a new enum value added with ALTER TYPE ADD VALUE
--   to be referenced in the SAME transaction. Supabase runs each migration
--   file in one transaction, so the enum additions must commit here and the
--   schema/function that USE the new values must be in the next file (007).
-- =============================================================================

-- Add 'searching' to request_status.
-- New ride requests will default to 'searching' (set in migration 007).
-- The matching engine picks up rows in this state and promotes them to 'matched'.
-- 'pending' is kept for backward compatibility with pre-migration rows.
alter type public.request_status add value if not exists 'searching';

-- Add 'pending_driver' to group_status.
-- The matching engine creates groups with this status.
-- Step 8 driver-assignment moves them from 'pending_driver' -> 'confirmed'.
alter type public.group_status add value if not exists 'pending_driver';
