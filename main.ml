(* Function to find the argument immediately following the --scaffold flag, if present *)
let get_scaffold_directory () =
  (* Converts Sys.argv to a list, skipping the executable name itself *)
  let args = Array.to_list Sys.argv |> List.tl in
  Printf.printf "Command-line arguments: [%s]\n" (String.concat "; " args);
  flush stdout;

  (* Find the index of the "--scaffold" flag *)
  let rec find_scaffold_flag index = function
    | [] -> None
    | "--scaffold" :: rest -> Some (index + 1)
    | _ :: rest -> find_scaffold_flag (index + 1) rest
  in

  match find_scaffold_flag 0 args with
  | None ->
      Printf.printf "'--scaffold' flag not found, erroring out.\n";
      flush stdout;
      None
  | Some i when i < List.length args ->
      let target_arg = List.nth args i in
      if String.starts_with ~prefix:"--" target_arg then (
        Printf.printf "No valid directory specified after '--scaffold', erroring out.\n";
        flush stdout;
        None
      ) else (
        Printf.printf "Scaffold target directory: %s\n" target_arg;
        flush stdout;
        Some target_arg
      )
  | Some _ -> 
      Printf.printf "No argument found after '--scaffold', erroring out.\n";
      flush stdout;
      None

(* The main function handling execution logic *)
let () =
  Printf.printf "Program started\n";
  flush stdout;
  
  (* Ensure the program has the --scaffold flag with a following argument *)
  match get_scaffold_directory () with
  | None ->
      Printf.printf "Program requires a directory after '--scaffold' flag. Exiting.\n";
      flush stdout;
      exit 1
  | Some target_path ->
      Printf.printf "Target path for scaffolding and cleaning: %s\n" target_path;
      flush stdout;

      (* Temporarily commenting out possible problematic code *)
      Scaffolder_lib.scaffold target_path;

      Printf.printf "Program completed\n";
      flush stdout

