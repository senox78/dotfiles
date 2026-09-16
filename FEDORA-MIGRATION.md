# Fedoraへの手動移行手順

作成: 2026-09-16。現在のdotfilesを調査した移行用の手順書。Fedora実機での通し検証は未実施。

## 1. 今回の構成

Fedora Workstation（通常のDNF版、x86_64）を新規インストールし、GNOME/GDMを残したままniriを追加する想定。Silverblue/KinoiteなどのAtomic Desktop用の手順ではない。

| 対象 | 管理方法 |
| --- | --- |
| OS、ドライバ、音声、日本語入力、niri | FedoraのRPM / DNF |
| 日常のエディタ、CLI | DNF。未収録ツールは個別導入 |
| GUIアプリ | DNF、必要に応じてFlatpak |
| dotfiles | このリポジトリから手動でsymlink |
| ユーザーサービス | `~/.config/systemd/user/`に手動配置 |
| 開発ツールチェーン | プロジェクトごとのNix devShell |

Home Managerは導入しない。`nix profile install`で日常アプリを管理しない。既存の`flake.nix`、`home/`、`hosts/`、`modules/`は旧環境の仕様書として残す。

**既存の`script/fedora-home-manager-bootstrap.sh`は実行しない。** Home Managerを適用するため今回の方針と異なる。`fedora-desktop-packages.sh`もそのまま実行せず、下記の手順で導入する。

以下のシェルブロックは、特記しない限り **Bashで実行** する。fishに切り替えた後は最初に`bash`を起動する。設定ファイルのブロックは指定先にエディタで保存する。

## 2. NixOSを消す前に保存するもの

外部ディスクなどへ保存し、実際に読み戻せることを確認する。

- `~/dotfiles`全体（未コミット・ステージ済みの変更も含む）。cloneだけでは現在の作業内容は戻らない。
- `~/org`、`~/Develop`、`~/ghq`、Documents、Pictures、壁紙、必要なダウンロード。
- `~/.ssh`、`~/.gnupg`、`~/.local/share/keyrings`、ブラウザのプロファイル。
- `~/.config/fcitx5`、入力辞書、`~/.local/share/fonts`、独自アプリのデータ。
- `~/.local/bin`、`~/my_apps`、必要なら`~/.cargo/bin`。Nixストアを指すsymlinkはコピーだけでは動かない。
- `~/.env`や各ツールの認証設定。これらはGitへ追加せず、保護したバックアップに保存する。
- **デスクトップ機のImmichはホーム外にある。13節に従い、写真とDBをセットで退避してからOSを入れ替える。**

現状の記録例（NixOS上）:

```bash
mkdir -p ~/migration-notes
git -C ~/dotfiles status --short > ~/migration-notes/dotfiles-status.txt
lsblk -f > ~/migration-notes/disks.txt
systemctl --user list-unit-files > ~/migration-notes/user-units.txt
fc-list : family | sort -u > ~/migration-notes/fonts.txt
```

`migration-notes`も外部へ保存する。旧`hardware-configuration.nix`のUUIDや`crypttab`をFedoraへ転記しない。既存ホームを再利用する場合も、Nix/Home Managerへのsymlinkを新環境の設定としてそのまま使わない。

## 3. Fedoraの初期セットアップ

Workstationをインストールし、ユーザー名は可能なら`rei`、ホームは`/home/rei`に揃える。まずGNOMEでネットワーク・音声・画面表示が動くことを確認する。

```bash
sudo dnf upgrade --refresh
sudo dnf install git curl fish direnv gnupg2 pinentry-gnome3 \
  neovim vim tmux ripgrep fd-find fzf jq eza bat \
  gh difftastic btop htop unzip zip wget python3
sudo timedatectl set-timezone Asia/Tokyo
```

更新後に再起動する。dotfilesはバックアップから`~/dotfiles`へ復元する。バックアップが不要な場合だけcloneする:

```bash
git clone https://github.com/senox78/dotfiles.git ~/dotfiles
```

パッケージ名や提供状況はFedoraのリリースで変わる。見つからないものは`dnf search 名前`、`dnf info 名前`で確認し、その機能を後回しにする。旧スクリプトの一覧が全て標準リポジトリにあるとは仮定しない。

## 4. デスクトップ関連を導入する

