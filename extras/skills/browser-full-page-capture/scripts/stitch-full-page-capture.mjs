#!/usr/bin/env node
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import os from "node:os";
import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const LIMITS = Object.freeze({ dimension: 10_000, step: 10_000, wait: 60_000, quality: 31, segments: 500, stitchedHeight: 100_000 });

function usage() {
  console.log(`Usage:
  node stitch-full-page-capture.mjs --url <url> --out <image.jpg> [options]
  node stitch-full-page-capture.mjs --manifest <manifest.json> [options]

Options:
  --item <n>              Manifest mode: capture only one 1-based item index.
  --viewport <WxH>        Viewport size. Default: 1440x1100.
  --step <px>             Scroll step. Default: viewport height - 150.
  --wait <ms>             Wait after each scroll stop. Default: 2000.
  --quality <n>           ffmpeg JPEG quality. Default: 3.
`);
}

function finiteInteger(value, name, { min, max }) {
  if (!Number.isFinite(value) || !Number.isInteger(value) || value < min || value > max) {
    throw new Error(`${name} must be an integer from ${min} to ${max}`);
  }
  return value;
}

export function parseArgs(argv) {
  const args = {
    url: "",
    out: "",
    manifest: "",
    item: 0,
    viewport: "1440x1100",
    step: null,
    wait: 2000,
    quality: 3,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--help" || arg === "-h") args.help = true;
    else if (arg === "--url") args.url = argv[++index] || "";
    else if (arg === "--out") args.out = argv[++index] || "";
    else if (arg === "--manifest") args.manifest = argv[++index] || "";
    else if (arg === "--item") args.item = Number(argv[++index] || 0);
    else if (arg === "--viewport") args.viewport = argv[++index] || args.viewport;
    else if (arg === "--step") args.step = Number(argv[++index] || 0);
    else if (arg === "--wait") args.wait = Number(argv[++index] || args.wait);
    else if (arg === "--quality") args.quality = Number(argv[++index] || args.quality);
    else throw new Error(`Unknown argument: ${arg}`);
  }

  const match = args.viewport.match(/^(\d+)x(\d+)$/);
  if (!match) throw new Error(`Invalid --viewport: ${args.viewport}`);

  args.width = Number(match[1]);
  args.height = Number(match[2]);
  finiteInteger(args.width, "viewport width", { min: 1, max: LIMITS.dimension });
  finiteInteger(args.height, "viewport height", { min: 1, max: LIMITS.dimension });
  if (args.step === null) args.step = Math.max(1, args.height - 150);
  finiteInteger(args.step, "--step", { min: 1, max: LIMITS.step });
  finiteInteger(args.wait, "--wait", { min: 0, max: LIMITS.wait });
  finiteInteger(args.quality, "--quality", { min: 1, max: LIMITS.quality });
  finiteInteger(args.item, "--item", { min: 0, max: 1_000_000 });
  if (args.step > args.height) {
    throw new Error(`--step must be <= viewport height (${args.height})`);
  }
  if (args.manifest && (args.url || args.out)) {
    throw new Error("--manifest cannot be combined with --url or --out");
  }
  if (!args.manifest && args.item) throw new Error("--item requires --manifest");
  if (args.url) args.url = validateHttpUrl(args.url);

  return args;
}

export function planSegments(scrollHeight, viewportHeight, step, maxSegments = LIMITS.segments) {
  finiteInteger(scrollHeight, "scroll height", { min: 1, max: 100_000_000 });
  finiteInteger(viewportHeight, "viewport height", { min: 1, max: LIMITS.dimension });
  finiteInteger(step, "step", { min: 1, max: LIMITS.step });
  const maxScrollY = Math.max(0, scrollHeight - viewportHeight);
  const positions = [];
  for (let y = 0; y < maxScrollY; y += step) {
    if (positions.length >= maxSegments) throw new Error(`Capture exceeds ${maxSegments} segment cap`);
    positions.push(y);
  }
  if (!positions.includes(maxScrollY)) positions.push(maxScrollY);
  if (positions.length > maxSegments) throw new Error(`Capture exceeds ${maxSegments} segment cap`);
  return positions;
}

export function resolveContained(baseDir, relativePath, field = "output path") {
  if (!relativePath || path.isAbsolute(relativePath)) throw new Error(`${field} must be a relative path`);
  const base = path.resolve(baseDir);
  const resolved = path.resolve(base, relativePath);
  if (resolved !== base && !resolved.startsWith(`${base}${path.sep}`)) {
    throw new Error(`${field} escapes the manifest directory`);
  }
  return resolved;
}

