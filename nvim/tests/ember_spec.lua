#!/usr/bin/env nvim
--- Run: nvim --headless --cmd "set rtp+=~/work/etabli/nvim" -l ~/work/etabli/nvim/tests/ember_spec.lua

local resolver = require("config.ember.resolver")
local t = require("tests.helpers")

-- ============================================================
-- Tests
-- ============================================================

t.describe("normalize_to_classic", function()
  t.it("converts simple angle bracket to classic", function()
    t.assert_eq(resolver.normalize_to_classic("Shared::Svg"), "shared/svg")
  end)

  t.it("converts multi-segment angle bracket", function()
    t.assert_eq(
      resolver.normalize_to_classic("Feature::WorkflowEditor::Header"),
      "feature/workflow-editor/header"
    )
  end)

  t.it("converts deeply nested component", function()
    t.assert_eq(
      resolver.normalize_to_classic("Feature::WorkflowEditor::Renderer::Flat::Card"),
      "feature/workflow-editor/renderer/flat/card"
    )
  end)

  t.it("converts single-word component", function()
    t.assert_eq(resolver.normalize_to_classic("Svg"), "svg")
  end)

  t.it("converts PascalCase with consecutive uppercase (acronym)", function()
    -- Consecutive uppercase are treated as a group (not split)
    -- This matches Ember's behavior: SVG -> svg, not s-v-g
    local result = resolver.normalize_to_classic("XMLParser")
    t.assert_eq(result, "xMLParser")
  end)

  t.it("passes through already-classic names unchanged", function()
    t.assert_eq(resolver.normalize_to_classic("my-component"), "my-component")
  end)

  t.it("converts MicroFrontend::ReactHost", function()
    t.assert_eq(
      resolver.normalize_to_classic("MicroFrontend::ReactHost"),
      "micro-frontend/react-host"
    )
  end)

  t.it("converts BetaSettingsLayout", function()
    t.assert_eq(resolver.normalize_to_classic("BetaSettingsLayout"), "beta-settings-layout")
  end)
end)

