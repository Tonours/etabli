/**
 * Image injection — detect image file paths in user input and attach them as base64.
 *
 * When a user drops a file or pastes a path into the textbox, this extension
 * reads the file, encodes it as base64, and injects it as an ImageContent
 * alongside the remaining text.
 *
 * Handles paths with escaped spaces (dropped files) and double-quoted paths:
 *   /tmp/Capture\ d'écran\ 2026.png what's this?
 *   "/tmp/my screenshot.png" describe this
 *   ~/simple.png ./other.jpg compare
 *
 * Supports: png, jpg/jpeg, gif, webp
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import type { ImageContent } from "@mariozechner/pi-ai";
import { Container, Text } from "@mariozechner/pi-tui";
import { existsSync, readFileSync, statSync } from "node:fs";
import { basename } from "node:path";
import { resolve } from "node:path";
import { homedir } from "node:os";
import { getExtension, formatSize, tokenize, MIME_MAP, IMAGE_EXTENSIONS } from "./lib/img-utils.ts";

const MAX_FILE_SIZE = 20 * 1024 * 1024; // 20MB

function resolvePath(raw: string): string {
  const expanded = raw.startsWith("~") ? homedir() + raw.slice(1) : raw;
  return resolve(expanded);
}

function isImageFile(token: string): boolean {
  if (!IMAGE_EXTENSIONS.has(getExtension(token))) return false;
  const filePath = resolvePath(token);
  try {
    return existsSync(filePath) && statSync(filePath).isFile();
  } catch {
    return false;
  }
}

interface ImageInfo {
  content: ImageContent;
  name: string;
  size: number;
}

function readImageAsBase64(token: string): ImageInfo | null {
  const filePath = resolvePath(token);
  const ext = getExtension(filePath);
  const mimeType = MIME_MAP[ext];
  if (!mimeType) return null;

  try {
    const stat = statSync(filePath);
    if (stat.size > MAX_FILE_SIZE) return null;
    const data = readFileSync(filePath).toString("base64");
    return {
      content: { type: "image", data, mimeType },
      name: basename(filePath),
      size: stat.size,
    };
  } catch {
    return null;
  }
}

export default function (pi: ExtensionAPI) {
  let pendingImages: ImageInfo[] = [];

  // Clear preview widget when agent finishes responding
  pi.on("agent_end", async (_event, ctx) => {
    if (pendingImages.length > 0) {
      ctx.ui.setWidget("img-preview", undefined);
      pendingImages = [];
    }
  });

  pi.on("input", async (event, ctx) => {
    // Clear previous preview
    if (pendingImages.length > 0) {
      ctx.ui.setWidget("img-preview", undefined);
      pendingImages = [];
    }

    // Skip extension-injected messages only (not commands or paths)
    if (event.source === "extension") {
      return { action: "continue" as const };
    }

    const tokens = tokenize(event.text);
    const images: ImageInfo[] = [];
    const textParts: string[] = [];

    for (const token of tokens) {
      if (isImageFile(token)) {
        const img = readImageAsBase64(token);
        if (img) {
          images.push(img);
          continue;
        }
      }
      textParts.push(token);
    }

    if (images.length === 0) {
      return { action: "continue" as const };
    }

    const text = textParts.join(" ").trim() || "Describe this image.";
    const allImages: ImageContent[] = [...(event.images ?? []), ...images.map((i) => i.content)];

    // Show preview widget above editor
    pendingImages = images;
    ctx.ui.setWidget(
      "img-preview",
      (_tui, theme) => {
        const container = new Container();
        container.addChild(new Text(theme.fg("accent", `📎 ${images.length} image${images.length > 1 ? "s" : ""} attached:`), 0, 0));

        for (const img of images) {
          const icon = img.content.mimeType.includes("png")
            ? "🖼️"
            : img.content.mimeType.includes("jpg") || img.content.mimeType.includes("jpeg")
              ? "📷"
              : img.content.mimeType.includes("gif")
                ? "🎬"
                : "🖼️";
          const line = `  ${icon} ${img.name} (${formatSize(img.size)})`;
          container.addChild(new Text(theme.fg("success", line), 0, 0));
        }

        return {
          render(width: number): string[] {
            return container.render(width);
          },
          invalidate() {
            container.invalidate();
          },
        };
      },
      { placement: "aboveEditor" },
    );

    return { action: "transform" as const, text, images: allImages };
  });
}
