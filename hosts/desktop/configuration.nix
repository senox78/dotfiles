{
  pkgs,
  inputs,
  lib,
  userName,
  ...
}:
let
  userHome = "/home/${userName}";
  mediaRoot = "/run/media/${userName}";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop.nix
    inputs.nix-hazkey.nixosModules.hazkey
  ];

  networking.hostName = "selipaq";
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

  # Keep KVM and VirtualBox installed side by side.  With this disabled, KVM
  # only claims VT-x while a KVM VM exists, so VirtualBox can use it after all
  # KVM VMs have been shut down (and vice versa).
  boot.kernelParams = [ "kvm.enable_virt_at_load=0" ];
  virtualisation.virtualbox.host.enable = true;

  hardware.enableAllFirmware = true;

  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    # GTK_IM_MODULE/QT_IM_MODULE を設定しない (XMODIFIERS は残るので XWayland は XIM で動く)。
    # GTK3 は GTK_IM_MODULE の値に関係なく zwp_text_input_v3 を張るため、これを設定すると
    # Firefox が DBus フロントエンドと wayland_v2 フロントエンドの両方に InputContext を
    # 持ってしまう。どちらがフォーカスを取るかがウィンドウごと・タイミングごとに変わり、
    # classicui が候補ウィンドウを描き直すたびにちらつく。経路を wayland_v2 の一本に揃える。
    fcitx5.waylandFrontend = true;
  };
  services.hazkey.enable = true;
  services.tailscale.enable = true;

  services.smartd = {
    enable = true;
    devices = [
      { device = "/dev/sda"; }
      { device = "/dev/sdb"; }
    ];
  };

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # Auto-mount internal data drives by UUID via systemd.
  # sda1 (ext4, ~465G) is the HDD, sdb1 (ext4, ~238G) is the SSD.
  fileSystems."${mediaRoot}/hdd" = {
    device = "/dev/disk/by-uuid/8d675241-ce9e-4c58-b18b-fd2b686bd749";
    fsType = "ext4";
  };
  fileSystems."${mediaRoot}/ssd" = {
    device = "/dev/disk/by-uuid/cd76b396-71ae-48a3-a3e3-b953bc460496";
    fsType = "ext4";
  };

  # Immich stores original assets and generated media on the HDD. PostgreSQL
  # needs lower-latency local storage, so its data directory lives on sdb.
  # The application listens on all interfaces, but the firewall exposes it only
  # through Tailscale; it is not reachable from the LAN or the Internet.
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    mediaLocation = "${mediaRoot}/hdd/immich";
  };
  services.postgresql.dataDir = "${mediaRoot}/ssd/immich/postgresql";

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2283 ];

  # tmpfiles runs before this boot's data-disk mounts are guaranteed to be
  # available. Prepare the paths after both mounts instead, before either
  # service enters its private mount namespace.
  systemd.services.immich-storage-prepare = {
    description = "Prepare Immich storage directories";
    unitConfig.RequiresMountsFor = [
      "${mediaRoot}/hdd"
      "${mediaRoot}/ssd"
    ];
    before = [
      "immich-server.service"
      "postgresql.service"
    ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils ];
    script = ''
      install -d -m 0700 -o immich -g immich ${mediaRoot}/hdd/immich
      install -d -m 0700 -o postgres -g postgres ${mediaRoot}/ssd/immich
      install -d -m 0700 -o postgres -g postgres ${mediaRoot}/ssd/immich/postgresql
    '';
  };

  systemd.services.postgresql = {
    requires = [ "immich-storage-prepare.service" ];
    after = [ "immich-storage-prepare.service" ];
  };
  systemd.services.immich-server = {
    requires = [ "immich-storage-prepare.service" ];
    after = [ "immich-storage-prepare.service" ];
  };

  # nixbuild.net remote builder. The nix-daemon runs as root, so the key must be
  # passphrase-less and reachable from root's ssh config (/etc/ssh/ssh_config).
  # A dropped connection while copying results back is reported as a build
  # failure, so keep the keepalive tolerant of brief network hiccups.
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

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
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
  # Let nixbuild.net fetch dependencies from cache.nixos.org itself instead of
  # uploading them from this machine.
  nix.settings.builders-use-substitutes = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="320f", ATTRS{idProduct}=="5055", \
      MODE="0660", GROUP="users", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", \
      ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0a70", \
      MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", \
      ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0440", \
      MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';

  # bootloader configurations for UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

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
  # gcr-ssh-agent は鍵の解錠時に ssh-add を fork し、passphrase を askpass 経由で
  # キーリングから取る。セッション環境に SSH_ASKPASS_REQUIRE=never が紛れ込むと
  # ssh-add が askpass を拒否して署名が「agent refused operation」で落ちるため、
  # このサービスでは明示的に落とす（シェル rc からの流入に対する保険）。
  systemd.user.services.gcr-ssh-agent.serviceConfig.UnsetEnvironment = [
    "SSH_ASKPASS_REQUIRE"
    "SSH_ASKPASS"
  ];

  programs.direnv.enable = true;

  nixpkgs.config.allowUnfree = true;

  users.users.${userName} = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
      "kvm"
      "vboxusers"
    ];
    shell = pkgs.fish;
  };

  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Manage /etc/crypttab via Nix to override manual/broken entries
  environment.etc."crypttab".text = lib.mkForce "";

  system.stateVersion = "24.11";

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  # Deduplicate identical files among live store paths.  This complements GC:
  # it reduces space use but does not remove any reachable paths.
  nix.optimise.automatic = true;
}
