{
  description = "Test app for nix-container-utility: two Docker containers (hello + watch).";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # hello: a tiny node:http server.  / returns a hit counter, /healthz
      # returns {"ok":true}.  The app IS the entrypoint - no init, no mounts.
      hello = pkgs.writeShellApplication {
        name = "hello";
        runtimeInputs = [ pkgs.nodejs-slim ];
        text = ''
          exec ${pkgs.nodejs-slim}/bin/node -e '
            const http = require("node:http");
            let hits = 0;
            const started = Date.now();
            http.createServer((req, res) => {
              hits += 1;
              const path = (req.url || "/").split("?")[0];
              const body = path === "/healthz"
                ? { ok: true }
                : { hello: "world", hits, uptimeSec: Math.round((Date.now() - started) / 1000) };
              const data = JSON.stringify(body);
              res.writeHead(200, { "content-type": "application/json", "content-length": Buffer.byteLength(data) });
              res.end(data);
            }).listen(8080, () => console.log("hello on :8080"));
          '
        '';
      };

      # busybox nc's -e takes a single program path, so the HTTP responder is
      # its own script file and nc is pointed straight at it.
      responder = pkgs.writeShellScript "watch-view" ''
        body=$(cat /var/lib/watch/history.jsonl 2>/dev/null)
        len=$(printf "%s" "$body" | wc -c)
        printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s" "$len" "$body"
      '';

      # watch: polls hello:8080/healthz every 5s, appends a JSON record, and
      # serves the history as JSON on :8081 (busybox nc, one process per
      # container).
      watch = pkgs.writeShellApplication {
        name = "watch";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
          pkgs.busybox
          pkgs.bash
        ];
        text = ''
          mkdir -p /var/lib/watch
          : >> /var/lib/watch/history.jsonl

          # background: poll hello every 5s and append a record
          (
            probe_file=/var/lib/watch/.probe.json
            while true; do
              if curl -sf --max-time 3 http://hello:8080/healthz > "$probe_file"; then
                status=up
              else
                status=down
                printf '{"ok":false}\n' > "$probe_file"
              fi
              jq -c --arg s "$status" '. + {status: $s, ts: now}' "$probe_file" \
                >> /var/lib/watch/history.jsonl
              tail -n 200000 /var/lib/watch/history.jsonl > /var/lib/watch/.tmp \
                && mv /var/lib/watch/.tmp /var/lib/watch/history.jsonl
              sleep 5
            done
          ) &

          # foreground: serve the history as JSON on :8081.
          exec ${pkgs.busybox}/bin/busybox nc -lk -p 8081 -e ${responder}
        '';
      };
    in
    {
      # Each package is a plain OCI image tarball (docker load).  These are the
      # attributes the main repo's compose file names after `#` in a
      # `nix://ssh://…#hello` reference.
      packages.${system} = {
        hello = pkgs.dockerTools.buildLayeredImage {
          name = "testapp-hello";
          tag = "latest";
          contents = [
            hello
            pkgs.nodejs-slim
          ];
          config = {
            Entrypoint = [ "${hello}/bin/hello" ];
            Env = [ "PORT=8080" ];
            ExposedPorts = { "8080/tcp" = { }; };
          };
        };

        watch = pkgs.dockerTools.buildLayeredImage {
          name = "testapp-watch";
          tag = "latest";
          contents = [
            watch
            pkgs.bash
            pkgs.coreutils
          ];
          config = {
            Entrypoint = [ "${watch}/bin/watch" ];
            ExposedPorts = { "8081/tcp" = { }; };
          };
        };
      };
    };
}
