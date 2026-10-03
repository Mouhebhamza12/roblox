local CurrencyService = {}

function CurrencyService.Add(data, amount)
	data.Coins += amount
end

function CurrencyService.CanAfford(data, amount)
	return data.Coins >= amount
end

function CurrencyService.Spend(data, amount)
	if not CurrencyService.CanAfford(data, amount) then return false end
	data.Coins -= amount
	return true
end

return CurrencyService
