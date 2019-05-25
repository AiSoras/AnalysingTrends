package.cpath = package.cpath .. ";" .. getWorkingFolder() .. "\\?51.dll"
require( "iuplua" )

-- Параметры
--p_classcode = "TQBR" -- Код класса
--p_seccode = "SBER" -- Код бумаги 
--p_interval = INTERVAL_M1 -- Временной интервал
p_bars = 140 -- Количество баров
p_range = 5 -- Размер фрактала
p_MA_f = 5 -- Быстрая MA (с меньшим периодом)
p_MA_a = 20 -- Cредняя MA (с промежуточным периодом)
p_MA_s = 80 -- Медленная MA (с большим периодом)

p_interval_start = INTERVAL_M1
p_interval_finish = INTERVAL_H1

--count -- Число свечей в источнике данных (= индексу последней свечки)
--trend_dow -- Последний зафиксированный тренд по Доу
--trend_williams -- Последний зафиксированный тренд по Вильямсу
--trend_ma -- Тренд по скользящим средним

results = {} -- Конечная таблица с данными анализа

fileName = "log.txt" -- Название файла по умолчанию
filePath = "C:\\Users\\5otai\\Desktop\\" -- Путь к файлам

intervals = {INTERVAL_TICK, INTERVAL_M1, INTERVAL_M2, INTERVAL_M3, INTERVAL_M4,
	INTERVAL_M5, INTERVAL_M6, INTERVAL_M10, INTERVAL_M15, INTERVAL_M20, INTERVAL_M30,
	INTERVAL_H1, INTERVAL_H2, INTERVAL_H4, INTERVAL_D1, INTERVAL_W1, INTERVAL_MN1}	

function main() -- Основной поток программы
	saveToFile("The program is running! "..os.date("%b %d %H:%M:%S").."\n")
	classcode = iup.text{
					multiline = "NO",
					expand = "NO",
					value = "TQBR"
					}
	seccode = iup.text{
					multiline = "NO",
					expand = "NO",
					value = "SBER"}
	dlg = iup.dialog
		{
		iup.gridbox
			{
			iup.label {title="Seccode: "},
			seccode,
			iup.label {title="Classcode: "},
			classcode,
			iup.button{title="OK", action = btn_ok_click},
			iup.button{title="Exit", action = btn_exit_click},
			numdiv = "2", 
			EXPANDCHILDREN = "YES", 
			ORIENTATION = "HORIZONTAL",
			GAPLIN = "10",
			GAPCOL = "10",
			margin = "10x10"
			}
		;title="Main", 
		font="Helvetica, 14",
		size="150x80"
		}
	dlg:showxy(iup.CENTER,iup.CENTER)

	-- to be able to run this script inside another context
	if (iup.MainLoopLevel()==0) then
		iup.MainLoop()
		iup.Close()
	end
end

function getResults() -- Получение результатов анализа
	
	if(p_range % 2 == 0) then
		p_range = p_range + 1
	end

	if(p_range < 3) then 
		p_range = 3
	end

	-- Определяем центр фрактала (смещение)	
	center = math.floor(p_range/2)

	local file = io.open(filePath.."Results.json","w")
	file:write("{\n\t\"results\":[\n")
	for i = getIndexByValue(intervals,p_interval_start), getIndexByValue(intervals,p_interval_finish) do
		local interval = intervals[i]
		-- Создаем таблицу со всеми свечами нужного интервала, класса и кода	
		ds, error_desc = CreateDataSource(p_classcode, p_seccode, interval)	
		-- Ограничиваем количество попыток (времени) ожидания получения данных от сервера
		local try_count = 0
		-- Ждем пока не получим данные от сервера,
		--	либо пока не закончится время ожидания (количество попыток)
		while ds == nil and try_count < 100 do
			sleep(300)
			try_count = try_count + 1
		end
		--ds:SetUpdateCallback(handleNewKindle) -- Задаем свой обработчик при поступлении новой информации из источника
		-- Если от сервера пришла ошибка, то выведем ее и прервем выполнение
		if error_desc ~= nil and error_desc ~= "" then
			message("Ошибка получения таблицы свечей:" .. error_desc)
			return 0
		elseif ds:Size() < p_bars + p_range then
			message("Недостаточно свечей! "..tostring(ds:Size()))
			return 0
		else 
			local fractals = getFrac(interval)
			local trend_dow = defTrendDow(fractals)
			local trend_williams = defTrendWilliams(fractals)
			local trend_ma = defTrendMA()
			count = ds:Size()
			local str = "Интервал: "..tostring(interval).." min \n\tТренд\n\n".."По Доу: "..trend_dow.."\n".."По Вильямсу: "..trend_williams.."\n".."По скользящим средним: "..trend_ma.."\n\n"
			saveToFile(str,"Results.txt")	
			
			local json_str = "\t\t{\n\t\t\t\"interval\":"..tostring(interval)..
			",\n\t\t\t\"methods\":[\n\t\t\t\t{\n\t\t\t\t\t\"Dow\":\""..trend_dow..
			"\"\n\t\t\t\t},\n\t\t\t\t{\n\t\t\t\t\t\"Williams\":\""..trend_williams..
			"\"\n\t\t\t\t},\n\t\t\t\t{\n\t\t\t\t\t\"MA\":\""..trend_ma.."\"\n\t\t\t\t}\n\t\t\t]\n\t\t},\n"
			file:write(json_str)	
			file:flush()
			results[#results+1] = { 
								["interval"] = interval,
								["methods"] = {
												["ma"] = trend_ma,
												["dow"] = trend_dow,
												["williams"] = trend_williams
											}
							}
		end		
	end
	ds:Close()
	file:seek("end",-3) -- Убирает последнюю запятую
	file:write(" \n\t]\n}")
	file:close()
