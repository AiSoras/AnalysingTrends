p_classcode = "QJSIM"
p_seccode = "SBER" 
p_interval = INTERVAL_M4 -- Временной интервал
p_bars = 140 -- Количество баров
p_range = 5 -- Размер фрактала

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
	ds, error_desc = CreateDataSource(p_classcode,p_seccode,p_interval)	
	-- Ограничиваем количество попыток (времени) ожидания получения данных от сервера
	local try_count = 0
	-- Ждем пока не получим данные от сервера,
	--	либо пока не закончится время ожидания (количество попыток)
	while ds:Size() == 0 and try_count < 1000 do
		sleep(100)
		try_count = try_count + 1
	end
	-- Если от сервера пришла ошибка, то выведем ее и прервем выполнение
	if error_desc ~= nil and error_desc ~= "" then
		message("Ошибка получения таблицы свечей:" .. error_desc)
		return 0
	elseif ds:Size() < p_bars + center then
		message("Недостаточно свечей!")
		return 0
	else
		local fractals = getFrac()
		message("Получено свечей: "..tostring(ds:Size()).."\n"..
			"Тренд\n"..
			"По Доу: "..defTrendDow(fractals).."\n"..
			"По Вильямсу: "..defTrendWilliams(fractals))
	end
		
--  while is_run do
		     		
--	end
end

--[[ is_run = true    

function OnStop(stop_flag)
	is_run = false
end
]]--

function getFrac() -- Возвращает индексы фракталов в обратном порядке
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
				if current >= math.max(ds:H(i-center-j),ds:H(i-center+j)) then
					found = true
				else
					found = false
					break
				end
			end
			if found then
				fractals.high[#fractals.high+1] = i
			end
		end
		
		-- Фрактал вниз
		if fractals.low[#fractals.low] == nil or fractals.low[#fractals.low] > i  then
			local found = false
			local current = ds:L(i-center)
			for j = 1, center do
				if current >= math.min(ds:L(i-center-j),ds:L(i-center+j)) then
					found = true
				else
					found = false
					break
				end
			end
			if found then
				fractals.low[#fractals.low+1] = i
				if fractals.high[#fractals.high] == i then -- В случае двунаправленного фрактала
					i = i - 2
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
	local lastChange = "none"
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
					if lastChange == "high" then -- Два подряд пробития вверх (Возможные случаи: *_**;_**; ** -> *)
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
				lastChange = "high"
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
					if lastChange == "low" then -- Два подряд пробития вниз (Возможные случаи: _*_ _;*_ _; _ _ -> _)
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
				lastChange = "low"
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