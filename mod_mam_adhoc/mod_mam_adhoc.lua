module:depends"adhoc";
local dataforms_new = require "util.dataforms".new;
local dm_load = require "util.datamanager".load;
local dm_store = require "util.datamanager".store;
local jid_split = require "util.jid".split;
local t_insert = table.insert;

local mam_prefs_form = dataforms_new{
	title = "Archive preferences";
	--instructions = "";
	{
		name = "default",
		label = "Default storage policy",
		type = "list-single",
		value = {
			{ value = "always", label = "Always" },
			{ value = "never", label = "Never", default = true},
			{ value = "roster", label = "Roster" },
		},
	};
	{
		name = "always",
		label = "Always store messages to/from",
		type = "jid-multi"
	};
	{
		name = "never",
		label = "Never store messages to/from",
		type = "jid-multi"
	};
};

local host = module.host;

local default_attrs = {
	always = true, [true] = "always",
	never = false, [false] = "never",
	roster = "roster",
}

local global_default_policy = module:get_option("default_archive_policy", false);
local archive_store = "archive2";
local prefs_store = archive_store .. "_prefs";
local function get_prefs(user)
	return dm_load(user, host, prefs_store) or
		{ [false] = global_default_policy };
end
local function set_prefs(user, prefs)
	return dm_store(user, host, prefs_store, prefs);
end

local function mam_prefs_handler(self, data, state)
	local username, hostname = jid_split(data.from);
	if state then -- the second return value
		if data.action == "cancel" then
			return { status = "canceled" };
		end

		if not username or not hostname or hostname ~= module.host then
			return { status = "error", error = { type = "cancel",
				condition = "forbidden", message = "Invalid user or hostname." } };
		end

		local fields = mam_prefs_form:data(data.form);

		local default, always, never = fields.default, fields.always, fields.never;
		local prefs = {};
		if default then
			prefs[false] = default_attrs[default];
		end
		if always then
			for i=1,#always do
				prefs[always[i]] = true;
			end
		end
		if never then
			for i=1,#never do
				prefs[never[i]] = false;
			end
		end

		set_prefs(username, prefs);

		return { status = "completed" }
	else -- No state, send the form.
		local prefs = get_prefs(username);
		local values = {
			default = {
				{ value = "always", label = "Always" };
				{ value = "never", label = "Never" };
				{ value = "roster", label = "Roster" };
			};
			always = {};
			never = {};
		};

		for jid, p in pairs(prefs) do
			if jid then
				t_insert(values[p and "always" or "never"], jid);

			elseif p == true then -- Yes, this is ugly.  FIXME later.
				values.default[1].default = true;
			elseif p == false then
				values.default[2].default = true;
			elseif p == "roster" then
				values.default[3].default = true;
			end
		end
		return { status = "executing", actions  = { "complete" }, form = { layout = mam_prefs_form, values = values } }, true;
	end
end

module:add_item("adhoc", module:require"adhoc".new("Archive settings", "urn:xmpp:mam#configure", mam_prefs_handler));