end

function btn_exit_click(self) -- Обработка нажатия кнопки "Exit"
  return iup.CLOSE  
end

function btn_ok_click(self) -- Обработка нажатия кнопки "OK"
	p_classcode = classcode.value
	p_seccode = seccode.value
	getResults()
	
	counter = {
			dow = {
			up = 0,
			down = 0
			},
			williams = {
			up = 0,
			down = 0,
			flat = 0
			},
			ma = {
			up = 0,
			down = 0,
			flat = 0
			}}
	grd = iup.gridbox{numdiv = "9", 
		EXPANDCHILDREN = "YES", 
		ORIENTATION = "HORIZONTAL",
		GAPLIN = "10",
		GAPCOL = "10",
		margin = "10x10",
		--EXPAND = "NO",
		--HOMOGENEOUSCOL  = "YES"
		}
	grd:append(iup.label{title = "Interval\n\nDow\n\nWilliams\n\nMA"})
	for i = 1,7 do
		local lbl = iup.label{title = tostring(results[i].interval).." min\n\n"..
		results[i].methods.dow.."\n\n"..results[i].methods.williams.."\n\n"..results[i].methods.ma}
		grd:append(lbl)
		
		if results[i].methods.dow == "восходящий" then
			counter.dow.up = counter.dow.up + 1
		else
			counter.dow.down = counter.dow.down + 1
		end
		
		if results[i].methods.williams == "восходящий" then
			counter.williams.up = counter.williams.up + 1
		elseif results[i].methods.williams == "нисходящий" then
			counter.williams.down = counter.williams.down + 1
		else
			counter.williams.flat = counter.williams.flat + 1
		end
		
		if results[i].methods.ma == "восходящий" then
			counter.ma.up = counter.ma.up + 1
		elseif results[i].methods.ma == "нисходящий" then
			counter.ma.down = counter.ma.down + 1
		else
			counter.ma.flat = counter.ma.flat + 1
		end
		
	end
	grd:append(iup.label{title = "Total (up/down/flat)\n\n"..counter.dow.up.."/"..counter.dow.down.."\n\n"..
	counter.williams.up.."/"..counter.williams.down.."/"..counter.williams.flat.."\n\n"..
	counter.ma.up.."/"..counter.ma.down.."/"..counter.ma.flat})
	
	counter = {
			dow = {
			up = 0,
			down = 0
			},
			williams = {
			up = 0,
			down = 0,
			flat = 0
			},
			ma = {
			up = 0,
			down = 0,
			flat = 0
			}}
	grd:append(iup.label{title = "Interval\n\nDow\n\nWilliams\n\nMA"})
	for i = 5,11 do
		local lbl = iup.label{title = tostring(results[i].interval).." min\n\n"..
		results[i].methods.dow.."\n\n"..results[i].methods.williams.."\n\n"..results[i].methods.ma}
		grd:append(lbl)
		
		if results[i].methods.dow == "восходящий" then
			counter.dow.up = counter.dow.up + 1
		else
			counter.dow.down = counter.dow.down + 1
		end
		
		if results[i].methods.williams == "восходящий" then
			counter.williams.up = counter.williams.up + 1
		elseif results[i].methods.williams == "нисходящий" then
			counter.williams.down = counter.williams.down + 1
		else
			counter.williams.flat = counter.williams.flat + 1
		end
		
		if results[i].methods.ma == "восходящий" then
			counter.ma.up = counter.ma.up + 1
		elseif results[i].methods.ma == "нисходящий" then
			counter.ma.down = counter.ma.down + 1
		else
			counter.ma.flat = counter.ma.flat + 1
		end
	end
	grd:append(iup.label{title = "Total (up/down/flat)\n\n"..counter.dow.up.."/"..counter.dow.down.."\n\n"..
	counter.williams.up.."/"..counter.williams.down.."/"..counter.williams.flat.."\n\n"..
	counter.ma.up.."/"..counter.ma.down.."/"..counter.ma.flat})
	sec_dlg = iup.dialog
		{ grd
		--[[iup.gridbox
			{
			iup.button{title="Exit", action = btn_exit_click},
			gap = "10",
			alignment = "acenter",
			margin = "10x10",
			numdid = "8"
			}]]--
		;title="Results", 
		font="Helvetica, 14",
		size="800x200"
		}
	sec_dlg:showxy(iup.CENTER,iup.CENTER)
	dlg:destroy()
