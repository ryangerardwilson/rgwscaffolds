
let ensure_dir path =
  if Sys.file_exists path then
    Printf.printf "Directory '%s' already exists, skipping creation.\n" path
  else begin
    Unix.mkdir path 0o755;
    Printf.printf "Created directory: %s\n" path
  end

(* New function to ensure the full path directory exists, creating it if necessary *)
let ensure_full_path path =
  let rec create_dir_recursively path =
    if not (Sys.file_exists path) then begin
      create_dir_recursively (Filename.dirname path);
      Unix.mkdir path 0o755;
      Printf.printf "Created directory: %s\n" path
    end
  in
  create_dir_recursively path

(* Helper function to write content to a file (overwrite if exists) *)
let write_file filename content =
  let oc = open_out filename in
  output_string oc content;
  close_out oc;
  Printf.printf "Created or updated file: %s\n" filename

(* Now we actually scaffold the directory structure when --scaffold is present *)
let scaffold target_dir =
  (* Make sure the target directory exists *)
  ensure_full_path target_dir;

  let full_path sub_path = Filename.concat target_dir sub_path in

  ensure_dir (full_path "lib");
  ensure_dir (full_path "utils");
  ensure_dir (full_path "dist");

  write_file (full_path ".env") Templates_lib.file_env;
  write_file (full_path "main.ml") Templates_lib.file_main_ml;
  write_file (full_path "routes.ml") Templates_lib.file_routes_ml;

  write_file (full_path "lib/Home.ml") Templates_lib.file_home_ml;
  write_file (full_path "lib/About.ml") Templates_lib.file_about_ml;

  write_file (full_path "utils/Renderer.ml") Templates_lib.file_renderer_ml;

  write_file (full_path "dist/home.html") Templates_lib.file_home_html;
  write_file (full_path "dist/about.html") Templates_lib.file_about_html;

  print_endline "Scaffolding complete. You can now edit your files or compile."

