-- ═══════════════════════════════════════════
--  SUPABASE SETUP
-- ═══════════════════════════════════════════
--
--  1. Create a free project at https://supabase.com
--  2. Go to SQL Editor and run the following:

-- Teas table
CREATE TABLE teas (
  id TEXT NOT NULL,
  user_id UUID NOT NULL DEFAULT auth.uid(),
  name TEXT NOT NULL,
  chinese_name TEXT DEFAULT '',
  type TEXT NOT NULL CHECK (type IN ('green','black','oolong','white','puerh','yellow')),
  province TEXT DEFAULT '',
  region TEXT DEFAULT '',
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  elevation DOUBLE PRECISION,
  flavor TEXT DEFAULT '',
  description TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  starter BOOLEAN DEFAULT FALSE,
  edited BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id, user_id)
);

-- Track which starter teas a user has hidden
CREATE TABLE deleted_starters (
  user_id UUID NOT NULL DEFAULT auth.uid(),
  starter_id TEXT NOT NULL,
  PRIMARY KEY (user_id, starter_id)
);

-- Enable Row Level Security
ALTER TABLE teas ENABLE ROW LEVEL SECURITY;
ALTER TABLE deleted_starters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own teas" ON teas
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own deleted starters" ON deleted_starters
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

--  3. Go to Authentication > Settings and enable Email provider
--  4. Copy your Project URL and anon key from Settings > API
--  5. Paste them into SUPABASE_URL and SUPABASE_ANON_KEY in index.html
--
--  Deploy: Push to GitHub and enable GitHub Pages in repo Settings > Pages
