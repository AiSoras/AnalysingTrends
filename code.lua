p_classcode = "TQBR" -- Код класса
p_seccode = "SBER" -- Код бумаги 
p_interval = INTERVAL_D1 -- Временной интервал
p_bars = 140 -- Количество баров
p_range = 5 -- Размер фрактала
fileName = "log.txt"
filePath = "C:\\Users\\<youracc>\\Desktop\\"

intervals = {INTERVAL_TICK, INTERVAL_M1, INTERVAL_M2, INTERVAL_M3, INTERVAL_M4,
	INTERVAL_M5, INTERVAL_M6, INTERVAL_M10, INTERVAL_M15, INTERVAL_M20, INTERVAL_M30,
	INTERVAL_H1, INTERVAL_H2, INTERVAL_H4, INTERVAL_D1, INTERVAL_W1, INTERVAL_MN1}	


if(p_range % 2 == 0) then
	p_range = p_range + 1
end

if(p_range < 3) then 
	p_range = 3
end

-- Определяем центр фрактала (смещение)	
center = math.floor(p_range/2)

function main()
	-- Создаем таблицу со всеми свечами нужного интервала, класса и кода	
	ds, error_desc = CreateDataSource(p_classcode, p_seccode, p_interval)	
	-- Ограничиваем количество попыток (времени) ожидания получения данных от сервера
	local try_count = 0
	-- Ждем пока не получим данные от сервера,
	--	либо пока не закончится время ожидания (количество попыток)
	while ds == nil and try_count < 100 do
		sleep(100)
		try_count = try_count + 1
	end
	-- Если от сервера пришла ошибка, то выведем ее и прервем выполнение
	if error_desc ~= nil and error_desc ~= "" then
		message("Ошибка получения таблицы свечей:" .. error_desc)
		return 0
	elseif ds:Size() < p_bars + p_range then
		message("Недостаточно свечей! "..tostring(ds:Size()))
		return 0
	else
		saveToFile("The program is running! "..os.date("%b %d %H:%M:%S").."\n") 
		local fractals = getFrac()
		message("Получено свечей: "..tostring(ds:Size()).."\n\n"..
			"\tТренд\n\n"..
			"По Доу: "..defTrendDow(fractals).."\n"..
			"По Вильямсу: "..defTrendWilliams(fractals))
	end
end

function getIndexByValue(array, value) -- Возвращает индекс первого совпавшего значения в массиве 
	for ind, val in pairs(array) do
		if val == value then
			return ind
		end	
	end
	return nil
end

function specFrac(frac_time, frac_high, frac_low, frac_interval) -- Определяет, что произошло раньше: low или high
	local new_interval = intervals[getIndexByValue(intervals,frac_interval)-1]
	local ds = CreateDataSource(p_classcode, p_seccode, new_interval)
	local kindle, ind_high, ind_low
	local try_count = 0	
	while ds == nil and try_count < 100 do
		sleep(100)
		try_count = try_count + 1
	end	
	if ds ~= nil then
		for i = 1, ds:Size() do
			if ds:T(i) == frac_time then
				kindle = i
				break
			end
		end
		if kindle ~= nil then
			while kindle <= ds:Size() do
				if ds:H(kindle) == frac_high then
					ind_high = kindle
				end
				if ds:L(kindle) == frac_low then
					ind_low = kindle
				end
				if ind_low ~= nil or ind_high ~= nil then -- На уровне ниже тоже может быть двунаправленный фрактал
					break
				end
				kindle = kindle + 1
			end
			if ind_low ~= nil and ind_high ~= nil then
				if ind_low < ind_high then
					return "low"
				elseif ind_low > ind_high then
					return "high"
				else -- Если это оказался двунаправленный фрактал, то снова переходим на уровень ниже
					return specFrac(ds:T(ind_low), frac_low, frac_high, new_interval)
				end
			elseif ind_low ~= nil then
				return "low"
			elseif ind_high ~= nil then 
				return "high"
			end
		end
	else 
		return nil
	end
end

function saveToFile(str)
	local file = io.open(filePath..fileName,"a") -- режим записи в файл с добавлением к содержимому файла 
	file:write(str.."\n")
	file:close()
end

