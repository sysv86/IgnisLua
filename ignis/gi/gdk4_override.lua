local GdkOverride = {}

function GdkOverride._post_instantiate(gdk_ns)
    local ok_pb, GdkPixbuf = pcall(require, "lgi.GdkPixbuf")
    if not ok_pb then
        local ok_lgi, lgi = pcall(require, "lgi")
        if ok_lgi and lgi and lgi.require then
            ok_pb, GdkPixbuf = pcall(lgi.require, "GdkPixbuf", "2.0")
        end
    end
    if ok_pb and GdkPixbuf then
        gdk_ns.Pixbuf = GdkPixbuf.Pixbuf
    end

    if gdk_ns.Display and gdk_ns.Display._method then
        gdk_ns.Display._method.get_monitors_list = function(display)
            local list = {}
            local model = display:get_monitors()
            if not model then return list end
            local n = model:get_n_items() or 0
            for i = 0, n - 1 do
                local item = model:get_item(i)
                if item then
                    table.insert(list, item)
                end
            end
            return list
        end
    end
end

return GdkOverride
