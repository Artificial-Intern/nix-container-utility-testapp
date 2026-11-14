{
  description = "Demo branch for nix-container-utility pinning: hello, version one.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      hello = pkgs.writeShellApplication {
        name = "hello";
        runtimeInputs = [ pkgs.nodejs-slim ];
        text = ''
          exec ${pkgs.nodejs-slim}/bin/node -e '
            const http = require("node:http");
            let hits = 0;
            http.createServer((req, res) => {
              hits += 1;
              const path = (req.url || "/").split("?")[0];
              const body = path === "/healthz"
                ? { ok: true }
                : { hello: "world", version: "one", hits };
              const data = JSON.stringify(body);
              res.writeHead(200, { "content-type": "application/json", "content-length": Buffer.byteLength(data) });
              res.end(data);
            }).listen(8080, () => console.log("hello on :8080"));
          '
        '';
      };
    in
    {
      packages.${system} = {
        hello = pkgs.dockerTools.buildLayeredImage {
          name = "demo-hello";
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
      };
    };
}