end

function getIndexByValue(array, value) -- Возвращает индекс первого совпавшего значения в массиве 
	for ind, val in ipairs(array) do
		if val == value then
			return ind
		end	
	end
	return nil
end

function saveToFile(str,...) -- По умолчанию сохраняет строку str в файл с названием fileName, можно вторым аргументом задать другое название
	local file 
	local mode = "a"
	if arg.n == 0 then
		file = io.open(filePath..fileName, mode) -- режим записи в файл с добавлением к содержимому файла		
	else
		if arg[2] ~= nil then 
			mode = arg[2]
		end	
		file = io.open(filePath..arg[1], mode)
	end
	file:write(str.."\n")
	file:close()
end

function getFrac(interval) -- Возвращает индексы вершин фракталов в обратном порядке
	-- Создаем таблицу для нижних и верхних фракталов (при этом порядок будет обратный, так как начинаем рассматривать интервал с конца)
	local fractals = {
		low = {},
		high = {}
	}
	count = ds:Size()
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
					local spec = specFrac(ds:T(i-center), ds:H(i-center), ds:L(i-center), interval)
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

function defTrendWilliams(fractals) -- Определение тренда по Вильямсу
	local trend = "отсутствует"
	-- Определение пробитий подряд для каждого вида фракталов
	local br = {
		h = 0, 
		l = 0
	}
	local last_change = "none"
	local hi = #fractals.high 
	local li = #fractals.low
	local first_kindle = math.min(fractals.high[hi],fractals.low[li])
	saveToFile("Williams. Start at "..tostring(ds:T(first_kindle).month).."m "..
					tostring(ds:T(first_kindle).day).."d "..
					tostring(ds:T(first_kindle).hour)..":"..tostring(ds:T(first_kindle).min).."\n", "Compare.txt")
	for i = first_kindle, count - 1 do 
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
						if trend ~= "восходящий" then
							local str = "[ Uptrend ] "..tostring(ds:T(i).month).."m "..
								tostring(ds:T(i).day).."d "..
								tostring(ds:T(i).hour)..":"..tostring(ds:T(i).min)
							saveToFile(str.."\n", "Compare.txt")
							trend = "восходящий"
						end
						br.h = 1 
						br.l = 0
					elseif br.l == 2 then -- Чередование пробитий (Возможные случаи: _*_* -> _*)
						if trend ~= "горизонтальный" then
							local str = "[Flattrend] "..tostring(ds:T(i).month).."m "..
								tostring(ds:T(i).day).."d "..
								tostring(ds:T(i).hour)..":"..tostring(ds:T(i).min)
							saveToFile(str.."\n", "Compare.txt")
							trend = "горизонтальный"
						end
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
						if trend ~= "нисходящий" then
							local str = "[Downtrend] "..tostring(ds:T(i).month).."m "..
								tostring(ds:T(i).day).."d "..
								tostring(ds:T(i).hour)..":"..tostring(ds:T(i).min)
							saveToFile(str.."\n", "Compare.txt")
							trend = "нисходящий"
						end
						br.l = 1
						br.h = 0
					elseif br.h == 2 then -- Чередование пробитий (Возможные случаи: *_*_ -> *_)
						if trend ~= "горизонтальный" then
							local str = "[Flattrend] "..tostring(ds:T(i).month).."m "..
								tostring(ds:T(i).day).."d "..
								tostring(ds:T(i).hour)..":"..tostring(ds:T(i).min)
							saveToFile(str.."\n", "Compare.txt")
							trend = "горизонтальный"
						end
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

