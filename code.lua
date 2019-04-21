p_classcode = "QJSIM"
p_seccode = "SBER" 
p_interval = INTERVAL_M4 -- ��������� ��������
p_bars = 140 -- ���������� �����
p_range = 5 -- ������ ��������

if(p_range % 2 == 0) then
	p_range = p_range + 1
end

if(p_range < 3) then 
	p_range = 3
end

-- is_run = true    

function main()
	-- ������� ������� �� ����� ������� ������� ���������, ������ � ����	
	ds, error_desc = CreateDataSource(p_classcode,p_seccode,p_interval)	
	-- ������������ ���������� ������� (�������) �������� ��������� ������ �� �������
	local try_count = 0
	-- ���� ���� �� ������� ������ �� �������,
	--	���� ���� �� ���������� ����� �������� (���������� �������)
	while ds:Size() == 0 and try_count < 1000 do
		sleep(100)
		try_count = try_count + 1
	end
	-- ���� �� ������� ������ ������, �� ������� �� � ������� ����������
	if error_desc ~= nil and error_desc ~= "" then
		message("������ ��������� ������� ������:" .. error_desc)
		return 0
	elseif ds:Size() < p_bars + p_range//2 then
		message("������������ ������!")
		return 0
	else
		message(tostring(ds:Size()))
		sleep(1000)
		getFrac()
		defTrendWilliams()
	end
		
--  while is_run do
		     		
--	end
end

--[[
function OnStop(stop_flag)
	is_run = false
end
]]--

function getFrac()
	-- ���������� ����� ��������	
	local center = p_range//2
	-- ������� ������� ��� ������ � ������� ��������� (��� ���� ������� ����� ��������, ��� ��� �������� ������������� �������� � �����)
	fractals = {
		low = {},
		high = {}
	}
	-- ���������� ����� ����� ���������� ������ (= ������� ��������� ������)
	local count = ds:Size()
	-- ��������� ����� ���������
	local i = count - 1
	-- �������� � ����� ����������
	while (i >= count - p_bars - 1)  do -- p_bars-������ ��� ����� ���������
	
		-- ������� �����
		if fractals.high[#fractals.high] > i  then
			local found = false
			local current = ds:H(i-center)
			for local j = 1, center do
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
		
		-- ������� ����
		if fractals.low[#fractals.low] > i  then
			local found = false
			local current = ds:L(i-center)
			for local j = 1, center do
				if current >= math.min(ds:L(i-center-j),ds:L(i-center+j)) then
					found = true
				else
					found = false
					break
				end
			end
			if found then
				fractals.low[#fractals.low+1] = i
				if fractals.high[#fractals.high] == i then -- � ������ ���������������� ��������
					i = i - 2
				end
			end
		end
		
		i = i - 1	
	end	
end	

function defTrendDow()

end