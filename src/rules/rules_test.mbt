// Rules of this repository that can be checked from its files.
// `moon test` runs at the module root, so paths are relative to it.

///|
fn walk(dir : String) -> Array[String] raise @fs.IOError {
  @fs.read_dir(dir)
  .map(name => {
    let path = "\{dir}/\{name}"
    match @fs.is_dir(path) {
      true => walk(path)
      false => [path]
    }
  })
  .fold(init=[], (paths, more) => paths + more)
}

///|
/// Fails with every violation and the reason of the rule.
fn assert_none(violations : Array[String], reason~ : String) -> Unit raise {
  match violations {
    [] => ()
    _ => fail("\{reason}:\n" + violations.join("\n"))
  }
}

///|
/// Files under `dir` whose name ends with `suffix` and that contain `needle`.
fn files_containing(
  dir : String,
  suffix~ : String,
  needle : String,
) -> Array[String] raise @fs.IOError {
  walk(dir)
  .filter(path => path.has_suffix(suffix))
  .filter(path => @fs.read_file_to_string(path).contains(needle))
}

///|
let module_prefix = "internal/strawboar/"

///|
let ffi = "extern \"js\""

///|
/// Packages of this module (relative to `src/`) and the packages of this module they import.
fn packages() -> Map[String, Array[String]] raise @fs.IOError {
  walk("src")
  .filter(path => path.has_suffix("/moon.pkg"))
  .map(path => {
    let pkg = path
      .strip_prefix("src/")
      .unwrap()
      .strip_suffix("/moon.pkg")
      .unwrap()
      .to_owned()
    // Imported packages are string literals, so split by `"`.
    let deps = @fs.read_file_to_string(path)
      .split("\"")
      .to_array()
      .filter_map(s => s.strip_prefix(module_prefix).map(dep => dep.to_owned()))
    (pkg, deps)
  })
  |> Map::from_array
}

///|
/// Whether `pkg` uses JS FFI, directly or through the packages it imports.
fn uses_ffi(
  pkg : String,
  packages : Map[String, Array[String]],
) -> Bool raise @fs.IOError {
  let dir = "src/\{pkg}"
  @fs.read_dir(dir)
  .filter(name => name.has_suffix(".mbt"))
  .map(name => @fs.read_file_to_string("\{dir}/\{name}").contains(ffi))
  .contains(true) ||
  packages
  .get(pkg)
  .unwrap_or([])
  .map(dep => uses_ffi(dep, packages))
  .contains(true)
}

///|
/// The reason why `pkg` must not depend on `dep` (both relative to `src/`).
fn dependency_rule(pkg : String, dep : String, dep_uses_ffi~ : Bool) -> String? {
  match pkg {
    "core" if dep == "app" || dep == "server" || dep_uses_ffi =>
      Some(
        "core is pure (no JS FFI, also through its dependencies) and shared by app and server",
      )
    "app" if dep == "server" || dep == "lib/cloudflare" =>
      Some("app runs in the browser, not on the Worker")
    _ if pkg.has_prefix("lib/") && !dep.has_prefix("lib/") =>
      Some("lib holds generic packages with no knowledge of this app")
    _ => None
  }
}

///|
test "packages depend only on the packages they are allowed to" {
  let packages = packages()
  let violations = packages
    .to_array()
    .map(entry => {
      let (pkg, deps) = entry
      deps
      .map(dep => {
        dependency_rule(pkg, dep, dep_uses_ffi=uses_ffi(dep, packages)).map(reason => {
          "\{pkg} -> \{dep}: \{reason}"
        })
      })
      .filter_map(violation => violation)
    })
    .fold(init=[], (all, more) => all + more)
  assert_none(violations, reason="Forbidden package dependencies")
}

///|
test "raw JS FFI lives only in lib" {
  let violations = files_containing("src", suffix=".mbt", ffi).filter(path => {
    !path.has_prefix("src/lib/")
  })
  assert_none(
    violations,
    reason="Raw JS FFI goes to src/lib (web or cloudflare), so that the other packages stay pure",
  )
}

///|
test "app avoids the escape hatches of Rabbita" {
  let violations = ["@cmd.effect", "@dom."].map(needle => {
    files_containing("src/app", suffix=".mbt", needle)
  })
  assert_none(
    violations.fold(init=[], (all, more) => all + more),
    reason="Follow the conventions of Rabbita (create_state, create_resource, @http) instead of @cmd.effect or @dom",
  )
}

///|
test "e2e specs use the page object for locators" {
  let violations = [".locator(", ".getBy"].map(needle => {
    files_containing("e2e", suffix=".spec.ts", needle)
  })
  assert_none(
    violations.fold(init=[], (all, more) => all + more),
    reason="Keep locators and UI actions in the page object of e2e/page.ts",
  )
}
