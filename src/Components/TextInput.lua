local Packages = script.Parent.Parent.Packages

local Roact = require(Packages.Roact)
local Hooks = require(Packages.Hooks)
local StudioTheme = require(Packages.StudioTheme)

local e = Roact.createElement

export type TextInputProps = {
	autoSize: Enum.AutomaticSize?,
	disabled: boolean?,
	readonly: boolean?,
	text: string?,
	textSize: number?,
	textColour: (Color3 | Enum.StudioStyleGuideColor)?,
	size: UDim2?,
	position: UDim2?,
	zindex: number?,
	order: number?,
	font: Enum.Font?,
	multiline: boolean?,
	wrapped: boolean?,
	placeholder: string?,
	maxHeight: number?,
	selectAllOnFocus: boolean?,

	onChanged: ((TextBox) -> ())?,
	onSubmit: ((TextBox) -> ())?,
	onFocus: ((TextBox) -> ())?,
	onFocusLost: ((TextBox) -> ())?,
}

local function TextInput(props: TextInputProps, hooks)
	local theme, styles = StudioTheme.useTheme(hooks)

	local hover, setHover = hooks.useState(false)
	local press, setPress = hooks.useState(false)
	local focus, setFocus = hooks.useState(false)

	local inputRef = hooks.useValue(Roact.createRef())

	local colours = hooks.useMemo(function()
		local modifiers = { background = nil, foreground = nil, border = nil, placeholder = nil }

		if props.disabled then
			modifiers.background = Enum.StudioStyleGuideModifier.Disabled
			modifiers.foreground = Enum.StudioStyleGuideModifier.Disabled
			modifiers.border = Enum.StudioStyleGuideModifier.Disabled
			modifiers.placeholder = Enum.StudioStyleGuideModifier.Disabled
		elseif focus then
			modifiers.background = Enum.StudioStyleGuideModifier.Selected
			modifiers.foreground = Enum.StudioStyleGuideModifier.Default
			modifiers.border = Enum.StudioStyleGuideModifier.Selected
			modifiers.placeholder = Enum.StudioStyleGuideModifier.Selected
		elseif press then
			modifiers.background = Enum.StudioStyleGuideModifier.Pressed
			modifiers.foreground = Enum.StudioStyleGuideModifier.Pressed
			modifiers.border = Enum.StudioStyleGuideModifier.Pressed
			modifiers.placeholder = Enum.StudioStyleGuideModifier.Pressed
		elseif hover then
			modifiers.background = Enum.StudioStyleGuideModifier.Hover
			modifiers.foreground = Enum.StudioStyleGuideModifier.Hover
			modifiers.border = Enum.StudioStyleGuideModifier.Hover
			modifiers.placeholder = Enum.StudioStyleGuideModifier.Hover
		end

		return {
			background = theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBackground, modifiers.background),
			border = theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBorder, modifiers.border),
			placeholder = theme:GetColor(Enum.StudioStyleGuideColor.DimmedText, modifiers.placeholder),
			foreground = theme:GetColor(Enum.StudioStyleGuideColor.MainText, modifiers.foreground),
		}
	end, { hover, press, focus, props.disabled, theme })

	local onInputBegan = hooks.useCallback(function(_, input: InputObject)
		if props.disabled then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			setHover(true)
		elseif input.UserInputType.Name:match("MouseButton%d+") then
			setPress(true)
		end
	end, { props.disabled })

	local function onInputEnded(_, input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			setHover(false)
			setPress(false)
		elseif input.UserInputType.Name:match("MouseButton%d+") then
			setPress(false)
		end
	end

	local function onInputChanged(_, input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			setHover(true)
		end
	end

	return e("ImageButton", {
		Active = not props.disabled,
		AutoButtonColor = false,
		AutomaticSize = props.autoSize,
		BackgroundColor3 = colours.border,
		Position = props.position,
		LayoutOrder = props.order,
		Size = props.size,
		ZIndex = props.zindex,
		Image = "",

		[Roact.Event.InputBegan] = onInputBegan,
		[Roact.Event.InputEnded] = onInputEnded,
		[Roact.Event.InputChanged] = onInputChanged,

		[Roact.Event.Activated] = function()
			local input = inputRef.value:getValue()

			if input then
				input:CaptureFocus()
			end
		end,
	}, {
		corners = e("UICorner", {
			CornerRadius = UDim.new(0, styles.borderRadius),
		}),

		padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 1),
			PaddingLeft = UDim.new(0, 1),
			PaddingRight = UDim.new(0, 1),
			PaddingTop = UDim.new(0, 1),
		}),

		content = e("Frame", {
			AutomaticSize = props.autoSize,
			BackgroundColor3 = colours.background,
			Size = UDim2.fromScale(1, 0),
		}, {
			corners = e("UICorner", {
				CornerRadius = UDim.new(0, styles.borderRadius - 1),
			}),

			padding = e("UIPadding", {
				PaddingBottom = UDim.new(0, styles.spacing),
				PaddingLeft = UDim.new(0, styles.spacing),
				PaddingRight = UDim.new(0, styles.spacing),
				PaddingTop = UDim.new(0, styles.spacing),
			}),

			input = e("TextBox", {
				Active = not props.disabled,
				AutomaticSize = props.autoSize,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				Font = props.font or styles.font.default,
				Text = props.text,
				TextSize = props.textSize or styles.fontSize,
				TextColor3 = colours.foreground,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ClearTextOnFocus = false,
				TextEditable = not (props.readonly or props.disabled),
				TextWrapped = props.wrapped,
				Selectable = not props.disabled,
				ClipsDescendants = true,
				MultiLine = props.multiline,
				PlaceholderText = props.placeholder,
				PlaceholderColor3 = colours.placeholder,

				[Roact.Ref] = inputRef.value,
				[Roact.Event.Focused] = function(rbx: TextBox)
					setFocus(true)

					if props.selectAllOnFocus then
						rbx.CursorPosition = #rbx.Text + 1
						rbx.SelectionStart = 1
					end

					if props.onFocus then
						props.onFocus(rbx)
					end
				end,

				[Roact.Event.FocusLost] = function(rbx: TextBox, enterPressed: boolean)
					setFocus(false)
					setHover(false)
					setPress(false)

					if enterPressed and props.onSubmit then
						props.onSubmit(rbx)
					end

					if props.onFocusLost then
						props.onFocusLost(rbx)
					end
				end,

				[Roact.Change.Text] = props.onChanged,
			}, {
				maxHeight = if props.maxHeight
					then e("UISizeConstraint", {
						MaxSize = Vector2.new(math.huge, props.maxHeight),
					})
					else nil,
			}),
		}),
	})
end

return Hooks.new(Roact)(TextInput, {
	componentType = "PureComponent",
	defaultProps = {
		autoSize = Enum.AutomaticSize.Y,
		size = UDim2.fromScale(1, 0),
		wrapped = true,
		text = "",
	},
})