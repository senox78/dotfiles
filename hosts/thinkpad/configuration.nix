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
    # GTK_IM_MODULE/QT_IM_MODULE を設定しない (XMODIFIERS は残るので XWayland は XIM で動く)。
    # GTK3 は GTK_IM_MODULE の値に関係なく zwp_text_input_v3 を張るため、これを設定すると
    # Firefox が DBus フロントエンドと wayland_v2 フロントエンドの両方に InputContext を
    # 持ってしまう。どちらがフォーカスを取るかがウィンドウごと・タイミングごとに変わり、
    # classicui が候補ウィンドウを描き直すたびにちらつく。経路を wayland_v2 の一本に揃える。
    fcitx5.waylandFrontend = true;
  };
  services.hazkey.enable = true;
  # Ctrl と Alt を左右とも入れ替える。keyd は入力デバイス段階で変換するため、
  # Wayland / X11 を問わず同じ配列になる。Rainy 75 は本体側の配列を使うため除外する。
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

  # lid を閉じたときの挙動。logind は 3 つを状況で使い分ける:
  #   HandleLidSwitchDocked        … ドック中(外部モニタ接続中)。最優先
  #   HandleLidSwitchExternalPower … AC 接続中かつ非ドック
  #   HandleLidSwitch              … それ以外(= バッテリー かつ 非ドック)
  #
  # 3 つとも suspend。外部モニタ接続中は logind が「ドック」と判定し、
  #   HandleLidSwitchDocked の既定値 ignore だと lid を閉じても何も起きない
  # （＝ロックもされない）ので、明示的に指定する必要がある。suspend すれば
  # swayidle の before-sleep = loginctl lock-session が走り復帰時にロック
  # される。
  #
  # HandleLidSwitch = "hibernate" は試したが戻した(2026-07-25)。この機は
  # /sys/power/mem_sleep が [s2idle] のみ(Modern Standby, S3 無し)なので S4 に
  # 落とせれば持ち運び中の電力はほぼゼロにできる。しかし蓋起因の hibernate は
  # amdgpu と競合して危険:
  #   16:03:18 Lid closed / Hibernating...
  #   16:03:19 Lid opened            ← 凍結処理中(6 秒超)に開け直した
  #   16:03:26 soft lockup, Tainted: [D]=DIE
  #   16:03:54 amdgpu_dm_atomic_commit_tail → amdgpu_bo_unpin → ttm_bo_unpin
  #            _raw_spin_lock で停止 → ハング → 強制電源断
  # イメージは書かれないので次回は cold boot(PM: Image not found (code -22))に
  # なりセッションが飛ぶ。同日 16:00 の試行も Lid opened と同時刻で中断した。
  # 一方 swayidle の 30 分アイドル hibernate は蓋イベントを伴わないため成功実績
  # がある(7/24 23:46 に 7391040 kbytes 書き込み → 翌 00:05 に resume 成功)。
  # よって長時間放置の省電力は swayidle 側に任せ、蓋は suspend に留める。
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
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", \
      ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0a70", \
      MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';
  # LUKS devices
  # boot.initrd.luks.devices = {
  # Swap partition
  # "luks-1dc20a4c-0384-4870-bb99-e5a65f1df495" = {
  #   device = "/dev/disk/by-uuid/1dc20a4c-0384-4870-bb99-e5a65f1df495";
  #   allowDiscards = true;
  # };
  # Backup disk
  # "bk_disk" = {
  #   device = "/dev/disk/by-uuid/86f101a3-83e7-42e6-9cba-06b2621f8db2";
  #   allowDiscards = true;
  # };
  # };

  # ===== swap =====
  # この機の swap は hardware-configuration.nix が生成する LUKS パーティション
  # (luks-86adca68) のみ。initrd 中に解錠しないと起動時に
  # /dev/mapper/luks-86adca68 を待って固まるので、下の boot.initrd.luks.devices で
  # 登録する(/etc/nixos の gen 1 と同じ対応)。
  #
  # 2026-08-05: ここにあった /swapfile(34GiB) + boot.resumeDevice の組はデスクトップ機
  # (root=luks-5c4ff8a1, swap=luks-82faf233) からコピペした残骸で、この機には存在しない
  # /dev/mapper/luks-5c4ff8a1-… を resume= に指定していた。systemd initrd がその
  # デバイス待ちでハングし、gen 2/3 が起動不能になっていた(resume_offset も不要)。
  # swap は 8.8GiB で RAM(30GiB) に届かないため、この機では hibernate は使えない。
  boot.initrd.luks.devices."luks-86adca68-ce6c-40cf-a0be-cf1432f342cd" = {
    device = "/dev/disk/by-uuid/86adca68-ce6c-40cf-a0be-cf1432f342cd";
  };

  fileSystems."/mnt/bk_disk" = {
    device = "/dev/mapper/bk_disk";
    fsType = "ext4";
    options = [
      "noauto"
      "nofail"
    ];
  };

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
