# nix-sparkrun

Nix flake packaging [sparkrun](https://github.com/spark-arena/sparkrun) — Launch and manage Docker-based inference workloads on NVIDIA DGX Spark systems.

Pinned to upstream `v0.2.38`.

## Quick start

```bash
# Run directly without installing
nix run github:SoarinFerret/nix-sparkrun -- --help

# Install into your profile
nix profile install github:SoarinFerret/nix-sparkrun

# Then on a DGX Spark node:
sparkrun setup
sparkrun run qwen3-1.7b-vllm
```

## Flake outputs

| Output | What it is |
| --- | --- |
| `packages.<system>.sparkrun` (also `default`) | Wrapped CLI binary |
| `apps.<system>.default` | `nix run` target |
| `overlays.default` | Adds `pkgs.sparkrun` + four Python deps not in nixpkgs |
| `devShells.<system>.default` | Shell with `sparkrun`, `uv`, `python3`, `openssh`, `docker-client` |

Supported systems: `aarch64-linux` (DGX Spark / GB10) and `x86_64-linux`.

## Using from another flake

```nix
{
  inputs.sparkrun.url = "github:SoarinFerret/nix-sparkrun";

  outputs = { self, nixpkgs, sparkrun, ... }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ sparkrun.overlays.default ];
      };
    in {
      # pkgs.sparkrun is now available
      packages.${system}.myThing = pkgs.sparkrun;
    };
}
```

## NixOS module example

```nix
{ pkgs, sparkrun, ... }:
{
  nixpkgs.overlays = [ sparkrun.overlays.default ];

  environment.systemPackages = [ pkgs.sparkrun ];

  # sparkrun shells out to these at runtime:
  virtualisation.docker.enable = true;
  programs.ssh.startAgent = true;
}
```

## Runtime requirements

sparkrun is an orchestrator — it shells out to system tools that must be on `PATH` on every cluster node:

- `docker` (with NVIDIA Container Toolkit configured)
- `ssh` / `ssh-keygen` / `ssh-copy-id`
- Optional: `nvidia-smi`, `ibstat` / `mlxconfig` for ConnectX-7 detection

The dev shell includes `docker-client` and `openssh` for convenience, but the actual Docker daemon and the cluster mesh you have to set up yourself (`sparkrun setup` walks through it).

## What the flake patches

Upstream `pyproject.toml` pins every Python dep with `==`. Nix's closure already gives you reproducibility, so the strict pins are relaxed via `pythonRelaxDeps`. Four dependencies are not (or not at the right version) in nixpkgs and are fetched from PyPI inside the overlay:

- `scitrera-app-framework` (0.0.69)
- `vpd` (0.9.13)
- `botwinick-utils` (0.0.20)
- `python-json-logger` (4.0.0 — nixpkgs has 3.x)

`click`, `pyyaml`, `six`, `huggingface-hub`, and `textual` come from nixpkgs. If a future sparkrun release needs a stricter version of any of these, pin it via your own `pythonPackagesExtensions` override or open an issue here.

## Updating to a new sparkrun release

1. Bump `sparkrunVersion` in `flake.nix`.
2. Refresh the PyPI hash:

   ```bash
   nix-prefetch-url https://files.pythonhosted.org/packages/source/s/sparkrun/sparkrun-<NEW>.tar.gz \
     | xargs nix hash convert --hash-algo sha256 --to sri
   ```

3. If upstream changed deps (check `pyproject.toml`), update the `dependencies` list and `pythonRelaxDeps` accordingly.
4. `nix flake update && nix build .#sparkrun`.

## License

sparkrun itself is Apache-2.0 (see upstream). This packaging is provided as-is.
