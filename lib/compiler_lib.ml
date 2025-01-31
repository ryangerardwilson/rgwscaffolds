let run_command command =
  Sys.command command = 0

let all_files_in_dir dir =
  let cmd = Printf.sprintf "find %s -type f -name '*.ml'" dir in
  let chan = Unix.open_process_in cmd in
  let rec read_lines acc =
    match input_line chan with
    | line -> read_lines (line :: acc)
    | exception End_of_file -> close_in chan; List.rev acc
  in
  read_lines []

let compile target_dir =
  let output = Filename.concat target_dir "app" in

  (* Get files in specific directories *)
  let util_files = all_files_in_dir (Filename.concat target_dir "utils") in
  let lib_files = all_files_in_dir (Filename.concat target_dir "lib") in
  let route_file = Filename.concat target_dir "routes.ml" in
  let main_file = Filename.concat target_dir "main.ml" in

  (* Function to compile a single file *)
  let compile_file file =
    let cmd = Printf.sprintf
                "ocamlfind ocamlopt -c -thread -I %s/utils -I %s/lib -I %s -package cohttp-lwt-unix,lwt,tyxml,fpath,dotenv,str -thread %s"
                target_dir target_dir target_dir file in
    run_command cmd
  in

  let link_files files output =
    let cmx_files = List.map (fun file -> (Filename.chop_extension file) ^ ".cmx") files in
    let link_cmd =
      Printf.sprintf
        "ocamlfind ocamlopt -o %s -thread -I %s/utils -I %s/lib -package cohttp-lwt-unix,lwt,tyxml,fpath,dotenv,str -linkpkg %s"
        output target_dir target_dir (String.concat " " cmx_files)
    in
    run_command link_cmd
  in

  (* Compile utils files first *)
  let compiled_utils = List.for_all compile_file util_files in

  if compiled_utils then
    (* Compile lib files, linking against utils *)
    let compiled_libs = List.for_all compile_file lib_files in

    if compiled_libs then
      (* Compile routes.ml, linking against lib and utils *)
      if compile_file route_file then
        (* Compile main.ml, linking against everything else *)
        if compile_file main_file then
          (* Link all compiled object files into an executable *)
          let all_cmx_files = util_files @ lib_files @ [route_file; main_file] in
          if link_files all_cmx_files output then
            print_endline "Compilation successful."
          else
            print_endline "Linking failed. Intermediate files not removed."
        else
          print_endline "Compilation failed for main.ml."
      else
        print_endline "Compilation failed for routes.ml."
    else
      print_endline "Compilation failed for lib files."
  else
    print_endline "Compilation failed for utils files."

let clean_build_artifacts target_dir =
  print_endline "Cleaning up build artifacts...";
  let cleanup_patterns = [
    "*.cmi"; "*.cmx"; "*.o"; "*.cmo"; "a.out";
    "lib/*.cmi"; "lib/*.cmx"; "lib/*.o";
    "utils/*.cmi"; "utils/*.cmx"; "utils/*.o"
  ] in
  List.iter (fun pattern ->
    let command = Printf.sprintf "rm -f %s/%s" target_dir pattern in
    ignore (run_command command)) cleanup_patterns;
  print_endline "Cleanup complete."

