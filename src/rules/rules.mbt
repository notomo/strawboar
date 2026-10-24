// Logic of the rules in repository_test.mbt, kept apart from reading the files.

///|
let module_prefix = "internal/strawboar/"

///|
pub let ffi = "extern \"js\""

///|
/// The package (relative to `src/`) that a file under `src/` belongs to.
fn package_of(path : String) -> String {
  let dir = path.rev_find("/").map(i => path[:i].to_owned()).unwrap_or("")
  dir.strip_prefix("src/").map(pkg => pkg.to_owned()).unwrap_or(dir)
}

///|
/// Packages of this module (relative to `src/`) imported in a `moon.pkg`.
fn imports(moon_pkg : String) -> Array[String] {
  // Imported packages are string literals, so split by `"`.
  moon_pkg
  .split("\"")
  .to_array()
  .filter_map(s => s.strip_prefix(module_prefix).map(pkg => pkg.to_owned()))
}

///|
/// Whether `pkg` uses JS FFI, directly or through the packages it imports.
fn uses_ffi(
  pkg : String,
  deps~ : Map[String, Array[String]],
  ffi_packages~ : Set[String],
) -> Bool {
  ffi_packages.contains(pkg) ||
  deps
  .get(pkg)
  .unwrap_or([])
  .iter()
  .any(dep => uses_ffi(dep, deps~, ffi_packages~))
}

///|
/// The reason why `pkg` must not depend on `dep`.
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
/// Dependencies that break `dependency_rule`, as `pkg -> dep: reason`.
/// `deps` maps each package to the packages it imports, and `ffi_packages`
/// are the packages that contain JS FFI themselves.
pub fn dependency_violations(
  deps : Map[String, Array[String]],
  ffi_packages~ : Set[String],
) -> Array[String] {
  deps
  .to_array()
  .map(entry => {
    let (pkg, imported) = entry
    imported.filter_map(dep => {
      let dep_uses_ffi = uses_ffi(dep, deps~, ffi_packages~)
      dependency_rule(pkg, dep, dep_uses_ffi~).map(reason => {
        "\{pkg} -> \{dep}: \{reason}"
      })
    })
  })
  .fold(init=[], (all, more) => all + more)
}

///|
/// Whether `text` has Japanese characters: CJK symbols, kana, kanji or full-width forms.
pub fn has_japanese(text : String) -> Bool {
  text
  .iter()
  .any(c => {
    match c {
      '\u{3000}'..<='\u{30FF}'
      | '\u{3400}'..<='\u{9FFF}'
      | '\u{FF00}'..<='\u{FFEF}' => true
      _ => false
    }
  })
}

///|
/// Fails with every violation and the reason of the rule.
pub fn assert_none(violations : Array[String], reason~ : String) -> Unit raise {
  match violations {
    [] => ()
    _ => fail("\{reason}:\n" + violations.join("\n"))
  }
}
