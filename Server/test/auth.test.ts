import { beforeAll, describe, expect, it } from "vitest";
import {
  sha256,
  verifyAppleIdentityToken,
  type AppleJsonWebKey,
  type AppleKeyProvider,
} from "../src/auth";

const NOW = new Date("2026-07-23T12:00:00.000Z");
const NOW_SECONDS = Math.floor(NOW.getTime() / 1_000);
const CLIENT_ID = "com.kathrynswint.Tali";
const RAW_NONCE = "test-raw-nonce";

let privateKey: CryptoKey;
let publicJWK: AppleJsonWebKey;

beforeAll(async () => {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  privateKey = keyPair.privateKey;
  publicJWK = {
    ...await crypto.subtle.exportKey("jwk", keyPair.publicKey),
    kid: "current-key",
    alg: "RS256",
    use: "sig",
  };
});

describe("Sign in with Apple identity-token verification", () => {
  it("accepts a correctly signed token with the expected claims", async () => {
    const claims = await verify(token(), RAW_NONCE);

    expect(claims.sub).toBe("apple-user-123");
  });

  it("accepts an audience array containing the client ID", async () => {
    const claims = await verify(token({ aud: ["another-client", CLIENT_ID] }), RAW_NONCE);

    expect(claims.sub).toBe("apple-user-123");
  });

  it("refreshes the key set once when Apple rotates to an unknown kid", async () => {
    const calls: boolean[] = [];
    const provider: AppleKeyProvider = async (forceRefresh = false) => {
      calls.push(forceRefresh);
      return forceRefresh ? [publicJWK] : [{ ...publicJWK, kid: "previous-key" }];
    };

    await verifyAppleIdentityToken(await token(), RAW_NONCE, CLIENT_ID, {
      now: NOW,
      keyProvider: provider,
    });

    expect(calls).toEqual([false, true]);
  });

  it.each([
    ["issuer", { iss: "https://attacker.example" }],
    ["audience", { aud: "another-client" }],
    ["expiration", { exp: NOW_SECONDS }],
    ["future issued-at", { iat: NOW_SECONDS + 301 }],
    ["subject", { sub: "" }],
    ["nonce", { nonce: "not-the-nonce-hash" }],
  ])("rejects an invalid %s claim", async (_label, overrides) => {
    await expect(verify(token(overrides), RAW_NONCE)).rejects.toThrow();
  });

  it("rejects a token signed by a different private key", async () => {
    const otherPair = await crypto.subtle.generateKey(
      {
        name: "RSASSA-PKCS1-v1_5",
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]),
        hash: "SHA-256",
      },
      false,
      ["sign", "verify"],
    );

    await expect(verify(makeToken(baseClaims(), otherPair.privateKey), RAW_NONCE)).rejects.toThrow(
      "Invalid JWT signature",
    );
  });

  it("rejects unsupported algorithms before key lookup", async () => {
    let called = false;
    const provider: AppleKeyProvider = async () => {
      called = true;
      return [publicJWK];
    };

    await expect(verifyAppleIdentityToken(
      await makeToken(baseClaims(), privateKey, { alg: "HS256", kid: "current-key" }),
      RAW_NONCE,
      CLIENT_ID,
      { now: NOW, keyProvider: provider },
    )).rejects.toThrow("Unsupported JWT header");
    expect(called).toBe(false);
  });
});

async function verify(jwt: Promise<string>, rawNonce: string) {
  return verifyAppleIdentityToken(await jwt, rawNonce, CLIENT_ID, {
    now: NOW,
    keyProvider: async () => [publicJWK],
  });
}

function token(overrides: Record<string, unknown> = {}): Promise<string> {
  return makeToken({ ...baseClaims(), ...overrides }, privateKey);
}

function baseClaims(): Record<string, unknown> {
  return {
    iss: "https://appleid.apple.com",
    aud: CLIENT_ID,
    exp: NOW_SECONDS + 600,
    iat: NOW_SECONDS - 10,
    sub: "apple-user-123",
    nonce: undefined,
  };
}

async function makeToken(
  inputClaims: Record<string, unknown>,
  signingKey: CryptoKey,
  header: Record<string, unknown> = { alg: "RS256", kid: "current-key" },
): Promise<string> {
  const claims = {
    ...inputClaims,
    nonce: inputClaims.nonce ?? await sha256(RAW_NONCE),
  };
  const encodedHeader = base64URL(new TextEncoder().encode(JSON.stringify(header)));
  const encodedClaims = base64URL(new TextEncoder().encode(JSON.stringify(claims)));
  const signingInput = `${encodedHeader}.${encodedClaims}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signingKey,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64URL(new Uint8Array(signature))}`;
}

function base64URL(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("base64url");
}
