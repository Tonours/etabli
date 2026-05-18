#!/usr/bin/env nvim
--- Integration tests for ember cursor parsing
--- Run: nvim --headless --cmd "set rtp+=~/work/etabli/nvim" -l ~/work/etabli/nvim/tests/ember_cursor_spec.lua

local definition = require("config.ember.definition")
local t = require("tests.helpers")

--- Helper: set buffer content and cursor, then test get_component_at_cursor
local function test_at_cursor(lines, cursor_line, cursor_col)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_win_set_cursor(0, { cursor_line, cursor_col - 1 }) -- 0-indexed col
  return definition.get_component_at_cursor()
end

-- ============================================================
-- Tests
-- ============================================================

t.describe("parse angle bracket components", function()
  t.it("detects simple angle bracket component at start of tag name", function()
    local name, typ = test_at_cursor({ "<Shared::Svg />" }, 1, 2)
    t.assert_eq(name, "Shared::Svg")
    t.assert_eq(typ, "angle")
  end)

  t.it("detects angle bracket in middle of tag name", function()
    local name, typ = test_at_cursor({ "<Feature::WorkflowEditor::Header @foo=\"bar\" />" }, 1, 15)
    t.assert_eq(name, "Feature::WorkflowEditor::Header")
    t.assert_eq(typ, "angle")
  end)

  t.it("detects angle bracket at end of tag name", function()
    local name, typ = test_at_cursor({ "<Shared::Svg />" }, 1, 11)
    t.assert_eq(name, "Shared::Svg")
    t.assert_eq(typ, "angle")
  end)

  t.it("detects closing tag", function()
    local name, typ = test_at_cursor({ "</Feature::WorkflowEditor::Header>" }, 1, 5)
    t.assert_eq(name, "Feature::WorkflowEditor::Header")
    t.assert_eq(typ, "angle")
  end)

  t.it("ignores cursor in attributes area", function()
    local name, _ = test_at_cursor({ "<Feature::WorkflowEditor::Header @foo=\"bar\" />" }, 1, 35)
    t.assert_eq(name, nil, "should not match in attributes")
  end)

  t.it("ignores lowercase HTML elements like <div>", function()
    local name, _ = test_at_cursor({ "<div class=\"foo\">" }, 1, 2)
    t.assert_eq(name, nil, "should not match HTML elements")
  end)

  t.it("ignores HTML elements like <span>", function()
    local name, _ = test_at_cursor({ "<span>" }, 1, 2)
    t.assert_eq(name, nil)
  end)

  t.it("detects indented component", function()
    local name, typ = test_at_cursor({
      "<div>",
      "  <Feature::WorkflowEditor::Palette />",
      "</div>",
    }, 2, 10)
    t.assert_eq(name, "Feature::WorkflowEditor::Palette")
    t.assert_eq(typ, "angle")
  end)

  t.it("detects single-segment component", function()
    local name, typ = test_at_cursor({ "<Svg />" }, 1, 2)
    t.assert_eq(name, "Svg")
    t.assert_eq(typ, "angle")
  end)
end)

