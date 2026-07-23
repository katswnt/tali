import { describe, expect, it } from "vitest";
import { pairingCodeFromMessage } from "../src/pairing";

describe("phone pairing command", () => {
  it("accepts an exact eight-character code", () => {
    expect(pairingCodeFromMessage("PAIR ABCD2345")).toBe("ABCD2345");
    expect(pairingCodeFromMessage(" pair abcd2345 ")).toBe("ABCD2345");
  });

  it("does not treat normal habit text as pairing", () => {
    expect(pairingCodeFromMessage("yoga")).toBeNull();
    expect(pairingCodeFromMessage("PAIR short")).toBeNull();
    expect(pairingCodeFromMessage("PAIR ABCD2345 extra")).toBeNull();
  });
});
