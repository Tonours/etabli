import { multiplyTransforms } from "./kinematics.js";

const IDENTITY_TRANSFORM = Object.freeze([
  1, 0, 0, 0,
  0, 1, 0, 0,
  0, 0, 1, 0,
  0, 0, 0, 1
]);

function elementName(node) {
  return String(node?.localName || node?.tagName || "").split(":").pop();
}

function childElements(parent) {
  return Array.from(parent?.childNodes || []).filter((node) => node?.nodeType === 1);
}

function childElementsByTag(parent, tagName) {
  return childElements(parent).filter((node) => elementName(node) === tagName);
}

function descendantElementsByTag(parent, tagName, result = []) {
  for (const child of childElements(parent)) {
    if (elementName(child) === tagName) {
      result.push(child);
    }
    descendantElementsByTag(child, tagName, result);
  }
  return result;
}

function childText(parent, tagName) {
  return String(childElementsByTag(parent, tagName)[0]?.textContent || "").trim();
}

function parseNumberList(value, count, fallback, context) {
  const text = String(value || "").trim();
  if (!text) {
    return [...fallback];
  }
  const parsed = text.split(/\s+/).map((entry) => Number(entry));
  if (parsed.length !== count || parsed.some((entry) => !Number.isFinite(entry))) {
    throw new Error(`${context} must contain ${count} numeric values`);
  }
  return parsed;
}

function translationTransform(x, y, z) {
  return [
    1, 0, 0, x,
    0, 1, 0, y,
    0, 0, 1, z,
    0, 0, 0, 1
  ];
}

function scaleTransform(x, y, z) {
  return [
    x, 0, 0, 0,
    0, y, 0, 0,
    0, 0, z, 0,
    0, 0, 0, 1
  ];
}

function rotationTransformFromRpy(roll, pitch, yaw) {
  const sr = Math.sin(roll);
  const cr = Math.cos(roll);
  const sp = Math.sin(pitch);
  const cp = Math.cos(pitch);
  const sy = Math.sin(yaw);
  const cy = Math.cos(yaw);
  return [
    cy * cp, (cy * sp * sr) - (sy * cr), (cy * sp * cr) + (sy * sr), 0,
    sy * cp, (sy * sp * sr) + (cy * cr), (sy * sp * cr) - (cy * sr), 0,
    -sp, cp * sr, cp * cr, 0,
    0, 0, 0, 1
  ];
}

function poseTransform(values) {
  return multiplyTransforms(
    translationTransform(values[0], values[1], values[2]),
    rotationTransformFromRpy(values[3], values[4], values[5])
  );
}

function parsePose(parentElement, context) {
  const poseElement = childElementsByTag(parentElement, "pose")[0] || null;
  if (!poseElement) {
    return {
      hasPose: false,
      relativeTo: "",
      values: [0, 0, 0, 0, 0, 0],
      transform: [...IDENTITY_TRANSFORM]
    };
  }
  const values = parseNumberList(
    poseElement.textContent,
    6,
    [0, 0, 0, 0, 0, 0],
    `${context} pose`
  );
  return {
    hasPose: true,
    relativeTo: String(poseElement.getAttribute("relative_to") || "").trim(),
    values,
    transform: poseTransform(values)
  };
}

function poseValuesAreIdentity(pose) {
  return (Array.isArray(pose?.values) ? pose.values : []).every((value) => Math.abs(Number(value) || 0) <= 1e-12);
}

function isAllowedModelFrame(relativeTo, modelName) {
  return !relativeTo || relativeTo === "world" || relativeTo === "__model__" || relativeTo === modelName;
}

function normalizeAbsoluteUrl(url) {
  if (url instanceof URL) {
    return url.toString();
  }
  return new URL(String(url || "/"), globalThis.window?.location?.href || "http://localhost/").toString();
}

function resolveMeshUrl(uri, sourceUrl) {
  const rawUri = String(uri || "").trim();
  if (!rawUri) {
    throw new Error("SDF mesh URI is required");
  }
  const normalizedSourceUrl = normalizeAbsoluteUrl(sourceUrl);
  let resolvedUrl;
  if (rawUri.startsWith("package://")) {
    resolvedUrl = new URL(rawUri.slice("package://".length).replace(/^\/+/, ""), new URL("/", normalizedSourceUrl));
  } else if (/^[a-z][a-z0-9+.-]*:\/\//i.test(rawUri)) {
    throw new Error(`Unsupported SDF mesh URI scheme: ${rawUri}`);
  } else {
    resolvedUrl = new URL(rawUri, normalizedSourceUrl);
  }
  return `${resolvedUrl.pathname}${resolvedUrl.search}`;
}

