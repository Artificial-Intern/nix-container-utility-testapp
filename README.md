# nix-container-utility-testapp

Two Docker containers, built as plain OCI images by nixpkgs' `dockerTools`.
This repo exists to be pulled over SSH by `nix-container-utility`'s `nix://`
grammar:

```yaml
image: nix://ssh://git@github.com/Artificial-Intern/nix-container-utility-testapp#hello
```

## Containers

| package | image | what it does |
|---|---|---|
| `hello` | `testapp-hello` | node:http server. `/` returns a hit counter, `/healthz` returns `{"ok":true}`. Port 8080. |
| `watch` | `testapp-watch` | polls `hello:8080/healthz` every 5s, appends a JSON record, serves the history on 8081. |

`watch` reaches `hello` through the compose service name (`hello`), so the two
containers need to share a network.

## Build

```sh
nix build .#packages.x86_64-linux.hello
nix build .#packages.x86_64-linux.watch
```

Each result is a `docker load`-able tarball.