function getFrac() -- Возвращает индексы вершин фракталов в обратном порядке
	-- Создаем таблицу для нижних и верхних фракталов (при этом порядок будет обратный, так как начинаем рассматривать интервал с конца)
	local fractals = {
		low = {},
		high = {}
	}
	-- Определяем общее число полученных свечей (= индексу последней свечки)
	local count = ds:Size()
	-- Последнюю свечу исключаем
	local i = count - 1
	-- Начинаем с конца промежутка
	while (i >= count - p_bars - 1)  do -- p_bars-свечей без учёта последней
		
		-- Фрактал вверх
		if fractals.high[#fractals.high] == nil or fractals.high[#fractals.high] > i  then
			local found = false
			local current = ds:H(i-center)
			for j = 1, center do
				if current >= ds:H(i-center-j) and current > ds:H(i-center+j) then
					found = true
				else
					found = false
					break
				end
			end
			if found then
				fractals.high[#fractals.high+1] = i - center -- Сохраняем центр фрактала вверх
				saveToFile("[ Up ] "..tostring(ds:T(i - center).month).."m "..
					tostring(ds:T(i - center).day).."d "..
					tostring(ds:T(i - center).hour)..":"..tostring(ds:T(i - center).min)..
					"\t\tHigh: "..tostring(ds:H(i - center)))				
			end
		end
		
		-- Фрактал вниз
		if fractals.low[#fractals.low] == nil or fractals.low[#fractals.low] > i  then
			local found = false
			local current = ds:L(i-center)
			for j = 1, center do
				if current <= ds:L(i-center-j) and current < ds:L(i-center+j) then
					found = true
				else
					found = false
					break
				end
			end
			if found then
				fractals.low[#fractals.low+1] = i - center -- Сохраняем центр фрактала вверх
				saveToFile("[Down] "..tostring(ds:T(i - center).month).."m "..
					tostring(ds:T(i - center).day).."d "..
					tostring(ds:T(i - center).hour)..":"..tostring(ds:T(i - center).min)..
					"\t\tLow: "..tostring(ds:L(i - center)))
				if fractals.high[#fractals.high] == i - center then -- В случае двунаправленного фрактала 
					local spec = specFrac(ds:T(i-center), ds:H(i-center), ds:L(i-center), p_interval)
					if spec == "low" then
						fractals.high[#fractals.high] = nil
					elseif spec == "high" then
						fractals.low[#fractals.low] = nil
					end
					i = i - p_range
				end
			end
		end

		i = i - 1	
	end	
	return fractals
end

function defTrendWilliams(fractals) 
	local count = ds:Size()
	local trend = "отсутствует"
	-- Определение пробитий подряд для каждого вида фракталов
	br = {
		h = 0, 
		l = 0
	}
	local last_change = "none"
	local hi = #fractals.high 
	local li = #fractals.low
	for i = count - p_bars - 1, count - 1 do 
		-- Могут быть nil
		local hF = fractals.high[hi]
		local next_hF = fractals.high[hi-1]
		
		local lF = fractals.low[li]
		local next_lF = fractals.low[li-1]
		
		-- Проверка для верхних фракталов
		if hF ~= nil and i > hF then
			if i == next_hF then -- Достижение следующего фрактала
				hi = hi - 1
			end
			if ds:H(i) > ds:H(hF) then -- Пробитие верхнего фрактала
				br.h = br.h + 1 -- Фиксирование пробития
				if br.h >= 2 then
					if last_change == "high" then -- Два подряд пробития вверх (Возможные случаи: *_**;_**; ** -> *)
						trend = "восходящий"
						br.h = 1 
						br.l = 0
					elseif br.l == 2 then -- Чередование пробитий (Возможные случаи: _*_* -> _*)
						trend = "горизонтальный"
						br.h = 1
						br.l = 1
					end
				end
				if i ~= next_hF then -- Во избежание двойного удаления
					hi = hi - 1
				end
				last_change = "high"
			end
		end
		
		-- Проверка для фракталов вниз 
		if lF ~= nil and i > lF then
			if i == next_lF then 
				li = li - 1
			end
			if ds:L(i) < ds:L(lF) then
				br.l = br.l + 1
				if br.l >= 2 then
					if last_change == "low" then -- Два подряд пробития вниз (Возможные случаи: _*_ _;*_ _; _ _ -> _)
						trend = "нисходящий"
						br.l = 1
						br.h = 0
					elseif br.h == 2 then -- Чередование пробитий (Возможные случаи: *_*_ -> *_)
						trend = "горизонтальный"
						br.h = 1
						br.l = 1
					end
				end
				if i ~= next_lF then 
					li = li - 1
				end
				last_change = "low"
			end
		end	
	end
	return trend
end

function defTrendDow(fractals)
	local count = ds:Size()
	local trend = "отсутствует"
	local hi = #fractals.high - 1 
	local li = #fractals.low - 1

	for i = math.min(hi,li), count - 1 do 
		-- Могут быть nil
		local hF = fractals.high[hi]
		local prev_hF = fractals.high[hi+1]
		local next_hF = fractals.high[hi-1]
		
		local lF = fractals.low[li]
		local prev_lF = fractals.low[li+1]
		local next_lF = fractals.low[li-1]
		
		if hF ~= nil and i > hF then
			if i == next_hF then
				hi = hi - 1
			end
			if ds:H(i) > ds:H(hF) then -- Если локальный максимум пробит				
				if lF ~= nil and ds:L(prev_lF) < ds:L(lF) then -- Требования двух (!) точек
					trend = "восходящий"
				end
				if i~= next_hF then
					hi = hi - 1
				end
			end
		end
		
		if lF ~= nil and i > lF then
			if i == next_lF then
				li = li - 1
			end
			if ds:L(i) < ds:L(lF) then
				if hF ~= nil and ds:H(prev_hF) > ds:H(hF) then
					trend = "нисходящий"
				end
				if i~= next_lF then
					li = li - 1
				end
			end
		end		
	end
	return trend
end