t.describe("parse mustache components", function()
  t.it("detects simple mustache component", function()
    local name, typ = test_at_cursor({ "{{my-component}}" }, 1, 3)
    t.assert_eq(name, "my-component")
    t.assert_eq(typ, "mustache")
  end)

  t.it("detects mustache with path separator", function()
    local name, typ = test_at_cursor({ "{{workflow-editor/header}}" }, 1, 5)
    t.assert_eq(name, "workflow-editor/header")
    t.assert_eq(typ, "mustache")
  end)

  t.it("detects block component opening", function()
    local name, typ = test_at_cursor({ "{{#my-component}}" }, 1, 4)
    t.assert_eq(name, "my-component")
    t.assert_eq(typ, "mustache")
  end)

  t.it("detects block component closing", function()
    local name, typ = test_at_cursor({ "{{/my-component}}" }, 1, 4)
    t.assert_eq(name, "my-component")
    t.assert_eq(typ, "mustache")
  end)

  t.it("detects mustache with arguments", function()
    local name, typ = test_at_cursor({ "{{my-component value=123}}" }, 1, 5)
    t.assert_eq(name, "my-component")
    t.assert_eq(typ, "mustache")
  end)

  t.it("ignores helpers without dash or slash", function()
    local name, _ = test_at_cursor({ "{{if condition a b}}" }, 1, 3)
    t.assert_eq(name, nil, "simple words should not match")
  end)

  t.it("ignores paths with dots (this.something)", function()
    local name, _ = test_at_cursor({ "{{this.something}}" }, 1, 3)
    t.assert_eq(name, nil, "dotted paths should not match")
  end)

  t.it("detects deeply nested mustache", function()
    local name, typ = test_at_cursor({
      "<div>",
      "  {{workflow-editor/renderer}}",
      "</div>",
    }, 2, 5)
    t.assert_eq(name, "workflow-editor/renderer")
    t.assert_eq(typ, "mustache")
  end)
end)

t.describe("multi-tag on same line", function()
  t.it("detects second angle bracket component after a closed one", function()
    local name, typ = test_at_cursor({ "<Foo /><Bar />" }, 1, 9)
    t.assert_eq(name, "Bar", "should detect Bar, not Foo")
    t.assert_eq(typ, "angle")
  end)

  t.it("detects first angle bracket component when two are on same line", function()
    local name, typ = test_at_cursor({ "<Foo /><Bar />" }, 1, 2)
    t.assert_eq(name, "Foo")
    t.assert_eq(typ, "angle")
  end)

  t.it("detects second mustache component after a closed one", function()
    local name, typ = test_at_cursor({ "{{foo-bar}}{{baz-qux}}" }, 1, 13)
    t.assert_eq(name, "baz-qux", "should detect baz-qux, not foo-bar")
    t.assert_eq(typ, "mustache")
  end)

  t.it("detects first mustache component when two are on same line", function()
    local name, typ = test_at_cursor({ "{{foo-bar}}{{baz-qux}}" }, 1, 3)
    t.assert_eq(name, "foo-bar")
    t.assert_eq(typ, "mustache")
  end)

  t.it("detects angle bracket among multiple closed tags", function()
    local name, typ = test_at_cursor({
      "<Layout::Header /><Layout::Body /><Layout::Footer />",
    }, 1, 22)
    t.assert_eq(name, "Layout::Body")
    t.assert_eq(typ, "angle")
  end)

  t.it("detects mustache between angle brackets", function()
    -- <div>{{my-component}}</div> — cursor on mustache
    local name, typ = test_at_cursor({ "<div>{{my-component}}</div>" }, 1, 8)
    t.assert_eq(name, "my-component")
    t.assert_eq(typ, "mustache")
  end)
end)

t.describe("edge cases", function()
  t.it("returns nil for empty line", function()
    local name, _ = test_at_cursor({ "" }, 1, 1)
    t.assert_eq(name, nil)
  end)

  t.it("returns nil for plain text", function()
    local name, _ = test_at_cursor({ "Hello World" }, 1, 5)
    t.assert_eq(name, nil)
  end)

  t.it("returns nil for HTML comment", function()
    local name, _ = test_at_cursor({ "<!-- some comment -->" }, 1, 5)
    t.assert_eq(name, nil)
  end)

  t.it("handles line with both angle and mustache (angle wins at cursor)", function()
    local name, typ = test_at_cursor({ "<Shared::Svg>{{some-helper}}</Shared::Svg>" }, 1, 3)
    t.assert_eq(name, "Shared::Svg")
    t.assert_eq(typ, "angle")
  end)

  t.it("handles mustache when not in angle bracket", function()
    local name, typ = test_at_cursor({ "<div>{{some-helper}}</div>" }, 1, 8)
    t.assert_eq(name, "some-helper")
    t.assert_eq(typ, "mustache")
  end)
end)

-- ============================================================
t.summary()
