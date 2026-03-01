import { describe, expect, test } from "bun:test";
import { getExtension, formatSize, tokenize, isImagePath, IMAGE_EXTENSIONS, MIME_MAP } from "../lib/img-utils.ts";

describe("getExtension", () => {
  test("extracts extension from simple path", () => {
    expect(getExtension("/tmp/image.png")).toBe(".png");
  });

  test("extracts extension from path with spaces", () => {
    expect(getExtension("/tmp/my image.jpg")).toBe(".jpg");
  });

  test("returns lowercase extension", () => {
    expect(getExtension("/tmp/image.PNG")).toBe(".png");
    expect(getExtension("/tmp/image.JpG")).toBe(".jpg");
  });

  test("returns empty string for no extension", () => {
    expect(getExtension("/tmp/README")).toBe("");
  });

  test("handles hidden files (treats as extension)", () => {
    // .gitignore after dot is treated as extension
    expect(getExtension("/tmp/.gitignore")).toBe(".gitignore");
  });

  test("handles multiple dots", () => {
    expect(getExtension("/tmp/archive.tar.gz")).toBe(".gz");
  });
});

describe("formatSize", () => {
  test("formats bytes", () => {
    expect(formatSize(512)).toBe("512B");
    expect(formatSize(1023)).toBe("1023B");
  });

  test("formats kilobytes", () => {
    expect(formatSize(1024)).toBe("1.0KB");
    expect(formatSize(1536)).toBe("1.5KB");
    expect(formatSize(10240)).toBe("10.0KB");
  });

  test("formats megabytes", () => {
    expect(formatSize(1024 * 1024)).toBe("1.0MB");
    expect(formatSize(5 * 1024 * 1024)).toBe("5.0MB");
    expect(formatSize(20 * 1024 * 1024)).toBe("20.0MB");
  });
});

describe("tokenize", () => {
  test("splits simple whitespace-separated tokens", () => {
    expect(tokenize("hello world test")).toEqual(["hello", "world", "test"]);
  });

  test("handles backslash-escaped spaces", () => {
    expect(tokenize("/path/to/my\\ file.png")).toEqual(["/path/to/my file.png"]);
  });

  test("handles macOS screenshot paths with apostrophes", () => {
    const input = "/var/folders/Capture\\ d'écran\\ 2026.png";
    expect(tokenize(input)).toEqual(["/var/folders/Capture d'écran 2026.png"]);
  });

  test("handles double-quoted strings", () => {
    expect(tokenize('"my file with spaces.png" check this')).toEqual([
      "my file with spaces.png",
      "check",
      "this",
    ]);
  });

  test("handles escaped characters in quotes", () => {
    // Backslash is stripped, so \n becomes n
    expect(tokenize('"hello\\nworld" test')).toEqual(["hellonworld", "test"]);
  });

  test("preserves apostrophes in unquoted text", () => {
    // macOS filenames often contain apostrophes
    expect(tokenize("what's up")).toEqual(["what's", "up"]);
  });

  test("handles multiple images with text", () => {
    const input = "./a.png ./b.jpg compare these";
    expect(tokenize(input)).toEqual(["./a.png", "./b.jpg", "compare", "these"]);
  });

  test("handles mixed escaped and regular spaces", () => {
    const input = "/tmp/file\\ one.png /tmp/filetwo.png";
    expect(tokenize(input)).toEqual(["/tmp/file one.png", "/tmp/filetwo.png"]);
  });

  test("handles empty input", () => {
    expect(tokenize("")).toEqual([]);
  });

  test("handles whitespace including newlines", () => {
    // Newlines are treated as literal characters and become tokens
    expect(tokenize("   \t  ")).toEqual([]);
  });

  test("handles single token", () => {
    expect(tokenize("single")).toEqual(["single"]);
  });
});

describe("isImagePath", () => {
  test("detects png files", () => {
    expect(isImagePath("image.png")).toBe(true);
    expect(isImagePath("image.PNG")).toBe(true);
  });

  test("detects jpg/jpeg files", () => {
    expect(isImagePath("image.jpg")).toBe(true);
    expect(isImagePath("image.jpeg")).toBe(true);
    expect(isImagePath("image.JPG")).toBe(true);
  });

  test("detects gif files", () => {
    expect(isImagePath("image.gif")).toBe(true);
  });

  test("detects webp files", () => {
    expect(isImagePath("image.webp")).toBe(true);
  });

  test("rejects non-image extensions", () => {
    expect(isImagePath("file.txt")).toBe(false);
    expect(isImagePath("file.pdf")).toBe(false);
    expect(isImagePath("file")).toBe(false);
  });

  test("handles paths with directories", () => {
    expect(isImagePath("/tmp/images/photo.png")).toBe(true);
    expect(isImagePath("~/Pictures/screenshot.jpg")).toBe(true);
  });
});

describe("IMAGE_EXTENSIONS", () => {
  test("contains expected extensions", () => {
    expect(IMAGE_EXTENSIONS.has(".png")).toBe(true);
    expect(IMAGE_EXTENSIONS.has(".jpg")).toBe(true);
    expect(IMAGE_EXTENSIONS.has(".jpeg")).toBe(true);
    expect(IMAGE_EXTENSIONS.has(".gif")).toBe(true);
    expect(IMAGE_EXTENSIONS.has(".webp")).toBe(true);
  });

  test("does not contain other extensions", () => {
    expect(IMAGE_EXTENSIONS.has(".txt")).toBe(false);
    expect(IMAGE_EXTENSIONS.has(".pdf")).toBe(false);
  });
});

describe("MIME_MAP", () => {
  test("maps png to image/png", () => {
    expect(MIME_MAP[".png"]).toBe("image/png");
  });

  test("maps jpg and jpeg to image/jpeg", () => {
    expect(MIME_MAP[".jpg"]).toBe("image/jpeg");
    expect(MIME_MAP[".jpeg"]).toBe("image/jpeg");
  });

  test("maps gif to image/gif", () => {
    expect(MIME_MAP[".gif"]).toBe("image/gif");
  });

  test("maps webp to image/webp", () => {
    expect(MIME_MAP[".webp"]).toBe("image/webp");
  });
});
