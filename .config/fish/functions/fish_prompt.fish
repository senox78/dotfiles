# .zshrc の PROMPT (remote_info / nix_shell_prompt / git_prompt / face_prompt)
# と同じ見た目に揃えている。
function fish_prompt
    set -l last_status $status
    set -l yellow (set_color yellow)
    set -l red (set_color red)
    set -l blue (set_color blue)
    set -l green (set_color green)
    set -l magenta (set_color magenta)
    set -l normal (set_color normal)

    # remote_info
    if test -n "$SSH_CONNECTION"
        echo -n -s $yellow (whoami) "@" (prompt_hostname) $normal " "
    end

    # path
    echo -n -s $blue (prompt_pwd) $normal " "

    # nix_shell_prompt
    if set -q IN_NIX_SHELL
        echo -n -s $magenta "[nix:$IN_NIX_SHELL]" $normal " "
    end

    # git_prompt: (branch|✔) / (branch|✘|↑1↓2)
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
        test -z "$branch"; and set branch (git rev-parse --short HEAD 2>/dev/null)

        set -l changed (git status --porcelain 2>/dev/null | count)

        set -l ahead 0
        set -l behind 0
        set -l upstream (git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
        if test -n "$upstream"
            set ahead (git rev-list "$upstream..HEAD" 2>/dev/null | count)
            set behind (git rev-list "HEAD..$upstream" 2>/dev/null | count)
        end

        set -l status_icon
        if test $changed -eq 0
            set status_icon "$green✔$normal"
        else
            set status_icon "$red✘$normal"
        end

        set -l remote_info ""
        if test $ahead -gt 0 -o $behind -gt 0
            test $ahead -gt 0; and set remote_info "$remote_info$yellow↑$ahead$normal"
            test $behind -gt 0; and set remote_info "$remote_info$yellow↓$behind$normal"
            set remote_info "|$remote_info"
        end

        echo -n -s "(" $green $branch $normal "|" $status_icon $remote_info ")"
    end

    # fish 独自: 5 秒を超えたコマンドの実行時間
    # 120 秒を超えたら分表示 (例: 2m30s)、120 分を超えたら時間表示 (例: 2h5m)
    if test -n "$CMD_DURATION"; and test $CMD_DURATION -gt 5000
        set -l secs (math -s0 $CMD_DURATION / 1000)
        set -l mins (math -s0 $secs / 60)
        if test $mins -gt 120
            set -l hours (math -s0 $mins / 60)
            set -l remmins (math -s0 $mins % 60)
            echo -n -s $yellow " (" $hours "h" $remmins "m)" $normal
        else if test $secs -gt 120
            set -l rem (math -s0 $secs % 60)
            echo -n -s $yellow " (" $mins "m" $rem "s)" $normal
        else
            echo -n -s $yellow " (" (math -s1 $CMD_DURATION / 1000) "s)" $normal
        end
    end

    echo

    # face_prompt
    if test $last_status -eq 0
        echo -n -s (set_color -o green) ":)" $normal " "
    else
        echo -n -s (set_color -o red) ":(" $normal " "
    end
end