function labelForMeshUri(uri) {
  const parts = String(uri || "").split("/");
  return parts[parts.length - 1] || "mesh";
}

function parseRgbaColor(colorText, context) {
  const rawValues = String(colorText || "").trim().split(/\s+/).filter(Boolean);
  if (rawValues.length !== 3 && rawValues.length !== 4) {
    throw new Error(`${context} must contain 3 or 4 numeric color values`);
  }
  const values = rawValues.map((entry) => Number(entry));
  if (values.some((value) => !Number.isFinite(value) || value < 0 || value > 1)) {
    throw new Error(`${context} must use color values between 0 and 1`);
  }
  return `#${values.slice(0, 3).map((value) => {
    const component = Math.round(value * 255);
    return component.toString(16).padStart(2, "0");
  }).join("")}`;
}

function materialColorFromElement(materialElement, context) {
  if (!materialElement) {
    return "";
  }
  const diffuseText = childText(materialElement, "diffuse");
  if (diffuseText) {
    return parseRgbaColor(diffuseText, `${context} diffuse material`);
  }
  const ambientText = childText(materialElement, "ambient");
  return ambientText ? parseRgbaColor(ambientText, `${context} ambient material`) : "";
}

function parseMeshInstance(containerElement, { linkName, kind, index, sourceUrl }) {
  const labelKind = kind === "collision" ? "collision" : "visual";
  const pose = parsePose(containerElement, `SDF link ${linkName} ${labelKind} ${index}`);
  if (pose.relativeTo && pose.relativeTo !== linkName) {
    throw new Error(`SDF link ${linkName} ${labelKind} ${index} uses unsupported pose frame ${JSON.stringify(pose.relativeTo)}`);
  }
  const geometryElement = childElementsByTag(containerElement, "geometry")[0] || null;
  const meshElement = geometryElement ? childElementsByTag(geometryElement, "mesh")[0] : null;
  if (!meshElement) {
    throw new Error(`SDF link ${linkName} ${labelKind} ${index} uses unsupported geometry; only mesh geometry is supported`);
  }
  const uri = childText(meshElement, "uri");
  if (!uri) {
    throw new Error(`SDF link ${linkName} ${labelKind} ${index} is missing a mesh URI`);
  }
  const [scaleX, scaleY, scaleZ] = parseNumberList(
    childText(meshElement, "scale"),
    3,
    [1, 1, 1],
    `SDF link ${linkName} ${labelKind} ${index} mesh scale`
  );
  return {
    id: `${linkName}:${kind[0]}${index}`,
    label: labelForMeshUri(uri),
    meshUrl: resolveMeshUrl(uri, sourceUrl || "/"),
    color: materialColorFromElement(
      childElementsByTag(containerElement, "material")[0] || null,
      `SDF link ${linkName} ${labelKind} ${index}`
    ),
    localTransform: multiplyTransforms(
      pose.transform,
      scaleTransform(scaleX, scaleY, scaleZ)
    )
  };
}

function parseLink(linkElement, sourceUrl) {
  const name = String(linkElement.getAttribute("name") || "").trim();
  if (!name) {
    throw new Error("SDF link name is required");
  }
  const visuals = childElementsByTag(linkElement, "visual").map((visualElement, index) => (
    parseMeshInstance(visualElement, { linkName: name, kind: "visual", index: index + 1, sourceUrl })
  ));
  const collisions = childElementsByTag(linkElement, "collision").map((collisionElement, index) => (
    parseMeshInstance(collisionElement, { linkName: name, kind: "collision", index: index + 1, sourceUrl })
  ));
  return {
    name,
    visuals,
    collisions,
    pose: parsePose(linkElement, `SDF link ${name}`)
  };
}

function parseJointLimit(axisElement, jointName, jointType) {
  if (jointType === "continuous") {
    return { minValueDeg: -180, maxValueDeg: 180 };
  }
  if (jointType !== "revolute" && jointType !== "prismatic") {
    return { minValueDeg: 0, maxValueDeg: 0 };
  }
  const limitElement = childElementsByTag(axisElement, "limit")[0] || null;
  const lower = Number(childText(limitElement, "lower"));
  const upper = Number(childText(limitElement, "upper"));
  if (!Number.isFinite(lower) || !Number.isFinite(upper)) {
    throw new Error(`SDF ${jointType} joint ${jointName} has invalid limits`);
  }
  if (jointType === "revolute") {
    return {
      minValueDeg: (lower * 180) / Math.PI,
      maxValueDeg: (upper * 180) / Math.PI
    };
  }
  return {
    minValueDeg: lower,
    maxValueDeg: upper
  };
}

