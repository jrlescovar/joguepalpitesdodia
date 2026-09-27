begin;

-- Allow several owner-selected matchups on one day. The draw already inserts
-- every reserved row first and randomly pairs only the remaining players.
alter table public.daily_battle_reserved_pairings
  drop constraint daily_battle_reserved_pairings_pkey;
alter table public.daily_battle_reserved_pairings
  add primary key (day_id, player_left),
  add unique (day_id, player_right);

-- Historical player-specific reservations are omitted from the public source.

commit;
