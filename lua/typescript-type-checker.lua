---@class Config
---@field command string
local config = {
  command = "Typecheck",
}

---@class TypescriptTypeChecker
local M = {}

---@type Config
M.config = config

M.run = function()
  local success, pcall_result = pcall(require, "fidget.progress")

  local progress

  if success then
    progress = pcall_result
  end

  local tsc_command = "npx tsc --noEmit --pretty false"

  local handle = progress
    and progress.handle.create({
      title = "Type-checking",
      message = "Running TypeScript type-checker...",
      lsp_client = { name = "typescript-type-checker" },
    })

  local on_exit = function()
    if handle then
      handle:finish()
    end
  end

  local on_stdout = function(_, data)
    local qf_list = {}

    for _, line in ipairs(data) do
      if line ~= "" then -- Ignore empty lines
        -- Match the filename, line number, column number, and the full message
        local pattern = "(.-)%((%d+),(%d+)%)%:%s*(.*)"
        local filename, lnum, col, full_message = line:match(pattern)

        if filename and lnum and col and full_message then
          table.insert(qf_list, {
            filename = filename,
            lnum = tonumber(lnum),
            col = tonumber(col),
            text = full_message,
            type = "E",
          })
        end
      end
    end

    vim.fn.setqflist(qf_list, "r")

    if #qf_list > 0 then
      vim.cmd("copen")
      vim.notify("Found " .. #qf_list .. " TypeScript errors", vim.log.levels.ERROR)
    else
      vim.cmd("cclose")
      vim.notify("No TypeScript errors found", vim.log.levels.INFO)
    end
  end

  vim.fn.jobstart(tsc_command, {
    on_stdout = on_stdout,
    on_exit = on_exit,
    stdout_buffered = true,
  })
end

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})

  vim.api.nvim_create_user_command(M.config.command, function()
    M.run()
  end, {
    force = true,
  })
end

return M
