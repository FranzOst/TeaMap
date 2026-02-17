# Deployment Plan: China Tea Map — Online with Persistent Database

## Goal
Deploy `china-tea-map.html` online with multi-user authentication and a real database so each user's teas persist across devices and sessions.

## Stack
- **Hosting**: GitHub Pages (free, already on GitHub, no build tools)
- **Database + Auth**: Supabase free tier (PostgreSQL, built-in auth, CDN JS client)

---

## Phase 1: Supabase Project Setup

### 1.1 Create Supabase project
- Sign up at https://supabase.com (free)
- Create a new project, pick a region close to you
- Note the **Project URL** and **anon key** from Settings > API

### 1.2 Create database tables
Run in Supabase SQL Editor:

```sql
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

-- Track which starter teas a user has deleted/hidden
CREATE TABLE deleted_starters (
  user_id UUID NOT NULL DEFAULT auth.uid(),
  starter_id TEXT NOT NULL,
  PRIMARY KEY (user_id, starter_id)
);
```

### 1.3 Enable Row Level Security
```sql
ALTER TABLE teas ENABLE ROW LEVEL SECURITY;
ALTER TABLE deleted_starters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own teas"
  ON teas FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own deleted starters"
  ON deleted_starters FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

### 1.4 Enable authentication providers
- Go to Authentication > Providers
- Enable **Email** (simplest) and optionally **Google** OAuth
- For Google: create OAuth credentials in Google Cloud Console, paste Client ID + Secret into Supabase

---

## Phase 2: Code Changes in `china-tea-map.html`

All changes are in the single HTML file. No new files needed.

### 2.1 Add Supabase CDN script
Add after the Leaflet script tag:
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

### 2.2 Add Supabase initialization
Near the top of the `<script>` block (after STARTER_TEAS):
```javascript
const SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'eyJ...YOUR-ANON-KEY';
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
```

### 2.3 Add auth UI
Add a login/logout button to the header area. On page load:
- Check if user is logged in via `sb.auth.getSession()`
- If not logged in, show a login modal (email + password, or Google button)
- If logged in, show username + logout button
- Auth state listener to react to login/logout

### 2.4 Replace persistence functions

**`loadTeas()`** → async, fetches from Supabase:
```javascript
async function loadTeas() {
  const { data: saved } = await sb.from('teas').select('*');
  const { data: deletedRows } = await sb.from('deleted_starters').select('starter_id');

  const deletedIds = (deletedRows || []).map(r => r.starter_id);
  const dbTeas = (saved || []).map(mapDbToTea);
  const starters = STARTER_TEAS.filter(t => !deletedIds.includes(t.id));
  const savedIds = new Set(dbTeas.map(t => t.id));
  return starters.filter(t => !savedIds.has(t.id)).concat(dbTeas);
}
```

**`saveTeas()`** → replaced by per-tea upsert:
```javascript
async function saveTeaToDB(tea) {
  await sb.from('teas').upsert(mapTeaToDb(tea));
}
```

**`saveDeleted()`** → Supabase insert:
```javascript
async function saveDeletedToDB(starterId) {
  await sb.from('deleted_starters').upsert({ starter_id: starterId });
}
```

**`deleteTea()`** → Supabase delete:
```javascript
async function deleteTeaFromDB(id) {
  await sb.from('teas').delete().eq('id', id);
}
```

### 2.5 Update mutation call sites
- `saveTea()` form handler (line ~1330): change `saveTeas()` → `await saveTeaToDB(tea)`, make function async
- `deleteTea()` (line ~1460): change to async, use `saveDeletedToDB()` and `deleteTeaFromDB()`
- `DOMContentLoaded` handler: make async, `allTeas = await loadTeas()`

### 2.6 One-time localStorage migration
On first login, check if `chinaTeaMapData` exists in localStorage. If so, upload it to Supabase, then set a `chinaTeaMapMigrated` flag so it only runs once.

### 2.7 localStorage fallback
Keep localStorage as a fallback: if Supabase calls fail (network issue), gracefully degrade to localStorage so the app never breaks.

---

## Phase 3: Deploy to GitHub Pages

### 3.1 Rename file (optional but recommended)
Rename `china-tea-map.html` → `index.html` so the URL is clean:
`https://franzost.github.io/general/`

### 3.2 Commit and push
```bash
git add index.html
git commit -m "Add Supabase persistence and auth for online deployment"
git push
```

### 3.3 Enable GitHub Pages
- Go to repo Settings > Pages
- Source: "Deploy from a branch"
- Branch: `main`, folder: `/ (root)`
- Site goes live within minutes

---

## Summary of Changes

| What | Before | After |
|------|--------|-------|
| Hosting | Local file | GitHub Pages |
| Data storage | localStorage | Supabase PostgreSQL (localStorage fallback) |
| Auth | None | Email/password + optional Google |
| User isolation | N/A | Row Level Security per user |
| External dependencies | Leaflet CDN | Leaflet CDN + Supabase CDN |
| Build tools needed | None | None |
| Files changed | 0 | 1 (`china-tea-map.html`) |
| Lines changed | 0 | ~70-90 |
