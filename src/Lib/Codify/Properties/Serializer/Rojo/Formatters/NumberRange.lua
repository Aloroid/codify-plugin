--!strict
local Common = require(script.Parent.Parent.Parent.Parent.Common)

export type NumberRangeFormat = "EXPLICIT"

local Formatter: Common.FormatterMap<NumberRange, NumberRangeFormat> = {}

function Formatter.EXPLICIT(value)
	return {
		NumberRange = {
			value.Min,
			value.Max,
		},
	}
end

return Formatter
