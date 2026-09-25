{
  pkgs,
  inputs,
  lib,
  userName,
  ...
}:
let
  userHome = "/home/${userName}";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop.nix
    inputs.nix-hazkey.nixosModules.hazkey
    # ../../modules/thinkpad.nix
  ];

  networking.hostName = "selinoir";
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "none";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "start";
  };

  hardware.enableAllFirmware = true;

  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
  };
  services.hazkey.enable = true;
  services.keyd.keyboards.default.ids = lib.mkForce [
    "*"
    "-320f:5055"
  ];
  services.keyd.keyboards.default.settings.main = lib.mkForce {
    leftcontrol = "leftalt";
    leftalt = "leftcontrol";
    rightcontrol = "rightalt";
    rightalt = "rightcontrol";
  };
  services.tailscale.enable = true;

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "suspend";
  };

  services.fprintd.enable = true;
  security.pam.services = {
    # GDM runs gdm-fingerprint separately from gdm-password. Enabling
    # pam_fprintd in the shared login stack blocks the password prompt.
    login.fprintAuth = lib.mkForce false;
    sudo.fprintAuth = true;
    # hyprlock scans the sensor itself over fprintd's DBus API. Leaving
    # pam_fprintd in the stack (fprintAuth defaults to services.fprintd.enable)
    # makes PAM claim the same device concurrently, which breaks both paths.
    hyprlock.fprintAuth = false;
  };

  programs.ssh.extraConfig = ''
    Host eu.nixbuild.net
      PubkeyAcceptedKeyTypes ssh-ed25519
      ServerAliveInterval 60
      ServerAliveCountMax 15
      IdentityFile ${userHome}/.ssh/nixbuild
  '';

  programs.ssh.knownHosts.nixbuild = {
    hostNames = [ "eu.nixbuild.net" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
  };

  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "eu.nixbuild.net";
      sshUser = "seli";
      system = "x86_64-linux";
      maxJobs = 100;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
      ];
    }
  ];
  nix.settings.builders-use-substitutes = true;
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", \
      ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0a70", \
      MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';
  boot.initrd.luks.devices."luks-4cbdc1f5-be3a-4e0d-a0c9-51865546e644" = {
    device = "/dev/disk/by-uuid/4cbdc1f5-be3a-4e0d-a0c9-51865546e644";
  };

  fileSystems."/mnt/bk_disk" = {
    device = "/dev/mapper/bk_disk";
    fsType = "ext4";
    options = [
      "noauto"
      "nofail"
    ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    openssl
  ];

  programs.ssh.startAgent = false;
  services.gnome.gcr-ssh-agent.enable = true;
  systemd.user.services.gcr-ssh-agent.serviceConfig.UnsetEnvironment = [
    "SSH_ASKPASS_REQUIRE"
    "SSH_ASKPASS"
  ];

  programs.direnv.enable = true;

  nixpkgs.config.allowUnfree = true;

  users.users.${userName} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "kvm"
    ];
    shell = pkgs.fish;
  };

  programs.zsh.enable = true;
  programs.fish.enable = true;

  environment.etc."crypttab".text = lib.mkForce "";

  system.stateVersion = "24.11";

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  nix.optimise.automatic = true;
}
