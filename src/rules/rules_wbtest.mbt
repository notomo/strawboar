///|
test "package_of" {
  inspect(package_of("src/lib/web/moon.pkg"), content="lib/web")
  inspect(package_of("src/core/chore.mbt"), content="core")
}

///|
test "imports keeps only the packages of this module" {
  let moon_pkg =
    #|import {
    #|  "internal/strawboar/core",
    #|  "moonbitlang/core/json",
    #|}
    #|
    #|import {
    #|  "internal/strawboar/lib/web",
    #|} for "test"
  assert_eq(imports(moon_pkg), ["core", "lib/web"])
}

///|
test "uses_ffi follows the imported packages" {
  let deps = {
    "core": ["lib/text"],
    "lib/text": ["lib/web"],
    "lib/web": [],
    "lib/pure": [],
  }
  let ffi_packages = Set::from_array(["lib/web"])
  assert_true(uses_ffi("lib/web", deps~, ffi_packages~))
  assert_true(uses_ffi("core", deps~, ffi_packages~))
  assert_false(uses_ffi("lib/pure", deps~, ffi_packages~))
}

///|
test "dependency_violations" {
  let ffi_packages = Set::from_array(["lib/web", "lib/cloudflare"])
  let violations = deps => {
    dependency_violations(deps, ffi_packages~).map(v => {
      v.split(":").next().unwrap().to_owned()
    })
  }
  assert_eq(
    violations({
      "core": ["lib/pure"],
      "app": ["core", "lib/web"],
      "server": ["core", "lib/web", "lib/cloudflare"],
      "lib/cloudflare": ["lib/web"],
      "lib/pure": [],
      "lib/web": [],
    }),
    [],
  )
  assert_eq(
    violations({
      "core": ["lib/web", "lib/text", "app"],
      "lib/text": ["lib/web"],
      "lib/web": [],
    }),
    ["core -> lib/web", "core -> lib/text", "core -> app"],
  )
  assert_eq(
    violations({ "app": ["server", "lib/cloudflare"], "lib/web": ["core"] }),
    ["app -> server", "app -> lib/cloudflare", "lib/web -> core"],
  )
}

///|
test "assert_none fails with the reason and the violations" {
  assert_none([], reason="unused")
  let message = try assert_none(["a", "b"], reason="Rule") catch {
    Failure(message) => message
    _ => "other error"
  } noraise {
    _ => "no error"
  }
  assert_true(message.has_suffix("Rule:\na\nb"), msg=message)
}
