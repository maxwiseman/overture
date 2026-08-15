# Overture

Overture is a Turborepo with two runtime surfaces:

- `apps/web`: the public Next.js website, Payload CMS, publication API, and Better Auth on port 3001.
- `apps/ios`: native SwiftUI reader and Sign in with Apple client.

The website reads Payload through its server-side Local API. The SwiftUI app reads the
same normalized content contract through `GET /api/publication/editions/current`.
Public clients can only read published Payload documents; editors authenticated in
Payload can still read drafts.

## Local setup

1. Install dependencies with `bun install`.
2. Copy `apps/web/.env.example` to `apps/web/.env`. Better Auth and Payload share the
   Postgres `DATABASE_URL`: Better Auth owns `public`, while Payload is isolated in the
   `payload` schema.
3. Give Payload and Better Auth separate strong secrets.
4. Apply the Better Auth development schema with `bun run db:push`.
5. Apply the checked-in Payload migration with `bun run cms:migrate`.
6. Start the application with `bun run dev`.
7. Run `bun run cms:seed` for an idempotent published starter edition, or open
   `http://localhost:3001/admin` to create the first editor and publish your own.

The website and iOS app read the newest published edition from
`GET /api/publication/editions/current`. The iOS app keeps its bundled offline edition
when that route is unavailable.

For production, run the Drizzle and Payload migrations as explicit release steps. A
successful local build does not mean either schema has been applied to production.

## Deployment

Deploy the monorepo as one web project:

- Root directory: `apps/web`

The application needs `DATABASE_URL`, `PAYLOAD_SECRET`, `BLOB_READ_WRITE_TOKEN`,
`BETTER_AUTH_SECRET`, `BETTER_AUTH_URL`, and `CORS_ORIGIN`, plus the Apple variables
below when Apple sign-in is enabled. Hosted PostgreSQL connection strings should use
`sslmode=verify-full` so certificate and hostname verification remain explicit.

Release in this order:

1. Run `bun run db:migrate` and `bun run cms:migrate` against the production database.
2. Deploy the website/CMS application.
3. Verify `/admin`, `/api/auth/ok`, and `/api/publication/editions/current` on the public host.
4. Point `maxw.news` at the deployment, then test its TLS certificate.
5. Build the iOS Release configuration, which uses `https://maxw.news`.

Payload stores production media in Vercel Blob. When `BLOB_READ_WRITE_TOKEN` is absent,
such as in a basic local setup, the adapter is disabled and Payload uses local storage.

When `overture.press` is ready, attach it to the web project, add the new Apple return
URL, update the production origins and iOS Release URL, and keep `maxw.news` available
through at least one app release.

## Sign in with Apple

In Apple Developer:

1. Enable Sign in with Apple for the App ID `com.overture.news.swiftui`.
2. Create a web Service ID for `APPLE_CLIENT_ID` and register
   `https://maxw.news/api/auth/callback/apple` as its return URL. Add the equivalent
   `overture.press` URL before the domain migration.
3. Create a Sign in with Apple key. Set `APPLE_TEAM_ID`, `APPLE_KEY_ID`, and
   `APPLE_PRIVATE_KEY`; the server generates a fresh client-secret JWT at startup.
   `APPLE_CLIENT_SECRET` remains available as a manually rotated fallback.
4. Set `APPLE_APP_BUNDLE_IDENTIFIER=com.overture.news.swiftui` so Better Auth accepts
   native identity tokens whose audience is the app bundle identifier.

The native app hashes a one-time nonce, uses `AuthenticationServices`, sends Apple's
identity token to `/api/auth/sign-in/social`, captures Better Auth's `set-auth-token`
header, and keeps that bearer token in Keychain. Email/password remains available on
the website as a development fallback.

## Commands

- `bun run dev`: start the unified website and CMS.
- `bun run dev:web`: start the unified web app directly.
- `bun run cms:generate:types`: regenerate Payload types.
- `bun run cms:migrate:create` / `bun run cms:migrate`: create or apply CMS migrations.
- `bun run cms:seed`: create or refresh the published starter edition.
- `bun run db:push`: update a development database directly.
- `bun run db:generate` / `bun run db:migrate`: create and apply release auth migrations.
- `bun run check-types`: typecheck all TypeScript apps.
- `bun run build`: build the website and CMS.

Unsigned iOS build:

```sh
xcodebuild -project apps/ios/Overture.xcodeproj -scheme Overture \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath /private/tmp/overture-derived CODE_SIGNING_ALLOWED=NO build
```
