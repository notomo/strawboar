// Reading the files of this repository for the rules.
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
/// Files under `dir` whose name ends with `suffix` and that contain `needle`.
pub fn files_containing(
  dir : String,
  suffix~ : String,
  needle : String,
) -> Array[String] raise @fs.IOError {
  walk(dir)
  .filter(path => path.has_suffix(suffix))
  .filter(path => @fs.read_file_to_string(path).contains(needle))
}

///|
/// Packages of this module and the packages of this module they import.
pub fn read_packages() -> Map[String, Array[String]] raise @fs.IOError {
  walk("src")
  .filter(path => path.has_suffix("/moon.pkg"))
  .map(path => (package_of(path), imports(@fs.read_file_to_string(path))))
  |> Map::from_array
}

///|
/// Packages that contain JS FFI themselves.
pub fn read_ffi_packages() -> Set[String] raise @fs.IOError {
  files_containing("src", suffix=".mbt", ffi).map(package_of) |> Set::from_array
}
