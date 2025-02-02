import os
import subprocess
import shutil
import sys

def preprocess(src_directory, templates_file, scaffolder_file):
    templates_content = []
    scaffolder_content = []

    for root, _, files in os.walk(src_directory):
        for file in files:
            file_path = os.path.join(root, file)
            # Determine the context structure
            relative_path = os.path.relpath(file_path, src_directory)
            parts = relative_path.split(os.sep)
            if len(parts) == 1:  # file in root
                key = f"file_{file.replace('.', '_')}"
            else:
                # Dir and file parts
                dir_parts = "_".join(parts[:-1])
                file_parts = parts[-1].replace('.', '_')
                key = f"dir_{dir_parts}_file_{file_parts}"

            # Read file contents
            with open(file_path, 'r') as f:
                file_content = f.read()

            templates_content.append(f"let {key} = {{|\n{file_content}\n|}}\n\n")

    # Write to lib/templates_lib.ml
    with open(templates_file, 'w') as tf:
        tf.writelines(templates_content)

    # Write a minimal structure for lib/scaffolder_lib.ml (if needed)
    with open(scaffolder_file, 'w') as sf:
        scaffolder_content.append("""\

let ensure_dir path =
  if Sys.file_exists path then
    Printf.printf "Directory '%s' already exists, skipping creation.\\n" path
  else begin
    Unix.mkdir path 0o755;
    Printf.printf "Created directory: %s\\n" path
  end

(* Helper function to write content to a file (overwrite if exists) *)
let write_file filename content =
  let oc = open_out filename in
  output_string oc content;
  close_out oc;
  Printf.printf "Created or updated file: %s\\n" filename
""")
        sf.writelines(scaffolder_content)


def compile_modules(lib_directory):
    subprocess.run(["ocamlc", "-c", "-I", lib_directory, os.path.join(lib_directory, "templates_lib.ml")])
    subprocess.run(["ocamlc", "-c", "-I", lib_directory, os.path.join(lib_directory, "scaffolder_lib.ml")])

def link_modules(lib_directory, output_file, main_file):
    subprocess.run([
        "ocamlc", "-I", lib_directory, "-o", output_file,
        "unix.cma", os.path.join(lib_directory, "templates_lib.cmo"),
        os.path.join(lib_directory, "scaffolder_lib.cmo"),
        main_file
    ])

def cleanup():
    for root, _, files in os.walk("."):
        for file in files:
            if file.endswith((".cmo", ".cmi", ".out")):
                os.remove(os.path.join(root, file))

def generate_test_scaffold(script_path):
    test_dir = "test"
    if os.path.isdir(test_dir):
        shutil.rmtree(test_dir)
        print("Existing 'test' directory removed.")
    
    subprocess.run([script_path, "--scaffold", "test"])
    print("Test scaffold has been generated.")

def main():
    # Paths
    src_directory = "src"
    lib_directory = "lib"
    templates_file = os.path.join(lib_directory, "templates_lib.ml")
    scaffolder_file = os.path.join(lib_directory, "scaffolder_lib.ml")
    output_file = "rgwscaffolds"
    main_file = "main.ml"

    # Step 0: Preprocessing
    print("Preprocessing: Generating templates_lib.ml and scaffolder_lib.ml...")
    preprocess(src_directory, templates_file, scaffolder_file)

    # Step I: Compile modules
    print("Compiling modules...")
    compile_modules(lib_directory)

    # Step II: Link modules
    print("Linking modules...")
    link_modules(lib_directory, output_file, main_file)
    print("Compilation complete.")

    # Step III: Cleanup
    print("Cleaning up temporary files...")
    cleanup()

    # Step IV: Generate test scaffold if flag is present
    if "--and_generate_test_scaffold" in sys.argv:
        print("Generating test scaffold...")
        generate_test_scaffold(output_file)

if __name__ == "__main__":
    main()

