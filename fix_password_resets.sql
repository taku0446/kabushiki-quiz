-- ============================================================
-- 修正用SQL: password_resets テーブルが見つからない問題の対処
-- ============================================================
-- 「Could not find the table 'public.password_resets' in the schema cache」
-- というエラーが出た場合は、このSQLだけを実行してください。
--
-- 使い方:
-- 1. Supabaseダッシュボード → 左メニュー「SQL Editor」
-- 2. 「New query」をクリック
-- 3. このファイルの内容を全部貼り付けて「Run」を実行
-- ============================================================

-- パスワードリセット用のコード管理テーブル
create table if not exists password_resets (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  reset_code text not null,
  expires_at timestamptz not null,
  used boolean default false,
  created_at timestamptz default now()
);

alter table password_resets enable row level security;

-- 既に同名ポリシーがあるとエラーになるため、先に削除してから作成し直す（安全な再実行のため）
drop policy if exists "Allow public read password_resets" on password_resets;
drop policy if exists "Allow public insert password_resets" on password_resets;
drop policy if exists "Allow public update password_resets" on password_resets;

create policy "Allow public read password_resets" on password_resets for select using (true);
create policy "Allow public insert password_resets" on password_resets for insert with check (true);
create policy "Allow public update password_resets" on password_resets for update using (true);

-- ============================================================
-- 重要: SupabaseのAPI層(PostgREST)は、テーブル一覧を内部的にキャッシュしています。
-- 新しいテーブルを作成した直後は、このキャッシュが古いままで
-- 「Could not find the table 'public.password_resets' in the schema cache」
-- というエラーが出ることがあります。
-- 以下のコマンドでキャッシュを強制的に再読み込みさせます。
-- ============================================================
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- 実行後、もう一度サイトで「パスワードを忘れましたか？」を試してください。
-- まだ同じエラーが出る場合は、Supabaseダッシュボードの「Table Editor」で
-- password_resets テーブルが実際に作成されているか目視で確認してください。
-- それでも解決しない場合は、Supabaseプロジェクトを一度「Pause」→「Resume」
-- することでAPI層が完全に再起動し、キャッシュが更新されることがあります。
-- ============================================================