function parentByChildMap(joints) {
  const result = new Map();
  for (const joint of joints) {
    result.set(joint.childLink, joint.parentLink);
  }
  return result;
}

function resolveJointPose({ jointPose, childPose, parentLink, childLink, jointName }) {
  if (jointPose.hasPose) {
    if (jointPose.relativeTo === parentLink || (!jointPose.relativeTo && poseValuesAreIdentity(jointPose))) {
      return jointPose.transform;
    }
    throw new Error(`SDF joint ${jointName} uses unsupported pose frame ${JSON.stringify(jointPose.relativeTo || "__model__")}; use relative_to=${JSON.stringify(parentLink)}`);
  }
  if (!childPose?.hasPose || (!childPose.relativeTo && poseValuesAreIdentity(childPose))) {
    return [...IDENTITY_TRANSFORM];
  }
  if (childPose.relativeTo === parentLink) {
    return childPose.transform;
  }
  throw new Error(`SDF link ${childLink} uses unsupported pose frame ${JSON.stringify(childPose.relativeTo || "__model__")}; use relative_to=${JSON.stringify(parentLink)}`);
}

function parseJoint(jointElement, { linkNames, linkPoses }) {
  const name = String(jointElement.getAttribute("name") || "").trim();
  if (!name) {
    throw new Error("SDF joint name is required");
  }
  const type = String(jointElement.getAttribute("type") || "").trim().toLowerCase();
  if (!["fixed", "continuous", "revolute", "prismatic"].includes(type)) {
    throw new Error(`Unsupported SDF joint type: ${type || "(missing)"}`);
  }
  const parentLink = childText(jointElement, "parent");
  const childLink = childText(jointElement, "child");
  if (!parentLink || !childLink) {
    throw new Error(`SDF joint ${name} must declare parent and child links`);
  }
  if (!linkNames.has(parentLink) || !linkNames.has(childLink)) {
    throw new Error(`SDF joint ${name} references missing links`);
  }
  const axisElement = childElementsByTag(jointElement, "axis")[0] || null;
  const axis = type === "fixed"
    ? [1, 0, 0]
    : parseNumberList(childText(axisElement, "xyz"), 3, [1, 0, 0], `SDF joint ${name} axis`);
  const limits = parseJointLimit(axisElement, name, type);
  return {
    name,
    type,
    parentLink,
    childLink,
    originTransform: resolveJointPose({
      jointPose: parsePose(jointElement, `SDF joint ${name}`),
      childPose: linkPoses.get(childLink),
      parentLink,
      childLink,
      jointName: name
    }),
    axis,
    defaultValueDeg: 0,
    minValueDeg: limits.minValueDeg,
    maxValueDeg: limits.maxValueDeg,
    mimic: null
  };
}

function validateTree(links, joints) {
  const linkNames = new Set(links.map((link) => link.name));
  const children = new Set();
  const jointsByParent = new Map();
  const jointNames = new Set();
  for (const joint of joints) {
    if (jointNames.has(joint.name)) {
      throw new Error(`Duplicate SDF joint name: ${joint.name}`);
    }
    jointNames.add(joint.name);
    if (children.has(joint.childLink)) {
      throw new Error(`SDF link ${joint.childLink} has multiple parents`);
    }
    children.add(joint.childLink);
    const current = jointsByParent.get(joint.parentLink) || [];
    current.push(joint.childLink);
    jointsByParent.set(joint.parentLink, current);
  }
  const rootCandidates = [...linkNames].filter((linkName) => !children.has(linkName));
  if (rootCandidates.length !== 1) {
    throw new Error(`SDF must form a single rooted joint tree; found roots ${JSON.stringify(rootCandidates)}`);
  }
  const rootLink = rootCandidates[0];
  const visited = new Set();
  const visiting = new Set();
  const visit = (linkName) => {
    if (visited.has(linkName)) {
      return;
    }
    if (visiting.has(linkName)) {
      throw new Error("SDF joint graph contains a cycle");
    }
    visiting.add(linkName);
    for (const childLink of jointsByParent.get(linkName) || []) {
      visit(childLink);
    }
    visiting.delete(linkName);
    visited.add(linkName);
  };
  visit(rootLink);
  if (visited.size !== links.length) {
    const missing = links.map((link) => link.name).filter((linkName) => !visited.has(linkName));
    throw new Error(`SDF leaves links disconnected from the root: ${JSON.stringify(missing)}`);
  }
  return rootLink;
}

