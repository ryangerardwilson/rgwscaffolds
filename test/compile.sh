
#!/bin/bash

# Step 1: Compile modules
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib utils/Renderer.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Session.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Landing.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Home.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/About.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Auth.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Dashboard.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib main.ml

# Step 2: Link modules
ocamlfind ocamlc -thread -package cohttp-lwt-unix,dotenv,str,base64 -linkpkg \
  -o app \
  utils/Renderer.cmo \
  lib/Session.cmo \
  lib/Landing.cmo \
  lib/Home.cmo \
  lib/About.cmo \
  lib/Auth.cmo \
  lib/Dashboard.cmo \
  main.cmo

# Step 3: Clean .cmi, .cmo, .out
find . -type f \( -name "*.cmo" -o -name "*.cmi" -o -name "*.out" \) -exec rm -f {} +

echo "Use the --and_run flag to compile and run the app automatically."

# Step 4: Optionally run
if [[ "$1" == "--and_run" ]]; then
  ./app
fi
