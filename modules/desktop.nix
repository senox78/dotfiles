{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  wlmstr = inputs.wlmstr.packages.${pkgs.system}.default;

  # バー/通知は compositor の spawn-at-startup ではなく systemd user サービスで
  # 立ち上げる。テーマはセッションの compositor (XDG_CURRENT_DESKTOP) で分岐する
  # にかかわらず Paper Design の既定 CSS を使う。exec するので systemd が実プロセスを
  # 追跡できる。
  waybarLaunch = pkgs.writeShellScript "waybar-launch" ''
    set -eu
    BASE="$HOME/dotfiles/.config/waybar"
    case "''${XDG_CURRENT_DESKTOP:-}" in
      niri)
        exec ${pkgs.waybar}/bin/waybar -c "$BASE/config.niri.jsonc" -s "$BASE/style.css"
        ;;
      sway:wlroots)
        exec ${pkgs.waybar}/bin/waybar -c "$BASE/config.sway.jsonc" -s "$BASE/style.css"
        ;;
      *)
        exec ${pkgs.waybar}/bin/waybar -c "$BASE/config.hypr.jsonc" -s "$BASE/style.css"
        ;;
    esac
  '';

  # SwayNC が通知 D-Bus 名を取得するまで Type=dbus の unit を activating に保つ。
  # Waybar はこの unit を Requires= するため、通知先の無いバーを起動完了にしない。
  swayncLaunch = pkgs.writeShellScript "swaync-launch" ''
    set -eu
    BASE="$HOME/dotfiles/.config/swaync"
    case "''${XDG_CURRENT_DESKTOP:-}" in
      niri)
        exec ${pkgs.swaynotificationcenter}/bin/swaync -s "$BASE/style.css"
        ;;
      *)
        exec ${pkgs.swaynotificationcenter}/bin/swaync
        ;;
    esac
  '';

  # wl-paste --watch は選択が変わるたびに cliphist store を走らせて居続けるので、
  # text/image の 2 つをバックグラウンドで起動して待つ (cgroup 単位で管理される)。
  cliphistStore = pkgs.writeShellScript "cliphist-store" ''
    set -eu
    ${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store &
    ${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store &
    wait
  '';

  # swayidle は各コマンドを 1 つの argv (内部で sh -c) として受けるため、複雑な判定は
  # writeShellScript で個別に作り、そのパスを渡す。コンポジタは niri / Hyprland 共用
  # なので pidof で振り分ける。swayidle のサービス PATH は最小限に絞っているため、
  # 実行は /run/current-system/sw/bin を絶対パスで叩く (loginctl / systemctl は
  # PATH に入るのでそのまま)。
  #
  # 音声再生の判定について。swayidle は ext_idle_notifier_v1 の無操作だけで発火し、
  # 音声のみの再生でアイドル抑止を取るアプリはほぼ無い。そのため PipeWire に再生中
  # ストリームがあるかを自前で見る。pw-dump が落ちた場合は「ロックする」側に倒れる
  # (fail-safe)。
  swayidleBrightnessDown = pkgs.writeShellScript "swayidle-brightness-down" ''
    exec /run/current-system/sw/bin/brightnessctl -s set 10%
  '';
  swayidleBrightnessUp = pkgs.writeShellScript "swayidle-brightness-up" ''
    exec /run/current-system/sw/bin/brightnessctl -r
  '';
  # 8 分: 減光。-s で現在の輝度を保存し、復帰時に -r で元に戻す。→ 上記 2 スクリプト。
  #
  # 10 分: ロック + 画面オフ (DPMS)。GNOME の idle-delay 600 相当。ここが無いと
  # 30 分の hibernate まで画面が点きっぱなしになり、離席のたびにパネルが電力を
  # 食い続ける (かつロックも掛からない)。
  #
  # ロックを撃たない条件が 2 つ:
  #   - 音声再生中 (30 分の hibernate と同じ判定)
  #   - AC 接続中。AC = 自宅/ドックで在席中という運用なので、離席時の情報漏洩より
  #     復帰のたびの再認証のほうが邪魔になる。バッテリー駆動 = 持ち出し中なので
  #     こちらは従来どおりロックする。
  # AC 判定は hibernate 側の `= 0` ではなく `!= 1` にしてある。ファイルが読めない
  # ときに「ロックする」側へ倒すため (fail-safe の向きが逆)。
  # 画面オフは AC でも再生中でも常に行う: パネルを消しても再生は続くし、ロック
  # しないこととも独立なので省電力上むしろ好都合。
  swayidleLockOff = pkgs.writeShellScript "swayidle-lock-off" ''
    [ "$(cat /sys/class/power_supply/AC/online)" != 1 ] \
      && ! /run/current-system/sw/bin/pw-dump \
        | /run/current-system/sw/bin/jq -e 'any(.[]; .info.props."media.class"=="Stream/Output/Audio" and .info.state=="running")' >/dev/null \
      && loginctl lock-session
    if pidof niri >/dev/null; then
      /run/current-system/sw/bin/niri msg action power-off-monitors
    else
      /run/current-system/sw/bin/hyprctl dispatch dpms off
    fi
  '';
  swayidleMonitorsOn = pkgs.writeShellScript "swayidle-monitors-on" ''
    if pidof niri >/dev/null; then
      /run/current-system/sw/bin/niri msg action power-on-monitors
    else
      /run/current-system/sw/bin/hyprctl dispatch dpms on
    fi
  '';
  # アイドル 30 分で hibernate (S4)。ただし「バッテリー駆動時のみ」。before-sleep が
  # ロックも掛ける。
  # AC 接続 (=ドック) 時は hibernate しない (経緯は旧 hypridle.conf 参照)。
  swayidleHibernate = pkgs.writeShellScript "swayidle-hibernate" ''
    [ "$(cat /sys/class/power_supply/AC/online)" = 0 ] \
      && ! /run/current-system/sw/bin/pw-dump \
        | /run/current-system/sw/bin/jq -e 'any(.[]; .info.props."media.class"=="Stream/Output/Audio" and .info.state=="running")' >/dev/null \
      && systemctl hibernate
  '';

  # loginctl lock-session で立てた logind 側の lock 状態は、hyprlock を解除して
  # 終了しただけでは下がらない。残したままだと復帰後に lock 通知が再送され、
  # hyprlock が連続起動するため、locker の終了と session unlock を対にする。
  swayidleLock = pkgs.writeShellScript "swayidle-lock" ''
    ${lib.getExe pkgs.hyprlock}
    loginctl unlock-session
  '';

  swayidleLaunch = pkgs.writeShellScript "swayidle-launch" ''
    exec ${pkgs.swayidle}/bin/swayidle -w \
      timeout 480 ${swayidleBrightnessDown} resume ${swayidleBrightnessUp} \
      timeout 3600 ${swayidleLockOff} resume ${swayidleMonitorsOn} \
      timeout 1800 ${swayidleHibernate} \
      lock ${swayidleLock} \
      before-sleep 'loginctl lock-session'
  '';
in
{
  # ===== desktop base (entire system) =====
  services.desktopManager.gnome.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.displayManager.defaultSession = "niri";
  # Use GNOME's helper, which matches the gnome-keyring SSH-agent configuration.
  programs.ssh.askPassword = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
  programs.niri.enable = true;
  # Installs hyprlock *and* creates /etc/pam.d/hyprlock. Without the PAM
  # service, hyprlock falls through to /etc/pam.d/other (pam_deny) and the
  # password fallback can never succeed.
  programs.hyprlock.enable = true;
  # PipeWire + rtkit
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Wayland portal
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  # polkit
  security.polkit.enable = true;
  # An authentication agent is required for any action whose polkit default is
  # auth_self / auth_admin (fprintd enroll, udisks mounts, ...). Without one the
  # request is denied outright with no prompt. GDM only supplies an agent to its
  # own greeter, so a bare niri/Hyprland session has none.
  systemd.packages = [ pkgs.hyprpolkitagent ];
  systemd.user.services.hyprpolkitagent.wantedBy = [ "graphical-session.target" ];

  # ===== desktop session services =====
  # 以前は compositor の spawn-at-startup / hypr の exec_cmd で起動していた
  # セッション部品を systemd user サービスに移管した。graphical-session.target
  # 配下なので compositor が立った後に起動し、停止時は一緒に終わる。
  # 環境変数の伝播 (dbus-update-activation-environment / import-environment) と
  # xdg-desktop-portal の restart だけは compositor 側に残している。
  systemd.user.services = {
    udiskie = {
      description = "udiskie automount daemon";
      unitConfig = {
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.udiskie} -a -t --notify";
        Restart = "on-failure";
      };
      wantedBy = [ "graphical-session.target" ];
    };

    cliphist-store = {
      description = "cliphist clipboard store";
      unitConfig = {
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      serviceConfig = {
        # writeShellScript は実行ファイルそのものを返す（/bin 配下ではない）。
        ExecStart = "${cliphistStore}";
        Restart = "on-failure";
      };
      wantedBy = [ "graphical-session.target" ];
    };

    awww-daemon = {
      description = "awww wallpaper engine daemon";
      unitConfig = {
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      serviceConfig = {
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        Restart = "on-failure";
        # awww-daemon は壁紙を描画する際に `awww` クライアントを fork する。
        # systemd user サービスには NixOS が既定の Environment PATH を注入するため、
        # standalone の PATH= では上書きされてしまう。Environment で後勝ちさせる。
        Environment = [ "PATH=/run/current-system/sw/bin" ];
      };
      wantedBy = [ "graphical-session.target" ];
    };

    wlmstr-init = {
      description = "set initial wallpaper";
      unitConfig = {
        PartOf = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
          "awww-daemon.service"
        ];
        Requires = [ "awww-daemon.service" ];
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${wlmstr}/bin/wlmstr next seq";
        # wlmstr は `awww img` を subprocess で叩くので、awww の入った
        # /run/current-system/sw/bin を PATH に足す (Environment で後勝ちさせる)。
        Environment = [ "PATH=/run/current-system/sw/bin" ];
      };
      wantedBy = [ "graphical-session.target" ];
    };

    waybar = {
      description = "Waybar status bar";
      unitConfig = {
        PartOf = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
          "swaync.service"
        ];
        Conflicts = [ "noctalia.service" ];
        Requires = [ "swaync.service" ];
      };
      serviceConfig = {
        ExecStart = waybarLaunch;
        Restart = "on-failure";
        # waybar の module が swaync-client 等を exec するので、systemPackages 側の
        # /run/current-system/sw/bin を PATH に足す (Environment で後勝ちさせる)。
        Environment = [ "PATH=/run/current-system/sw/bin" ];
      };
      # Waybar を既定のバーとする。Noctalia は必要なときだけ
      # `systemctl --user start noctalia` で切り替える。
      wantedBy = [ "graphical-session.target" ];
    };

    swaync = {
      description = "SwayNC notification daemon for Waybar";
      unitConfig = {
        # Noctalia が Conflicts=waybar.service で Waybar を停止すると、この unit
        # も連動して停止する。PartOf は SwayNC を単独起動しない。
        PartOf = [ "waybar.service" ];
        After = [ "graphical-session.target" ];
        Conflicts = [ "noctalia.service" ];
      };
      serviceConfig = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = swayncLaunch;
        Restart = "on-failure";
      };
    };

    # idle manager。hypridle から swayidle に移行した (2026-08-08)。hypridle の
    # .config/hypr/hypridle.conf は swayidle の CLI / スクリプト化に合わせて消した。
    # swayidle の package は同梱の systemd unit を持たない (NixOS の
    # services.swayidle モジュールも現行 nixpkgs には無い) ので、ここで立てる。
    # loginctl lock-session の logind シグナルを lock イベントで受け、
    # hyprlock を起動する。PAM は起動後の認証に使われる。
    swayidle = {
      description = "Idle manager for Wayland";
      unitConfig = {
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      serviceConfig = {
        ExecStart = swayidleLaunch;
        Restart = "on-failure";
        # 各コマンドは sh -c で叩く。loginctl / systemctl を解決できるよう
        # /run/current-system/sw/bin を PATH に足す (Environment で後勝ちさせる)。
        Environment = [ "PATH=/run/current-system/sw/bin" ];
      };
      wantedBy = [ "graphical-session.target" ];
    };
  };
  # GNOME and standalone Wayland sessions share GNOME Keyring as their Secret
  # Service backend. GDM's PAM stack unlocks the login keyring below.
  services.gnome.gnome-keyring.enable = true;
  # unlock keyring by PAM relation when login
  # GDM 経由のログインでも login キーリングが解錠される。/etc/pam.d/gdm-password は
  # login を substack/include するだけなので、ここの pam_gnome_keyring がそのまま
  # 効く(gdm-fingerprint は自前の行を持つが、同じくこのオプションで gate される)。
  # よって GDM 用に別途書く必要は無い。これが効いていないと gcr-ssh-agent が
  # ~/.ssh/id_ed25519 のパスフレーズを取り出せず、GitHub への SSH が署名待ちで
  # 固まる（gcr 4.x は askpass GUI を出せないため）。
  security.pam.services.login.enableGnomeKeyring = true;

  services.upower.enable = true;

  # ===== display manager =====
  # GDM。greetd + ReGreet(cage 上の GTK4)から 2026-08-04 に戻した。
  # 経緯と、GDM で復活する既知のコスト(greeter 常駐 / gsd-media-keys の
  # power key 奪取 / sleep の delay inhibitor)は chglog/login.md を読むこと。
  #
  # ここを greetd 系に戻すなら、GNOME セッションが壊れることを先に理解しておく。
  # wayland-sessions/*.desktop の DesktopNames= を読んでセッションリーダに
  # XDG_CURRENT_DESKTOP / XDG_SESSION_DESKTOP を export するのは DM の仕事で、
  # gdm-session-worker はやるが greetd/ReGreet はやらない。Hyprland と niri は
  # 自前の設定(hypr/config/env.lua, niri/config.kdl)で立てているので無傷だが、
  # gnome-session はこの変数を一切さわらない(バイナリに文字列すら無い)。
  # 値が付かないと gnome-control-center が
  #   Running gnome-control-center is only supported under GNOME and Unity, exiting
  # で即終了し、GNOME の設定アプリが開かなくなる。
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;

  services.keyd = {
    enable = true;

    keyboards.default.settings.main = {
      pageup = "noop";
      pagedown = "noop";

      # keyd は既定で rightcontrol を layer(control) に束縛し、control 修飾子を
      # 内部の MOD_CTRL(KEY_LEFTCTRL) で再送出するため、右Ctrlが左Ctrl(Control_L)
      # に化ける。ここで素通しにして KEY_RIGHTCTRL を維持させる（Fcitx5 で個別バインド用）。
      rightcontrol = "rightcontrol";

      assistant = "rightmeta";

      # Delete は単押しでは何も送らない（実質無効化）。300ms 長押しで coffee
      # (evdev 152 = KEY_SCREENLOCK) を送り、コンポジタ側でロックする
      # （hypr/config/binds.lua と niri/config.kdl の XF86ScreenSaver）。
      # evdev rules は必ず inet(evdev) を混ぜるので、この keycode は us 配列でも
      # XF86ScreenSaver という keysym を持つ = Hyprland でも niri でも拾える。
      # 長押し時間はここで調整する。
      delete = "timeout(noop, 300, coffee)";
    };
  };

  # Virtualization (libvirt + virt-manager + TPM2.0)
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;

  # tlp
  # services.tlp.enable = true;
  services.tlp = {
    enable = true;

    settings = {
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";
    };
  };
  services.power-profiles-daemon.enable = false;

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Prefer the external TP-Link UB500 (2357:0604).  The Intel Bluetooth
  # function integrated with the Wi-Fi card is USB 1-14 (8087:0a2b); prevent
  # just that device from authorizing, while leaving other btusb devices alone.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", KERNEL=="1-14", ATTR{idVendor}=="8087", ATTR{idProduct}=="0a2b", ATTR{authorized}="0"
  '';

  # Fonts: JP glyphs for CJK on lang-less pages, Monaspace Radon for Latin monospace
  fonts = {
    packages = with pkgs; [
      monaspace
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      nerd-fonts.symbols-only
    ];
    fontconfig.defaultFonts = {
      sansSerif = [
        "Noto Sans"
        "Noto Sans CJK JP"
      ];
      serif = [
        "Noto Serif"
        "Noto Serif CJK JP"
      ];
      monospace = [
        "Monaspace Radon"
        "Noto Sans Mono CJK JP"
        "Symbols Nerd Font Mono"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  environment.systemPackages = with pkgs; [
    # swayidle の各コマンドが /run/current-system/sw/bin から叩くので、ユーザ
    # プロファイルではなくシステム側に入れておく (swayidle のサービス PATH は
    # 最小限)。brightnessctl = 減光、jq = PipeWire の再生中判定。
    brightnessctl
    jq
    awww
    waybar
    swaynotificationcenter
    rofi
    hyprpaper
    swayidle
    hyprpolkitagent
    hyprpicker
    hyprshot
    wl-clipboard
    kitty
    cliphist
    swtpm
    udiskie
    usbutils
    # niri 26.04+ provides X11 exclusively through xwayland-satellite
    # (on-demand). Without it there is no X server at all: DISPLAY stays empty
    # and X clients (Steam, etc.) fail with "Unable to open a connection to X".
    xwayland-satellite
  ];
}
