#!/bin/bash

# Step I - Compile modules in order of dependencies
# Although, we can use 'ocamlc -c file_name.ml', when we specify paths in our command we need to use 'ocamlc -c -I lib lib/file_name.ml'
ocamlc -c -I lib lib/templates_lib.ml
ocamlc -c -I lib lib/scaffolder_lib.ml

# Step II - Link modules to main in order of dependencies
ocamlc -I lib -o rgwscaffolds unix.cma lib/templates_lib.cmo lib/scaffolder_lib.cmo main.ml

# Print statement indicating compilation is complete
echo "Compilation complete."

# Helper message to inform the user about the flag
echo "Use the --and_generate_test_scaffold flag to generate the test scaffold."

# Step III - Remove all .cmo, .cmi, .out files from the pwd and all sub-directories
find . -type f \( -name "*.cmo" -o -name "*.cmi" -o -name "*.out" \) -exec rm -f {} +

# Step IV - Check for the --and_generate_test_scaffold flag and execute the scaffold command if present
if [[ " $@ " =~ " --and_generate_test_scaffold " ]]; then
  ./rgwscaffolds --scaffold test
  echo "Test scaffold has been generated."
fi

