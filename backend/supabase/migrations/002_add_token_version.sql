-- 19 Nov: logout support
-- Run this once in Supabase SQL Editor on a database created from the
-- earlier schema.sql (before token_version was added).
-- Existing tokens stop working after this; users must log in again.
alter table public.users
  add column if not exists token_version integer not null default 0;
