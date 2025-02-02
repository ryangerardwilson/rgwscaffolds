
open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix

let server_side_render (filename : string) (substitutions : (string * string) list) : (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t =
  (* Allow user to specify a PUBLIC_DIR via environment variable; defaults to "dist" *)
  let public_dir = Sys.getenv_opt "PUBLIC_DIR" |> Option.value ~default:"dist" in
  let filepath = Filename.concat public_dir filename in

  if Sys.file_exists filepath then
    Lwt_io.(with_file ~mode:Input filepath read) >>= fun content ->
    let replaced_content =
      List.fold_left (fun acc (key, value) ->
        Str.global_replace (Str.regexp_string key) value acc
      ) content substitutions
    in
    Server.respond_string ~status:`OK ~body:replaced_content ()
  else
    Server.respond_string
      ~status:`Not_found
      ~body:"File not found"
      ()
