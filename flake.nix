{
  description = "sparkrun — launch and manage Docker-based inference workloads on NVIDIA DGX Spark";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      sparkrunVersion = "0.2.38";

      mkPythonOverrides = py-final: py-prev: {
        botwinick-utils = py-final.buildPythonPackage rec {
          pname = "botwinick-utils";
          version = "0.0.20";
          pyproject = true;
          src = py-final.fetchPypi {
            pname = "botwinick_utils";
            inherit version;
            hash = "sha256-iiDPVJthykK0ntJunQr2MS1wGM4p4NOY18hMkOo71fQ=";
          };
          build-system = [ py-final.setuptools ];
          doCheck = false;
          pythonImportsCheck = [ "botwinick_utils" ];
        };

        vpd = py-final.buildPythonPackage rec {
          pname = "vpd";
          version = "0.9.13";
          pyproject = true;
          src = py-final.fetchPypi {
            inherit pname version;
            hash = "sha256-G9aoEZTXzU6/7/WJnFfZhEetzyfU7FWXrGyiQBNfYVE=";
          };
          build-system = [ py-final.setuptools ];
          dependencies = [ py-final.six py-final.pyyaml ];
          doCheck = false;
          pythonImportsCheck = [ "vpd" ];
        };

        # nixpkgs ships python-json-logger 3.x; scitrera-app-framework wants >=4.0.0.
        python-json-logger = py-final.buildPythonPackage rec {
          pname = "python-json-logger";
          version = "4.0.0";
          pyproject = true;
          src = py-final.fetchPypi {
            pname = "python_json_logger";
            inherit version;
            hash = "sha256-9Y5o60bh+u0n4PV0pVoEVe7Ne4pbiLhaeEUZujz/BH8=";
          };
          build-system = [ py-final.setuptools ];
          doCheck = false;
          pythonImportsCheck = [ "pythonjsonlogger" ];
        };

        scitrera-app-framework = py-final.buildPythonPackage rec {
          pname = "scitrera-app-framework";
          version = "0.0.69";
          pyproject = true;
          src = py-final.fetchPypi {
            pname = "scitrera_app_framework";
            inherit version;
            hash = "sha256-R4Rcmfh3UE+BcZmwGZKA7m8SZlYGlA3m2FbTeruI5WQ=";
          };
          build-system = [ py-final.setuptools ];
          dependencies = [
            py-final.botwinick-utils
            py-final.vpd
            py-final.python-json-logger
          ];
          doCheck = false;
          pythonImportsCheck = [ "scitrera_app_framework" ];
        };
      };

      mkSparkrun = pkgs: pkgs.python3.pkgs.buildPythonApplication {
        pname = "sparkrun";
        version = sparkrunVersion;
        pyproject = true;

        src = pkgs.python3.pkgs.fetchPypi {
          pname = "sparkrun";
          version = sparkrunVersion;
          hash = "sha256-xPX8yx7+zompHq8i9qAEzRM9umWPJVFpHkErKka1rG4=";
        };

        build-system = with pkgs.python3.pkgs; [ setuptools setuptools-scm ];

        # The upstream pyproject pins exact versions (`==`) for supply-chain
        # reasons. Nix's closure already provides reproducibility, so we relax
        # those pins to whatever the overlay resolves to.
        pythonRelaxDeps = [
          "click"
          "pyyaml"
          "six"
          "huggingface-hub"
          "textual"
          "scitrera-app-framework"
          "vpd"
        ];

        dependencies = with pkgs.python3.pkgs; [
          scitrera-app-framework
          vpd
          six
          click
          pyyaml
          huggingface-hub
          textual
        ];

        doCheck = false;
        pythonImportsCheck = [ "sparkrun" "sparkrun.cli" ];

        meta = {
          description = "Launch and manage Docker-based inference workloads on NVIDIA DGX Spark";
          homepage = "https://github.com/spark-arena/sparkrun";
          license = nixpkgs.lib.licenses.asl20;
          mainProgram = "sparkrun";
          platforms = nixpkgs.lib.platforms.linux;
        };
      };

      overlay = final: prev: {
        pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
          mkPythonOverrides
        ];
        sparkrun = mkSparkrun final;
      };

      systems = [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      overlays.default = overlay;
    }
    // flake-utils.lib.eachSystem systems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.sparkrun;
          sparkrun = pkgs.sparkrun;
        };

        apps.default = {
          type = "app";
          program = "${pkgs.sparkrun}/bin/sparkrun";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.sparkrun
            pkgs.uv
            pkgs.python3
            # Runtime tools sparkrun shells out to:
            pkgs.openssh
            pkgs.docker-client
          ];
        };
      });
}
