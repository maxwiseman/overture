import { createDb } from "@overture/db";
import * as schema from "@overture/db/schema/auth";
import { env } from "@overture/env/server";
import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { nextCookies } from "better-auth/next-js";
import { bearer } from "better-auth/plugins/bearer";
import { importPKCS8, SignJWT } from "jose";

async function generateAppleClientSecret() {
  const privateKey = await importPKCS8(
    env.APPLE_PRIVATE_KEY!.replace(/\\n/g, "\n"),
    "ES256",
  );
  const now = Math.floor(Date.now() / 1000);

  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APPLE_KEY_ID })
    .setIssuer(env.APPLE_TEAM_ID!)
    .setSubject(env.APPLE_CLIENT_ID!)
    .setAudience("https://appleid.apple.com")
    .setIssuedAt(now)
    .setExpirationTime(now + 180 * 24 * 60 * 60)
    .sign(privateKey);
}

function createAppleProvider() {
  const appleValues = [
    env.APPLE_CLIENT_ID,
    env.APPLE_CLIENT_SECRET,
    env.APPLE_APP_BUNDLE_IDENTIFIER,
    env.APPLE_TEAM_ID,
    env.APPLE_KEY_ID,
    env.APPLE_PRIVATE_KEY,
  ];
  if (appleValues.every((value) => value === undefined)) return undefined;

  if (!env.APPLE_CLIENT_ID || !env.APPLE_APP_BUNDLE_IDENTIFIER) {
    throw new Error(
      "Apple auth requires APPLE_CLIENT_ID and APPLE_APP_BUNDLE_IDENTIFIER.",
    );
  }

  const baseConfig = {
    clientId: env.APPLE_CLIENT_ID,
    appBundleIdentifier: env.APPLE_APP_BUNDLE_IDENTIFIER,
  };

  if (env.APPLE_TEAM_ID && env.APPLE_KEY_ID && env.APPLE_PRIVATE_KEY) {
    return {
      apple: async () => ({
        ...baseConfig,
        clientSecret: await generateAppleClientSecret(),
      }),
    };
  }

  if (env.APPLE_CLIENT_SECRET) {
    return {
      apple: {
        ...baseConfig,
        clientSecret: env.APPLE_CLIENT_SECRET,
      },
    };
  }

  throw new Error(
    "Apple auth requires APPLE_CLIENT_SECRET or APPLE_TEAM_ID, APPLE_KEY_ID, and APPLE_PRIVATE_KEY.",
  );
}

export function createAuth() {
  const db = createDb();
  const apple = createAppleProvider();

  return betterAuth({
    database: drizzleAdapter(db, {
      provider: "pg",

      schema: schema,
    }),
    trustedOrigins: [env.CORS_ORIGIN, "https://appleid.apple.com"],
    user: {
      additionalFields: {
        role: {
          type: ["reader", "editor"],
          required: true,
          defaultValue: "reader",
          input: false,
        },
      },
    },
    socialProviders: apple,
    emailAndPassword: {
      enabled: true,
    },
    secret: env.BETTER_AUTH_SECRET,
    baseURL: env.BETTER_AUTH_URL,
    plugins: [bearer(), nextCookies()],
  });
}

export const auth = createAuth();
