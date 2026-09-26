-- WineGuesser database schema for Supabase (free tier).
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- Then change the host PIN on the last line before running (or later with an UPDATE).

create table if not exists settings (
  id          int primary key default 1 check (id = 1),
  wine_count  int  not null default 6 check (wine_count between 1 and 12),
  revealed    boolean not null default false,
  answers     jsonb not null default '[]'::jsonb,
  prize       text not null default 'A very nice bottle of wine',
  host_pin    text not null default 'change-me'
);
insert into settings (id) values (1) on conflict (id) do nothing;

create table if not exists players (
  phone        text primary key,
  name         text not null,
  guesses      jsonb,
  submitted_at timestamptz,
  created_at   timestamptz not null default now()
);

-- Lock the tables: the app only talks to the functions below.
alter table settings enable row level security;
alter table players  enable row level security;
revoke all on settings, players from anon, authenticated;

-- Public game state. Answers stay hidden until the host reveals them.
create or replace function get_state() returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'wineCount', wine_count,
    'revealed',  revealed,
    'prize',     prize,
    'answers',   case when revealed then answers else null end
  ) from settings where id = 1;
$$;

-- Leaderboard: only people who submitted. Phone numbers are never returned,
-- and nobody's guesses are visible until the reveal.
create or replace function get_board() returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'name',        p.name,
      'submittedAt', p.submitted_at,
      'guesses',     case when s.revealed then p.guesses else null end
    ) order by p.submitted_at), '[]'::json)
  from players p cross join settings s
  where s.id = 1 and p.submitted_at is not null;
$$;

-- Sign up (or sign back in) with a name and phone number.
create or replace function join_game(p_name text, p_phone text) returns json
language plpgsql security definer set search_path = public as $$
declare r players;
begin
  if length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')) < 10 then
    raise exception 'Enter a full phone number';
  end if;
  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Enter your name';
  end if;
  insert into players (phone, name)
  values (regexp_replace(p_phone, '\D', '', 'g'), left(trim(p_name), 40))
  on conflict (phone) do update set name = excluded.name
  returning * into r;
  return json_build_object('name', r.name, 'phone', r.phone, 'guesses', r.guesses, 'submittedAt', r.submitted_at);
end $$;

create or replace function submit_guesses(p_phone text, p_guesses jsonb) returns json
language plpgsql security definer set search_path = public as $$
declare r players;
begin
  if (select revealed from settings where id = 1) then
    raise exception 'The answers are out, so guesses are locked';
  end if;
  update players set guesses = p_guesses, submitted_at = now()
  where phone = regexp_replace(p_phone, '\D', '', 'g')
  returning * into r;
  if not found then raise exception 'Sign up first'; end if;
  return json_build_object('name', r.name, 'phone', r.phone, 'guesses', r.guesses, 'submittedAt', r.submitted_at);
end $$;

-- Host only: set the number of wines, the answers, and reveal them.
create or replace function host_save(p_pin text, p_wine_count int, p_answers jsonb, p_revealed boolean)
returns json language plpgsql security definer set search_path = public as $$
begin
  if p_pin is distinct from (select host_pin from settings where id = 1) then
    raise exception 'Wrong host PIN';
  end if;
  update settings set wine_count = p_wine_count, answers = p_answers, revealed = p_revealed where id = 1;
  return json_build_object('ok', true);
end $$;

-- Host only: read the answers back before the reveal.
create or replace function host_load(p_pin text) returns json
language plpgsql security definer set search_path = public as $$
declare s settings;
begin
  select * into s from settings where id = 1;
  if p_pin is distinct from s.host_pin then raise exception 'Wrong host PIN'; end if;
  return json_build_object('wineCount', s.wine_count, 'answers', s.answers, 'revealed', s.revealed,
    'players', (select count(*) from players where submitted_at is not null));
end $$;

grant execute on function get_state(), get_board(), join_game(text, text),
  submit_guesses(text, jsonb), host_save(text, int, jsonb, boolean), host_load(text)
  to anon, authenticated;

-- CHANGE THIS PIN before the party:
update settings set host_pin = 'change-me' where id = 1;
