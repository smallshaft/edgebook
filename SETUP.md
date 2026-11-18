# edgebook setup, step by step

You don't need to run anything on your own computer. Everything below happens in the browser. Do the parts in order, because later steps need things from earlier ones. Keep a notes file open, since you'll copy a few values between sites.

## Part 1: Supabase (database + logins), about 10 minutes

1. Go to https://supabase.com/dashboard and sign in (GitHub login is fine).
2. Click **New project**. Name it `edgebook`, make up a database password and save it in your notes, pick the region closest to you (East US), keep the **Free** plan, and click **Create new project**. Wait about 2 minutes for it to finish.
3. **Create the tables.** In the left sidebar, click **SQL Editor**. Open https://github.com/smallshaft/edgebook/blob/claude/peaceful-davinci-o9kh6l/supabase/migrations/0001_init.sql, click the **Copy raw file** button (two overlapping squares, top right of the file), paste it into the SQL Editor, and click **Run**. You should see "Success. No rows returned." To check, click **Table Editor** in the sidebar and you should see tables like `profiles`, `trades`, and `markets`.
4. **Copy your keys.** Click the gear icon (**Project Settings**) at the bottom of the sidebar, then **API Keys**.
   - Copy the **publishable** key (starts with `sb_publishable_`) into your notes.
   - Copy the **secret** key (starts with `sb_secret_`) into your notes. If there isn't one, click to create one. Treat it like a password: it can read and write your whole database. Never paste it into a chat, a GitHub file, or anywhere public.
5. **Copy your project URL.** Click the **Connect** button at the top of the page. The URL looks like `https://abcdefghijkl.supabase.co`. Put it in your notes. The random letters are your **project ref**; you'll need them again in Part 3.

## Part 2: Vercel (puts the site online), about 5 minutes

1. Go to https://vercel.com and sign up with **Continue with GitHub**. Choose the free **Hobby** plan.
2. Click **Add New… → Project**. Find `edgebook` in the list and click **Import**. If it isn't listed, click **Adjust GitHub App Permissions** and give Vercel access to the `edgebook` repo.
3. Before clicking Deploy, open the **Environment Variables** section on the same screen and add these three, one at a time (name in the left box, value in the right):

   | Name | Value |
   | --- | --- |
   | `NEXT_PUBLIC_SUPABASE_URL` | your project URL from Part 1, step 5 |
   | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | your `sb_publishable_…` key |
   | `SUPABASE_SECRET_KEY` | your `sb_secret_…` key |

   Names must match exactly. Paste values with no spaces or quotes.
4. Click **Deploy** and wait about a minute. When it shows "Congratulations", click the preview to open your site. Copy the address (like `https://edgebook-xyz.vercel.app`) into your notes. That's your **site URL**.
   - If you already deployed before adding the variables: go to the project's **Settings → Environment Variables**, add them there, then go to **Deployments**, click the **⋯** on the top deployment, and click **Redeploy**. Variables only take effect after a redeploy.

## Part 3: Tell Supabase where your site lives, about 2 minutes

1. Back in Supabase, sidebar → **Authentication** → **URL Configuration**.
2. **Site URL**: replace it with your site URL from Part 2, step 4. Click **Save**.
3. **Redirect URLs**: click **Add URL** and add your site URL followed by `/**`, for example `https://edgebook-xyz.vercel.app/**`. Click **Save**.

At this point, email sign-in should already work for **your own email** (the one that owns the Supabase account). Supabase's built-in email sender only delivers to your own team's addresses. That's fine for testing; Resend fixes it for real users later.

## Part 4: Google login, about 10 minutes

1. Go to https://console.cloud.google.com. In the project dropdown at the top left, click **New Project**, name it `edgebook`, and click **Create**. Make sure the new project is selected in the dropdown.
2. In the search bar at the top, type **Google Auth Platform** and open it. Click **Get started**. Fill in the app name (`edgebook`) and your email, choose **External** for audience, and finish the wizard.
3. In the Google Auth Platform left menu, click **Audience**. While the app is in "Testing", only people you list can sign in. Under **Test users**, add your own Gmail address.
4. Click **Clients → Create client**.
   - Application type: **Web application**. Name: `edgebook web`.
   - **Authorized JavaScript origins**: add your site URL (no trailing slash), like `https://edgebook-xyz.vercel.app`.
   - **Authorized redirect URIs**: add `https://<your-project-ref>.supabase.co/auth/v1/callback`. Use your project ref from Part 1, step 5. This is Supabase's address, not your Vercel address. Supabase also shows this exact URL on its Google provider page (next step), so you can copy it from there.
   - Click **Create**. Copy the **Client ID** and **Client secret** into your notes.
5. Back in Supabase: **Authentication → Sign In / Providers** (may be labeled just **Providers**) → **Google**. Turn it on, paste the Client ID and Client secret, and click **Save**.

## Part 5: Test it

1. Open your site URL on your phone. You should see the dark landing page with "How good a trader are you, really?"
2. Go to `<your site URL>/dashboard` while signed out. It should send you to the sign-in page.
3. Tap **Continue with Google** and sign in with the Gmail you added as a test user. You should land on the dashboard showing your email and **Plan: free**.
4. Sign out. Sign in again, this time typing your email and tapping **Email me a sign-in link**. Open the email on the same phone and tap the link. You should land on the dashboard again.
5. In Supabase → **Table Editor → profiles**, you should see a row with your email and `plan = free`.

## If something goes wrong

- **The site says "Login isn't configured yet"**: the Vercel variables are missing or misnamed, or you didn't redeploy after adding them (Part 2, step 4).
- **Google says "redirect_uri_mismatch"**: the redirect URI in Google (Part 4, step 4) must be exactly `https://<project-ref>.supabase.co/auth/v1/callback`.
- **Google says "access blocked" or the app isn't verified**: add your Gmail as a test user (Part 4, step 3).
- **Sign-in works but you land on the homepage or a "link didn't work" message**: check the Redirect URL in Part 3, step 3, including the `/**` at the end.
- **No sign-in email arrives**: check spam. If you used an email that isn't the Supabase account owner's, the built-in sender won't deliver to it.
- **SQL Editor shows an error**: you probably copied only part of the file. Clear the editor, copy the whole raw file again, and rerun. If it says something "already exists", the first run worked and you're fine.

## Later (not needed yet): Resend for emails to real users

Do this once you own a domain (about $10/yr) and before inviting other people.

1. Sign up at https://resend.com. Under **Domains**, add your domain and add the DNS records it shows at your domain registrar. Wait for it to show **Verified**.
2. Under **API Keys**, create a key and copy it.
3. In Supabase: **Authentication → Emails → SMTP Settings**, turn on custom SMTP. Host `smtp.resend.com`, port `465`, username `resend`, password = the Resend API key, sender email = something like `login@yourdomain.com`.

## Optional: run it on your own computer

You don't need this to test. If you want it anyway:

1. Install Node.js (LTS) from https://nodejs.org.
2. In a terminal, run:
   ```bash
   git clone https://github.com/smallshaft/edgebook.git
   cd edgebook
   npm install
   ```
3. Create a file named `.env.local` in the `edgebook` folder (next to `package.json`) with your three values:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://abcdefghijkl.supabase.co
   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
   SUPABASE_SECRET_KEY=sb_secret_...
   ```
   Git ignores this file, so your keys stay off GitHub.
4. Run `npm run dev` and open http://localhost:3000. For login to work locally, also add `http://localhost:3000/**` to Supabase's Redirect URLs (Part 3).
