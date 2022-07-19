{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:arqv/zig-overlay";
    
    flake-utils.inputs.nipkgs.follows = "nixpkgs";
    zig-overlay.inputs.nipkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    let systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    in flake-utils.lib.eachSystem systems (system:
      let pkgs = import nixpkgs { inherit system; };
          zig = zig-overlay.packages.${system}.master.latest;
      in rec {
        packages.default = packages.zig-builder;
        packages.zig-builder = derivation {
          name = "zig-builder";
          inherit system;
          builder = "${pkgs.bash}/bin/bash";
          args = ["-c" ''
              ${pkgs.coreutils}/bin/mkdir -p $out/bin
              ${zig}/bin/zig build-exe ${./nix-builder.zig} -femit-bin=$out/bin/zig-builder --cache-dir /build/zig-cache --global-cache-dir /build/global-cache
          ''];
        };

        packages.example = derivation rec {
          name = "example";
          src = ./example;
          inherit system;
          zig = zig-overlay.packages.${system}.master.latest;
          builder = "${packages.zig-builder}/bin/zig-builder";
          args = ["install"];
        };

    });
}
