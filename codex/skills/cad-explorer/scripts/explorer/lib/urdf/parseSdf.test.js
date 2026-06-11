import assert from "node:assert/strict";
import test from "node:test";

import { parseSdf } from "./parseSdf.js";

class FakeElement {
  constructor(tagName, attributes = {}, children = [], text = "") {
    this.nodeType = 1;
    this.tagName = tagName;
    this.localName = String(tagName || "").split(":").pop();
    this.namespaceURI = null;
    this._attributes = { ...attributes };
    this.childNodes = children;
    this._text = String(text || "");
  }

  getAttribute(name) {
    return Object.hasOwn(this._attributes, name) ? this._attributes[name] : null;
  }

  get textContent() {
    return `${this._text}${this.childNodes.map((child) => String(child?.textContent || "")).join("")}`;
  }
}

class FakeDocument {
  constructor(documentElement) {
    this.documentElement = documentElement;
  }

  querySelector(selector) {
    return selector === "parsererror" ? null : null;
  }
}

function el(tagName, attributes = {}, children = [], text = "") {
  return new FakeElement(tagName, attributes, children, text);
}

function textEl(tagName, text, attributes = {}) {
  return el(tagName, attributes, [], text);
}

function withFakeDomParser(document, callback) {
  const previous = globalThis.DOMParser;
  globalThis.DOMParser = class FakeDomParser {
    parseFromString() {
      return document;
    }
  };
  try {
    return callback();
  } finally {
    globalThis.DOMParser = previous;
  }
}

function meshVisual(linkName, uri, color = "0.168627 0.184314 0.2 1") {
  return el("visual", { name: `${linkName}_visual` }, [
    textEl("pose", "0 0 0 0 0 0", { relative_to: linkName }),
    el("geometry", {}, [
      el("mesh", {}, [
        textEl("uri", uri),
        textEl("scale", "0.001 0.001 0.001")
      ])
    ]),
    el("material", {}, [
      textEl("diffuse", color)
    ])
  ]);
}

function meshCollision(linkName, uri) {
  return el("collision", { name: `${linkName}_collision` }, [
    el("geometry", {}, [
      el("mesh", {}, [
        textEl("uri", uri)
      ])
    ])
  ]);
}

function link(name, { parent = "", pose = "0 0 0 0 0 0" } = {}) {
  const children = [
    textEl("pose", pose, parent ? { relative_to: parent } : {}),
    meshVisual(name, `meshes/${name}.stl`),
    meshCollision(name, `meshes/${name}_collision.stl`)
  ];
  return el("link", { name }, children);
}

function joint(index, parent, child, type = "revolute") {
  const axisChildren = [
    textEl("xyz", "0 0 1")
  ];
  if (type !== "continuous") {
    axisChildren.push(el("limit", {}, [
      textEl("lower", "-1.57079632679"),
      textEl("upper", "1.57079632679")
    ]));
  }
  return el("joint", { name: `joint_${index}`, type }, [
    textEl("parent", parent),
    textEl("child", child),
    textEl("pose", `${index * 0.01} 0 0 0 0 0`, { relative_to: parent }),
    el("axis", {}, axisChildren)
  ]);
}

function sdfRoot(children, attributes = { version: "1.12" }) {
  return el("sdf", attributes, children);
}

function parseWithRoot(root, sourceUrl = "/workspace/robots/so101.sdf") {
  return withFakeDomParser(new FakeDocument(root), () => parseSdf("<sdf />", { sourceUrl }));
}

