-- avatarEditorPropertyChanged : sent when a user changes a property on their avatar.
-- eventContext : (string) the location or context in which the event is occurring.
-- propertyName : (string) the name of the property being changed if applicable.
-- propertyValue : (string or number) the value of the property.
-- currentCategoryIndex : (number) Current category (i.e. recent, clothes, body, outfits) the user is in.
-- tabIndex : (number) The tab number the user is on (i.e. torso, left arm, right arm, etc.)

return function(eventStreamImpl, eventContext, propertyName, propertyValue, currentCategoryIndex, tabIndex)
	assert(type(eventContext) == "string", "Expected eventContext to be a string")
	assert(type(propertyName) == "string", "Expected propertyName to be a string")
	assert(type(propertyValue) == "string" or type(propertyValue) == "number", "Expected propertyValue to be a string")
	assert(type(currentCategoryIndex) == "number", "Expected currentCategoryIndex to be a number")
	assert(type(tabIndex) == "number", "Expected tabIndex to be a number")

	local eventName = "avatarEditorPropertyChanged"

	eventStreamImpl:setRBXEventStream(eventContext, eventName, {
			prop = propertyName,
			val = propertyValue,
			ci = currentCategoryIndex,
			ti = tabIndex,
		}
	)
end