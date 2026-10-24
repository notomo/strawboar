// Rules of this repository that can be checked from its files.

///|
test "packages depend only on the packages they are allowed to" {
  @rules.assert_none(
    @rules.dependency_violations(
      @rules.read_packages(),
      ffi_packages=@rules.read_ffi_packages(),
    ),
    reason="Forbidden package dependencies",
  )
}

///|
test "raw JS FFI lives only in lib" {
  @rules.assert_none(
    @rules.files_containing("src", suffix=".mbt", @rules.ffi).filter(path => {
      !path.has_prefix("src/lib/")
    }),
    reason="Raw JS FFI goes to src/lib (web or cloudflare), so that the other packages stay pure",
  )
}

///|
test "app avoids the escape hatches of Rabbita" {
  let violations = ["@cmd.effect", "@dom."].map(needle => {
    @rules.files_containing("src/app", suffix=".mbt", needle)
  })
  @rules.assert_none(
    violations.fold(init=[], (all, more) => all + more),
    reason="Follow the conventions of Rabbita (create_state, create_resource, @http) instead of @cmd.effect or @dom",
  )
}

///|
test "e2e specs use the page object for locators" {
  let violations = [".locator(", ".getBy"].map(needle => {
    @rules.files_containing("e2e", suffix=".spec.ts", needle)
  })
  @rules.assert_none(
    violations.fold(init=[], (all, more) => all + more),
    reason="Keep locators and UI actions in the page object of e2e/page.ts",
  )
}