test("parseSdf reads SO101-style model-level SDF robot data", () => {
  const links = [
    link("base_link"),
    ...Array.from({ length: 7 }, (_, index) => link(`link_${index + 1}`, {
      parent: index === 0 ? "base_link" : `link_${index}`
    }))
  ];
  const joints = Array.from({ length: 7 }, (_, index) => joint(
    index + 1,
    index === 0 ? "base_link" : `link_${index}`,
    `link_${index + 1}`,
    index === 6 ? "continuous" : "revolute"
  ));
  const root = sdfRoot([
    el("model", { name: "so101_new_calib" }, [...links, ...joints])
  ]);

  const sdfData = parseWithRoot(root);

  assert.equal(sdfData.robotName, "so101_new_calib");
  assert.equal(sdfData.rootLink, "base_link");
  assert.equal(sdfData.links.length, 8);
  assert.equal(sdfData.joints.length, 7);
  assert.equal(sdfData.links[0].visuals[0].meshUrl, "/workspace/robots/meshes/base_link.stl");
  assert.equal(sdfData.links[0].visuals[0].color, "#2b2f33");
  assert.equal(sdfData.links[0].collisions[0].meshUrl, "/workspace/robots/meshes/base_link_collision.stl");
  assert.deepEqual(sdfData.joints[0].axis, [0, 0, 1]);
  assert.equal(Math.round(sdfData.joints[0].minValueDeg), -90);
  assert.equal(Math.round(sdfData.joints[0].maxValueDeg), 90);
  assert.equal(sdfData.joints[6].type, "continuous");
  assert.equal(sdfData.motion, null);
  assert.equal(sdfData.srdf, null);
});

test("parseSdf rejects missing roots, missing models, multiple models, and worlds", () => {
  assert.throws(
    () => parseWithRoot(el("robot", { name: "not_sdf" })),
    /root element must be <sdf>/
  );
  assert.throws(
    () => parseWithRoot(sdfRoot([])),
    /exactly one direct <model>/
  );
  assert.throws(
    () => parseWithRoot(sdfRoot([el("model", { name: "a" }), el("model", { name: "b" })])),
    /exactly one direct <model>/
  );
  assert.throws(
    () => parseWithRoot(sdfRoot([el("world", { name: "default" })])),
    /worlds are not supported/
  );
});

test("parseSdf rejects duplicate links and duplicate joints", () => {
  assert.throws(
    () => parseWithRoot(sdfRoot([
      el("model", { name: "robot" }, [
        link("base_link"),
        link("base_link")
      ])
    ])),
    /Duplicate SDF link name/
  );
  assert.throws(
    () => parseWithRoot(sdfRoot([
      el("model", { name: "robot" }, [
        link("base_link"),
        link("tool_link", { parent: "base_link" }),
        el("joint", { name: "duplicate_joint", type: "fixed" }, [
          textEl("parent", "base_link"),
          textEl("child", "tool_link")
        ]),
        el("joint", { name: "duplicate_joint", type: "fixed" }, [
          textEl("parent", "base_link"),
          textEl("child", "tool_link")
        ])
      ])
    ])),
    /Duplicate SDF joint name/
  );
});

test("parseSdf rejects unsupported render inputs and joint types", () => {
  assert.throws(
    () => parseWithRoot(sdfRoot([
      el("model", { name: "robot" }, [
        el("include", {}, [textEl("uri", "model://other_robot")])
      ])
    ])),
    /includes are not supported/
  );
  assert.throws(
    () => parseWithRoot(sdfRoot([
      el("model", { name: "robot" }, [
        link("base_link"),
        link("tool_link", { parent: "base_link" }),
        el("joint", { name: "ball_joint", type: "ball" }, [
          textEl("parent", "base_link"),
          textEl("child", "tool_link")
        ])
      ])
    ])),
    /Unsupported SDF joint type/
  );
});

test("parseSdf rejects missing mesh URIs and unsupported pose frames", () => {
  assert.throws(
    () => parseWithRoot(sdfRoot([
      el("model", { name: "robot" }, [
        el("link", { name: "base_link" }, [
          el("visual", {}, [
            el("geometry", {}, [el("mesh")])
          ])
        ])
      ])
    ])),
    /missing a mesh URI/
  );
  assert.throws(
    () => parseWithRoot(sdfRoot([
      el("model", { name: "robot" }, [
        link("base_link"),
        el("link", { name: "tool_link" }, [
          textEl("pose", "1 0 0 0 0 0", { relative_to: "unrelated_frame" }),
          meshVisual("tool_link", "meshes/tool_link.stl")
        ]),
        el("joint", { name: "base_to_tool", type: "fixed" }, [
          textEl("parent", "base_link"),
          textEl("child", "tool_link")
        ])
      ])
    ])),
    /unsupported pose frame/
  );
});
