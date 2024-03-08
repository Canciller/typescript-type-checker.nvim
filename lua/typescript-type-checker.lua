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
  local tsc_command = "npx tsc --noEmit --pretty false"
  local issues_found = false -- Track whether any issues were found

  local on_event = function(_, data, event)
    if event == "stdout" or event == "stderr" then
      local qf_list = {}
      for _, line in ipairs(data) do
        if line ~= "" then -- Ignore empty lines
          local filename, lnum, col, err_type, err_code, message =
            line:match("([^%(%)]+)%((%d+),(%d+)%)%:%s*(%w+)%s*(TS%d+):%s*(.*)")
          if filename and lnum and col and message then
            issues_found = true -- Set flag to true if an issue is found
            local type = (err_type == "error" and "E") or (err_type == "warning" and "W") or ""
            local formatted_message = err_type .. " " .. err_code .. ": " .. message

            table.insert(qf_list, {
              filename = filename,
              lnum = tonumber(lnum),
              col = tonumber(col),
              text = formatted_message,
              type = type,
            })
          end
        end
      end

      if #qf_list > 0 then
        vim.fn.setqflist(qf_list, "r")
        vim.cmd("copen")
      end
    elseif event == "exit" then
      if not issues_found then
        -- Clear the quickfix list and close the quickfix window if no issues were found
        vim.fn.setqflist({}, "r")
        vim.cmd("cclose")
        vim.defer_fn(function()
          print("No TypeScript issues found")
        end, 0)
      else
        vim.defer_fn(function()
          print("TypeScript check complete")
        end, 0)
      end
    end
  end

  vim.fn.jobstart(tsc_command, {
    on_stdout = on_event,
    on_stderr = on_event,
    on_exit = on_event,
    stdout_buffered = true,
    stderr_buffered = true,
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