export function validateHttpUrl(value, field = "--url") {
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`${field} must be a valid http or https URL`);
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error(`${field} must use http or https`);
  }
  return parsed.href;
}

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", (error) => {
      reject(new Error(`${command} unavailable: ${error.message}`));
    });
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} ${args.join(" ")}\n${stderr.trim()}`));
    });
  });
}

async function ensureParent(file) {
  await fs.mkdir(path.dirname(file), { recursive: true });
}

async function requirePlaywright() {
  try {
    const requireFromWorkspace = createRequire(path.join(process.cwd(), "package.json"));
    return requireFromWorkspace("playwright");
  } catch (error) {
    throw new Error(
      `Playwright is required in the current project to capture browser pages. ${error.message}`,
    );
  }
}

async function captureUrl({ chromium, url, out, args, tempRoot }) {
  await ensureParent(out);
  await fs.mkdir(tempRoot, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const rawDir = path.join(tempRoot, "raw");
  const segmentDir = path.join(tempRoot, "segments");
  await fs.mkdir(rawDir, { recursive: true });
  await fs.mkdir(segmentDir, { recursive: true });

  try {
    const page = await browser.newPage({
      viewport: { width: args.width, height: args.height },
      deviceScaleFactor: 1,
    });

    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
    await page.waitForTimeout(5000);

    const initialHeight = await page.evaluate(() =>
      Math.max(document.documentElement.scrollHeight, document.body?.scrollHeight || 0),
    );

    for (let y = 0; y <= Math.max(0, initialHeight - args.height); y += args.height) {
      await page.evaluate((scrollY) => window.scrollTo(0, scrollY), y);
      await page.waitForTimeout(350);
    }

    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(args.wait);

    const scrollHeight = await page.evaluate(() =>
      Math.max(document.documentElement.scrollHeight, document.body?.scrollHeight || 0),
    );
    if (scrollHeight > LIMITS.stitchedHeight) {
      throw new Error(`Page height ${scrollHeight}px exceeds ${LIMITS.stitchedHeight}px stitched-height cap`);
    }
    const requestedPositions = planSegments(scrollHeight, args.height, args.step);

    const captures = [];
    for (let index = 0; index < requestedPositions.length; index += 1) {
      await page.evaluate((scrollY) => window.scrollTo(0, scrollY), requestedPositions[index]);
      await page.waitForTimeout(args.wait);
      if (index > 0) {
        await page.evaluate(() => {
          for (const element of document.querySelectorAll("body *")) {
            const position = getComputedStyle(element).position;
            if (position === "fixed" || position === "sticky") {
              element.dataset.etabliCaptureVisibility = element.style.visibility;
              element.style.visibility = "hidden";
            }
          }
        });
      }
      const actualY = await page.evaluate(() => Math.round(window.scrollY || 0));
      if (captures.some((capture) => capture.y === actualY)) continue;

      const rawFile = path.join(rawDir, `${String(index + 1).padStart(3, "0")}.jpg`);
      await page.screenshot({ path: rawFile, type: "jpeg", quality: 86, fullPage: false });
      captures.push({ y: actualY, rawFile });
    }

    captures.sort((left, right) => left.y - right.y);
    if (captures.length === 0) throw new Error(`No viewport captures produced for ${url}`);

    const segmentFiles = [];
    let stitchedHeight = 0;
    for (let index = 0; index < captures.length; index += 1) {
      const current = captures[index];
      const next = captures[index + 1];
      const segmentHeight = Math.max(
        1,
        Math.min(args.height, next ? next.y - current.y : scrollHeight - current.y),
      );
      const segmentFile = path.join(segmentDir, `${String(index + 1).padStart(3, "0")}.jpg`);
      await run("ffmpeg", [
        "-y",
        "-i",
        current.rawFile,
        "-vf",
        `crop=${args.width}:${segmentHeight}:0:0`,
        "-q:v",
        String(args.quality),
        segmentFile,
      ]);
      segmentFiles.push(segmentFile);
      stitchedHeight += segmentHeight;
    }

    if (segmentFiles.length === 1) {
      await fs.copyFile(segmentFiles[0], out);
    } else {
      const stackInputs = segmentFiles.flatMap((file) => ["-i", file]);
      const stackFilter = `${segmentFiles.map((_, index) => `[${index}:v]`).join("")}vstack=inputs=${segmentFiles.length}`;
      await run("ffmpeg", [
        "-y",
        ...stackInputs,
        "-filter_complex",
        stackFilter,
        "-q:v",
        String(args.quality),
        out,
      ]);
    }

    await page.close();
    return {
      url,
      out,
      width: args.width,
      height: stitchedHeight,
      scrollHeight,
      step: args.step,
      wait: args.wait,
      segments: segmentFiles.length,
    };
  } finally {
    await browser.close();
  }
}

async function cropSections({ fullFile, baseDir, sections, args, fullHeight }) {
  const updated = [];

  for (let index = 0; index < sections.length; index += 1) {
    const section = sections[index];
    if (!section.file) {
      updated.push(section);
      continue;
    }

    const rawYStart = Number.isFinite(Number(section.yStart))
      ? Math.max(0, Math.round(Number(section.yStart)))
      : Math.round((fullHeight * index) / sections.length);
    const yStart = Math.min(rawYStart, Math.max(0, fullHeight - 1));
    const rawYEnd = Number.isFinite(Number(section.yEnd))
      ? Math.min(fullHeight, Math.round(Number(section.yEnd)))
      : index === sections.length - 1
        ? fullHeight
        : Math.round((fullHeight * (index + 1)) / sections.length);
    const yEnd = Math.min(fullHeight, Math.max(yStart + 1, rawYEnd));
    const cropHeight = Math.max(1, yEnd - yStart);
    const cropFile = resolveContained(baseDir, section.file, `sectionImages[${index}].file`);

    await ensureParent(cropFile);
    await run("ffmpeg", [
      "-y",
      "-i",
      fullFile,
      "-vf",
      `crop=${args.width}:${cropHeight}:0:${yStart}`,
      "-q:v",
      String(args.quality),
      cropFile,
    ]);

    updated.push({
      ...section,
      source: path.relative(baseDir, fullFile).replaceAll(path.sep, "/"),
      yStart,
      yEnd,
      height: cropHeight,
    });
  }

  return updated;
}

async function captureManifest({ chromium, manifestPath, args }) {
  const absoluteManifest = path.resolve(manifestPath);
  const baseDir = path.dirname(absoluteManifest);
  const manifest = JSON.parse(await fs.readFile(absoluteManifest, "utf8"));
  if (!Array.isArray(manifest.items)) throw new Error("Manifest must contain items[]");

  const targets = manifest.items
    .map((item, index) => ({ item, index }))
    .filter(({ index }) => !args.item || index === args.item - 1);
  if (targets.length === 0) throw new Error(`No manifest items matched --item ${args.item}`);

  const tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), "etabli-full-page-"));

  try {
    for (const { item, index } of targets) {
      if (!item.pageUrl) throw new Error(`Item ${index + 1} is missing pageUrl`);
      if (!item.fullPageImage) throw new Error(`Item ${index + 1} is missing fullPageImage`);
      const pageUrl = validateHttpUrl(item.pageUrl, `items[${index}].pageUrl`);

      const fullFile = resolveContained(baseDir, item.fullPageImage, `items[${index}].fullPageImage`);
      const result = await captureUrl({
        chromium,
        url: pageUrl,
        out: fullFile,
        args,
        tempRoot: path.join(tempRoot, `item-${String(index + 1).padStart(3, "0")}`),
      });

      if (Array.isArray(item.sectionImages) && item.sectionImages.length > 0) {
        item.sectionImages = await cropSections({
          fullFile,
          baseDir,
          sections: item.sectionImages,
          args,
          fullHeight: result.height,
        });
      }

      item.fullPageCapture = {
        method: "stitchedViewportScreenshots",
        viewport: { width: args.width, height: args.height },
        step: args.step,
        waitMs: args.wait,
        segmentCount: result.segments,
        scrollHeight: result.scrollHeight,
        stitchedHeight: result.height,
      };
    }
  } finally {
    await fs.rm(tempRoot, { recursive: true, force: true });
  }

  const stagedManifest = `${absoluteManifest}.tmp-${process.pid}`;
  await fs.writeFile(stagedManifest, `${JSON.stringify(manifest, null, 2)}\n`);
  await fs.rename(stagedManifest, absoluteManifest);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    usage();
    return;
  }

  if (!args.manifest && (!args.url || !args.out)) {
    usage();
    process.exitCode = 2;
    return;
  }

  await run("ffmpeg", ["-version"]);
  const { chromium } = await requirePlaywright();

  if (args.manifest) {
    await captureManifest({ chromium, manifestPath: args.manifest, args });
    return;
  }

  const out = path.resolve(args.out);
  const tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), "etabli-full-page-"));
  try {
    await captureUrl({ chromium, url: args.url, out, args, tempRoot });
  } finally {
    await fs.rm(tempRoot, { recursive: true, force: true });
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] || "").href) {
  main().catch((error) => {
    console.error(error.stack || error.message);
    process.exit(1);
  });
}
