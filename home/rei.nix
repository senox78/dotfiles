{
  config,
  pkgs,
  lib,
  inputs,
  standalone ? false,
  ...
}:
let
  tex = pkgs.texliveSmall.withPackages (
    ps: with ps; [
      collection-langjapanese
      collection-luatex
      collection-latexextra
      haranoaji
      haranoaji-extra
      fontspec
      hyperref
      latexmk
    ]
  );
in
{
  imports = [
    ./common_user.nix
  ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      AddKeysToAgent = "yes";
      # Kitty が子プロセスへ設定する light/dark ヒントを SSH 先にも渡す。
      # 接続先の sshd にも AcceptEnv TERM_BACKGROUND が必要。
      SendEnv = [ "TERM_BACKGROUND" ];
    };
  };

  fonts.fontconfig.enable = true;

  # XDG user dirs は freedesktop の仕様。
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = false;
  };

  # TeX and herdr are retained in the NixOS closure.  Fedora projects should
  # declare their exact versions in a devShell instead.
  home.packages = lib.optionals (!standalone) [
    tex
    inputs.herdr.packages.${pkgs.system}.default
  ];
}
