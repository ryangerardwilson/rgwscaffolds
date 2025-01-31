
open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix

let routes = [
  ("/home", Home.handle_root);
  ("/about", About.handle_about);
]

let route conn req body =
  let uri_path = Uri.path (Request.uri req) in
  match List.find_opt (fun (path, _) -> path = uri_path) routes with
  | Some (_, handler) -> handler conn req body
  | None -> Server.respond_string ~status:`Not_found ~body:"Not Found" ()
