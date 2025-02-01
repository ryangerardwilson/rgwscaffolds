
open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix

let handle_root _conn _req _body =
  (* Define which file (in dist/) to serve and what substitutions to apply *)
  let filename = "home.html" in
  let substitutions = [
    ("{{CUSTOM_VAR}}", "Custom Value 111");
    ("{{ANOTHER_VAR}}", "Another Value 222 ");
  ] in
  Renderer.server_side_render filename substitutions
