{
  description = "nix support for generic-boltzmann-brain";

  inputs.nixpkgs.url = "github:NixOs/nixpkgs/nixpkgs-unstable";
  
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.mach-nix.url = "github:DavHau/mach-nix";
  
  outputs = inputs@{ self, nixpkgs, flake-utils, mach-nix }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let

        name = "generic-boltzmann-brain";

        compiler = "ghc902";  
         
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowBroken = true;
            allowUnsupportedSystem = true;
          };
        };

        mylib = mach-nix.lib.${system}; # adds mkPython, mkPythonShell, etc.

        paganini-py = mylib.mkPython {
          requirements = ''
            paganini==1.5
            cvxpy>=1.2.1
          '';
        };

        haskellPackages = pkgs.haskell.packages.${compiler}.override {
          overrides = self: super: {
            
            generic-boltzmann-brain = 
              self.callCabal2nix "generic-boltzmann-brain" ./. { };

            BinderAnn = self.callCabal2nix "BinderAnn" (builtins.fetchGit {
              url = "https://github.com/OctopiChalmers/BinderAnn.git";
              rev = "8f082b23ebd4e79e86e934f41ddfcba59652fadd";
            }) {};

            paganini-hs = pkgs.haskell.lib.dontCheck (
              self.callCabal2nix "paganini-hs" (builtins.fetchGit {
                url = "https://github.com/maciej-bendkowski/paganini-hs.git";
                rev = "f6f4f8d26c30544d17eab63583d4ff5e9158d2d9";
              }) {}
            );
          };
        };

        devShell = haskellPackages.shellFor {
          withHoogle = false; # Provides docs, optional. 
          packages = p: [
            p.generic-boltzmann-brain
          ]; 
          buildInputs = with pkgs; [
            cabal-install
            ghcid
            haskell-language-server
            hlint
            ormolu
            cabal2nix
            paganini-py
          ];
        };

        # TODO: add paganini-py to the derivation dependencies and remove `dontCheck`. don't check for now
        drv = pkgs.haskell.lib.dontCheck haskellPackages.generic-boltzmann-brain;
        
      in
        rec {
          inherit devShell;
          defaultPackage = drv;
        })
  ;}