function validateLinkPoseFrames(links, joints, rootLink, modelName) {
  const parentByChild = parentByChildMap(joints);
  for (const link of links) {
    const pose = link.pose;
    if (!pose?.hasPose) {
      continue;
    }
    if (link.name === rootLink) {
      if (!isAllowedModelFrame(pose.relativeTo, modelName)) {
        throw new Error(`SDF root link ${link.name} uses unsupported pose frame ${JSON.stringify(pose.relativeTo)}`);
      }
      continue;
    }
    const parentLink = parentByChild.get(link.name) || "";
    if (pose.relativeTo === parentLink || (!pose.relativeTo && poseValuesAreIdentity(pose))) {
      continue;
    }
    throw new Error(`SDF link ${link.name} uses unsupported pose frame ${JSON.stringify(pose.relativeTo || "__model__")}; use relative_to=${JSON.stringify(parentLink)}`);
  }
}

function stripParserOnlyFields(links) {
  return links.map(({ pose, ...link }) => link);
}

function assertNoUnsupportedRenderInputs(root) {
  if (childElementsByTag(root, "world").length > 0) {
    throw new Error("SDF worlds are not supported by CAD Explorer rendering");
  }
  if (descendantElementsByTag(root, "include").length > 0) {
    throw new Error("SDF includes are not supported by CAD Explorer rendering");
  }
  if (descendantElementsByTag(root, "plugin").length > 0) {
    throw new Error("SDF plugins are not supported by CAD Explorer rendering");
  }
  if (descendantElementsByTag(root, "sensor").length > 0) {
    throw new Error("SDF sensors are not supported by CAD Explorer rendering");
  }
  if (descendantElementsByTag(root, "light").length > 0) {
    throw new Error("SDF lights are not supported by CAD Explorer rendering");
  }
}

export function parseSdf(xmlText, { sourceUrl } = {}) {
  if (typeof DOMParser === "undefined") {
    throw new Error("DOMParser is unavailable in this environment");
  }
  const document = new DOMParser().parseFromString(String(xmlText || ""), "application/xml");
  const parseError = document.querySelector("parsererror");
  if (parseError) {
    throw new Error("Failed to parse SDF XML");
  }
  const sdfRoot = document.documentElement;
  if (!sdfRoot || elementName(sdfRoot) !== "sdf") {
    throw new Error("SDF root element must be <sdf>");
  }
  const version = String(sdfRoot.getAttribute("version") || "").trim();
  if (!version) {
    throw new Error("SDF root element must declare a version");
  }
  assertNoUnsupportedRenderInputs(sdfRoot);

  const modelElements = childElementsByTag(sdfRoot, "model");
  if (modelElements.length !== 1) {
    throw new Error("SDF rendering requires exactly one direct <model>");
  }
  const model = modelElements[0];
  if (childElementsByTag(model, "model").length > 0) {
    throw new Error("SDF nested models are not supported by CAD Explorer rendering");
  }
  const robotName = String(model.getAttribute("name") || "").trim();
  if (!robotName) {
    throw new Error("SDF model name is required");
  }

  const links = childElementsByTag(model, "link").map((linkElement) => parseLink(linkElement, sourceUrl));
  if (!links.length) {
    throw new Error("SDF model must define at least one link");
  }
  const linkNames = new Set();
  const linkPoses = new Map();
  for (const link of links) {
    if (linkNames.has(link.name)) {
      throw new Error(`Duplicate SDF link name: ${link.name}`);
    }
    linkNames.add(link.name);
    linkPoses.set(link.name, link.pose);
  }

  const joints = childElementsByTag(model, "joint").map((jointElement) => parseJoint(jointElement, {
    linkNames,
    linkPoses
  }));
  const rootLink = validateTree(links, joints);
  validateLinkPoseFrames(links, joints, rootLink, robotName);
  const rootPose = linkPoses.get(rootLink);

  return {
    robotName,
    rootLink,
    rootWorldTransform: rootPose?.hasPose ? rootPose.transform : [...IDENTITY_TRANSFORM],
    links: stripParserOnlyFields(links),
    joints,
    motion: null,
    srdf: null
  };
}
