-- 中↔英/数字 自动补空格（稳健精简版：多字节中文标点与CJK扩展兼容）
-- 放置：engine/filters 倒数第二个  - lua_filter@cn_en_spacer

local F = {}

-- ========= UTF-8 汉字判定（支持常用区 3 字节 + 扩展区 4 字节） =========
-- 常用 CJK：U+4E00–U+9FFF（UTF-8: E4–E9 80–BF 80–BF）
local function is_han3(bytes3)
  if not bytes3 or #bytes3 ~= 3 then return false end
  local b1, b2, b3 = bytes3:byte(1, 3)
  return (b1 >= 228 and b1 <= 233) and (b2 >= 128 and b2 <= 191) and (b3 >= 128 and b3 <= 191)
end

-- 扩展区（示例覆盖 U+20000–U+2FA1F）：UTF-8: F0 A0–AF 80–BF 80–BF
local function is_han4(bytes4)
  if not bytes4 or #bytes4 ~= 4 then return false end
  local b1, b2, b3, b4 = bytes4:byte(1, 4)
  return (b1 == 240) and (b2 >= 160 and b2 <= 175) and (b3 >= 128 and b3 <= 191) and (b4 >= 128 and b4 <= 191)
end

local function starts_with_han(s)
  if not s then return false end
  local first3 = s:sub(1, 3)
  if is_han3(first3) then return true end
  local first4 = s:sub(1, 4)
  if is_han4(first4) then return true end
  return false
end

local function ends_with_han(s)
  if not s then return false end
  local last3 = s:sub(-3)
  if is_han3(last3) then return true end
  local last4 = s:sub(-4)
  if is_han4(last4) then return true end
  return false
end

-- ========= 中文标点判定（多字节，不能用 [%…] 字节类） =========
-- 仅列常见全角中文标点；如需扩展，往表里加字符串即可。
local CH_PUNCTS = {
  "、","，","。","！","？","；","：","“","”","‘","’","（","）",
  "《","》","【","】","『","』","—","…","￥","·"
}

local function starts_with_chpunct(s)
  if not s then return false end
  for _, p in ipairs(CH_PUNCTS) do
    if s:sub(1, #p) == p then return true end
  end
  return false
end

local function ends_with_chpunct(s)
  if not s then return false end
  for _, p in ipairs(CH_PUNCTS) do
    if s:sub(-#p) == p then return true end
  end
  return false
end

-- ========= ASCII 判定与工具 =========
-- 英文/数字/撇号（单字节，Lua 模式即可）
local ASC_HEAD = "^[%a%d']"
local ASC_TAIL = "[%a%d']$"

local function rtrim(s) return (s or ""):gsub("%s+$","") end
local function add_lead(s) return (s and s:match("^%s")) and s or (" "..s) end

-- ========= 主过滤器 =========
function F.func(input, env)
  local ctx = env and env.engine and env.engine.context
  local prev = ctx and ctx.commit_history and ctx.commit_history:latest_text() or ""
  prev = rtrim(prev)

  for cand in input:iter() do
    local cur = cand.text
    if #prev > 0 and cur and #cur > 0 then
      -- 规则1：英/数 → 汉（且“当前”不以中文标点开头）
      if prev:match(ASC_TAIL) and starts_with_han(cur) and not starts_with_chpunct(cur:gsub("^%s+","")) then
        cand = cand:to_shadow_candidate("cn_en_spacer", add_lead(cur), cand.comment)

      -- 规则2：汉 → 英/数（且“上一个”不以中文标点结尾）
      elseif ends_with_han(prev) and not ends_with_chpunct(prev) and cur:match(ASC_HEAD) then
        cand = cand:to_shadow_candidate("cn_en_spacer", add_lead(cur), cand.comment)
      end
    end
    yield(cand)
  end
end

return F
