(* Function to get the first non-flag argument from the command line *)
let get_first_non_flag_argument () =
  (* Converts Sys.argv to a list, skipping the executable name itself *)
  let args = Array.to_list Sys.argv |> List.tl in
  Printf.printf "Command-line arguments: [%s]\n" (String.concat "; " args);
  flush stdout;

  (* Find the first argument that does not start with "--" *)
  let non_flag_argument = List.find_opt (fun arg -> not (String.starts_with ~prefix:"--" arg)) args in
  (match non_flag_argument with
   | Some arg -> Printf.printf "First non-flag argument: %s\n" arg
   | None -> Printf.printf "No non-flag argument found, defaulting to '.'\n");
  flush stdout;
  non_flag_argument

(* The main function handling execution logic *)
let () =
  Printf.printf "Program started\n";
  flush stdout;

  (* Get specified path or default to the current directory *)
  let target_path = Option.value (get_first_non_flag_argument ()) ~default:"." in
  Printf.printf "Target path for scaffolding and cleaning: %s\n" target_path;
  flush stdout;

  (* Temporarily commenting out possible problematic code *)
  Scaffolder_lib.scaffold target_path;
  Compiler_lib.compile target_path;
  Compiler_lib.clean_build_artifacts target_path;

  Printf.printf "Program completed\n";
  flush stdout;

