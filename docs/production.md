# Production setup

`yumeter-dev` is for development and testing only. Real users get a separate
production Supabase project, so testing never touches their data. This is the
checklist for standing it up and shipping a release. Steps marked **(you)**
need your accounts or credentials and cannot be done from the codebase.

## 1. Create the production project (you)

1. In the Supabase dashboard, create a project, e.g. `yumeter`. Pick the region
   closest to most users, and put that region in the privacy policy
   (`[REGION]` in `assets/legal/privacy_policy.md`).
2. Note the project ref and URL, and copy the **publishable** key from
   Settings → API Keys. Never copy the secret key anywhere outside the
   dashboard.

## 2. Database, storage and functions

With the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
installed, from the `yumeter` folder:

```bash
supabase login
supabase link --project-ref <prod-ref>
supabase db push
supabase functions deploy analyze-meal
supabase functions deploy delete-account
supabase functions deploy cleanup-photos --no-verify-jwt
```

`db push` applies every file in `supabase/migrations` in order: tables, row
level security, the photo bucket, the cleanup job, weigh-ins and the photo
limit. `cleanup-photos` runs with `--no-verify-jwt` because the scheduler
calls it with the publishable key, not a user's session; the function checks
that key itself.

## 3. Scheduled cleanup

The daily photo cleanup reads where to send its request from Vault. Run once
in the production project's SQL editor, with that project's values:

```sql
select vault.create_secret('https://<prod-ref>.supabase.co', 'project_url');
select vault.create_secret('<prod publishable key>', 'publishable_key');
```

## 4. Function secrets (you)

Edge Functions → Secrets:

| Secret | Value |
| --- | --- |
| `GEMINI_API_KEY` | A key on a **paid** Gemini tier. The free tier is shared, often overloaded, and may use photos to improve Google's products. Once paid, delete the marked free-tier sentence in the privacy policy. |
| `DAILY_PHOTO_LIMIT` | Optional. Photo analyses per user per UTC day; 20 if unset. |
| `GEMINI_MODELS` | Optional. Comma-separated models to try in order. |

To move to another provider instead, replace
`supabase/functions/analyze-meal/gemini.ts` and keep `estimateMeal`'s shape.

## 5. Sign-in email (you)

1. Get a domain and an email sending service that supports it (Resend, Brevo,
   Postmark and others have free tiers). Verify the domain with them.
2. Authentication → Emails → SMTP Settings: enable custom SMTP with the
   service's details and a sender like `no-reply@<your domain>`.
3. Authentication → Emails → **Confirm signup** and **Magic Link**: set the
   body to show the code, since the app signs in with a code, not a link:

   ```html
   <h2>Your Yumeter code</h2>
   <p>Enter this code in the app: {{ .Token }}</p>
   ```

   Subject for both: `Your Yumeter code`.
4. Authentication → Rate Limits: check the email limit suits your volume.
5. Put the service's name in the privacy policy (`[EMAIL PROVIDER]`).

## 6. Google sign-in (you)

The Google Cloud project `Yumeter` already has a **Web** client (used by
Supabase) and an **Android** client registered for package `com.yumeter.app`
with the debug key's SHA-1, which covers test builds. For releases:

1. Google Cloud → Google Auth Platform → Clients: add two more **Android**
   clients for `com.yumeter.app` (or more SHA-1s to the existing one), with:
   - the upload key's SHA-1 (step 8, then `keytool -list -v -keystore
     %USERPROFILE%\yumeter-upload.jks -alias upload`);
   - Google Play's app signing key SHA-1, from Play Console → Test and
     release → App integrity, once the app exists in Play Console.
2. Google Auth Platform → Audience: publish the consent screen to
   **Production** (it starts in Testing, limited to listed test users).
3. In the production Supabase project, Authentication → Sign In / Providers →
   Google: enable, paste the Web client ID and secret, put every client ID in
   **Client IDs** separated by commas with the **Web** one first, and turn on
   **Skip nonce check**, as Supabase's Flutter guide says.
4. iOS needs its own iOS client, its URL scheme in `ios/Runner/Info.plist`,
   and Sign in with Apple alongside it (App Store guideline 4.8). Until then
   the app offers Google on Android only.

## 7. Legal pages (you)

Fill the placeholders in `assets/legal/privacy_policy.md` and
`assets/legal/terms_of_use.md`: `[DEVELOPER NAME]`, `[CONTACT EMAIL]`,
`[COUNTRY]`, `[REGION]`, `[EMAIL PROVIDER]`. Have both reviewed by someone
qualified before launch. Publish the privacy policy at a public URL too; both
stores ask for one in the listing.

## 8. Android signing key (you)

Play signs the published app with its own key; you sign uploads with an
upload key. Create it once and keep it, and its passwords, safe and backed
up. Losing it means asking Google to reset it.

```bash
keytool -genkey -v -keystore %USERPROFILE%\yumeter-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (already ignored by git; never commit
it):

```properties
storePassword=<the keystore password>
keyPassword=<the key password>
keyAlias=upload
storeFile=C:\\Users\\<you>\\yumeter-upload.jks
```

With that file present, release builds sign with the upload key; without it
they fall back to the debug key, which Play rejects.

## 9. Build a release

The app talks to `yumeter-dev` unless told otherwise. Always pass the
production values:

```bash
flutter build appbundle --release --dart-define=SUPABASE_URL=https://<prod-ref>.supabase.co --dart-define=SUPABASE_KEY=<prod publishable key> --dart-define=SUPPORT_EMAIL=<support address>
```

`SUPPORT_EMAIL` goes into the User-Agent Open Food Facts asks every app to
send, so they can reach you about API use.

## 10. Before submitting

- Sign in with a fresh email on a real device against production, run
  onboarding, log by photo, barcode, search and quick add, then delete the
  account and confirm in the dashboard that everything is gone.
- Check Database → Advisors for security warnings.
- Store listings: privacy policy URL, data safety (Play) and privacy
  nutrition label (App Store) matching the privacy policy, and screenshots
  without the accuracy claims ruled out in `docs/copy-guidelines.md`.
