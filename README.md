
# 1. Compile Script

    ./compile.sh

# 2. Manual Compilation

    # Step I - Compile modules in order of dependencies 
    # Although, we can use 'ocamlc -c file_name.ml', when we specify paths in our command we need to use 'ocamlc -c -I lib lib/file_name.ml'
    ocamlc -c -I lib lib/templates_lib.ml; ocamlc -c -I lib lib/scaffolder_lib.ml; ocamlc -c -I lib lib/compiler_lib.ml; 

    # Step II - Link modules to main in order of dependencies
    ocamlc -I lib -o rgwscaffolds unix.cma lib/templates_lib.cmo lib/scaffolder_lib.cmo lib/compiler_lib.cmo main.ml

    # Step III - remove all .cmo, .cmi, .out files from the pwd and all sub-directories
    find . -type f \( -name "*.cmo" -o -name "*.cmi" -o -name "*.out" \) -exec rm -f {} +

    # Step IV - Execute the executable, scaffolding in the x directory
    ./rgwscaffolds --scaffold test

    # Step V - cd into the test directory, and run the app
    cd test; ./app

    Combined Command:
    ocamlc -c -I lib lib/templates_lib.ml; ocamlc -c -I lib lib/scaffolder_lib.ml; ocamlc -c -I lib lib/compiler_lib.ml; ocamlc -I lib -o rgwscaffolds unix.cma lib/templates_lib.cmo lib/scaffolder_lib.cmo lib/compiler_lib.cmo main.ml; find . -type f \( -name "*.cmo" -o -name "*.cmi" -o -name "*.out" \) -exec rm -f {} +; ./rgwscaffolds --scaffold test; cd test; ./app 

# 3. Manual Compilation of the Scaffolded App

    # Step I - Compile modules in order of dependencies
    # Although, we can use 'ocamlc -c file_name.ml', when we specify paths in our command we need to use 'ocamlc -c -I lib lib/file_name.ml'


    When compiling individual `.ml` files that use Cohttp, you should tell the compiler where to find Cohttp using the `-package` and `-I` options (for findlib-installed libraries). However, for Cohttp, it's more common to use the `ocamlfind` tool like this - where we also invoke threads because certain parts of the Cohttp Lwt Unix library rely on threads.
   

    ocamlfind ocamlc -thread -c -package cohttp-lwt-unix test/utils/Renderer.ml
    ocamlfind ocamlc -thread -c -package cohttp-lwt-unix test/lib/About.ml
    ocamlfind ocamlc -thread -c -package cohttp-lwt-unix test/lib/Home.ml


   ```bash
   ocamlfind ocamlc -thread -c -package cohttp-lwt-unix test/utils/Renderer.ml
   ```

2. **Check Module Visibility**: Ensure that the directory containing `Renderer` is visible to the OCaml compiler when compiling `About.ml` and `Home.ml`. Since `Renderer` is in a different directory (`test/utils`), you need to inform these files about the exact location:


    # STEP I - Ensure that the directory containing `Renderer` is visible to the OCaml compiler when compiling `About.ml` and `Home.ml`. Since `Renderer` is in a different directory (`test/utils`), you need to inform these files about the exact location:
    ocamlfind ocamlc -c -thread -package cohttp-lwt-unix test/utils/Renderer.ml
    ocamlfind ocamlc -c -thread -package cohttp-lwt-unix -I test/utils test/lib/About.ml
    ocamlfind ocamlc -c -thread -package cohttp-lwt-unix -I test/utils test/lib/Home.ml

    # STEP II - Link modules to main, in order of dependencies
    ocamlfind ocamlc -thread -package cohttp-lwt-unix,dotenv,str -linkpkg -o test/app test/utils/Renderer.cmo test/lib/About.cmo test/lib/Home.cmo test/main.ml

    # Step III - remove all .cmo, .cmi, .out files from the pwd and all sub-directories
    find . -type f \( -name "*.cmo" -o -name "*.cmi" -o -name "*.out" \) -exec rm -f {} +

    # Step IV - cd into the test directory, and run the app
    cd test
    ./app


    Combined command: ocamlfind ocamlc -c -thread -package cohttp-lwt-unix test/utils/Renderer.ml; ocamlfind ocamlc -c -thread -package cohttp-lwt-unix -I test/utils test/lib/About.ml; ocamlfind ocamlc -c -thread -package cohttp-lwt-unix -I test/utils test/lib/Home.ml; ocamlfind ocamlc -c -thread -package cohttp-lwt-unix -I test/lib test/routes.ml






#!/bin/bash

# STEP I - Ensure that the directory containing `Renderer` is visible to the OCaml compiler when compiling `About.ml` and `Home.ml`. Since `Renderer` is in a different directory (`test/utils`), you need to inform these files about the exact location:
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix utils/Renderer.ml
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix -I utils lib/About.ml
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix -I utils lib/Home.ml

# STEP II - Link modules to main, in order of dependencies
ocamlfind ocamlc -thread -package cohttp-lwt-unix,dotenv,str -linkpkg -o app utils/Renderer.cmo lib/About.cmo lib/Home.cmo main.ml

# Step III - remove all .cmo, .cmi, .out files from the pwd and all sub-directories
find . -type f \( -name "*.cmo" -o -name "*.cmi" -o -name "*.out" \) -exec rm -f {} +

# Step IV - run the app if --and_run flag is provided
if [[ "$1" == "--and_run" ]]; then
  ./app
fi

