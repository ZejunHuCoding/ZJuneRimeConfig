-- 中↔英/数字 自动补空格（极简稳定版）
-- 位置：engine/filters 倒数第二个  - lua_filter@cn_en_spacer

local F = {}

local ASCII    = "[%a%d']+"       -- 英/数字“词”
local NONASCII = "[\128-\255]"    -- 粗判“中文/全角等”
local CHPUN    = "[、，。！？；：：“”‘’（）《》【】『』—…￥·]"  -- 常见中文标点

local function rtrim(s) return (s or ""):gsub("%s+$","") end
local function add_lead(s) return (s:match("^%s") and s) or (" "..s) end

function F.func(input, env)
  local prev = env and env.engine and env.engine.context
             and env.engine.context.commit_history
             and env.engine.context.commit_history:latest_text() or ""
  prev = rtrim(prev)  -- 覆盖“先敲空格又删掉”的场景

  for cand in input:iter() do
    local cur = cand.text

    if #prev > 0 then
      -- 英/数 -> 中（或其它非 ASCII）；若当前是中文标点则不加
      if prev:match(ASCII.."$") and cur:find(NONASCII) and not cur:match("^%s*"..CHPUN) then
        cand = cand:to_shadow_candidate("cn_en_spacer", add_lead(cur), cand.comment)

      -- 中(非标点结尾) -> 英/数
      elseif prev:find(NONASCII) and not prev:match(CHPUN.."$") and cur:match("^"..ASCII.."$") then
        cand = cand:to_shadow_candidate("cn_en_spacer", add_lead(cur), cand.comment)
      end
    end

    yield(cand)
  end
end

return F
