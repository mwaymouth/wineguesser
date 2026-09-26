# WineGuesser

A phone-friendly blind wine tasting game for Tim's birthday. Friends sign up with their name and phone number, taste glasses 1 through N, guess the grape and region for each, and seal their sheet. The leaderboard shows who has sealed; at the reveal it re-sorts by score and crowns the winner.

No build step. One HTML file, one config file, one SQL file.

## How it works

- **Guests**: open the link, tap *Join the tasting*, enter name + phone, fill in the sheet, tap *Seal my guesses*. The phone number is only used to sign back in on the same or another device. It is never shown to anyone.
- **Host (you)**: tap *Host* at the bottom (or open `/#host`), enter the PIN, set the number of wines and the answers, and tick *Reveal* when everyone is done. Reveal locks guesses and shows scores.
- **Scoring**: 1 point per correct grape, 1 per correct region. Matching is forgiving: "Cab" = Cabernet Sauvignon, "Napa" = Napa Valley, "Shiraz" = Syrah. For regions you can list several accepted answers with slashes, e.g. `Willamette Valley / Oregon`.

Without a backend configured, the app runs in **preview mode** with sample tasters and host PIN `1234`. Nothing is saved.

## Deploy for free (about 15 minutes)

### 1. Backend: Supabase (free tier)

1. Create a project at https://supabase.com (free plan).
2. Open **SQL Editor → New query**, paste the whole of `schema.sql`, change `'change-me'` on the last line to your own host PIN, and click **Run**.
3. Go to **Project Settings → API** and copy the **Project URL** and the **anon public** key.
4. Put both in `config.js`:

```js
window.WINE_CONFIG = {
  supabaseUrl: "https://xxxx.supabase.co",
  supabaseAnonKey: "eyJ...",
  birthdayName: "Tim",
  eventLabel: "Birthday Blind Tasting",
};
```

The anon key is safe to ship in the page: the tables are locked down with row-level security and the app only calls the SQL functions in `schema.sql`, which never return phone numbers or unrevealed answers.

### 2. Hosting: GitHub Pages (free)

1. Push this repo to GitHub.
2. **Settings → Pages → Build and deployment → Source: GitHub Actions.** The included workflow (`.github/workflows/pages.yml`) publishes on every push to `main`.
3. Your link is `https://<your-username>.github.io/wineguesser/`. Text it to the group.

Netlify or Vercel work too: point them at the repo, no build command, publish directory `.`.

### 3. Party day

- Number the bottles 1..N and pour blind.
- Open `/#host`, enter the PIN, set the wine count and answers, **Save**.
- When everyone has sealed, tick **Reveal answers and scores**, **Save**. The board re-sorts live (guests' phones refresh every 15 seconds).

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app (UI + logic) |
| `config.js` | Supabase URL/key and the birthday name |
| `schema.sql` | Tables, security policies and RPC functions |
| `scripts/build-preview.py` | Bundles a single-file demo into `dist/preview.html` |
| `.github/workflows/pages.yml` | Deploys to GitHub Pages |
