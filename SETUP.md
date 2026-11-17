# edgebook setup, step by step

Everything here happens in your browser. You don't need to run anything on your computer.
Do the parts in order. Each one ends with a check so you know it worked.

You'll fill in two values as you go. Keep them in a note:
- **APP URL**: your Vercel address, like `https://edgebook-abc123.vercel.app` (you get it in Part 3)
- **SUPABASE URL**: like `https://abcdefghijkl.supabase.co` (Part 1)

---

## Part 1: Get your Supabase values

1. Go to https://supabase.com/dashboard and open your project.
2. Click the **Connect** button at the top of the page. Copy the URL that looks like `https://abcdefghijkl.supabase.co`. That's your **SUPABASE URL**.
3. In the left sidebar, click the gear icon (**Project Settings**), then **API Keys**.
4. Copy the **publishable** key (starts with `sb_publishable_`) and the **secret** key (starts with `sb_secret_`).

Never paste the secret key into a chat, email, GitHub, or a screenshot. If it leaks, create a new secret key on that same page, then delete the old one.

## Part 2: Create the database tables

1. Open https://github.com/smallshaft/edgebook/blob/claude/peaceful-davinci-o9kh6l/supabase/migrations/0001_init.sql
2. Click the **Copy raw file** button (two overlapping squares, top-right of the file).
3. In Supabase's left sidebar, click **SQL Editor**, then **New query**.
4. Paste and click **Run** (bottom-right).

**Check:** you see "Success. No rows returned". Click **Table Editor** in the sidebar and you should see tables like `profiles`, `trades`, and `markets`.

If you get an error saying something "already exists", the script already ran once. That's fine. Don't run it again.

## Part 3: Deploy to Vercel

1. Go to https://vercel.com and sign up or log in **with GitHub**.
2. Click **Add New…** → **Project**.
3. Find `edgebook` and click **Import**. If it isn't listed, click **Adjust GitHub App Permissions** and give Vercel access to the `edgebook` repo.
4. Leave the framework (Next.js) and build settings alone. Open the **Environment Variables** section and add these three, one per row:

   | Key | Value |
   |---|---|
   | `NEXT_PUBLIC_SUPABASE_URL` | your SUPABASE URL |
   | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | the `sb_publishable_...` key |
   | `SUPABASE_SECRET_KEY` | the `sb_secret_...` key (set its type to **Secret** if asked) |

   Spell the keys exactly as shown. They're case-sensitive.
5. Click **Deploy** and wait 1–2 minutes.

**Check:** you see a "Congratulations" screen. Click the preview to open the site. Copy the address from the browser bar. That's your **APP URL**.

If you added or changed a variable after deploying, it won't apply until you redeploy: open **Deployments**, click the three dots on the newest one, then **Redeploy**.

## Part 4: Tell Supabase where your app lives

1. In Supabase, click **Authentication** in the left sidebar, then **URL Configuration**.
2. **Site URL**: replace `http://localhost:3000` with your APP URL. Click **Save**.
3. Under **Redirect URLs**, click **Add URL** and add each of these:
   - `https://YOUR-APP.vercel.app/**` (your APP URL followed by `/**`)
   - `http://localhost:3000/**`
4. Save.

## Part 5: Test email sign-in

1. Open your APP URL, click **Get started**, enter your email, and tap **Email me a sign-in link**.
2. Open the email from Supabase and click the link. Use the same device and browser.

**Check:** you land on the Dashboard showing your email and **Plan: free**. In Supabase **Table Editor → profiles**, there's now a row for you. Then open `YOUR-APP/dashboard` in a private/incognito window. It should send you to the sign-in page.

Supabase's built-in email sender only allows a few emails per hour, and it may only deliver to your own (team) address. That's fine for testing. Resend fixes it later.

## Part 6: Turn on Google sign-in (optional, about 10 minutes)

**In Supabase first:**
1. **Authentication** → **Sign In / Providers** → **Google**. Copy the **Callback URL** shown there (looks like `https://abcdefghijkl.supabase.co/auth/v1/callback`). Leave this tab open.

**In Google Cloud:**
2. Go to https://console.cloud.google.com. Use the project picker at the top to create a **New Project** named `edgebook`, then select it.
3. Search the top bar for **Google Auth Platform** and open it. Click **Get started**.
   - App name: `edgebook`. User support email: your email.
   - Audience: **External**.
   - Contact email: your email. Agree to the policy, then **Create**.
4. In the left menu, click **Audience**. Under **Test users**, add your own Gmail address. While the app is in "Testing" mode, only test users can sign in.
5. In the left menu, click **Clients** → **Create client**.
   - Application type: **Web application**. Name: `edgebook web`.
   - **Authorized JavaScript origins**: add your APP URL (no trailing slash) and `http://localhost:3000`.
   - **Authorized redirect URIs**: paste the Supabase **Callback URL** from step 1.
   - Click **Create**. Copy the **Client ID** and **Client secret**.

**Back in Supabase:**
6. On the Google provider page, turn on **Enable Sign in with Google**, paste the Client ID and Client secret, then **Save**.

**Check:** sign out, open your APP URL, click **Get started** → **Continue with Google**, and pick your Gmail. You land on the Dashboard.

## If something breaks

Send the exact error text, or a screenshot that doesn't show any secret keys, plus which part and step you were on.
