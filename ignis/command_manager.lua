local gobject = require("ignis.gobject")
local exceptions = require("ignis.exceptions")

local CommandManager = gobject.class(gobject.Object, {
    init = function(self)
        self._commands = {}
    end,

    get_command = function(self, command_name)
        local command = self._commands[command_name]
        if command then
            return command
        else
            error(exceptions.CommandNotFoundError(command_name))
        end
    end,

    add_command = function(self, command_name, callback)
        if self._commands[command_name] then
            error(exceptions.CommandAddedError(command_name))
        end
        self._commands[command_name] = callback
    end,

    command = function(self, name)
        return function(callback)
            local actual_name = name or tostring(callback)
            self:add_command(actual_name, callback)
            return callback
        end
    end,

    remove_command = function(self, command_name)
        if not self._commands[command_name] then
            error(exceptions.CommandNotFoundError(command_name))
        end
        self._commands[command_name] = nil
    end,

    run_command = function(self, command_name, ...)
        local command = self:get_command(command_name)
        return command(...)
    end,

    list_command_names = function(self)
        local names = {}
        for name, _ in pairs(self._commands) do
            table.insert(names, name)
        end
        return names
    end
})

local default_instance = nil

function CommandManager.get_default()
    if not default_instance then
        default_instance = CommandManager()
    end
    return default_instance
end

return CommandManager
