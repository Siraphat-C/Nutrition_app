-- Thai menu names live in the database instead of the app code.
-- New model classes are added by the server with no calories yet,
-- so calories_per_100g may be empty until an admin fills it in.
-- Run once in Supabase SQL Editor. Safe to run again.

alter table public.foods add column if not exists food_name_th varchar(100);
alter table public.foods alter column calories_per_100g drop not null;

update public.foods set food_name_th = v.th
from (values
  ('khao_kha_moo',         'ข้าวขาหมู'),
  ('khao_man_kai',         'ข้าวมันไก่'),
  ('khao_na_ped',          'ข้าวหน้าเป็ด'),
  ('khao_mok_gai',         'ข้าวหมกไก่'),
  ('khao_moo_daeng',       'ข้าวหมูแดง'),
  ('khao_moo_tod',         'ข้าวหมูทอด'),
  ('khao_moo_kratiem',     'ข้าวหมูกระเทียม'),
  ('khao_pad_moo',         'ข้าวผัดหมู'),
  ('khao_kana_moo_krob',   'ข้าวคะน้าหมูกรอบ'),
  ('khao_kluk_kapi',       'ข้าวคลุกกะปิ'),
  ('pad_kra_pao_moo_sub',  'ข้าวกะเพราหมูสับ'),
  ('pad_kra_pao_moo_krob', 'ข้าวกะเพราหมูกรอบ')
) as v(name, th)
where public.foods.food_name = v.name
  and public.foods.food_name_th is null;
