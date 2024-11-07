local util = require("dapui.util")
local nio = require("nio")

---@param client dapui.DAPClient
return function(client)
  ---@class dapui.DAPClientLib
  local client_lib = {}

  local function open(frame)
    local win = nio.api.nvim_get_current_win()
    local source_win = util.select_source_win()
    if source_win and win ~= source_win then
      nio.api.nvim_set_current_win(source_win)
    end
    client.session._frame_set(frame)
  end

  ---@param frame dapui.types.StackFrame
  ---@param set_frame boolean Set the current frame of session to given frame
  function client_lib.jump_to_frame(frame, set_frame)
    local co = coroutine.running()
    if not co or co.is_main then
      nio.run(function()
        open(frame, set_frame)
      end)
    else
      open(frame, set_frame)
    end
  end

  ---@param variable dapui.types.Variable
  function client_lib.set_variable(container_ref, variable, value)
    local ok, err = pcall(function()
      if client.session.capabilities.supportsSetExpression and variable.evaluateName then
        local frame_id = client.session.current_frame and client.session.current_frame.id
        client.request.setExpression({
          expression = variable.evaluateName,
          value = value,
          frameId = frame_id,
        })
      elseif client.session.capabilities.supportsSetVariable and container_ref then
        client.request.setVariable({
          variablesReference = container_ref,
          name = variable.name,
          value = value,
        })
      else
        util.notify(
          "Debug server doesn't support setting " .. (variable.evaluateName or variable.name),
          vim.log.levels.WARN
        )
      end
    end)
    if not ok then
      util.notify(util.format_error(err))
    end
  end

  local stop_count = 0
  client.listen.stopped(function()
    stop_count = stop_count + 1
  end)
  client.listen.initialized(function()
    stop_count = 0
  end)

  ---@return integer: The number of times the debugger has stopped
  function client_lib.step_number()
    return stop_count
  end

  return client_lib
end
