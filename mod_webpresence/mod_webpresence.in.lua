local jid_split = require "util.jid".prepped_split;

if not require_resource then
	function require_resource(name)
		local f = io.open((config.get("*", "core", "presence_icons") or "")..name);
		if f then
			return f:read("*a");
		end
		module:log("warn", "Failed to open image file %s", (config.get("*", "core", "presence_icons") or "")..name);
		return "";
	end
end

local response_404 = { status = "404 Not Found", body = "<h1>Page Not Found</h1>Sorry, we couldn't find what you were looking for :(" };

local statuses = { "online", "away", "xa", "dnd", "chat", "offline" };

for _, status in ipairs(statuses) do
	statuses[status] = { status = "200 OK", headers = { ["Content-Type"] = "image/png" }, 
		body = require_resource("icons/status_"..status..".png") };
end

local function handle_request(method, body, request)
	local jid = request.url.path:match("[^/]+$");
	if jid then
		local user, host = jid_split(jid);
		if host and not user then
			user, host = host, request.headers.host;
			if host then host = host:gsub(":%d+$", ""); end
		end
		if user and host then
			local user_sessions = hosts[host] and hosts[host].sessions[user];
			if user_sessions then
				local status = user_sessions.top_resources[1];
				if status and status.presence then
					status = status.presence:child_with_name("show");
					if not status then
						status = "online";
					else
						status = status:get_text();
					end
					return statuses[status];
				end
			end
		end
	end
	return statuses.offline;
end

local ports = config.get(module.host, "core", "http_ports") or { 5280 };
require "net.httpserver".new_from_config(ports, "status", handle_request);