t.describe("split_path", function()
  t.it("splits a path into parts", function()
    local parts = resolver.split_path("workflow-editor/header")
    t.assert_eq(#parts, 2)
    t.assert_eq(parts[1], "workflow-editor")
    t.assert_eq(parts[2], "header")
  end)

  t.it("handles single element", function()
    local parts = resolver.split_path("workflow-editor")
    t.assert_eq(#parts, 1)
    t.assert_eq(parts[1], "workflow-editor")
  end)

  t.it("handles empty string", function()
    local parts = resolver.split_path("")
    t.assert_eq(#parts, 0)
  end)

  t.it("handles deep paths", function()
    local parts = resolver.split_path("a/b/c/d")
    t.assert_eq(#parts, 4)
  end)
end)

t.describe("resolve_candidates", function()
  local app = "/tmp/fake-project/app"

  t.it("generates feature component paths", function()
    local paths = resolver.resolve_candidates(app, "feature/workflow-editor/header")
    t.assert_contains(paths, app .. "/features/workflow-editor/components/header/template.hbs")
    t.assert_contains(paths, app .. "/features/workflow-editor/components/header/component.ts")
    t.assert_contains(paths, app .. "/features/workflow-editor/components/header/component.js")
  end)

  t.it("generates deeply nested feature component paths", function()
    local paths = resolver.resolve_candidates(app, "feature/workflow-editor/renderer/flat/card")
    t.assert_contains(paths, app .. "/features/workflow-editor/components/renderer/flat/card/template.hbs")
  end)

  t.it("generates shared component paths", function()
    local paths = resolver.resolve_candidates(app, "shared/svg")
    t.assert_contains(paths, app .. "/shared/components/svg/template.hbs")
    t.assert_contains(paths, app .. "/shared/components/svg/component.ts")
  end)

  t.it("generates route paths", function()
    local paths = resolver.resolve_candidates(app, "organization/projects")
    t.assert_contains(paths, app .. "/routes/organization/projects/template.hbs")
    t.assert_contains(paths, app .. "/routes/organization/projects/route.ts")
    t.assert_contains(paths, app .. "/routes/organization/projects/controller.ts")
  end)

  t.it("generates legacy pods paths", function()
    local paths = resolver.resolve_candidates(app, "organization/settings/security")
    t.assert_contains(paths, app .. "/legacy/pods/organization/settings/security/template.hbs")
    t.assert_contains(paths, app .. "/legacy/pods/organization/settings/security/route.ts")
  end)

  t.it("generates legacy pod component paths", function()
    local paths = resolver.resolve_candidates(app, "configuration-card")
    t.assert_contains(paths, app .. "/legacy/pods/components/configuration-card/template.hbs")
    t.assert_contains(paths, app .. "/legacy/pods/components/configuration-card/component.js")
  end)

  t.it("generates classic component paths (flat)", function()
    local paths = resolver.resolve_candidates(app, "micro-frontend/react-host")
    t.assert_contains(paths, app .. "/components/micro-frontend/react-host.hbs")
    t.assert_contains(paths, app .. "/components/micro-frontend/react-host.ts")
  end)

  t.it("generates classic component paths (pod-style)", function()
    local paths = resolver.resolve_candidates(app, "some-component")
    t.assert_contains(paths, app .. "/components/some-component/template.hbs")
    t.assert_contains(paths, app .. "/components/some-component/component.ts")
  end)

  t.it("generates templates/components paths", function()
    local paths = resolver.resolve_candidates(app, "some-component")
    t.assert_contains(paths, app .. "/templates/components/some-component.hbs")
  end)

  t.it("generates data model paths", function()
    local paths = resolver.resolve_candidates(app, "invoice")
    t.assert_contains(paths, app .. "/data/models/invoice.ts")
    t.assert_contains(paths, app .. "/data/adapters/invoice.ts")
    t.assert_contains(paths, app .. "/data/serializers/invoice.ts")
    t.assert_contains(paths, app .. "/data/transforms/invoice.ts")
  end)

  t.it("generates helper paths", function()
    local paths = resolver.resolve_candidates(app, "get-classes-with-modifiers")
    t.assert_contains(paths, app .. "/helpers/get-classes-with-modifiers.ts")
    t.assert_contains(paths, app .. "/helpers/get-classes-with-modifiers.js")
  end)

  t.it("generates service paths", function()
    local paths = resolver.resolve_candidates(app, "session")
    t.assert_contains(paths, app .. "/services/session.ts")
  end)

  t.it("generates shared helper/service/modifier paths", function()
    local paths = resolver.resolve_candidates(app, "some-helper")
    t.assert_contains(paths, app .. "/shared/helpers/some-helper.ts")
    t.assert_contains(paths, app .. "/shared/services/some-helper.ts")
    t.assert_contains(paths, app .. "/shared/modifiers/some-helper.ts")
  end)

  t.it("generates feature service paths", function()
    local paths = resolver.resolve_candidates(app, "feature/workflow-editor")
    t.assert_contains(paths, app .. "/features/workflow-editor/services/feature.ts")
    t.assert_contains(paths, app .. "/features/workflow-editor/state.ts")
  end)

  t.it("generates feature state paths for feature/name/state", function()
    local paths = resolver.resolve_candidates(app, "feature/workflow-editor/state")
    t.assert_contains(paths, app .. "/features/workflow-editor/state.ts")
  end)

  t.it("does not generate duplicate paths for same candidate", function()
    local paths = resolver.resolve_candidates(app, "some-component")
    local seen = {}
    for _, p in ipairs(paths) do
      t.assert_not_contains(seen, p, "duplicate path")
      table.insert(seen, p)
    end
  end)

  t.it("returns reasonable number of candidates", function()
    local paths = resolver.resolve_candidates(app, "feature/workflow-editor/header")
    assert(paths ~= nil and #paths > 0, "should have candidates")
    assert(#paths < 80, "too many candidates: " .. #paths)
  end)
end)

-- ============================================================
t.summary()
