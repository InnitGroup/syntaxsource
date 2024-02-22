-- For use with InputBegan and InputEnded events
-- specifically to determine pressed/unpressed states

return function(inputObject)
	local userInputType = inputObject.UserInputType
	return (userInputType == Enum.UserInputType.Touch or userInputType == Enum.UserInputType.MouseButton1)
end