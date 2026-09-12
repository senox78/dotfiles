# Emacs 設定の安全な自動反映（保留）

`init.el` の編集を通常利用中の Emacs に直接反映せず、検証を通った設定だけを main daemon へ昇格する案。

## 構成

- `emacs-main.service`: 日常利用用。最後に検証成功した `init.el` を読む。
- `emacs-develop.service`: 編集中の `init.el` を読む検証用 daemon。main と server socket、state、cache を分離する。
- `emacs-config-promote.path`: 開発版 `init.el` の保存を監視する。
- `emacs-config-promote.service`: 構文・batch load・develop daemon の起動を確認し、成功時だけ main 用の設定を更新する。

```text
dotfiles/.config/emacs/init.el        開発版
  │
  ├─ 検証失敗 → main は現行の正常設定のまま
  │
  └─ 検証成功 → ~/.local/state/emacs-main/init.el を更新 → main へ反映
```

## 検証

最初の検査は `emacs --batch -Q --load <init.el>` を使う。さらに develop daemon を別名で起動し、`emacsclient -s <develop-name> --eval ...` で応答を確認する。

## 注意点

- main を再起動すると、開いているフレームと未保存バッファを失う可能性がある。
- そのため昇格と main の再起動は分け、再起動は手動操作にするか、未保存バッファがないときだけ実行する。
- `systemd.path` には短い遅延を設け、保存途中の `init.el` を検証しない。
