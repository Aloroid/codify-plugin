local DebugSettings = settings():GetService("DebugSettings")
local Plugin = script.Parent.Parent

local HttpPromise = require(Plugin.Lib.HttpPromise)
local Promise = require(Plugin.Packages.Promise)
local Sift = require(Plugin.Packages.Sift)

local Properties = {}

local IGNORED_PROPERTIES = {
	Classes = {
		GuiObject = {
			"Font",
		},
	},
	Global = {
		"Parent",
	},
}

function Properties.FetchLatestVersion()
	return HttpPromise.RequestAsync("https://s3.amazonaws.com/setup.roblox.com/versionQTStudio", {
		cache = -1,
	}):andThen(function(version)
		local hash = version:match("version%-(%x+)")
		return hash
	end)
end

function Properties.FetchVersionHash(version: string?)
	version = if version then version else DebugSettings.RobloxVersion

	local deployVersion = version:gsub("%.", ", ")

	return HttpPromise.RequestAsync("https://s3.amazonaws.com/setup.roblox.com/DeployHistory.txt", {
		cache = -1,
	}):andThen(function(history)
		local deployments = history:split("\n")

		for lineNumber = #deployments, 1, -1 do
			local line = deployments[lineNumber]

			if line:find(deployVersion) then
				return assert(line:match("version%-(%x+)"), "Unable to find version hash in line: " .. line)
			end

			if lineNumber >= 128 then
				break
			end
		end

		return Promise.reject("Unable to find version hash for " .. deployVersion)
	end)
end

function Properties.FetchVersionWithFallback(version: string?)
	return Properties.FetchVersionHash(version):catch(function()
		return Properties.FetchLatestVersion()
	end)
end

function Properties.FetchAPIDump(hash: string)
	return HttpPromise.RequestJsonAsync("https://s3.amazonaws.com/setup.roblox.com/version-" .. hash .. "-API-Dump.json", {
		cache = -1,
	})
end

local function FindClassEntry(dump, class: string)
	local entryIndex = Sift.Array.findWhere(dump.Classes, function(classEntry)
		return classEntry.Name == class
	end)

	return dump.Classes[entryIndex]
end

function Properties.GetClassAncestry(class: string)
	return Properties.FetchVersionWithFallback()
		:andThen(function(version)
			return Properties.FetchAPIDump(version)
		end)
		:andThen(function(dump)
			local ancestorClasses = { FindClassEntry(dump, class) }

			while ancestorClasses[#ancestorClasses].Superclass ~= "<<<ROOT>>>" do
				table.insert(ancestorClasses, FindClassEntry(dump, ancestorClasses[#ancestorClasses].Superclass))
			end

			return ancestorClasses
		end)
end

function Properties.GetIgnoredPropertyNames(class: string)
	return Properties.GetClassAncestry(class):andThen(function(ancestry)
		local ignoredProperties = {}

		for _, ancestor in ipairs(ancestry) do
			local ignoreList = IGNORED_PROPERTIES.Classes[ancestor.Name]

			if ignoreList then
				table.insert(ignoredProperties, ignoreList)
			end
		end

		for _, globalProperty in ipairs(IGNORED_PROPERTIES.Global) do
			table.insert(ignoredProperties, globalProperty)
		end

		return Sift.Array.flatten(ignoredProperties, 1)
	end)
end

function Properties.GetPropertyList(class: string)
	return Properties.GetClassAncestry(class):andThen(function(ancestry)
		local success, ignoredProperties = Properties.GetIgnoredPropertyNames(class):await()
		local properties = {}

		for _, ancestor in ipairs(ancestry) do
			local propertyMembers = Sift.Array.filter(ancestor.Members, function(member)
				if member.MemberType ~= "Property" then
					return false
				end

				if member.Security.Read ~= "None" or member.Security.Write ~= "None" then
					return false
				end

				if member.Tags then
					local tagList = { "ReadOnly", "Deprecated", "Hidden", "NotScriptable" }

					for _, tag in ipairs(member.Tags) do
						if table.find(tagList, tag) then
							return false
						end
					end
				end

				return true
			end)

			for _, property in ipairs(propertyMembers) do
				if success and ignoredProperties and table.find(ignoredProperties, property.Name) then
					continue
				end

				table.insert(properties, property.Name)
			end
		end

		return properties
	end)
end

function Properties.GetChangedProperties(instance: Instance)
	return Properties.GetPropertyList(instance.ClassName):andThen(function(properties)
		local newInstance = Instance.new(instance.ClassName)
		local changedProps = {}

		for _, property in ipairs(properties) do
			if newInstance[property] ~= instance[property] then
				table.insert(changedProps, property)
			end
		end

		newInstance:Destroy()

		return changedProps
	end)
end

return Properties
