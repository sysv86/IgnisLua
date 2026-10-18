local ok_native, native = pcall(require, "ignis.native")

local Gtk4Override = {}

function Gtk4Override._post_instantiate(gtk_ns)
    if gtk_ns.init_check then
        pcall(gtk_ns.init_check)
    elseif ok_native and native and native.ensure_gtk4 then
        pcall(native.ensure_gtk4)
    end

    local Widget = gtk_ns.Widget
    if Widget and Widget._method then
        if not Widget._method.get_children then
            Widget._method.get_children = function(self)
                local children = {}
                if not self.get_first_child then
                    return children
                end
                local child = self:get_first_child()
                while child do
                    table.insert(children, child)
                    child = child.get_next_sibling and child:get_next_sibling() or nil
                end
                return children
            end
        end

        if not Widget._method.clear_children then
            Widget._method.clear_children = function(self)
                if not self.get_first_child then return end
                local child = self:get_first_child()
                while child do
                    local next_child = child.get_next_sibling and child:get_next_sibling() or nil
                    if self.remove then
                        pcall(self.remove, self, child)
                    elseif child.unparent then
                        pcall(child.unparent, child)
                    end
                    child = next_child
                end
            end
        end
    end

    local CssProvider = gtk_ns.CssProvider
    if CssProvider and CssProvider._method then
        CssProvider._method.load_css = function(self, css_data)
            css_data = tostring(css_data or "")
            if ok_native and native and native.css_load_from_string then
                if native.css_load_from_string(self, css_data) then
                    return
                end
            end
            if self.load_from_string then
                local ok = pcall(self.load_from_string, self, css_data)
                if ok then return end
            end
            if self.load_from_data then
                local ok = pcall(self.load_from_data, self, css_data, #css_data)
                if ok then return end
                pcall(self.load_from_data, self, css_data)
            end
        end
    end

    local TextBuffer = gtk_ns.TextBuffer
    if TextBuffer and TextBuffer._method and TextBuffer._method.set_text then
        local raw_set_text = TextBuffer._method.set_text
        TextBuffer._method.set_text = function(self, text, len)
            return raw_set_text(self, tostring(text or ""), len or -1)
        end
    end
end

return Gtk4Override
