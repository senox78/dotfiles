--!nonstrict

local hintId = "__hint__"

function onQuery(text)
    local input = noctalia.string.trim(text)

    if input == "" then
        launcher.setResults(text, {
            {
                id = hintId,
                title = "文字列を入力してください",
                subtitle = "例: /hello world",
                glyph = "message",
            },
        })
        return
    end

    local output = "hello " .. input

    launcher.setResults(text, {
        {
            id = output,
            title = output,
            subtitle = "選択するとクリップボードへコピーします",
            glyph = "copy",
            score = 100,
        },
    })
end

function onActivate(id)
    if id == hintId then
        return
    end

    local copied = noctalia.copyToClipboard(id, "text/plain")
    if not copied then
        noctalia.notifyError("Hello Prefix", "クリップボードへのコピーに失敗しました")
    end
end
