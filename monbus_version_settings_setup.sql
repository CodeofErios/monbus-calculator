-- モンバス計算機 Version2 / Version3：全端末の切替設定
-- Supabase > SQL Editor > New query で一度実行してください。
-- 初期状態 Version2。既存の設定は上書きしません。

CREATE TABLE IF NOT EXISTS public.monbus_version_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id=1),
  selected_version text NOT NULL DEFAULT 'v2' CHECK(selected_version IN ('v2','v3')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.monbus_version_settings (id,selected_version) VALUES (1,'v2')
ON CONFLICT (id) DO NOTHING;
ALTER TABLE public.monbus_version_settings ENABLE ROW LEVEL SECURITY;

-- 一般ユーザーも共有Versionを読めるため、管理者の切替が全端末に反映される。
DROP POLICY IF EXISTS "monbus_version_public_read" ON public.monbus_version_settings;
CREATE POLICY "monbus_version_public_read" ON public.monbus_version_settings
FOR SELECT TO anon, authenticated USING (true);

-- 共有Versionの変更は主管理者のみ。共同管理者の切替は端末保存のみでDB更新しない。
DROP POLICY IF EXISTS "monbus_version_main_admin_update" ON public.monbus_version_settings;
CREATE POLICY "monbus_version_main_admin_update" ON public.monbus_version_settings
FOR UPDATE TO authenticated
USING (lower(auth.jwt() ->> 'email')=lower('koki.ayaka1016@gmail.com'))
WITH CHECK (lower(auth.jwt() ->> 'email')=lower('koki.ayaka1016@gmail.com'));

GRANT SELECT ON public.monbus_version_settings TO anon, authenticated;
GRANT UPDATE (selected_version, updated_at) ON public.monbus_version_settings TO authenticated;

-- Realtimeで開いている端末にも変更を通知。受信できない場合は15秒ごとに再確認。
DO $$
BEGIN
  IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime')
     AND NOT EXISTS(
       SELECT 1 FROM pg_publication_tables
       WHERE pubname='supabase_realtime' AND schemaname='public'
         AND tablename='monbus_version_settings'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.monbus_version_settings;
  END IF;
END $$;
