# Fedora移行手順・短縮版

**FedoraでOSと普段のアプリを管理し、Nixは開発用devShellだけに使う。**
通常のFedora Workstation（x86_64）向け。Home Managerと既存のFedora導入スクリプトは使わない。
コマンドはBashで実行する。実機での通し検証は未実施。細かい設定は[詳細版](./FEDORA-MIGRATION.md)を参照。

## 1. バックアップ → Fedora導入

- `~/dotfiles`を**未コミットの変更ごと**外部へ保存する。
- `org`、開発リポジトリ、写真・壁紙、ブラウザデータ、SSH/GPG鍵、キーリング、入力辞書、認証設定も保存する。
- **Immichは写真とDBをセットで保存する（下記7節）。ホームのバックアップだけでは足りない。**
- Fedora Workstationをインストール。ユーザー名は可能なら`rei`に揃える。
- GNOMEでネットワーク・音声を確認し、dotfilesを`~/dotfiles`へ復元する。

## 2. アプリを入れる

```bash
sudo dnf upgrade --refresh
sudo dnf install git curl fish direnv gnupg2 pinentry-gnome3 \
  neovim vim tmux ripgrep fd-find fzf jq eza bat gh difftastic \
  niri kitty waybar SwayNotificationCenter rofi swayidle swaylock \
  wl-clipboard cliphist brightnessctl playerctl udiskie \
  xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
  fcitx5 fcitx5-configtool fcitx5-mozc emacs
```

更新後に再起動する。見つからないパッケージは`dnf search 名前`で確認する。
ブラウザ・文書・動画アプリは必要なものだけDNF/Flatpakで追加。FFmpegは公式RPMなら`ffmpeg-free`。

## 3. dotfilesを配置する

既存設定を退避してリンクする。以下は同じBashで実行する。

```bash
mkdir -p ~/.config
backup="$HOME/config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
for name in fish git nvim vim kitty emacs rofi waybar swaync tmux; do
  if [ -e "$HOME/.config/$name" ] || [ -L "$HOME/.config/$name" ]; then
    mv "$HOME/.config/$name" "$backup/$name"
  fi
  ln -s "$HOME/dotfiles/.config/$name" "$HOME/.config/$name"
done
```

- **fish**: `config.fish`のグローバルな`CC/CXX/LD`、ROCm設定、`GTK_IM_MODULE/QT_IM_MODULE`指定を外す。NixのPATHとdirenv hookは残す。
- **シェル**: `command -v fish`が`/usr/bin/fish`なら、`sudo usermod --shell /usr/bin/fish "$USER"`。fish起動後に`fisher update`。
- **tmux**: `~/.tmux.conf`に`source-file ~/.config/tmux/.tmux.conf`を書く。以前のプラグインは別途導入。
- **Git**: 鍵を復元し、`~/.config/git-signing.conf`に`[user]`と`signingkey = 鍵のフィンガープリント`を書く。

## 4. niriを使える状態にする

既存の`~/.config/niri`があれば退避し、設定をコピーする。

```bash
mkdir -p ~/.config/niri
cp -i ~/dotfiles/.config/niri/config.kdl ~/.config/niri/config.kdl
niri validate -c ~/.config/niri/config.kdl
```

検証エラーになった新しい構文を調整する。未導入の`wlmstr`、`niri-scratchpad`、`wooz`、`emacs-scratch`を呼ぶキーは一旦無効化。Bibata未導入ならカーソルをAdwaitaにする。

niri設定のトップレベルへ追加する（`rei`は実際のユーザー名に変更）:

```kdl
spawn-at-startup "waybar" "-c" "/home/rei/.config/waybar/config.niri.jsonc" "-s" "/home/rei/.config/waybar/style.css"
spawn-at-startup "swaync"
spawn-at-startup "fcitx5"
spawn-at-startup "udiskie" "-a" "-t" "--notify"
spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"
spawn-at-startup "swayidle" "-w" "timeout" "600" "swaylock -f" "lock" "swaylock -f" "before-sleep" "swaylock -f"
```

既存の`environment`ブロックに`XMODIFIERS "@im=fcitx"`を追加する。
Polkit認証エージェントも導入・起動する（パスの確認方法は詳細版7節）。二重の自動起動は避ける。

GDMからniriにログインし、`fcitx5-configtool`でMozcを追加する。最初はMozcとswaylockを使い、Hazkey/hyprlockは後から戻す。
`swaylock -f`で解除できることを確認してから、サスペンド復帰を試す。

## 5. Nixを開発専用で導入する

Fedora上で、Nix未導入の場合のみ実行する。

```bash
curl --proto '=https' --tlsv1.2 -sSf -L \
  https://install.determinate.systems/nix -o /tmp/fedora-nix-install.sh
less /tmp/fedora-nix-install.sh
sh /tmp/fedora-nix-install.sh install
```

ログインし直し、`nix --version`を確認する。
各プロジェクトにdevShellを定義した`flake.nix`を置いて`nix develop`を使う。`flake.lock`もGit管理する。
雛形とdirenv連携は詳細版10節を参照。dotfilesルートの既存flakeにはdevShellがない。

## 6. 日常環境を戻して確認する

- **Emacs**: まず通常起動で設定を確認。daemonとscratchpadの復元は詳細版9節。
- **独自ツール・見た目**: `wlmstr`、`awww`、scratchpad、フォントなどを非Nix版で個別導入してから設定を戻す。
- **メニュー**: 既存スクリプトの`hyprctl`によるログアウトを`niri msg action quit`へ、ロックを当面`swaylock -f`へ変更する。
- **ノートPC**: keyd・蓋・指紋・省電力は詳細版11節。休止状態は新しいswap/resume設定を確認するまで有効化しない。
- **最終確認**: 再起動、日本語、音声、画面共有、ロック・復帰、Git署名、開発環境を試す。`systemctl --user --failed`も確認する。

OS更新は`sudo dnf upgrade --refresh`。開発環境の更新は各プロジェクトで`nix flake update`。

## 7. Immich（デスクトップ機）

現在はNixOSサービス。Fedoraでは[公式Docker Compose構成](https://docs.immich.app/install/docker-compose/)へ移す。

1. **OSを消す前に**稼働中のImmichのバージョンを記録し、アップロード・更新を止めてDBバックアップを取得。写真も同じ時点の状態で外部へ保存する。
2. 保存対象は`/run/media/rei/hdd/immich/`全体＋DBの論理バックアップ。現在のDB本体は`/run/media/rei/ssd/immich/postgresql/`だが、これを新コンテナへ直結して移行しない。
3. FedoraでHDD/SSDを固定マウントし、同じImmichバージョンのComposeを用意。写真はHDD、**新規DB領域**はSSDにする。元のデータディスクはフォーマットしない。
4. [公式復元手順](https://docs.immich.app/administration/backup-and-restore/)でDBと写真を復元。NixOS時のメディアパスとコンテナ内パスの違いも確認する（詳細版13節）。
5. 公開先は引き続きTailscale限定。Compose既定の`2283:2283`をそのまま使わない。写真・動画・アルバム・スマホからの接続と、再起動後の復帰を確認する。

移行とバージョンアップは分ける。復元できるまで旧DB・写真・バックアップを残す。
