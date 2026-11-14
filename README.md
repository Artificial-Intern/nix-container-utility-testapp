# nix-container-utility-testapp

A two-container test app for
[`nix-container-utility`](https://github.com/QuintenMuyllaert/nix-container-utility).
It exists to be pulled over SSH by that flake's `nix://` grammar, so the
`nix://ssh://…` arm has a real remote flake to resolve against.

The main repo's `examples/docker/testapp/docker-compose.yaml` names these
packages:

```yaml
services:
  hello:
    image: nix://ssh://git@github.com/Artificial-Intern/nix-container-utility-testapp#hello
  watch:
    image: nix://ssh://git@github.com/Artificial-Intern/nix-container-utility-testapp#watch
```

Run it from the main repo:

```sh
nix run .#compose-testapp            # fetch both images over SSH, bring them up
nix run .#compose-testapp -- down    # tear them down
```

## Containers

| package | image | what it does |
|---|---|---|
| `hello` | `testapp-hello` | node:http server. `/` returns a hit counter, `/healthz` returns `{"ok":true}`. Port 8080. |
| `watch` | `testapp-watch` | polls `hello:8080/healthz` every 5s, appends a JSON record, serves the history on 8081. |

`watch` reaches `hello` through the compose service name (`hello`), so the two
containers share a network.  Both are plain OCI images built by nixpkgs'
`dockerTools`: no init, no `--privileged`, no `--cap-add`, no bind mounts.

## Build

```sh
nix build .#packages.x86_64-linux.hello
nix build .#packages.x86_64-linux.watch
```

Each result is a `docker load`-able tarball.
