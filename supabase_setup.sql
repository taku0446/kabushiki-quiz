-- ============================================================
-- 株クイズ - Supabase データベース構築スクリプト
-- ============================================================
-- 使い方:
-- 1. Supabaseのプロジェクトダッシュボードを開く
-- 2. 左メニューの「SQL Editor」をクリック
-- 3. 「New query」を押して、このファイルの内容を全部貼り付ける
-- 4. 右下の「Run」ボタンをクリックして実行する
-- ============================================================

-- ユーザープロフィール・統計情報テーブル
create table if not exists profiles (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  name text not null,
  avatar_url text default '',
  password_hash text not null,
  is_banned boolean default false,
  active_title text default '',
  correct_count integer default 0,
  attempts integer default 0,
  total_time numeric default 0,
  questions_answered integer default 0,
  total_minutes integer default 0,
  cleared_difficulties text[] default array[]::text[],
  answered_question_set jsonb default '{}'::jsonb,
  won_weekly_rank1 boolean default false,
  won_alltime_rank1 boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 仮想投資ポートフォリオテーブル
create table if not exists investments (
  id uuid primary key default gen_random_uuid(),
  user_email text not null references profiles(email) on delete cascade,
  cash numeric default 1000000,
  portfolio jsonb default '[]'::jsonb,
  current_total numeric default 1000000,
  week_key text default '',
  week_start_total numeric default 1000000,
  updated_at timestamptz default now(),
  unique(user_email)
);

-- 管理者からのお知らせテーブル
create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  created_at timestamptz default now(),
  edited_at timestamptz
);

-- お知らせの既読管理テーブル
create table if not exists notification_reads (
  user_email text not null,
  announcement_id uuid not null references announcements(id) on delete cascade,
  read_at timestamptz default now(),
  primary key (user_email, announcement_id)
);

-- AI投資勝負データテーブル（管理者が手動更新）
create table if not exists ai_battle (
  ai_id text primary key, -- 'gemini' | 'grok' | 'chatgpt'
  cash numeric default 1000000,
  holdings jsonb default '[]'::jsonb,
  last_updated timestamptz default now()
);

-- 初期データ：AI3体の枠を作成
insert into ai_battle (ai_id, cash, holdings) values
  ('gemini', 1000000, '[]'::jsonb),
  ('grok', 1000000, '[]'::jsonb),
  ('chatgpt', 1000000, '[]'::jsonb)
on conflict (ai_id) do nothing;

-- パスワードリセット用のコード管理テーブル
create table if not exists password_resets (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  reset_code text not null,
  expires_at timestamptz not null,
  used boolean default false,
  created_at timestamptz default now()
);

-- ============================================================
-- Row Level Security (RLS) の設定
-- ============================================================
-- このアプリはパスワードをアプリ側でハッシュ化してから保存するため、
-- 匿名キー(anon key)からの読み書きを許可するシンプルなポリシーを設定します。
-- 本番運用でより厳格にしたい場合はSupabase Authへの移行を推奨します。

alter table profiles enable row level security;
alter table investments enable row level security;
alter table announcements enable row level security;
alter table notification_reads enable row level security;
alter table ai_battle enable row level security;
alter table password_resets enable row level security;

-- profiles: 誰でも読み書き可能（メールアドレスをキーにアプリ側で制御）
create policy "Allow public read profiles" on profiles for select using (true);
create policy "Allow public insert profiles" on profiles for insert with check (true);
create policy "Allow public update profiles" on profiles for update using (true);

-- investments
create policy "Allow public read investments" on investments for select using (true);
create policy "Allow public insert investments" on investments for insert with check (true);
create policy "Allow public update investments" on investments for update using (true);

-- announcements
create policy "Allow public read announcements" on announcements for select using (true);
create policy "Allow public insert announcements" on announcements for insert with check (true);
create policy "Allow public update announcements" on announcements for update using (true);
create policy "Allow public delete announcements" on announcements for delete using (true);

-- notification_reads
create policy "Allow public read notification_reads" on notification_reads for select using (true);
create policy "Allow public insert notification_reads" on notification_reads for insert with check (true);

-- ai_battle
create policy "Allow public read ai_battle" on ai_battle for select using (true);
create policy "Allow public update ai_battle" on ai_battle for update using (true);

-- password_resets
create policy "Allow public read password_resets" on password_resets for select using (true);
create policy "Allow public insert password_resets" on password_resets for insert with check (true);
create policy "Allow public update password_resets" on password_resets for update using (true);

-- ============================================================
-- インデックス（検索・ランキング集計の高速化）
-- ============================================================
create index if not exists idx_profiles_correct_count on profiles(correct_count desc);
create index if not exists idx_investments_total on investments(current_total desc);

-- ============================================================
-- 重要: SupabaseのAPI層(PostgREST)はテーブル一覧を内部キャッシュしています。
-- 新しいテーブル作成直後にAPIがそれを認識できるよう、キャッシュを強制リロードします。
-- ============================================================
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- 完了！
-- このSQLを実行した後、Supabaseダッシュボードの
-- 「Project Settings」→「API」から以下の2つをコピーして
-- アプリ側に設定してください:
--   - Project URL
--   - anon public key
-- ============================================================