```bash
sudo dnf install niri kitty waybar SwayNotificationCenter rofi \
  swayidle swaylock wl-clipboard cliphist brightnessctl playerctl \
  udiskie xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk
sudo dnf install emacs firefox nautilus loupe gnome-text-editor \
  gnome-calendar thunderbird libreoffice inkscape mpv ffmpeg-free
sudo dnf install fcitx5 fcitx5-configtool fcitx5-mozc
```

`rofi`はWayland対応版か確認する。古い版の場合は`dnf info rofi-wayland`で別パッケージを確認する。`ffmpeg-free`がFedora公式の名前であり、完全版`ffmpeg`や追加コーデックが必要な場合はRPM Fusionの導入を別途検討する。

参考: [Fedora niri](https://packages.fedoraproject.org/pkgs/niri/niri/)、[SwayNotificationCenter](https://packages.fedoraproject.org/pkgs/SwayNotificationCenter/SwayNotificationCenter/)、[ffmpeg-free](https://packages.fedoraproject.org/pkgs/ffmpeg/ffmpeg-free/)。

## 5. 設定ファイルを配置する

最初はアプリ本体が入ったものだけリンクする。次は既存設定をバックアップしてリンクする手動コマンド。**同じBashでまとめて実行する。**

```bash
mkdir -p ~/.config
config_backup="$HOME/config-before-fedora-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$config_backup"
for name in fish git nvim vim kitty emacs rofi waybar swaync tmux; do
  if [ -e "$HOME/.config/$name" ] || [ -L "$HOME/.config/$name" ]; then
    mv "$HOME/.config/$name" "$config_backup/$name"
  fi
  ln -s "$HOME/dotfiles/.config/$name" "$HOME/.config/$name"
done
```

niriは互換性調整するため、最初はコピーにする（次節）。`hypr`、`wlmstr`、`yazi`などは対応ツールを入れてから同様に配置する。リポジトリに実体のない`.config/nix`等を旧Home Manager設定から機械的にリンクしない。

### fish

既存`config.fish`をエディタで調整する。リンク先の変更はdotfilesにも反映される。

- `CC=clang`、`CXX=clang++`、`LD=lld`のグローバル指定を削除。必要なプロジェクトのdevShellで指定する。
- ROCm関連の`LD_LIBRARY_PATH`、`ROCM_PATH`、`HSA_OVERRIDE_GFX_VERSION`は、FedoraでROCmを導入するまで外す。
- `GTK_IM_MODULE`と`QT_IM_MODULE`の一律指定を外す。日本語入力はniri側で設定し、必要なアプリだけ追加設定する。
- `rebuild`、`nbuild`はNixOS/Home Manager向けなので使わない。OS更新は`sudo dnf upgrade --refresh`。
- `ghq`、`hx`、`herdr`、AIツール等の略語は対応するアプリを個別導入するまで使えない。
- NixのPATH設定と`direnv hook fish | source`は残す。`fish_add_path -g $HOME/.local/bin`を追加する。
- 初回のfisher導入には通信が必要。fish起動後に`fisher update`を実行して`fish_plugins`のテーマも導入する。テーマ未導入時の警告はこの後で確認する。

```bash
command -v fish
sudo usermod --shell /usr/bin/fish "$USER"
```

`command -v fish`が`/usr/bin/fish`であることを確認してから変更。以降、一度ログアウトする。

### tmux

Home Managerが生成していた入口はリポジトリにない。`~/.tmux.conf`を次の内容で作る（既存ファイルがあれば先に退避）:

```tmux
source-file ~/.config/tmux/.tmux.conf
```

これで基本設定を使える。以前のsensible、yank、battery、cpu、resurrect、continuum、rose-pineは自動では入らない。必要なら後から各プラグインまたはTPMを導入する。

### Git署名

復元した鍵を`gpg --list-secret-keys --keyid-format long`で確認し、`~/.config/git-signing.conf`を作る:

```gitconfig
[user]
    signingkey = 復元した鍵のフィンガープリント
```

既存Git設定はコミット・タグ署名を有効にしている。鍵の設定がないとコミットに失敗する。テスト用リポジトリで署名を確認する。GitHub連携は必要なら`gh auth login`で設定する。

## 6. niriの設定と初回ログイン

`~/.config/niri`の既存設定を退避してから配置する:

```bash
mkdir -p ~/.config/niri
cp -i ~/dotfiles/.config/niri/config.kdl ~/.config/niri/config.kdl
niri --version
niri validate -c ~/.config/niri/config.kdl
```

コピー元には`blur`、`background-effect`、`place-within-backdrop`等の新しい構文がある。検証に失敗したら、指摘された設定をローカルコピーで外し、再検証する。バージョン番号だけで互換と判断しない。

初期段階では以下も変更する:

- `niri-scratchpad`、`emacs-scratch`、`wooz`、`wlmstr`を呼ぶキーは、ツールを入れるまでコメントアウト。
- `script/logout.py`と`script/cmd_p.py`のLogoutはHyprland専用。niriでは`niri msg action quit`へ変更してから使用する。暫定的には設定済みの`Super+M`で終了できる。
- Bibataカーソル未導入なら`cursor`と`environment`のカーソル名を`Adwaita`にする。
- `qt6ct`未導入なら`QT_QPA_PLATFORMTHEME "qt6ct"`を外す。
- 外部モニターはログイン後に`niri msg outputs`で名前とモードを確認して調整。

GDMでログアウトし、セッション選択からniriに入る。niriのセッション起動はGDMまたは`niri-session`を使う。[niri公式の起動手順](https://github.com/niri-wm/niri/wiki/Getting-Started)。

最初は`Super+T`でKitty、`Super+D`でランチャーが開けばよい。起動できなければGDMからGNOMEへ戻って設定を直す。

## 7. バー・通知・ロック等を起動する

最初の手動移行では、niriの`spawn-at-startup`で起動する。動作確認後にsystemd user unitへ移してもよい。両方に登録すると二重起動するので片方だけ使う。

`~/.config/niri/config.kdl`のトップレベルへ追加:

```kdl
spawn-at-startup "waybar" "-c" "/home/rei/.config/waybar/config.niri.jsonc" "-s" "/home/rei/.config/waybar/style.css"
spawn-at-startup "swaync"
spawn-at-startup "udiskie" "-a" "-t" "--notify"
spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"
spawn-at-startup "swayidle" "-w" "timeout" "600" "swaylock -f -c f1eee5" "lock" "swaylock -f -c f1eee5" "before-sleep" "swaylock -f -c f1eee5"
```

ユーザー名が異なる場合は上の`/home/rei`を書き換える。GNOMEセッションの中からこれらを同時に起動せず、niriに入り直して確認する。

ロックは初期段階ではFedora提供のswaylockを使う。既存メニューの`hyprlock`も当面`swaylock -f`へ変更する。まず手動で`swaylock -f`を実行し、パスワードで解除できることを確認。その後`loginctl lock-session`、サスペンド復帰を試す。上の設定は現在の「AC時はロックしない」挙動を再現せず、10分の無操作で常にロックする。

hyprlockを戻す場合は、対応RPMと`/etc/pam.d/hyprlock`の有無、既存設定の構文互換性を確認する。バイナリを置くだけでPAM認証まで設定されたとは扱わない。

Polkit認証エージェントも必要。例えば`dnf info polkit-gnome`で提供を確認し、導入後`rpm -ql polkit-gnome`で`polkit-gnome-authentication-agent-1`の実際のパスを調べる。その絶対パスを`spawn-at-startup`に追加する。パッケージ付属サービスが既に起動していれば追加しない。

音声・ポータルはWorkstation側の仕組みを利用し、確認する:

```bash
wpctl status
systemctl --user status pipewire wireplumber xdg-desktop-portal
systemctl --user --failed
```

画面共有はブラウザから実際に試す。[niriの周辺ソフトウェア](https://github.com/niri-wm/niri/wiki/Important-Software)も参照。

## 8. 日本語入力

最初はFedoraにあるFcitx5＋Mozcで動作確認する。**Hazkeyの完全再現は後段の別作業**。既存の`nix-hazkey` NixOSモジュールはFedoraへ適用できない。

niri設定の既存`environment`ブロック内に追加:

```kdl
XMODIFIERS "@im=fcitx"
```

トップレベルに追加:

```kdl
spawn-at-startup "fcitx5"
```

別の自動起動経路がある場合は一方だけ残す。niriへログインし直し、`fcitx5-configtool`でMozcを追加、入力切替キーを設定する。まずGTKアプリで変換を確認し、次にKitty、Emacs、ブラウザを試す。

Wayland対応GTKでは`GTK_IM_MODULE`を一律に設定しない。QtやX11アプリで入力できない場合は、そのアプリだけ`QT_IM_MODULE=fcitx`等を設定し、対応するFcitx5連携パッケージを確認する。[Fcitx公式のWayland設定](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland)。

## 9. Emacsのdaemonを戻す

まず`/usr/bin/emacs --no-init-file --load ~/dotfiles/.config/emacs/init.el`で設定を読み込めるか確認する。初回はELPA/MELPAからのパッケージ取得が発生する。旧環境のNix製tree-sitter文法やLSPサーバーは自動移行されない。

`mkdir -p ~/.config/systemd/user ~/.local/bin`を実行し、`~/.config/systemd/user/emacs.service`を作る:

```ini
[Unit]
Description=Emacs daemon
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/emacs --fg-daemon --no-init-file --load %h/dotfiles/.config/emacs/init.el
Restart=on-failure

[Install]
WantedBy=graphical-session.target
```

Fedora付属のEmacsサービスが既に動いている場合は、停止してから上のサービスへ切り替える。niriセッション内で:

```bash
systemctl --user daemon-reload
systemctl --user enable --now emacs.service
emacsclient -c ~/org
```

`~/.local/bin/emacs-scratch`を作る:

```sh
#!/bin/sh
exec /usr/bin/emacsclient --create-frame --frame-parameters='((title . "Scratchpad Emacs"))' "$@"
```

`chmod +x ~/.local/bin/emacs-scratch`で実行可能にする。niriの`Super+E`は`emacs $HOME/org`から`emacsclient -c $HOME/org`へ変更する。デスクトップ起動にもdaemonを使いたければ、別途ユーザー用`.desktop`エントリを作る。

常駐EmacsはプロジェクトのdevShell環境を自動継承しない。初期運用ではdevShell内から別のEmacsプロセスを起動するか、Emacs側にdirenv連携を導入する。`emacsclient`をdevShellから呼ぶだけでは既存daemonのPATHは変わらない。

## 10. NixはdevShell用途だけ導入する

Fedora上で実行する。既にNixがある場合は再インストールしない。

```bash
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix -o /tmp/fedora-nix-install.sh
less /tmp/fedora-nix-install.sh
sh /tmp/fedora-nix-install.sh install
```

インストーラーの案内に従い、ログインし直して`nix --version`と`nix flake --help`を確認する。[公式インストール案内](https://determinate.systems/install/)。

開発対象のプロジェクトに、例えば以下の`flake.nix`を置く（既存flakeがある場合は上書きしない）:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [ clang lld pkg-config ];
      };
    };
}
```

そのプロジェクト内で:

```bash
git add flake.nix
nix flake lock
nix develop
```

必要なRust/Node/Go/LSP/フォーマッタ等をプロジェクトごとの`packages`に足す。`flake.nix`と`flake.lock`をコミットする。dotfilesルートの既存flakeはNixOS/Home Manager用で、devShell用ではない。

direnvを使う場合、プロジェクトの`.envrc`に`use nix`と書き、同じディレクトリに以下の`shell.nix`を置く。これで追加のnix-direnv導入なしに、direnv標準の`use nix`から同じflakeのdevShellを読み込める:

```nix
(builtins.getFlake (toString ./.)).devShells.x86_64-linux.default
```

```bash
git add shell.nix .envrc
direnv allow
```

fishのhookは既存設定にある。Bashでも使う場合は`~/.bashrc`へ`eval "$(direnv hook bash)"`を追加する。[direnvのシェル設定](https://direnv.net/docs/hook.html)。初期段階では明示的な`nix develop`だけでもよい。後からnix-direnvを導入する場合は公式手順に従い、`.envrc`を`use flake`へ変更する。

## 11. 必要に応じて戻す機能

| 機能 | 手動移行の方法・確認点 |
| --- | --- |
| フォント | Monaspace、Nerd Fonts、Noto CJKをRPMまたは公式配布から導入。ユーザーフォントは`~/.local/share/fonts/`へ置き`fc-cache -f`。`fc-match 'Monaspace Radon'`で確認 |
| Bibata | テーマをRPMまたは公式配布から導入後、niriのカーソル名を戻す |
| wlmstr / awww | 両方の非Nix版を導入。`awww-daemon`起動後に`wlmstr next seq`を手動確認してから壁紙キーを戻す |
| niri-scratchpad / niri-float-sticky / wooz | `flake.nix`記載の上流から対応版を導入し、バージョン・取得元を記録。`~/.local/bin`等へ置き、コマンドが動いてからキーや自動起動を戻す |
| ghq / yazi / lazygit / helix | `dnf info`で提供確認。なければ上流の配布方法で導入。Nixのグローバルprofileへ逃がさない |
| Hazkey | 上流の非Nixインストール手順でFcitx5アドオン・バックエンド・辞書を導入。Mozcが動く状態を残して切替を確認 |
| Noctalia | 今回はWaybar＋SwayNCを使用。導入する場合はそれらの自動起動を止めてから切り替える |
| Tailscale | `dnf info tailscale`で提供確認し導入。なければ公式Fedoraリポジトリの案内に従う。`sudo systemctl enable --now tailscaled`、`sudo tailscale up`で接続 |
| Flatpakアプリ | GNOME Softwareで必要な提供元を有効化し、Spotify/Discord等を個別導入。Flatpakのapp-idに合わせniriのルールと起動コマンドを確認 |
| 自動処理 | `cycle_wallpaper`、`cliphist-clean`、`org-git-sync`はHome Managerを使わないと登録されない。初期は手動。必要なものだけ後からuser unit/timerを作る |

非Nix版のビルド手順・パッケージ名は上流ごとに異なるため、ここでは動作未確認のビルドコマンドを固定しない。`flake.nix`のinput URLから取得元を辿る。インストール済みでも`/nix/store`を参照する実行ファイルなら今回の用途分離にはならない。

### マシン固有の設定

- **keyd**: パッケージを導入後、`/etc/keyd/default.conf`へ下記を保存し、`sudo systemctl enable --now keyd`で適用する。これは現在のThinkPad用設定。デスクトップは`modules/desktop.nix`の別設定を参照する。

```ini
[ids]
*
-320f:5055

[main]
leftcontrol = leftalt
leftalt = leftcontrol
rightcontrol = rightalt
rightalt = rightcontrol
```

- **蓋を閉じたとき**: ThinkPadと同じ挙動にする場合、`sudo mkdir -p /etc/systemd/logind.conf.d`の後、`sudoedit /etc/systemd/logind.conf.d/60-lid.conf`で下記を保存して再起動する。作業中にlogindを再起動しない。

```ini
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=suspend
```

- **省電力**: 最初はFedora既定の電源管理を利用する。TLPを戻す場合は現在動いている電源管理サービスを確認して競合を解消する。Waybarの`tlp-waybar-status.sh`はTLP依存なので、それまでは該当モジュールを外す。
- **休止状態**: 最初はsuspendだけ使う。旧設定の自動hibernateは移植しない。新環境のディスク上のswap・暗号化・resume設定と復帰を検証してから有効化する。旧ThinkPad設定にはswap不足の記録もある。
- **指紋認証**: GNOME設定で登録できるか確認。sudo等への適用はFedoraのauthselect経由で行い、NixOSのPAM設定をコピーしない。
- **仮想環境・SSHサーバー**: 必要な場合だけFedora側でlibvirt/KVM、sshdを導入・有効化する。既存グループ名・サービス名・firewall設定はそのまま移せると仮定しない。
- **Bluetooth/udev**: 特定USBポートを無効化する旧ルールは初期移行では持ち込まない。問題が再現した場合にそのマシンのデバイスを調べて設定する。

## 12. 移行完了の確認

- 再起動してGDMからniriへ入り、Kitty・ランチャー・バー・通知が起動する。
- 日本語の入力・変換、音声、マイク、Bluetooth、画面共有が使える。
- 手動ロックとsuspend復帰で認証できる。ノートはAC/バッテリー/外部モニター接続時の蓋の挙動も確認する。
- Git署名とSSH接続が使える。EmacsのOrgファイルと必要なブラウザデータが戻っている。
- プロジェクト内で`nix develop`が動き、必要なビルド・LSPを使える。
- `systemctl --user --failed`を確認し、使わない旧サービスを残していない。

環境に残ったNixOS依存の調査:

```bash
rg -n '/run/current-system|/nix/store|nixos-rebuild|home-manager|hyprctl' \
  ~/dotfiles/.config ~/dotfiles/script
```

検索結果には旧環境用に残すものもある。削除を一括実行せず、Fedoraで実際に使う設定・キー・サービスから参照を外す。

設定で困ったらGNOMEへ戻る。リンクしたアプリの設定を戻す場合は、対象がsymlinkであることを`ls -ld`で確認し、`unlink ~/.config/対象`の後、5節で保存した設定を戻す。移行が安定するまで元データのバックアップを残す。

## 13. Immichの移行（デスクトップ機）

`hosts/desktop/configuration.nix`の設定は以下。実際の稼働バージョン・DB内容はまだ確認していない。

| 対象               | 現在の設定 |
| --- | --- |
| 実行方法           | NixOSの`services.immich` |
| 写真・生成メディア | `/run/media/rei/hdd/immich/` |
| PostgreSQL本体     | `/run/media/rei/ssd/immich/postgresql/` |
| 公開範囲           | TCP 2283、Tailscaleインターフェイスのみ許可 |

Fedoraでは[公式Docker Compose構成](https://docs.immich.app/install/docker-compose/)を使う。NixはImmichの管理には使わない。

### OS入れ替え前

1. Immich管理画面で稼働バージョンを記録する。PostgreSQLのバージョン・拡張機能、外部ライブラリの有無も控える。
2. スマホ等のアップロードとメディアを変更するジョブを止め、管理画面からDBバックアップを作成する。完了とファイルの存在を確認する。画面から作成できない版では、その版の公式手順に従ってPostgreSQLの論理ダンプを取得する。
3. バックアップ完了後、Immichサービスを停止してメディアへの書き込みを止める。`/run/media/rei/hdd/immich/`全体とDBバックアップを別ディスクへコピーする。外部ライブラリを使っている場合はその実体も保存する。
4. DB本体ディレクトリだけのコピーを復元手段にしない。保険として物理コピーを残すならPostgreSQL停止後に取得し、論理バックアップとは別に保管する。

DBバックアップには写真・動画は含まれず、写真だけでもアルバム等を復元できない。[公式バックアップ手順](https://docs.immich.app/administration/backup-and-restore/)。

### Fedoraで復元

1. データ用HDD/SSDをフォーマットせず保持する。`lsblk -f`で実機のUUIDを確認し、固定マウントを設定する。サービス起動前に両方のマウントが完了する依存関係も設定する。
2. Docker EngineとComposeプラグインを導入し、`docker compose version`を確認する。元と同じImmichリリースのComposeファイル・`.env`を取得し、`IMMICH_VERSION`を固定する。最初から最新版への更新を兼ねない。
3. `.env`の`UPLOAD_LOCATION`をHDD上の復元先へ、`DB_DATA_LOCATION`をSSD上の**新しい空ディレクトリ**へ設定する。旧PostgreSQLディレクトリは指定しない。所有権とSELinuxのアクセス許可はコンテナ向けに確認する。
4. **DB内のメディアパスを確認する。** ホスト側の`UPLOAD_LOCATION`変更だけではDB内パスは書き換わらない。NixOSの絶対パスとComposeのコンテナ内パスが異なる場合、該当バージョンが提供する移行手段か、元のパスを維持するコンテナ設定を確認してから起動する。外部ライブラリのコンテナ内パスも揃える。
5. 該当バージョンの[復元手順](https://docs.immich.app/administration/backup-and-restore/)で写真とDBを復元する。現行版には初回画面からの復元があるが、旧版はDBだけ起動して復元する手順になる場合がある。v2.5.0前後で手順が変わるため、版を合わせて参照する。
6. Composeのポート設定も変更する。既定の`2283:2283`は全インターフェイスに公開するため、まず`127.0.0.1:2283:2283`で復元確認し、Tailscale Serve経由などでtailnet限定のアクセスを用意する。Dockerの公開ポートをfirewalldの設定だけで制限できるとは仮定しない。
7. 元写真の表示・ダウンロード、動画、アルバム、ユーザー、スマホの接続先を確認する。再起動後のディスクマウント・コンテナ復帰と、LAN側に意図せず公開されていないことも確認する。

この移行はデータの復元検証が必要。旧DB・写真・外部バックアップは、復元成功と新環境のバックアップ取得を確認するまで残す。
