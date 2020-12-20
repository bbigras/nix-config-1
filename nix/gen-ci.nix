{ lib
, writeText
, writeScriptBin
, jq

, hosts
}:
let
  checkoutStep = {
    uses = "actions/checkout@v2";
    "with".fetch-depth = 0;
  };
  nixStep = {
    uses = "cachix/install-nix-action@v12";
    "with" = {
      nix_path = "nixpkgs=channel:nixos-unstable-small";
      install_url = "https://github.com/numtide/nix-flakes-installer/releases/download/nix-3.0pre20201007_5257a25/install";
      extra_nix_config = "experimental-features = nix-command flakes";
    };
  };
  aarch64Step = {
    name = "AArch64";
    run = ''
      # first create the ssh config dir for root
      sudo mkdir -p /root/.ssh

      # now add the key for the builder
      echo "''${{ secrets.AARCH64_BOX_KEY }}" |
          sudo tee /root/.ssh/aarch64.community.nixos > /dev/null
      sudo chmod 0600 /root/.ssh/aarch64.community.nixos

      # and make it a known host
      echo "''${{ secrets.KNOWN_HOSTS }}" |
          sudo tee -a /root/.ssh/known_hosts > /dev/null

      # lastly register the builder with nix
      builder_cfg=(
        lovesegfault@aarch64.nixos.community # user/addr
        aarch64-linux                        # arch
        /root/.ssh/aarch64.community.nixos   # key
        64                                   # maxJobs
        1                                    # speed factor
        big-parallel                         # features
      )
      echo "''${builder_cfg[*]}" |
          sudo tee /etc/nix/machines > /dev/null
    '';
  };
  cachixStep = {
    uses = "cachix/cachix-action@v8";
    "with" = {
      name = "nix-config";
      signingKey = "'\${{ secrets.CACHIX_SIGNING_KEY }}'";
    };
  };

  mkGenericJob = dependencies: extraSteps: {
    runs-on = "ubuntu-latest";
    needs = dependencies;
    steps = [
      checkoutStep
      nixStep
      aarch64Step
      cachixStep
    ] ++ extraSteps;
  };

  mkHostJob = host: mkGenericJob [ "check-ci" ] [{
    name = "Build";
    run = ''
      nix run nixpkgs#nix-build-uncached -- \
        -E "(builtins.getFlake (toString ./.)).deploy.nodes.${host}.profiles.system.path"
    '';
  }];

  ci = {
    on = {
      push.branches = [ "master" ];
      pull_request.branches = [ "**" ];
    };
    name = "CI";
    jobs = (lib.genAttrs hosts mkHostJob) // {
      check-ci = mkGenericJob [ ] [{
        run = ''
          cp ./.github/workflows/ci.yml /tmp/ci.yml.old
          nix run .#gen-ci
          diff ./.github/workflows/ci.yml /tmp/ci.yml.old || exit 1
        '';
      }];

      check-flake = mkGenericJob hosts [{
        run = "nix flake check";
      }];
    };
  };
  generated = writeText "ci.yml" (builtins.toJSON ci);
in
writeScriptBin "gen-ci" ''
  cat ${generated} | ${jq}/bin/jq > ./.github/workflows/ci.yml
''