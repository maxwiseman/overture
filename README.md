# Overture

Overture is a Turborepo with three runtime surfaces:

- `apps/cms`: Payload admin, published content, media, drafts, and editions on port 3002.
- `apps/web`: public Next.js website, publication API, and Better Auth on port 3001.
- `apps/ios`: native SwiftUI reader and Sign in with Apple client.

The content flow is `Payload -> /api/publication -> website and SwiftUI`. Public clients
can only read published Payload documents; editors authenticated in Payload can still
read drafts.

## Local setup

1. Install dependencies with `bun install`.
2. Copy `apps/cms/.env.example` to `apps/cms/.env` and `apps/web/.env.example` to
   `apps/web/.env`. Both apps can use the same Postgres `DATABASE_URL`: Better Auth
   owns `public`, while Payload is isolated in the `payload` schema.
3. Give Payload and Better Auth separate strong secrets.
4. Apply the Better Auth development schema with `bun run db:push`.
5. Apply the checked-in Payload migration with `bun run cms:migrate`.
6. Start both services with `bun run dev`.
7. Run `bun run cms:seed` for an idempotent published starter edition, or open
   `http://localhost:3002/admin` to create the first editor and publish your own.

The website and iOS app read the newest published edition from
`GET /api/publication/editions/current`. If Payload is down, the route returns 503 and
the iOS app keeps its bundled offline edition.

For production, run the Drizzle and Payload migrations as explicit release steps. A
successful local build does not mean either schema has been applied to production.

## Deployment

Deploy the monorepo as two projects from the same Git repository:

- CMS root directory: `apps/cms`
- Website/API root directory: `apps/web`

The CMS needs `DATABASE_URL`, `PAYLOAD_SECRET`, and `BLOB_READ_WRITE_TOKEN` from its
Vercel Blob store. The website/API needs
`DATABASE_URL`, `PAYLOAD_URL`, `BETTER_AUTH_SECRET`, `BETTER_AUTH_URL`, and
`CORS_ORIGIN`, plus the Apple variables below when Apple sign-in is enabled. Keep
`PAYLOAD_URL` server-only and point it at the deployed CMS origin.

Release in this order:

1. Run `bun run db:migrate` and `bun run cms:migrate` against the production database.
2. Deploy the CMS and verify its published-edition API.
3. Set the website's `PAYLOAD_URL` to the CMS HTTPS origin and deploy the website/API.
4. Verify `/api/auth/ok` and `/api/publication/editions/current` on the public API host.
5. Point `maxw.news` at the website/API deployment, then test its TLS certificate.
6. Build the iOS Release configuration, which uses `https://maxw.news`.

Payload stores production media in Vercel Blob. When `BLOB_READ_WRITE_TOKEN` is absent,
such as in a basic local setup, the adapter is disabled and Payload uses local storage.

When `overture.press` is ready, attach `overture.press` and `cms.overture.press` to the
existing Vercel projects, add the new Apple return URL, update the production origins and
iOS Release URL, and keep `maxw.news` available through at least one app release.

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

- `bun run dev`: start the CMS and website.
- `bun run dev:cms` / `bun run dev:web`: start one web app.
- `bun run cms:generate:types`: regenerate Payload types.
- `bun run cms:migrate:create` / `bun run cms:migrate`: create or apply CMS migrations.
- `bun run cms:seed`: create or refresh the published starter edition.
- `bun run db:push`: update a development database directly.
- `bun run db:generate` / `bun run db:migrate`: create and apply release auth migrations.
- `bun run check-types`: typecheck all TypeScript apps.
- `bun run build`: build the CMS and website.

Unsigned iOS build:

```sh
xcodebuild -project apps/ios/Overture.xcodeproj -scheme Overture \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath /private/tmp/overture-derived CODE_SIGNING_ALLOWED=NO build
```
