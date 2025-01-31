#!/bin/bash

# Load OPAM environment variables
eval $(opam env)

# Function to clean up .cmo, .cmi, .out files but not the executable
clean_up() {
  find . -type f \( -name '*.cmo' -o -name '*.cmi' -o -name '*.out' \) -delete
}

# List of libraries to be linked
packages=("cohttp-lwt-unix" "threads" "dotenv")

# Create a package flags string for ocamlfind
package_flags=""
for pkg in "${packages[@]}"; do
  package_flags+="-package $pkg "
done

# Clean up any existing compiled files
clean_up

# Array of source files in dependency order
files_to_compile=("lib/templates_lib.ml" "lib/scaffolder_lib.ml" "lib/compiler_lib.ml" "main.ml")

# Compile each file in the specified order and check if file exists
for file in "${files_to_compile[@]}"; do
  echo "Compiling $file..."
  if [ -f "$file" ]; then
    ocamlfind ocamlc -thread $package_flags -c -I lib "$file" || { echo "Compilation failed for $file"; exit 1; }
  else
    echo "File $file not found!"; exit 1;
  fi
done

# Correct order for linking, listing all .cmo files explicitly
# Ensures 'main.cmo' is linked last after its dependencies
cmo_files="lib/templates_lib.cmo lib/scaffolder_lib.cmo lib/compiler_lib.cmo main.cmo"

# Debugging line to show which .cmo files are being linked
echo "Linking the following .cmo files: $cmo_files"

# Compile the main executable, ensure all .cmo for modules are linked
echo "Compiling main executable..."
ocamlfind ocamlc -thread $package_flags -linkpkg -o rgwscaffolds $cmo_files || { echo "Compilation failed for rgwscaffolds"; exit 1; }

# Clean up everything but the main executable
clean_up

echo "Compilation completed successfully."