function defTrendDow(fractals) -- Определение тренда по Доу
	local trend = "отсутствует"
	local hi = #fractals.high - 1 
	local li = #fractals.low - 1
	local first_kindle = math.min(fractals.high[hi],fractals.low[li])
	saveToFile("Dow. Start at "..tostring(ds:T(first_kindle).month).."m "..
					tostring(ds:T(first_kindle).day).."d "..
					tostring(ds:T(first_kindle).hour)..":"..tostring(ds:T(first_kindle).min).."\n", "Compare.txt")
	for i = first_kindle, count - 1 do 
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
					if trend ~= "восходящий" then
						local str = "[ Uptrend ] "..tostring(ds:T(i).month).."m "..
							tostring(ds:T(i).day).."d "..
							tostring(ds:T(i).hour)..":"..tostring(ds:T(i).min)
						saveToFile(str.."\n", "Compare.txt")
						trend = "восходящий"
					end
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
					if trend ~= "нисходящий" then
						local str = "[Downtrend] "..tostring(ds:T(i).month).."m "..
							tostring(ds:T(i).day).."d "..
							tostring(ds:T(i).hour)..":"..tostring(ds:T(i).min)
						saveToFile(str.."\n", "Compare.txt")
						trend = "нисходящий"
					end
				end
				if i~= next_lF then
					li = li - 1
				end
			end
		end		
	end
	return trend
end

function defTrendMA() -- Определение тренда по скользящим средним
	local trend = "отсутствует"
	local MA_f, MA_a, MA_s
	for i = count - p_bars, count - 1 do
		MA_f = SMA(i, p_MA_f, MA_f)
		MA_a = SMA(i, p_MA_a, MA_a)
		MA_s = SMA(i, p_MA_s, MA_s)
		if MA_a <= MA_f and MA_a >= MA_s then -- Наблюдается тренд, если средняя MA располагается между двумя другими
			if MA_f > math.max(MA_a, MA_s) and trend ~="восходящий" then
				trend ="восходящий"
			elseif MA_f < math.min(MA_a, MA_s) and trend ~="нисходящий" then
				trend ="нисходящий"
			end 
		elseif trend ~="горизонтальный" then
			trend ="горизонтальный"
		end				
	end
	return trend
end

function SMA(index, period, prev_SMA) -- Простая скользящая средняя (SMA, Simple Moving Average)
	if prev_SMA == nil then
		local sum = 0
		for i = index - period + 1, index do
			sum = sum + ds:C(i)
		end
		return sum/period
	else
		return prev_SMA - (ds:C(index - period) - ds:C(index))/period
	end
end

function specFrac(frac_time, frac_high, frac_low, frac_interval) -- Определяет, что произошло раньше: low или high
	local new_interval = intervals[getIndexByValue(intervals,frac_interval)-1]
	if new_interval == nil then
		return nil
	end
	local ds = CreateDataSource(p_classcode, p_seccode, new_interval)
	local kindle, ind_high, ind_low
	local try_count = 0	
	local seconds = os.time(frac_time)
	while ds == nil and try_count < 100 do
		sleep(100)
		try_count = try_count + 1
	end	
	if ds ~= nil then
		for i = 1, ds:Size() do
			if os.time(ds:T(i)) == seconds then
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

--[[
function handleNewKindle (index) -- Обработка новой свечи
	if index == count + 1 then -- При окончательном формировании последней свечи и появлении новой
		local fractals = getFrac()
		local new_trend_dow = defTrendDow(fractals)
		local new_trend_williams = defTrendWilliams(fractals)
		if new_trend_dow ~= trend_dow or new_trend_williams ~= trend_williams then
			trend_dow = new_trend_dow
			trend_williams = new_trend_williams
			message("Направление тренда изменилось! Теперь он\n"..
			"По Доу: "..trend_dow.."\n"..
			"По Вильямсу: "..trend_williams)
		end
	end
end
]]--
