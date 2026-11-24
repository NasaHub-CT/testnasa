local __NH_T = {} --------------------------------------------------------------------
-- 只允许运行一次
--------------------------------------------------------------------
local Env = (getgenv and getgenv()) or _G
local GUI_NAME = "NASA_HUB_UI"
local ALLOW_RERUN_AFTER_CLOSE = true   -- true：关闭后可重新运行；false：整局只能运行一次

function __NH_T.findRunning()
    local roots = {}
    pcall(function() if gethui then roots[#roots + 1] = gethui() end end)
    pcall(function() roots[#roots + 1] = game:GetService("CoreGui") end)
    if Env.HIDEUI then roots[#roots + 1] = Env.HIDEUI end
    for _, root in ipairs(roots) do
        local ok, found = pcall(function() return root:FindFirstChild(GUI_NAME) end)
        if ok and found then return found end
    end
    return nil
end

do
    local stamp = Env.NASA_HUB_RUNNING
    local blocked = __NH_T.findRunning() ~= nil
        or (stamp ~= nil and (not ALLOW_RERUN_AFTER_CLOSE or os.clock() - stamp < 15))
    if blocked then
        warn("[NASA-Hub] 已经在运行了，不会重复打开 UI（想重开请先在 Settings 里 Unload）")
        return
    end
    Env.NASA_HUB_RUNNING = os.clock()
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
__NH_T.Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
__NH_T.HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
__NH_T.SoundService = game:GetService("SoundService")
__NH_T.ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
function __NH_T.resolveObjectsRoot()
	return Workspace:FindFirstChild("World") or Workspace:FindFirstChild("__OBJECTS")
end

local runtimeEnv = getgenv and getgenv() or _G
if type(runtimeEnv.__NasaV1HubShutdown) == "function" then
	pcall(runtimeEnv.__NasaV1HubShutdown)
end
local hubSession = {}
runtimeEnv.__NasaV1HubSession = hubSession
local function sessionAlive()
	return runtimeEnv.__NasaV1HubSession == hubSession
end
do
	local TAMPER_API = { "hookfunction", "hookmetamethod", "getconnections", "getgc", "getrawmetatable",
		"firetouchinterest", "newcclosure", "getnamecallmethod", "checkcaller", "getcallingscript" }
	local iscclosureFn = runtimeEnv.iscclosure or rawget(_G, "iscclosure")
	local isHookedFn = runtimeEnv.isfunctionhooked or rawget(_G, "isfunctionhooked")
	local baseline = {}
	for _, name in ipairs(TAMPER_API) do baseline[name] = runtimeEnv[name] end
	local function wrapped(fn)
		if type(fn) ~= "function" then return false end
		if type(iscclosureFn) == "function" then
			local ok, isC = pcall(iscclosureFn, fn)
			if ok and isC == false then return true end
		end
		if type(isHookedFn) == "function" then
			local ok, hooked = pcall(isHookedFn, fn)
			if ok and hooked == true then return true end
		end
		return false
	end
	local function tampered()
		for _, name in ipairs(TAMPER_API) do
			local current = runtimeEnv[name]
			if current ~= baseline[name] or wrapped(current) then return "api:" .. name end
		end
		local getmt = baseline.getrawmetatable
		if type(getmt) == "function" then
			local ok, mt = pcall(getmt, game)
			if ok and type(mt) == "table" then
				for _, key in ipairs({ "__namecall", "__index", "__newindex" }) do
					if wrapped(rawget(mt, key)) then return "mt:" .. key end
				end
			end
		end
		local probe = Instance.new("RemoteEvent")
		local probeFn = Instance.new("RemoteFunction")
		local hit
		if wrapped(probe.FireServer) then hit = "remote:FireServer"
		elseif wrapped(probeFn.InvokeServer) then hit = "remote:InvokeServer" end
		probe:Destroy()
		probeFn:Destroy()
		return hit
	end
	local function rejoin(reason)
		if runtimeEnv.__NasaV1TamperRejoining then return end
		runtimeEnv.__NasaV1TamperRejoining = true
		warn("[NasaHub] tamper detected (" .. tostring(reason) .. ") - rejoining")
		pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
		task.delay(5, function()
			pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
		end)
	end
	local okFirst, first = pcall(tampered)
	if okFirst and first then rejoin(first) end
	task.spawn(function()
		while sessionAlive() do
			task.wait(3)
			local ok, hit = pcall(tampered)
			if ok and hit then rejoin(hit) break end
		end
	end)
end
runtimeEnv.__NasaV1IdentityGetter = runtimeEnv.getthreadidentity
or runtimeEnv.get_thread_identity
or runtimeEnv.getidentity
or runtimeEnv.getthreadcontext
or runtimeEnv.get_thread_context
runtimeEnv.__NasaV1IdentitySetter = runtimeEnv.setthreadidentity
or runtimeEnv.set_thread_identity
or runtimeEnv.setidentity
or runtimeEnv.setthreadcontext
or runtimeEnv.set_thread_context
do
	local setter = runtimeEnv.__NasaV1IdentitySetter
	if type(setter) == "function" then
		pcall(setter, 8)
		runtimeEnv.__NasaV1UICapabilityIdentity = 8
	end
	local setCap = rawget(_G, "setfpscap") or rawget(_G, "set_fps_cap") or (type(setfpscap) == "function" and setfpscap)
	runtimeEnv.__NasaV1SetCapFps = function(num)
		local target = tonumber(num) or 240
		target = math.clamp(math.floor(target), 1, 1000)
		local fn = rawget(_G, "setfpscap") or rawget(_G, "set_fps_cap") or (type(setfpscap) == "function" and setfpscap)
		if type(fn) == "function" then
			return pcall(fn, target)
		end
		return false
	end
end
if type(runtimeEnv.__NasaV1TweenRuntimeCleanup) == "function" then
	pcall(runtimeEnv.__NasaV1TweenRuntimeCleanup)
end
if type(runtimeEnv.__NasaV1EggRuntimeCleanup) == "function" then
	pcall(runtimeEnv.__NasaV1EggRuntimeCleanup)
end
if type(runtimeEnv.__NasaV1AntiGuardCleanup) == "function" then
	pcall(runtimeEnv.__NasaV1AntiGuardCleanup)
end
runtimeEnv.__NasaV1TweenRuntimeGeneration = (runtimeEnv.__NasaV1TweenRuntimeGeneration or 0) + 1
__NH_T.tweenRuntimeGeneration = runtimeEnv.__NasaV1TweenRuntimeGeneration
local SPOOF_CFG = {
	KEY = "__NasaV1StealAnEggMovementSpoof",
	VERSION = 436,
	INTEGRITY_KEY = "__NasaV1StealAnEggIntegritySpoof",
	SIGNAL = "ClientCharacter: GetDebugSnapshot",
	HEADROOM = 1.35,
	CLAMP = 0.15,
	PADDING = 24,
	MULTIPLIER = 10,
	MIN_INPUT = 20,
	MAX_INPUT = 100,
	DEF_INPUT = 60,
	MIN_SPEED = 200,
	MAX_SPEED = 1000,
	DEF_SPEED = 600,
	FIELDS = {
		"LastObservedSample", "LastSample", "LastGoodSample",
		"LastGameplayTrustedSample", "LastValidatedSample",
		"LastValidatedGroundedSample", "LastConfirmedGroundSample",
		"CandidateGroundedSample"
	}
}
local MOVEMENT_SPOOF_KEY = SPOOF_CFG.KEY
local MOVEMENT_SPOOF_VERSION = SPOOF_CFG.VERSION
local INTEGRITY_SPOOF_KEY = SPOOF_CFG.INTEGRITY_KEY
__NH_T.INTEGRITY_SIGNAL_NAME = SPOOF_CFG.SIGNAL
local INTEGRITY_SPEED_HEADROOM = SPOOF_CFG.HEADROOM
__NH_T.LONG_FRAME_CLAMP = SPOOF_CFG.CLAMP
__NH_T.MOVEMENT_BASELINE_PADDING = SPOOF_CFG.PADDING
__NH_T.MOVEMENT_SPEED_MULTIPLIER = SPOOF_CFG.MULTIPLIER
__NH_T.MIN_MOVEMENT_SPEED_INPUT = SPOOF_CFG.MIN_INPUT
__NH_T.MAX_MOVEMENT_SPEED_INPUT = SPOOF_CFG.MAX_INPUT
__NH_T.DEFAULT_MOVEMENT_SPEED_INPUT = SPOOF_CFG.DEF_INPUT
local MIN_MOVEMENT_SPEED = SPOOF_CFG.MIN_SPEED
local MAX_MOVEMENT_SPEED = SPOOF_CFG.MAX_SPEED
local DEFAULT_MOVEMENT_SPEED = SPOOF_CFG.DEF_SPEED
__NH_T.INTEGRITY_SAMPLE_FIELDS = SPOOF_CFG.FIELDS
local _fpsEstimate = 60
do
	local RunService = game:GetService("RunService")
	RunService.Heartbeat:Connect(function(dt)
		if dt and dt > 0 then
			_fpsEstimate = _fpsEstimate * 0.9 + (1 / dt) * 0.1
		end
	end)
end
function __NH_T.currentFps() return _fpsEstimate end
runtimeEnv.__NasaV1NetPing = function()
	local ms = 0
	pcall(function() ms = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
	return tonumber(ms) or 0
end
local HOVER_PAD_SIZE_XZ = 8
local HOVER_PAD_THICKNESS = 1
local HOVER_PAD_NAME = "__NasaV1HoverPad"
local HOVER_PAD_OWNER_ATTRIBUTE = "NasaV1RuntimeOwner"
local hoverPadInstance = nil
local hoverPadOwnerId = tostring(math.random(100000, 999999))
local hoverPadConnection = nil
local hoverPadPostConnection = nil
local activeMoves = {}
local tweenArrivalHold = nil

__NH_T.speedDialStuds = nil
local function purgeOrphanHoverPads()
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("BasePart") and obj.Name == HOVER_PAD_NAME and obj ~= hoverPadInstance then
			pcall(obj.Destroy, obj)
		end
	end
end
local function syncHoverPad(targetPos)
	if not hoverPadInstance or not hoverPadInstance.Parent then return false end
	local character = LP.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return false end
	local rootPosition = typeof(targetPos) == "Vector3" and targetPos or root.Position
	local feetOffset = humanoid.RigType == Enum.HumanoidRigType.R15
	and (root.Size.Y * 0.5 + math.max(humanoid.HipHeight, 0.5))
	or (root.Size.Y * 0.5 + 2)
	hoverPadInstance.CFrame = CFrame.new(
		rootPosition.X,
		rootPosition.Y - feetOffset - HOVER_PAD_THICKNESS * 0.5 - 0.05,
		rootPosition.Z
	)
	return true
end
local function startHoverPad()
	if not hoverPadInstance or not hoverPadInstance.Parent or hoverPadInstance:GetAttribute(HOVER_PAD_OWNER_ATTRIBUTE) ~= hoverPadOwnerId then
		purgeOrphanHoverPads()
		if hoverPadInstance and hoverPadInstance.Parent then pcall(hoverPadInstance.Destroy, hoverPadInstance) end
		local part = Instance.new("Part")
		part.Name = HOVER_PAD_NAME
		part:SetAttribute(HOVER_PAD_OWNER_ATTRIBUTE, hoverPadOwnerId)
		part.Anchored = true
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Material = Enum.Material.SmoothPlastic
		part.Size = Vector3.new(HOVER_PAD_SIZE_XZ, HOVER_PAD_THICKNESS, HOVER_PAD_SIZE_XZ)
		hoverPadInstance = part
		part.Parent = Workspace
	end
	syncHoverPad()
	if not hoverPadConnection then
		hoverPadConnection = RunService.PreSimulation:Connect(function()
			if not syncHoverPad() then startHoverPad() end
			end)
	end
	if not hoverPadPostConnection then
		hoverPadPostConnection = RunService.PostSimulation:Connect(function()
			syncHoverPad()
			end)
	end
end
local function stopHoverPad()
	if hoverPadConnection then
		pcall(hoverPadConnection.Disconnect, hoverPadConnection)
		hoverPadConnection = nil
	end
	if hoverPadPostConnection then
		pcall(hoverPadPostConnection.Disconnect, hoverPadPostConnection)
		hoverPadPostConnection = nil
	end
	if hoverPadInstance then
		pcall(hoverPadInstance.Destroy, hoverPadInstance)
		hoverPadInstance = nil
	end
	purgeOrphanHoverPads()
end
stopHoverPad()
local function clearTweenArrivalHold()
	tweenArrivalHold = nil
end
function __NH_T.setTweenArrivalHold(root, destination)
	if root and typeof(destination) == "CFrame" then
		tweenArrivalHold = {
			Character = LP.Character,
			RootPart = root,
			CFrame = destination,
		}
	end
end
function __NH_T.enforceTweenArrivalHold()
	local hold = tweenArrivalHold
	if type(hold) ~= "table" or typeof(hold.CFrame) ~= "CFrame" then return false end
	if LP.Character ~= hold.Character or not hold.RootPart or not hold.RootPart.Parent then
		tweenArrivalHold = nil
		return false
	end
	startHoverPad()
	hold.RootPart.AssemblyLinearVelocity = Vector3.zero
	hold.RootPart.AssemblyAngularVelocity = Vector3.zero
	syncHoverPad(hold.CFrame.Position)
	hold.RootPart.CFrame = hold.CFrame
	syncHoverPad(hold.CFrame.Position)
	return true
end
function __NH_T.stopAllActiveMovements()
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for _, move in pairs(activeMoves) do
		if type(move) == "table" then
			move.cancelled = true
		end
	end
	table.clear(activeMoves)
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	clearTweenArrivalHold()
	stopHoverPad()
end
runtimeEnv.__NasaV1TweenRuntimeCleanup = function()
	for _, move in pairs(activeMoves) do
		if type(move) == "table" then move.cancelled = true end
	end
	table.clear(activeMoves)
	clearTweenArrivalHold()
	stopHoverPad()
end
local function environment()
	return getgenv and getgenv() or _G
end
function __NH_T.getMovementSpoof()
	local env = environment()
	local existing = env[MOVEMENT_SPOOF_KEY]
	if type(existing) ~= "table" or existing.Version ~= MOVEMENT_SPOOF_VERSION then
		if type(existing) == "table" then existing.Enabled = false end
		existing = {
			Version = MOVEMENT_SPOOF_VERSION,
			Installed = false,
			Enabled = false,
			Mode = "StateBaseline",
			Humanoid = nil,
			RootPart = nil,
			WalkSpeed = DEFAULT_MOVEMENT_SPEED,
		}
		env[MOVEMENT_SPOOF_KEY] = existing
	end
	return existing
end
local function setMovementSpoof(character, speed)
	local holder = __NH_T.getMovementSpoof()
	if not holder then return false end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	holder.Humanoid = humanoid
	holder.RootPart = root
	holder.WalkSpeed = math.clamp(
		tonumber(speed) or DEFAULT_MOVEMENT_SPEED,
		MIN_MOVEMENT_SPEED,
		MAX_MOVEMENT_SPEED * INTEGRITY_SPEED_HEADROOM
	)
	holder.Enabled = false
	return humanoid ~= nil and root ~= nil
end
function __NH_T.clearMovementSpoof()
	local holder = environment()[MOVEMENT_SPOOF_KEY]
	if type(holder) == "table" then
		holder.Enabled = false
		holder.Humanoid = nil
		holder.RootPart = nil
	end
end
function __NH_T.findIntegrityStateNow(player, humanoid, root)
	local found = nil
	if type(getcallbackvalue) == "function" and type(debug) == "table" and type(debug.getupvalue) == "function" then
		local signalModule = ReplicatedStorage:FindFirstChild("Packages")
		and ReplicatedStorage.Packages:FindFirstChild("Signal")
		if signalModule then
			local okSig, Signal = pcall(require, signalModule)
			if okSig and type(Signal) == "table" and type(Signal.Invoked) == "function" then
				local okBind, bindable = pcall(Signal.Invoked, __NH_T.INTEGRITY_SIGNAL_NAME)
				if okBind and bindable then
					local okCb, callback = pcall(getcallbackvalue, bindable, "OnInvoke")
					if okCb and type(callback) == "function" then
						local okInfo, info = pcall(debug.getinfo, callback)
						if okInfo then
							local function scan(value, depth, seen)
								if found or type(value) ~= "table" or depth > 3 or seen[value] then return end
								seen[value] = true
								if rawget(value, "Player") == player
								and rawget(value, "Character") == player.Character
								and rawget(value, "Humanoid") == humanoid
								and rawget(value, "RootPart") == root
								and type(rawget(value, "SampleHistory")) == "table"
								and type(rawget(value, "Evidence")) == "table"
								then
									found = value
									return
								end
								local scanned = 0
								for _, child in pairs(value) do
									scanned = scanned + 1
									if scanned > 128 then break end
									if type(child) == "table" then scan(child, depth + 1, seen) end
								end
							end
							for idx = 1, info.nups or 0 do
								local okUp, upvalue = pcall(debug.getupvalue, callback, idx)
								if okUp and type(upvalue) == "table" then
									scan(upvalue, 0, {})
									if found then break end
								end
							end
						end
					end
				end
			end
		end
	end
	if not found and type(getgc) == "function" then
		local okGc, objects = pcall(getgc, true)
		if okGc and type(objects) == "table" then
			for _, obj in ipairs(objects) do
				if type(obj) == "table"
				and rawget(obj, "Player") == player
				and rawget(obj, "Character") == player.Character
				and rawget(obj, "Humanoid") == humanoid
				and rawget(obj, "RootPart") == root
				and type(rawget(obj, "SampleHistory")) == "table"
				and type(rawget(obj, "Evidence")) == "table"
				then
					found = obj
					break
				end
			end
		end
	end
	return found
end
local integrityScanTop = { busy = false, nextAt = 0, misses = 0, found = nil }
function __NH_T.findIntegrityState(player, humanoid, root)
	local cached = integrityScanTop.found
	if type(cached) == "table"
	and rawget(cached, "Player") == player
	and rawget(cached, "Character") == player.Character
	and rawget(cached, "Humanoid") == humanoid
	and rawget(cached, "RootPart") == root
	then
		return cached
	end
	if integrityScanTop.busy or os.clock() < integrityScanTop.nextAt then
		return nil
	end
	integrityScanTop.busy = true
	task.spawn(function()
		task.wait()
		local ok, found = pcall(__NH_T.findIntegrityStateNow, player, humanoid, root)
		found = ok and found or nil
		integrityScanTop.found = found
		integrityScanTop.misses = found and 0 or integrityScanTop.misses + 1
		integrityScanTop.nextAt = os.clock() + (found and 0.2 or (integrityScanTop.misses >= 5 and 10 or 1))
		integrityScanTop.busy = false
		end)
	return nil
end
local function patchIntegrityState(state, speed, travelVelocity)
	if type(state) ~= "table" then return false end
	local root = rawget(state, "RootPart")
	local rootCFrame = root and root.Parent and root.CFrame or nil
	local rootPosition = rootCFrame and rootCFrame.Position or nil
	local coherentVelocity = typeof(travelVelocity) == "Vector3" and travelVelocity or Vector3.zero
	local function patchSample(sample)
		if type(sample) == "table" then
			rawset(sample, "WalkSpeed", speed)
			if rootCFrame then
				rawset(sample, "CFrame", rootCFrame)
				rawset(sample, "Position", rootPosition)
				rawset(sample, "LinearVelocity", coherentVelocity)
				rawset(sample, "AngularVelocity", Vector3.zero)
			end
		end
	end
	for _, field in ipairs(__NH_T.INTEGRITY_SAMPLE_FIELDS) do
		patchSample(rawget(state, field))
	end
	for _, sample in pairs(rawget(state, "SampleHistory") or {}) do
		patchSample(sample)
	end
	for _, sample in pairs(rawget(state, "SafeGroundCheckpoints") or {}) do
		patchSample(sample)
	end
	local evidence = rawget(state, "Evidence")
	if type(evidence) == "table" then
		evidence.Speed = 0
		evidence.Teleport = 0
		evidence.Flight = 0
	end
	local impulse = rawget(state, "ImpulseContext")
	if type(impulse) == "table" then
		local horizontalSpeed = math.max(tonumber(impulse.MaxHorizontalSpeed) or 0, speed)
		local duration = math.max(
			(tonumber(impulse.ExpiresAt) or 0) - (tonumber(impulse.StartedAt) or 0),
			__NH_T.LONG_FRAME_CLAMP
		)
		impulse.MaxHorizontalSpeed = horizontalSpeed
		if rootPosition then impulse.OriginPosition = rootPosition end
		impulse.MaxHorizontalDistance = math.max(
			tonumber(impulse.MaxHorizontalDistance) or 0,
			horizontalSpeed * duration + __NH_T.MOVEMENT_BASELINE_PADDING * 2
		)
		patchSample(impulse.PreMovementSafeSample)
	end
	if rawget(state, "CorrectionContext") == nil then
		rawset(state, "FirstSuspiciousAt", nil)
		if rawget(state, "ThreatLevel") == "Observing" then
			rawset(state, "ThreatLevel", "Trusted")
		end
	end
	return true
end
function __NH_T.getIntegritySpoof()
	local env = environment()
	local holder = env[INTEGRITY_SPOOF_KEY]
	if type(holder) ~= "table" then
		holder = {}
		env[INTEGRITY_SPOOF_KEY] = holder
	end
	return holder
end
local function integrityStateMatches(state, humanoid, root)
	return type(state) == "table"
	and rawget(state, "Player") == LP
	and rawget(state, "Character") == LP.Character
	and rawget(state, "Humanoid") == humanoid
	and rawget(state, "RootPart") == root
end
local function integrityStateCanTravel(state, humanoid, root)
	return integrityStateMatches(state, humanoid, root)
end
local function setIntegritySpoof(humanoid, root, speed)
	local holder = __NH_T.getIntegritySpoof()
	local state = holder.State
	if not integrityStateMatches(state, humanoid, root) then
		local now = os.clock()
		if now < (holder.NextSearchAt or 0) then return false end
		holder.NextSearchAt = now + 0.2
		state = __NH_T.findIntegrityState(LP, humanoid, root)
	end
	if not state then
		return false
	end
	if not integrityStateCanTravel(state, humanoid, root) then
		holder.Enabled = false
		holder.Humanoid = humanoid
		holder.RootPart = root
		holder.State = state
		return false
	end
	holder.NextSearchAt = 0
	holder.Enabled = true
	holder.Humanoid = humanoid
	holder.RootPart = root
	holder.State = state
	holder.WalkSpeed = math.clamp(
		speed * INTEGRITY_SPEED_HEADROOM,
		MIN_MOVEMENT_SPEED,
		MAX_MOVEMENT_SPEED * INTEGRITY_SPEED_HEADROOM
	)
	holder.TravelVelocity = Vector3.zero
	patchIntegrityState(state, holder.WalkSpeed, holder.TravelVelocity)
	return true
end
local function refreshIntegritySpoof(humanoid, root, speed, travelVelocity)
	local holder = environment()[INTEGRITY_SPOOF_KEY]
	if type(holder) ~= "table"
	or not holder.Enabled
	or holder.Humanoid ~= humanoid
	or holder.RootPart ~= root
	or not integrityStateCanTravel(holder.State, humanoid, root)
	then
		return false
	end
	holder.WalkSpeed = math.clamp(
		speed * INTEGRITY_SPEED_HEADROOM,
		MIN_MOVEMENT_SPEED,
		MAX_MOVEMENT_SPEED * INTEGRITY_SPEED_HEADROOM
	)
	if typeof(travelVelocity) == "Vector3" then
		holder.TravelVelocity = travelVelocity
	elseif typeof(holder.TravelVelocity) ~= "Vector3" then
		holder.TravelVelocity = Vector3.zero
	end
	return patchIntegrityState(holder.State, holder.WalkSpeed, holder.TravelVelocity)
end
function __NH_T.clearIntegritySpoof(humanoid)
	local holder = environment()[INTEGRITY_SPOOF_KEY]
	if type(holder) ~= "table" then return end
	if humanoid == nil or holder.Humanoid == humanoid then
		holder.Enabled = false
		holder.Humanoid = nil
		holder.RootPart = nil
		holder.State = nil
		holder.TravelVelocity = nil
		holder.NextSearchAt = 0
	end
end
local globalIntegrityConnection = nil
function __NH_T.startGlobalMovementProtection()
	if globalIntegrityConnection then return end
	globalIntegrityConnection = RunService.PreSimulation:Connect(function()
		if runtimeEnv.__NasaV1TweenRuntimeGeneration ~= __NH_T.tweenRuntimeGeneration then
			local staleConnection = globalIntegrityConnection
			globalIntegrityConnection = nil
			if staleConnection then pcall(staleConnection.Disconnect, staleConnection) end
			return
		end
		local char = LP.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not root or not hum then return end
		local targetSpeed = __NH_T.speedDialStuds()
		setMovementSpoof(char, targetSpeed * INTEGRITY_SPEED_HEADROOM)
		if not refreshIntegritySpoof(hum, root, targetSpeed) then
			setIntegritySpoof(hum, root, targetSpeed)
		end
		__NH_T.enforceTweenArrivalHold()
		end)
end
function __NH_T.stopGlobalMovementProtection()
	if globalIntegrityConnection then
		pcall(globalIntegrityConnection.Disconnect, globalIntegrityConnection)
		globalIntegrityConnection = nil
	end
	__NH_T.clearMovementSpoof()
	__NH_T.clearIntegritySpoof()
end
runtimeEnv.__NasaV1TweenRuntimeCleanup = function()
	__NH_T.stopAllActiveMovements()
	__NH_T.stopGlobalMovementProtection()
end
RunService.Heartbeat:Connect(function()
	local character = LP.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local velocity = root.AssemblyLinearVelocity
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local ws = humanoid and humanoid.WalkSpeed or 0
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontal.Magnitude > math.max(400, ws * 1.5) or math.abs(velocity.Y) > 400 then
		local cap = math.max(100, ws)
		if horizontal.Magnitude > cap then horizontal = horizontal.Unit * cap end
		root.AssemblyLinearVelocity = Vector3.new(horizontal.X, math.clamp(velocity.Y, -100, 100), horizontal.Z)
	end
	end)

pcall(function()
	local queueFunc = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
	if queueFunc then
		pcall(queueFunc, "")
	end
	end)
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
local zombieHealthConnection = nil
local zombiePinnerConnection = nil
local function enableFullZombieMode(character)
	if not character then return end
	local hum = character:WaitForChild("Humanoid", 5) or character:FindFirstChildOfClass("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart", 5) or character:FindFirstChild("HumanoidRootPart")
	if not hum then return end
	local maxHp = math.max(hum.MaxHealth, 100)
	local repairing = false
	local lastRepairAt = 0
	local function repair()
		if repairing or not hum.Parent then return end
		local now = os.clock()
		if now - lastRepairAt < 0.1 and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
			return
		end
		lastRepairAt = now
		repairing = true
		pcall(function()
			hum.BreakJointsOnDeath = false
			hum.RequiresNeck = false
			hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			if hum.Health <= 0 then
				hum.Health = maxHp
			end
			if hum:GetState() == Enum.HumanoidStateType.Dead then
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end
			end)
		repairing = false
	end
	repair()
	if zombieHealthConnection then pcall(zombieHealthConnection.Disconnect, zombieHealthConnection) end
	if zombiePinnerConnection then pcall(zombiePinnerConnection.Disconnect, zombiePinnerConnection) end
	zombieHealthConnection = hum.HealthChanged:Connect(function(health)
		if health <= 0 or health < maxHp then repair() end
		end)
	zombiePinnerConnection = RunService.Heartbeat:Connect(repair)
end
task.spawn(function()
	local char = LP.Character or LP.CharacterAdded:Wait()
	enableFullZombieMode(char)
	end)
LP.CharacterAdded:Connect(function(char)
	enableFullZombieMode(char)
	end)
	
--------------------------------------------------------------------
-- 可修改设置
--------------------------------------------------------------------
local Cfg = {
    Name = "NASA-Hub",
    Game = "Steal An Egg",                    -- 只是备用：平时会自动读取你进入的游戏名
    AutoGameName = true,                      -- true：自动读取游戏名字
    IntroBall = true,                         -- 开场动画 logo 外面的圆形底（false = 只有 logo，没有圆）
    Blink = true,                             -- NASA-Hub 扫光动画（从 1NasaHub 搬过来的）
    BlinkTime = 2.4,                          -- 光扫过文字一次的时间（秒，越小越快）
    Version = "V1.0",
    HeaderLink = "https://discord.gg/XyWHF2wnw",   -- 顶栏最左边显示的链接（填 "" 则不显示）
    Status = "Working",                         -- 顶部状态胶囊的文字
    Logo = "rbxassetid://106265792665809",    -- Logo 不变
    LogoSize = 48,
    LogoPos = UDim2.fromOffset(24, 62),
    Width = 992, Height = 540,                -- 宽度 = 侧边栏 + 空隙 + 右边面板
    MinW = 872, MinH = 450, MaxW = 1312, MaxH = 820,
    SidebarW = 200,                           -- 左侧栏宽度
    PanelGap = 12,                            -- 左右两块面板中间的空隙
    RightLogoId = "rbxassetid://76640105530094",   -- UI 右边的大 Logo（填 "" 则不显示）
    RightLogoSize = 520,
    RightLogoTransparency = 0.45,                  -- 越大越淡
    SafeTop = 56,
    HeaderH = 58,                             -- 顶部栏高度
    FpsCap = 120,                             -- 帧率上限（需要执行器支持 setfpscap；UI Settings 里可改）
    TabSlideTime = 0.45,                      -- 左边选中框滑动的时间（秒）
    OpenAnim = true,                          -- 点 Logo 打开 / 关闭 UI 时的缩放动画（true = 有动画）
    ToggleKey = Enum.KeyCode.RightShift,
    GhostColor = Color3.fromRGB(46, 230, 190),   -- 移动 UI 时的青色框颜色
    MoveTime = 0.5,                              -- 松手后面板滑到青色框的时间（秒）

    HUD = true, HudSub = "NASA-Studio", Badge = "Free",
    HudStyle = "Classic",                        -- 顶部状态样式："Classic" = 原来的小条；"Dynamic Island" = 灵动岛（UI Settings → HUD style 可随时切换）
    Debug = false,                               -- true = 在控制台显示 [NASA-Hub] 的日志；false = 安静
    BetterFont = true,                           -- 统一换成更清晰的 Builder Sans 字体（false = 还原 Gotham）
    TikTok = "https://www.tiktok.com/@your_account",
    Discord = "https://discord.gg/your_invite",

    Music = { {name = "3 Strikes", id = ""} },
    MusicVolume = 0.5,

    -- 下拉选项列表（想改名字直接改这里）
    Zones = {"Forest", "Lake", "Desert", "Jungle", "Snow", "Volcano", "Abyss Ocean", "Prehistoric", "Cosmic", "Cherry Blossom", "Titan Temple", "Light Dark", "Angels & Demons", "Enchanted Forest"},
    Mutations = {"Gold", "Diamond", "Rainbow", "Shiny", "Frozen", "Electric"},
    Rarities = {"Transcendent", "Prismatic", "Divine", "Eternal", "Secret", "Cosmic", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common"},
    Eggs = {"Common Egg", "Rare Egg", "Epic Egg", "Legendary Egg", "Mythic Egg"},

    UpdateLog = {
        "V5: bigger right logo and bigger text",
        "V5: pages are cached, Main opens without lag",
        "V5: NASA-Hub shine taken from 1NasaHub",
        "V5: sidebar selector slides smoothly",
        "V5: FPS cap option in UI Settings",
    },
}

--------------------------------------------------------------------
-- 颜色
--------------------------------------------------------------------
local HEADER_H = Cfg.HeaderH or 58

local C = {
    bg = Color3.fromRGB(16, 16, 18),
    bg2 = Color3.fromRGB(11, 11, 13),
    card = Color3.fromRGB(22, 22, 25),
    field = Color3.fromRGB(30, 30, 34),
    pill = Color3.fromRGB(34, 34, 39),
    pillOn = Color3.fromRGB(52, 52, 58),
    line = Color3.fromRGB(38, 38, 43),
    stroke = Color3.fromRGB(46, 46, 52),
    text = Color3.fromRGB(255, 255, 255),
    sub = Color3.fromRGB(150, 150, 158),
    mid = Color3.fromRGB(205, 205, 212),
    off = Color3.fromRGB(56, 56, 62),
    good = Color3.fromRGB(110, 235, 130),
    ok = Color3.fromRGB(255, 205, 90),
    bad = Color3.fromRGB(255, 90, 90),
    orange = Color3.fromRGB(255, 170, 60),
    green = Color3.fromRGB(70, 205, 140),
}

--------------------------------------------------------------------
-- 多语言
--------------------------------------------------------------------
local lang = "en"
__NH_T.ZH = {
    ["Home"] = "主页", ["Steal"] = "偷蛋", ["Garden"] = "花园", ["Pets"] = "宠物", ["Player"] = "玩家", ["Settings"] = "设置",
    ["Auto Steal"] = "自动偷蛋", ["Egg Predictor"] = "蛋预测", ["Events"] = "活动", ["Private Server"] = "私人服务器",
    ["Interface"] = "界面", ["Music"] = "音乐",
    ["Welcome Back"] = "欢迎回来", ["Server"] = "服务器", ["Update Log"] = "更新日志", ["Automation"] = "自动化",
    ["Filter"] = "过滤", ["Profile"] = "资料", ["Stats"] = "数据", ["Server Tools"] = "服务器工具", ["Community"] = "社区",
    ["Changes"] = "更新内容", ["Predictor"] = "预测", ["Egg Values"] = "蛋价值", ["Auto"] = "自动", ["Options"] = "选项",
    ["Pet Tools"] = "宠物工具", ["Event Tools"] = "活动工具", ["Join"] = "加入", ["General"] = "常规", ["System"] = "系统",
    -- Steal 页面
    ["Auto steal"] = "自动偷蛋", ["Move to egg"] = "移动到蛋", ["Delivery method"] = "运送方式", ["Teleport zones"] = "传送区域",
    ["Steal missing index eggs"] = "偷缺失图鉴的蛋", ["Steal from other players"] = "偷其他玩家的蛋", ["Anti guard"] = "反守卫",
    ["Drop eggs at safe zone"] = "在安全区放下蛋", ["Zones"] = "区域", ["Steal first"] = "优先偷", ["Mutations"] = "变异",
    ["Rarities"] = "稀有度", ["Only these eggs"] = "只偷这些蛋", ["Min value /s"] = "最低价值 /秒",
    ["Sell cheapest egg when bag is full"] = "背包满时卖掉最便宜的蛋", ["Only below /s"] = "只偷低于 /秒",
    ["Teleport"] = "传送", ["Walk"] = "走路", ["Tween"] = "缓动", ["Fast tween"] = "快速缓动", ["Best value"] = "最高价值",
    ["Closest"] = "最近", ["Cheapest"] = "最便宜", ["Random"] = "随机", ["None"] = "无", ["Off"] = "关",
    -- Egg Predictor
    ["Enable predictor"] = "启用预测", ["Notify on rare egg"] = "稀有蛋提醒", ["Min rarity"] = "最低稀有度", ["Refresh list"] = "刷新列表",
    ["Refresh"] = "刷新", ["Eggs"] = "蛋", ["Total"] = "总计", ["Loading..."] = "读取中...", ["No eggs found"] = "没有找到蛋",
    ["Egg data isn't available in this game"] = "这个游戏里读不到蛋的数据", ["Couldn't read eggs, try Refresh"] = "读取失败，请点刷新重试",
    -- Garden / Pets / Player
    ["Auto Farm"] = "自动刷", ["Auto Collect"] = "自动收集", ["Auto Rebirth"] = "自动重生", ["Auto Upgrade"] = "自动升级",
    ["Delay"] = "延迟", ["Mode"] = "模式", ["Normal"] = "正常", ["Fast"] = "快速", ["Safe"] = "安全",
    ["Notifications"] = "通知", ["Custom Value"] = "自定义值", ["Enter value"] = "输入数值", ["Apply Settings"] = "应用设置", ["Apply"] = "应用",
    ["Pet Viewer"] = "宠物查看", ["Pet Filter"] = "宠物过滤", ["Pet ESP"] = "宠物透视",
    ["Event Info"] = "活动信息", ["Event Rewards"] = "活动奖励", ["Event Timer"] = "活动计时",
    ["Server code"] = "服务器代码", ["Join Server"] = "加入服务器", ["Create Server"] = "创建服务器", ["Server List"] = "服务器列表", ["Open"] = "打开",
    -- Settings
    ["Language"] = "语言", ["Show FPS / Ping"] = "显示 FPS / Ping", ["Show floating logo"] = "显示悬浮 Logo", ["UI scale"] = "界面大小",
    ["Toggle key"] = "开关快捷键", ["Unload UI"] = "关闭并卸载 UI", ["Unload"] = "卸载",
    ["Weather"] = "天气", ["Snow"] = "雪天", ["Meteor"] = "流星", ["Enable Snow"] = "启用雪天", ["Enable Meteor"] = "启用流星",
    ["Snow Amount"] = "雪花数量", ["Fall Speed"] = "下落速度", ["Snow Size"] = "雪花大小", ["Wind"] = "风力",
    ["Meteor Amount"] = "流星数量", ["Meteor Speed"] = "流星速度", ["Tail Length"] = "尾巴长度", ["Background Stars"] = "背景星星",
    ["Cyan move frame"] = "青色移动框",
    ["Select Song"] = "选择歌曲", ["Play Music"] = "播放音乐", ["Volume"] = "音量", ["Loop"] = "循环播放", ["Custom Music ID"] = "自定义音乐 ID",
    ["Enter audio ID, press Enter"] = "输入音频 ID 后回车", ["Add a song ID in Settings > Music"] = "请先在 Settings > Music 里填歌曲 ID",
    -- Home
    ["Hide name"] = "隐藏名字", ["Hide avatar"] = "隐藏头像", ["FPS"] = "FPS", ["Ping"] = "Ping", ["Players"] = "玩家数", ["Session"] = "在线时长",
    ["Rejoin"] = "重新加入", ["Server Hop"] = "换服", ["Hop"] = "换服", ["Copy Job ID"] = "复制 Job ID", ["Copy"] = "复制",
    ["TikTok"] = "TikTok", ["Discord"] = "Discord", ["Rejoining..."] = "正在重新加入...", ["Searching servers..."] = "正在寻找服务器...",
    ["No server found"] = "没有找到服务器", ["Teleport failed"] = "传送失败", ["Job ID copied"] = "Job ID 已复制", ["Can't copy"] = "无法复制",
    ["Link copied"] = "链接已复制", ["Link not set"] = "还没设置链接", ["Not available"] = "暂不可用",
    ["Search"] = "搜索", ["Free"] = "免费", ["Ready"] = "就绪", ["Working"] = "运行中",
    ["Admin Abuse"] = "管理员功能", ["Main"] = "主要", ["UI Settings"] = "UI 设定", ["Admin Tools"] = "管理员工具",
    ["Option 1"] = "选项 1", ["Option 2"] = "选项 2", ["Option 3"] = "选项 3",
    ["Egg Filter"] = "蛋过滤", ["Egg ESP"] = "蛋透视", ["Steal Webhook"] = "偷蛋 Webhook",
    ["Safety"] = "安全", ["Range"] = "范围", ["Steal Delay"] = "偷蛋延迟", ["Steal Rare Only"] = "只偷稀有",
    ["Teleport Back"] = "偷完传回", ["Stop When Full"] = "背包满时停止", ["Steal Now"] = "立即偷蛋", ["Now"] = "立即",
    ["Rarity"] = "稀有度", ["Sort"] = "排序", ["Sort By"] = "排序方式", ["Reset Filter"] = "重置过滤", ["Reset"] = "重置",
    ["Value"] = "价值", ["Distance"] = "距离", ["Common"] = "普通", ["Rare"] = "稀有", ["Epic"] = "史诗", ["Legendary"] = "传说", ["Mythic"] = "神话",
    ["Display"] = "显示", ["Enable ESP"] = "启用透视", ["Show Name"] = "显示名字", ["Show Distance"] = "显示距离", ["Show Rarity"] = "显示稀有度",
    ["Max Distance"] = "最远距离", ["Text Size"] = "文字大小", ["Style"] = "样式", ["Box"] = "方框", ["Outline"] = "轮廓", ["Tracer"] = "射线",
    ["Webhook"] = "Webhook", ["Enable Webhook"] = "启用 Webhook", ["Webhook URL"] = "Webhook 链接", ["Include Egg Info"] = "包含蛋信息",
    ["Mention User"] = "提及用户", ["Message Type"] = "消息类型", ["Embed"] = "嵌入", ["Plain Text"] = "纯文本",
    ["Send Test Message"] = "发送测试消息", ["Send"] = "发送",
    ["Header: blinking NASA-Hub + auto game name"] = "顶部：闪烁的 NASA-Hub + 自动游戏名",
    ["Sidebar rebuilt with icons and labels"] = "侧边栏改成图标加文字",
    ["Features regrouped like 1NasaHub"] = "功能按 1NasaHub 重新分类",
    ["V5: bigger right logo and bigger text"] = "V5：右边 Logo 放大，文字放大",
    ["V5: pages are cached, Main opens without lag"] = "V5：页面缓存，打开 Main 不再卡顿",
    ["V5: NASA-Hub shine taken from 1NasaHub"] = "V5：NASA-Hub 扫光动画来自 1NasaHub",
    ["V5: sidebar selector slides smoothly"] = "V5：左边选中框平滑滑动",
    ["V5: FPS cap option in UI Settings"] = "V5：UI Settings 里新增帧率上限",
    ["FPS cap"] = "帧率上限", ["Reduce effects"] = "减少特效", ["Unlimited"] = "无限制",
}

local function T(s)
    if lang ~= "zh" or type(s) ~= "string" then return s end
    return __NH_T.ZH[s] or s
end

-- ===== 功能代码：脚本运行时自动从 GitHub 下载并执行（原 875-20171 行）=====
-- 功能代码末尾缺失的部分（自动放蛋 / 孵化 / 突变 / 环活动 / 卖宠物 / 卖蛋），下载后拼在功能代码后面
__NH_T.TAIL_SRC = [==[
-- ===== NASA-Hub：功能代码末尾缺失的部分（自动放蛋 / 孵化 / 突变 / 环活动 / 卖宠物 / 卖蛋）=====
-- 由主文件拼在功能代码后面一起运行。这里只有逻辑，不含任何界面。
do
local okTail, errTail = pcall(function()
	local LocalPlayer = Players.LocalPlayer
	local function withoutNone(list)
		local out = {}
		for _, value in ipairs(type(list) == "table" and list or {}) do
			if value ~= "None" and value ~= "" then out[#out + 1] = value end
		end
		return out
	end
	if Config.MutationRetry == nil then Config.MutationRetry = true end
	if Config.MutationChoice == nil then Config.MutationChoice = "Scrambled" end
	-- 过滤列表直接读 Config，包成 readDropdownFilter 能读的样子
	local function listSource(key)
		return { GetValue = function() return Config[key] or {} end }
	end
	local sellNamesDropdown = listSource("SellNames")
	local sellRarityDropdown = listSource("SellRarities")
	local sellEggRarityDropdown = listSource("SellEggRarities")

	------------------------------------------------------------ 自动放蛋
	local placeStatus = ""
	local function placeRarityOf(record, Assets)
		local category = record.AssetCategory
		local categoryData = category and Assets.Directory[category]
		local rarity = "Unknown"
		if categoryData and categoryData.Rarity then
			local rObj = categoryData.Rarity
			rarity = rObj.DisplayName or rObj._id or rObj.Name or "Unknown"
		end
		return rarity, categoryData
	end
	local function placeRarityMatches(rarity)
		local list = Config.PlaceRarities or {}
		if #list == 0 or table.find(list, "None") or table.find(list, "All") then return true end
		return table.find(list, rarity) ~= nil
	end
	local function placeAllowed(uid)
		return not (type(NasaPanels.isPlaceEnabled) == "function" and NasaPanels.isPlaceEnabled(uid) == false)
	end
	local placeWantsCache = { at = 0, value = false }
	local function placeWants()
		if not Config.AutoPlace then return false end
		if Config.IsPlacing then return true end
		local now = os.clock()
		if now - placeWantsCache.at < 1 then return placeWantsCache.value end
		placeWantsCache.at = now
		local value = false
		pcall(function()
			local EggCmds = require(ReplicatedStorage.Client.EggState)
			local Assets = require(ReplicatedStorage.Data.Assets)
			local myEggs = EggCmds.GetOwnerRuntimeRecords(LocalPlayer.UserId)
			if type(myEggs) ~= "table" then return end
			local placed, waiting = 0, 0
			for uid, record in pairs(myEggs) do
				if record.Placement ~= nil then
					placed = placed + 1
				elseif placeAllowed(uid) and placeRarityMatches((placeRarityOf(record, Assets))) then
					waiting = waiting + 1
				end
			end
			value = waiting > 0 and placed < 30
		end)
		placeWantsCache.value = value
		return value
	end
	UIRunners.AutoPlaceLoop = function()
		if Config.IsAutoPlaceWorkerRunning then return end
		Config.IsAutoPlaceWorkerRunning = true
		while Config.AutoPlace and sessionAlive() do
			task.wait(1.5)
			local success, err = pcall(function()
				local EggCmds = require(ReplicatedStorage.Client.EggState)
				local Assets = require(ReplicatedStorage.Data.Assets)
				local myTruePlot = nil
				local plotsFolder = workspace:FindFirstChild("Plots")
				if plotsFolder then
					for _, p in ipairs(plotsFolder:GetChildren()) do
						local sign = p:FindFirstChild("PlotSign")
						if sign then
							local pSign = sign:FindFirstChild("PlayerPlotSign")
							if pSign and pSign:FindFirstChild("Frame") and pSign.Frame:FindFirstChild("PlayerName") then
								local rawText = pSign.Frame.PlayerName.Text
								local cleanText = string.gsub(rawText, "<[^>]+>", "")
								if string.find(string.lower(cleanText), string.lower(LocalPlayer.Name)) or string.find(string.lower(cleanText), string.lower(LocalPlayer.DisplayName)) then
									myTruePlot = p
									break
								end
							end
						end
					end
				end
				if not myTruePlot then
					placeStatus = "Looking for your plot"
					return
				end
				local ToUpdate = myTruePlot:FindFirstChild("ToUpdate")
				local PetArea = ToUpdate and ToUpdate:FindFirstChild("PetArea")
				local CenterPoint = myTruePlot:FindFirstChild("CenterPoint") or PetArea
				if not PetArea then return end
				local eggsToPlace = {}
				local myEggs = EggCmds.GetOwnerRuntimeRecords(LocalPlayer.UserId)
				local placedCount = 0
				if type(myEggs) == "table" then
					for uid, record in pairs(myEggs) do
						if record.Placement ~= nil then
							placedCount = placedCount + 1
						else
							local rarity, categoryData = placeRarityOf(record, Assets)
							local match = placeAllowed(uid) and placeRarityMatches(rarity)
							local kgVal = tonumber(record.Kg) or tonumber(record.Weight) or tonumber(record.kg)
							if not kgVal and categoryData then
								kgVal = tonumber(categoryData.Kg) or tonumber(categoryData.Weight) or tonumber(categoryData.kg)
							end
							kgVal = kgVal or 0
							if match then table.insert(eggsToPlace, { Uid = uid, Rarity = rarity, Kg = kgVal }) end
						end
					end
				end
				table.sort(eggsToPlace, function(a, b) return a.Kg > b.Kg end)
				local char = LocalPlayer.Character
				local hrp  = char and char:FindFirstChild("HumanoidRootPart")
				local hum  = char and char:FindFirstChildOfClass("Humanoid")
				local originalCF = nil
				if #eggsToPlace == 0 or placedCount >= 30 then
					placeStatus = #eggsToPlace == 0 and "No eggs to place" or "Plot full (30 placed)"
					return
				end
				local function higherPriorityWants() return TaskLadder.blocker("auto_place") ~= nil end
				if higherPriorityWants() then
					placeStatus = TaskLadder.yieldLabel("auto_place") or ""
					return
				end
				local holder = TaskLadder.holder("auto_place")
				if holder then
					placeStatus = "Waiting for " .. TaskLadder.TITLES[holder] .. " to hand over"
					return
				end
				Config.IsPlacing = true
				placeStatus = string.format("Placing %d egg%s", #eggsToPlace, #eggsToPlace == 1 and "" or "s")
				local treadmill = runtimeEnv.__NasaV1TreadmillManager
				if treadmill and treadmill.activeTreadmill ~= nil then
					local leaveDeadline = os.clock() + 5
					while treadmill.activeTreadmill ~= nil and os.clock() < leaveDeadline and not higherPriorityWants() do
						pcall(function() treadmill:_requestUnequip() end)
						task.wait(0.3)
					end
				end
				char = LocalPlayer.Character
				hrp = char and char:FindFirstChild("HumanoidRootPart")
				hum = char and char:FindFirstChildOfClass("Humanoid")
				if hrp and hrp.Anchored then pcall(function() hrp.Anchored = false end) end
				if hum then pcall(function() hum:UnequipTools() end) end
				if hrp then originalCF = hrp.CFrame end
				local function placeCancelled() return not Config.AutoPlace or higherPriorityWants() end
				if hrp and PetArea then
					local placeTargetCF = PetArea.CFrame * CFrame.new(0, 3, 0)
					local placePathClear = isPathClear(hrp.Position + Vector3.new(0, 2, 0), placeTargetCF.Position + Vector3.new(0, 2, 0), char)
					if not placePathClear then
						local safezoneCF = CFrame.new(518.66, 70.57, -364.73) * CFrame.Angles(math.rad(180.00), math.rad(-89.82), math.rad(180.00))
						TweenMoveTo(hrp, hum, safezoneCF, placeCancelled)
						if placeCancelled() then return end
					end
					TweenMoveTo(hrp, hum, placeTargetCF, placeCancelled)
					if placeCancelled() then return end
					local fallWaited = 0
					while fallWaited < 0.5 and not placeCancelled() do
						task.wait(0.05)
						fallWaited = fallWaited + 0.05
					end
					if placeCancelled() then return end
				end
				local stopPlacing = false
				local occupiedPositions = {}
				for _, rec in pairs(myEggs) do
					if rec.Placement then
						local pos
						if typeof(rec.Placement) == "CFrame" then pos = rec.Placement.Position
						elseif typeof(rec.Placement) == "Vector3" then pos = rec.Placement
						elseif rec.Placement.Position then pos = rec.Placement.Position end
						if pos then table.insert(occupiedPositions, pos) end
					end
				end
				local searchIdx = 0
				for _, eggInfo in ipairs(eggsToPlace) do
					if not Config.AutoPlace or stopPlacing then break end
					if placedCount >= 30 then stopPlacing = true break end
					if placeCancelled() then return end
					local uid = eggInfo.Uid
					local eqSuccess = EggCmds.RequestEquipTool(uid)
					if eqSuccess then
						if placeCancelled() then return end
						task.wait(0.15)
						local placed = false
						while searchIdx < 30 and not placed do
							local placeCFrame = nil
							if PetArea and CenterPoint then
								while searchIdx < 30 do
									local columns = 10
									local paddingX = 6
									local paddingZ = 6
									local usableWidth = PetArea.Size.X - paddingX
									local usableDepth = PetArea.Size.Z - paddingZ
									local spacingX = usableWidth / columns
									local spacingZ = 6
									local row = math.floor(searchIdx / columns)
									local col = searchIdx % columns
									local startX = -(usableWidth / 2) + (spacingX / 2)
									local startZ = -(usableDepth / 2) + (spacingZ / 2)
									local rx = startX + (col * spacingX)
									local rz = startZ + (row * spacingZ)
									local worldPos = PetArea.CFrame * Vector3.new(rx, 0, rz)
									local localPos = CenterPoint.CFrame:PointToObjectSpace(worldPos)
									local testCFrame = CFrame.new(localPos.X, -0.5, localPos.Z)
									local isOccupied = false
									for _, pos in ipairs(occupiedPositions) do
										if (pos - testCFrame.Position).Magnitude < 1.0 then isOccupied = true break end
									end
									if not isOccupied then placeCFrame = testCFrame break end
									searchIdx = searchIdx + 1
								end
							end
							if not placeCFrame then stopPlacing = true break end
							if placeCancelled() then return end
							local plSuccess, plErr = EggCmds.RequestPlaceEgg(uid, placeCFrame)
							if plSuccess then
								table.insert(occupiedPositions, placeCFrame.Position)
								placedCount = placedCount + 1
								placed = true
								task.wait(0.15)
							else
								local lErr = plErr and string.lower(tostring(plErr)) or ""
								if string.find(lErr, "full") or string.find(lErr, "limit") or string.find(lErr, "capacity") or string.find(lErr, "maximum") then
									if Config.AutoPlace then Config.AutoPlace = false end
									stopPlacing = true
									break
								end
								table.insert(occupiedPositions, placeCFrame.Position)
								searchIdx = searchIdx + 1
								task.wait(0.1)
							end
						end
					end
				end
				if originalCF and hrp and not placeCancelled() then
					local returnPathClear = isPathClear(hrp.Position + Vector3.new(0, 2, 0), originalCF.Position + Vector3.new(0, 2, 0), char)
					if not returnPathClear then
						local safezoneCF = CFrame.new(518.66, 70.57, -364.73) * CFrame.Angles(math.rad(180.00), math.rad(-89.82), math.rad(180.00))
						TweenMoveTo(hrp, hum, safezoneCF, placeCancelled)
					end
					if placeCancelled() then return end
					TweenMoveTo(hrp, hum, originalCF, placeCancelled)
					task.wait(0.2)
				end
			end)
			if Config.IsPlacing then placeStatus = "" end
			Config.IsPlacing = false
			if not success then
				placeStatus = "Error, retrying"
				warn("[NASA-Hub] Auto Place error: " .. tostring(err))
			end
		end
		Config.IsAutoPlaceWorkerRunning = false
	end
	TaskLadder.register("auto_place", {
		wants = placeWants,
		active = function() return Config.IsPlacing == true end,
		enabled = function() return Config.AutoPlace == true end,
		status = function() return placeStatus end,
	})

	------------------------------------------------------------ 自动孵化
	UIRunners.AutoHatchLoop = function()
		if Config.IsAutoHatchWorkerRunning then return end
		Config.IsAutoHatchWorkerRunning = true
		task.spawn(function()
			local failedHatchAttempts = {}
			while Config.AutoHatch and sessionAlive() do
				task.wait(1.5)
				pcall(function()
					local EggCmds = require(ReplicatedStorage.Client.EggState)
					local myEggs = EggCmds.GetOwnerRuntimeRecords(LocalPlayer.UserId)
					if not myEggs then return end
					local eggsToHatch = {}
					for uid, record in pairs(myEggs) do
						if record.Placement ~= nil then table.insert(eggsToHatch, uid) end
					end
					local now = os.time()
					for _, uid in ipairs(eggsToHatch) do
						if not Config.AutoHatch then break end
						if not (failedHatchAttempts[uid] and now < failedHatchAttempts[uid]) then
							local record = myEggs[uid]
							local isReady = false
							if type(EggCmds.IsReadyToHatch) == "function" then
								local ok, ready = pcall(EggCmds.IsReadyToHatch, uid)
								isReady = ok and ready == true
							end
							if isReady or record.Ready == true or not failedHatchAttempts[uid] then
								local success = EggCmds.RequestHatchEgg(uid)
								if success then
									EggCmds.RequestCompleteHatchEgg(uid)
									failedHatchAttempts[uid] = nil
									task.wait(0.1)
								else
									failedHatchAttempts[uid] = now + 10
								end
							end
						end
					end
				end)
			end
			Config.IsAutoHatchWorkerRunning = false
		end)
	end

	------------------------------------------------------------ 自动突变
	local mutationWarnedNoItem = false
	local mutationState = { wants = false, busy = false, status = "" }
	local function sweepOnce()
		local EggCmds = require(ReplicatedStorage.Client.EggState)
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		local AssetsDir = nil
		pcall(function()
			local A = require(ReplicatedStorage.Data.Assets)
			AssetsDir = A.Directory or A
		end)
		local function recDisplayName(rec)
			local cat = rec.Category or rec.AssetCategory
			local cfg = AssetsDir and cat and AssetsDir[cat]
			return (cfg and cfg.DisplayName) or cat
		end
		local function recRarity(rec)
			local cat = rec.Category or rec.AssetCategory
			local cfg = AssetsDir and cat and AssetsDir[cat]
			local r = cfg and cfg.Rarity
			return r and (r.DisplayName or r._id) or nil
		end
		local function higherPriorityWants() return TaskLadder.blocker("use_scrambled") ~= nil end
		local mid = ({ Fractured = "Boss", Enchanted = "Enchanted", Nitro = "Nitro" })[Config.MutationChoice] or "Scrambled"
		local function eggValue(rec)
			local item = {
				AssetCategory = rec.AssetCategory or rec.Category,
				AssetScale = rec.AssetScale or rec.Scale or 1,
				Mutations = rec.Mutations or {},
				BaseMutation = rec.BaseMutation,
				AssetEyeColor = rec.AssetEyeColor,
				AssetColorSeed = rec.AssetColorSeed,
				AssetColorIndex = rec.AssetColorIndex,
				Gender = rec.Gender,
				Personality = rec.Personality,
				HasBeenFirstPlaced = rec.HasBeenFirstPlaced,
			}
			local ok, value = pcall(function() return Config:getAreaEggValue(item) end)
			return (ok and tonumber(value)) or 0
		end
		local function findConsumable()
			local char = LocalPlayer.Character
			for _, cont in ipairs({ char, LocalPlayer:FindFirstChildOfClass("Backpack") }) do
				if cont then
					for _, t in ipairs(cont:GetChildren()) do
						if t:IsA("Tool") and t:GetAttribute("ItemType") == "MutationConsumable" and t:GetAttribute("MutationId") == mid then
							return t
						end
					end
				end
			end
			return nil
		end
		local function recHasMutation(rec)
			local m = rec and rec.Mutations
			if m == nil then return false end
			if type(m) == "table" then
				for _, v in ipairs(m) do if v == mid then return true end end
				for k, v in pairs(m) do if k == mid or v == mid then return true end end
				return false
			end
			return tostring(m):find(mid) ~= nil
		end
		local speciesFilter = Config.MutationSpecies
		local hasSpeciesFilter = type(speciesFilter) == "table" and #speciesFilter > 0
		local rarityFilter = Config.MutationRarities
		local hasRarityFilter = type(rarityFilter) == "table" and #rarityFilter > 0
		local minRate = tonumber(Config.MutationMinRate) or 0
		local function eligible(rec)
			if type(rec) ~= "table" or rec.Placement == nil or recHasMutation(rec) then return false end
			if minRate > 0 then
				local rateOf = UIRunners.rateOf
				local rate = rateOf and rateOf({ Category = rec.Category or rec.AssetCategory, Scale = rec.Scale or rec.AssetScale or 1, Mutations = rec.Mutations or {} }) or 0
				if rate < minRate then return false end
			end
			local cat = rec.Category or rec.AssetCategory
			local disp = recDisplayName(rec)
			if hasSpeciesFilter then
				local pass = false
				for _, s in ipairs(speciesFilter) do
					if s == disp or s == cat then pass = true break end
				end
				if not pass then return false end
			end
			if hasRarityFilter then
				local rar = recRarity(rec)
				for _, r in ipairs(rarityFilter) do
					if r == rar then return true end
				end
				return false
			end
			return true
		end
		local tool = findConsumable()
		local myEggs = EggCmds.GetOwnerRuntimeRecords(LocalPlayer.UserId)
		local anyEligible = false
		if tool and type(myEggs) == "table" then
			for _, rec in pairs(myEggs) do
				if eligible(rec) then anyEligible = true break end
			end
		end
		mutationState.wants = anyEligible
		if not tool then
			mutationState.status = "No " .. tostring(Config.MutationChoice or "Scrambled") .. " item in your bag"
			if not mutationWarnedNoItem then
				warn("[NASA-Hub] Auto mutation: no " .. tostring(Config.MutationChoice or "Scrambled") .. " consumable in the bag, round skipped.")
				mutationWarnedNoItem = true
			end
			return
		end
		mutationWarnedNoItem = false
		if not anyEligible then
			mutationState.status = "No placed egg to mutate"
			return
		end
		if higherPriorityWants() then
			mutationState.status = TaskLadder.yieldLabel("use_scrambled") or ""
			return
		end
		local holder = TaskLadder.holder("use_scrambled")
		if holder then
			mutationState.status = "Waiting for " .. TaskLadder.TITLES[holder] .. " to hand over"
			return
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		mutationState.busy = true
		mutationState.status = "Applying " .. tostring(Config.MutationChoice or "Scrambled")
		if not char:FindFirstChild(tool.Name) then
			pcall(function() hum:EquipTool(tool) end)
			task.wait(0.15)
		end
		local queue = {}
		for uid, rec in pairs(myEggs) do
			if eligible(rec) then queue[#queue + 1] = { uid = uid, rec = rec, value = eggValue(rec) } end
		end
		table.sort(queue, function(a, b) return a.value > b.value end)
		for _, entry in ipairs(queue) do
			local uid, rec = entry.uid, entry.rec
			if higherPriorityWants() then break end
			if eligible(rec) then
				local renders = workspace:FindFirstChild("PlacedEggRenders")
				local render = renders and renders:FindFirstChild(tostring(LocalPlayer.UserId) .. "_" .. uid)
				local root = char:FindFirstChild("HumanoidRootPart")
				if render and root then
					local eggPos = render:GetPivot().Position
					if (eggPos - root.Position).Magnitude > 30 then
						mutationState.status = "Walking to " .. tostring(recDisplayName(rec))
						local away = Vector3.new(root.Position.X - eggPos.X, 0, root.Position.Z - eggPos.Z)
						local spot = eggPos + (away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)) * 10 + Vector3.new(0, 3, 0)
						pcall(TweenMoveTo, root, hum, CFrame.new(spot), higherPriorityWants)
						mutationState.status = "Applying " .. tostring(Config.MutationChoice or "Scrambled")
					end
				end
				local liveTool = findConsumable()
				if not liveTool then break end
				if not char:FindFirstChild(liveTool.Name) then
					pcall(function() hum:EquipTool(liveTool) end)
					task.wait(0.1)
				end
				local tries, mutated = 0, false
				repeat
					if higherPriorityWants() then break end
					if findConsumable() == nil then break end
					local ok, res = pcall(function()
						return Remotes.BossMastery.AskUseMutationConsumable:InvokeServer(uid)
					end)
					tries = tries + 1
					if ok and type(res) == "table" then
						if res.Mutated == true then mutated = true end
						if res.Success ~= true then break end
					else
						break
					end
					task.wait(0.25)
				until mutated or not Config.MutationRetry or tries >= 40
			end
		end
		mutationState.busy = false
		mutationState.status = ""
	end
	UIRunners.mutationSweep = function()
		local ok, err = pcall(sweepOnce)
		mutationState.busy = false
		if not ok then error(err, 0) end
	end
	TaskLadder.register("use_scrambled", {
		wants = function() return Config.AutoMutation == true and mutationState.wants == true end,
		active = function() return mutationState.busy == true end,
		enabled = function() return Config.AutoMutation == true end,
		status = function() return mutationState.status end,
	})
	UIRunners.AutoMutationLoop = function()
		if Config.IsAutoMutationWorkerRunning then return end
		Config.IsAutoMutationWorkerRunning = true
		task.spawn(function()
			while Config.AutoMutation and sessionAlive() do
				task.wait(1.0)
				pcall(UIRunners.mutationSweep)
			end
			Config.IsAutoMutationWorkerRunning = false
		end)
	end

	------------------------------------------------------------ 环活动
	UIRunners.RingEventLoop = function()
		if Config.IsRingEventRunning then return end
		Config.IsRingEventRunning = true
		task.spawn(function()
			local SAFE = CFrame.new(542.93, 71.5, -405.58)
			local FOREST = CFrame.new(602, 70.78, -372)
			local ANGELS_DEMONS = CFrame.new(5573, 70.77, -363)
			local function cancelled() return not Config.AutoRingEvent or not sessionAlive() end
			local function goTo(cf)
				if cancelled() then return false end
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum then task.wait(0.3) return not cancelled() end
				TweenMoveTo(hrp, hum, cf, cancelled, false, nil, true)
				return not cancelled()
			end
			while not cancelled() do
				if not goTo(SAFE) then break end
				if not goTo(FOREST) then break end
				if not goTo(ANGELS_DEMONS) then break end
				if not goTo(FOREST) then break end
			end
			Config.IsRingEventRunning = false
		end)
	end

	------------------------------------------------------------ 卖宠物 / 卖蛋
	local sellEarnings = nil
	local function sellRateOf(item)
		if sellEarnings == nil then
			pcall(function() sellEarnings = require(ReplicatedStorage.Shared.Util.AssetEarnings) end)
		end
		if not sellEarnings then return 0 end
		for _, fn in ipairs({ sellEarnings.LiveRatePerSecond, sellEarnings.RatePerSecond, sellEarnings.CatalogRatePerSecond }) do
			if type(fn) == "function" then
				local ok, rate = pcall(fn, item)
				if ok and type(rate) == "number" and rate > 0 then return rate end
			end
		end
		return 0
	end
	UIRunners.rateOf = sellRateOf
	local isAutoSellRunning = false
	local sellState = { petPending = false, petBusy = false, status = "" }
	UIRunners.startAutoSellLoop = function()
		if isAutoSellRunning then return end
		isAutoSellRunning = true
		task.spawn(function()
			local ok0, why0 = pcall(function()
				local Assets = require(ReplicatedStorage.Data.Assets)
				local Save = require(ReplicatedStorage.Shared.Save)
				local AssetRoster = require(ReplicatedStorage.Client.AssetRoster)
				local Remotes = require(ReplicatedStorage.Shared.Remotes)
				local function readPlacedUids()
					local ok, runtimeRecords = pcall(function() return AssetRoster.ReadOwnerPen(LocalPlayer.UserId) end)
					if not ok or type(runtimeRecords) ~= "table" then return nil end
					local placed = {}
					for key, rec in pairs(runtimeRecords) do
						if type(key) == "string" then placed[key] = true end
						if type(rec) == "table" and rec.UID then placed[rec.UID] = true end
					end
					return placed
				end
				local function stillSellablePet(entry, placedNow)
					if not Config.AutoSell then return false, "Auto Sell Pet is now off", "global" end
					if not autoSellCanRun() then return false, "another task has control", "global" end
					local namesNow = readDropdownFilter(sellNamesDropdown)
					local raritiesNow = readDropdownFilter(sellRarityDropdown)
					if not namesNow or not raritiesNow then return false, "filters unreadable", "global" end
					if type(placedNow) ~= "table" then return false, "placed pets could not be verified", "global" end
					if placedNow[entry.uid] then return false, "pet is placed on the plot", "pet" end
					if not petMatchesSellFilter(entry.petName, entry.rarity, namesNow, raritiesNow) then
						return false, "pet no longer matches the filter", "pet"
					end
					local sv = (Save.Peek or Save.Get)()
					local rec = sv and sv.Inventory and sv.Inventory[entry.uid]
					if rec == nil then return false, "pet is no longer in the inventory", "pet" end
					local maxRate = Config.SellPetMaxRate or 0
					if maxRate > 0 then
						local rate = sellRateOf({ Category = rec.Category or rec.AssetCategory, Scale = rec.Scale or rec.AssetScale or 1, Mutations = rec.Mutations or {} })
						if rate > maxRate then return false, "money/s is above the limit", "pet" end
					end
					if rec.IsFavorite == true then return false, "pet is favorited", "pet" end
					if rec.InFuse == true then return false, "pet is being fused", "pet" end
					if table.find(sv.EquippedAssets or {}, entry.uid) ~= nil then return false, "pet is equipped", "pet" end
					return true
				end
				while Config.AutoSell and sessionAlive() do
					local success, err = pcall(function()
						if not autoSellCanRun() then
							sellState.status = TaskLadder.yieldLabel("auto_sell") or ""
							return
						end
						local sellNames = readDropdownFilter(sellNamesDropdown)
						local sellRarities = readDropdownFilter(sellRarityDropdown)
						if not sellNames or not sellRarities then
							warn("[NASA-Hub] Auto Sell: filters unreadable, round skipped, nothing sold.")
							return
						end
						local mySave = (Save.Peek or Save.Get)()
						local myInventory = mySave and mySave.Inventory or {}
						local placedUids = readPlacedUids()
						if not placedUids then
							warn("[NASA-Hub] Auto Sell: could not verify which pets are placed, round skipped, nothing sold.")
							return
						end
						local petsToSell = {}
						local countProcessed = 0
						if type(myInventory) == "table" then
							for uid, record in pairs(myInventory) do
								countProcessed = countProcessed + 1
								if countProcessed % 250 == 0 then
									RunService.Heartbeat:Wait()
									if not Config.AutoSell then return end
								end
								if type(record) == "table" then
									local isPlaced = placedUids[uid] == true
									local isFavorite = record.IsFavorite == true or record["Favorite"] == true
									local isEquipped = table.find(mySave.EquippedAssets or {}, uid) ~= nil
									local inFuse = record.InFuse == true
									local assetId = record.Category or record.id or record.AssetCategory or record.ItemId
									local categoryData = assetId and Assets.Directory[assetId]
									local petName = categoryData and (categoryData.DisplayName or categoryData._id or categoryData.Name) or "Unknown"
									local rarityObj = categoryData and categoryData.Rarity
									local rarity = rarityObj and (rarityObj.DisplayName or rarityObj._id or rarityObj.Name) or "Unknown"
									local match = petMatchesSellFilter(petName, rarity, sellNames, sellRarities)
									local passValue = true
									local maxRate = Config.SellPetMaxRate or 0
									if maxRate > 0 then
										local rate = sellRateOf({ Category = assetId, Scale = record.Scale or record.AssetScale or 1, Mutations = record.Mutations or {} })
										passValue = rate <= maxRate
									end
									if match and passValue and not isFavorite and not isPlaced and not isEquipped and not inFuse then
										table.insert(petsToSell, { uid = uid, petName = petName, rarity = rarity })
									end
								end
							end
						end
						sellState.petPending = #petsToSell > 0
						if #petsToSell > 0 then
							sellState.petBusy = true
							sellState.status = string.format("Selling %d pet%s", #petsToSell, #petsToSell == 1 and "" or "s")
							for _, entry in ipairs(petsToSell) do
								local placedNow = readPlacedUids()
								local okNow, reasonNow, scopeNow = stillSellablePet(entry, placedNow)
								if not okNow then
									warn("[NASA-Hub] Auto Sell: not selling " .. tostring(entry.petName) .. " - " .. tostring(reasonNow))
									if scopeNow == "global" then break end
								else
									if not autoSellCanRun() then break end
									local character = LocalPlayer.Character
									local humanoid = character and character:FindFirstChildOfClass("Humanoid")
									local tool = nil
									for _, container in ipairs({ LocalPlayer.Backpack, character }) do
										if container then
											for _, candidate in ipairs(container:GetChildren()) do
												if candidate:IsA("Tool") and candidate:GetAttribute("UID") == entry.uid then
													tool = candidate
													break
												end
											end
										end
										if tool then break end
									end
									if tool and humanoid then
										humanoid:EquipTool(tool)
										task.wait(0.2)
										if not autoSellCanRun() then break end
										-- 发送前最后再核对一次，防止卖错
										local placedPreFire = readPlacedUids()
										local okFire, reasonFire, scopeFire = stillSellablePet(entry, placedPreFire)
										if not okFire then
											warn("[NASA-Hub] Auto Sell: cancelled at the last moment, not selling " .. tostring(entry.petName) .. " - " .. tostring(reasonFire))
											if scopeFire == "global" then break end
										else
											Remotes.PetSatchel.SellPet:FireServer({ entry.uid })
											task.wait(0.05)
										end
									end
								end
							end
						end
					end)
					sellState.petBusy = false
					if sellState.status:find("^Selling") then sellState.status = "" end
					if not success then warn("[NASA-Hub] Auto Sell error: " .. tostring(err)) end
					task.wait(1.5)
				end
			end)
			if not ok0 then warn("[NASA-Hub] Auto Sell could not start: " .. tostring(why0)) end
			isAutoSellRunning = false
		end)
	end

	local isAutoSellEggRunning = false
	local isAutoSellEggProcessing = false
	local function hasPendingEggToSell()
		if not Config.AutoSellEgg then return false end
		local rarities = readDropdownFilter(sellEggRarityDropdown)
		if not rarities or #rarities == 0 or table.find(rarities, "None") then return false end
		local okSave, Save = pcall(function() return require(ReplicatedStorage.Shared.Save) end)
		if not okSave or not Save then return false end
		local profile = (Save.Peek or Save.Get)()
		local inventory = profile and profile.EggInventory
		if type(inventory) ~= "table" then return false end
		local okAssets, AssetsMod = pcall(function() return require(ReplicatedStorage.Data.Assets) end)
		local Assets = okAssets and AssetsMod and AssetsMod.Directory
		if not Assets then return false end
		for uid, record in pairs(inventory) do
			local asset = type(record) == "table" and Assets[record.AssetCategory]
			local rarity = asset and asset.Rarity and (asset.Rarity.DisplayName or asset.Rarity._id)
			local passValue = true
			local maxRate = Config.SellEggMaxRate or 0
			if maxRate > 0 and type(record) == "table" then
				local rate = sellRateOf({ Category = record.AssetCategory, Scale = record.AssetScale or 1, Mutations = record.Mutations or {} })
				passValue = rate <= maxRate
			end
			if record.Placement == nil and passValue and eggMatchesSellFilter(rarity or "Unknown", rarities) then
				return true
			end
		end
		return false
	end
	runtimeEnv.__NasaV1IsAutoSellEggBusy = function()
		return isAutoSellEggProcessing or hasPendingEggToSell()
	end
	local eggPendingCache = { at = 0, value = false }
	local function eggSellPending()
		local now = os.clock()
		if now - eggPendingCache.at < 1 then return eggPendingCache.value end
		eggPendingCache.at = now
		local ok, value = pcall(hasPendingEggToSell)
		eggPendingCache.value = ok and value == true
		return eggPendingCache.value
	end
	TaskLadder.register("auto_sell", {
		wants = function()
			return (Config.AutoSell == true and sellState.petPending == true) or (Config.AutoSellEgg == true and eggSellPending())
		end,
		active = function() return sellState.petBusy == true or isAutoSellEggProcessing == true end,
		enabled = function() return Config.AutoSell == true or Config.AutoSellEgg == true end,
		status = function()
			if isAutoSellEggProcessing then return "Selling eggs" end
			return sellState.status
		end,
	})
	UIRunners.startAutoSellEggLoop = function()
		if isAutoSellEggRunning then return end
		isAutoSellEggRunning = true
		task.spawn(function()
			local ok0, why0 = pcall(function()
				local Assets = require(ReplicatedStorage.Data.Assets).Directory
				local EggState = require(ReplicatedStorage.Client.EggState)
				local Remotes = require(ReplicatedStorage.Shared.Remotes)
				local Save = require(ReplicatedStorage.Shared.Save)
				while Config.AutoSellEgg and sessionAlive() do
					local rarities = readDropdownFilter(sellEggRarityDropdown)
					local profile = (Save.Peek or Save.Get)()
					local inventory = profile and profile.EggInventory
					if rarities and type(inventory) == "table" and autoSellCanRun() then
						for uid, record in pairs(inventory) do
							if not Config.AutoSellEgg or not autoSellCanRun() then break end
							local asset = type(record) == "table" and Assets[record.AssetCategory]
							local rarity = asset and asset.Rarity and (asset.Rarity.DisplayName or asset.Rarity._id)
							local passValue = true
							local maxRate = Config.SellEggMaxRate or 0
							if maxRate > 0 and type(record) == "table" then
								local rate = sellRateOf({ Category = record.AssetCategory, Scale = record.AssetScale or 1, Mutations = record.Mutations or {} })
								passValue = rate <= maxRate
							end
							if record.Placement == nil and passValue and eggMatchesSellFilter(rarity or "Unknown", rarities) then
								if not autoSellCanRun() then break end
								isAutoSellEggProcessing = true
								local tm = runtimeEnv.__NasaV1TreadmillManager
								if tm and tm.activeTreadmill ~= nil then
									pcall(function() tm:_cancelIdle(true) end)
									task.wait(0.25)
								end
								local equipped = EggState.WearEggTool(uid)
								if equipped then
									task.wait(0.2)
									if not autoSellCanRun() then break end
									local fresh = (Save.Peek or Save.Get)()
									fresh = fresh and fresh.EggInventory and fresh.EggInventory[uid]
									if fresh and fresh.Placement == nil then
										Remotes.PetSatchel.SellPet:FireServer({ uid })
										task.wait(0.25)
									end
								end
							end
						end
					end
					isAutoSellEggProcessing = false
					task.wait(0.5)
				end
			end)
			if not ok0 then warn("[NASA-Hub] Auto Sell Egg could not start: " .. tostring(why0)) end
			isAutoSellEggProcessing = false
			isAutoSellEggRunning = false
		end)
	end

	------------------------------------------------------------ 开关函数（给界面调用）
	local function runOnce(flagKey, runner, onDone)
		local restore = Config[flagKey]
		Config[flagKey] = true
		task.spawn(runner)
		task.delay(2.4, function()
			local deadline = os.clock() + 30
			while Config.IsPlacing and os.clock() < deadline do task.wait(0.25) end
			Config[flagKey] = restore
			if onDone then pcall(onDone) end
		end)
	end
	local Apply = {}
	function Apply.AutoPlace(v) Config.AutoPlace = v == true if Config.AutoPlace then task.spawn(UIRunners.AutoPlaceLoop) end end
	function Apply.AutoHatch(v) Config.AutoHatch = v == true if Config.AutoHatch then task.spawn(UIRunners.AutoHatchLoop) end end
	function Apply.AutoMutation(v) Config.AutoMutation = v == true if Config.AutoMutation then task.spawn(UIRunners.AutoMutationLoop) end end
	function Apply.AutoRingEvent(v) Config.AutoRingEvent = v == true if Config.AutoRingEvent then UIRunners.RingEventLoop() end end
	function Apply.AutoSell(v) Config.AutoSell = v == true if Config.AutoSell then UIRunners.startAutoSellLoop() end end
	function Apply.AutoSellEgg(v) Config.AutoSellEgg = v == true if Config.AutoSellEgg then UIRunners.startAutoSellEggLoop() end end
	function Apply.MutationNow() task.spawn(function() pcall(UIRunners.mutationSweep) end) end
	function Apply.PlaceNow() runOnce("AutoPlace", UIRunners.AutoPlaceLoop) end
	function Apply.HatchNow() runOnce("AutoHatch", UIRunners.AutoHatchLoop) end
	UIRunners.runOnce = runOnce
	runtimeEnv.__NasaV1Apply = Apply
end)
if not okTail then warn("[NASA-Hub] 补充的功能代码出错: " .. tostring(errTail)) end
end

]==]

-- 放在独立线程里：功能代码出错或卡住，都不影响下面 UI 的创建
task.spawn(function()
	local PART_URL = "https://raw.githubusercontent.com/TT-USA/NasaHub/refs/heads/main/2NasaHub_part_875-20171%20(1).lua"
	local function fail(msg)
		if Cfg.Debug then warn("[NASA-Hub] " .. msg) end   -- 控制台默认不再刷屏；界面右下角仍会弹一条简短提示
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "NASA-Hub", Text = string.sub(string.match(msg, "[^\n]*") or msg, 1, 120), Duration = 8 })
		end)
	end
	local function download(url)
		local ok, res = pcall(function() return game:HttpGet(url, true) end)
		if ok and type(res) == "string" and #res >= 1000 then return res end
		local why = ok and ("服务器返回: " .. string.sub(tostring(res), 1, 60)) or tostring(res)
		local req = (syn and syn.request) or (http and http.request) or http_request or request
		if req then
			local ok2, r = pcall(req, { Url = url, Method = "GET" })
			if ok2 and type(r) == "table" and type(r.Body) == "string" then
				if #r.Body >= 1000 then return r.Body end
				why = "服务器返回(" .. tostring(r.StatusCode) .. "): " .. string.sub(r.Body, 1, 60)
			end
		end
		return nil, why
	end
	local body, why = download(PART_URL)
	-- 有的注入器会把链接里的 %20 再转义一次，失败就换成真正的空格再试
	if not body then body = download((string.gsub(PART_URL, "%%20", " "))) end
	if not body then return fail("功能代码下载失败（" .. tostring(why) .. "）。请检查网络、链接或文件名") end
	if Cfg.Debug then print("[NASA-Hub] 功能代码已下载 " .. #body .. " 字节，正在运行…") end
	-- 功能代码里用到的、在本文件前面声明的变量，通过参数传进去
	local header = "local NH, Players, RunService, ReplicatedStorage, TeleportService, ProximityPromptService, Workspace, resolveObjectsRoot, runtimeEnv, sessionAlive, SPOOF_CFG, currentFps, syncHoverPad, startHoverPad, stopHoverPad, clearTweenArrivalHold, setTweenArrivalHold, environment, setMovementSpoof, patchIntegrityState, integrityStateMatches, integrityStateCanTravel, setIntegritySpoof, refreshIntegritySpoof, startGlobalMovementProtection = ...; local Config, speedDialStuds; local LocalPlayer = Players.LocalPlayer; "
	local anchor = "\nfunction Config:applyStealValueInput("
	local at = string.find(body, anchor, 1, true)
	if at then body = string.sub(body, 1, at - 1) .. "\nNH.speedDialStuds = speedDialStuds" .. string.sub(body, at) end
	-- 开放几个功能代码里没有对外开放的对象，让界面可以控制它们（找不到就跳过，对应开关会提示）
	local exposures = {
		{ "function NasaHalloween.setEnabled(on) NasaHalloween.refresh() end", "\n\truntimeEnv.__NasaV1Halloween = NasaHalloween" },
		{ "function NasaTrain.setEnabled(on) NasaTrain.refresh() end", "\n\truntimeEnv.__NasaV1Train = NasaTrain" },
		{ "local NasaExtras = {}", "\nruntimeEnv.__NasaV1Extras = NasaExtras" },
	}
	for _, ex in ipairs(exposures) do
		local s0, e0 = string.find(body, ex[1], 1, true)
		if s0 then body = string.sub(body, 1, e0) .. ex[2] .. string.sub(body, e0 + 1) end
	end
	-- 把缺失的结尾拼上去（出错只会警告，不影响前面已经加载的功能）
	body = body .. "\n" .. __NH_T.TAIL_SRC
	local chunk, cerr = loadstring(header .. body .. "\nNH.speedDialStuds = speedDialStuds")
	if not chunk then return fail("功能代码语法错误: " .. tostring(cerr)) end
	local ok, err = xpcall(chunk, function(e) return tostring(e) .. "\n" .. debug.traceback() end,
		__NH_T, Players, RunService, ReplicatedStorage, TeleportService, __NH_T.ProximityPromptService, Workspace, __NH_T.resolveObjectsRoot, runtimeEnv, sessionAlive, SPOOF_CFG, __NH_T.currentFps, syncHoverPad, startHoverPad, stopHoverPad, clearTweenArrivalHold, __NH_T.setTweenArrivalHold, environment, setMovementSpoof, patchIntegrityState, integrityStateMatches, integrityStateCanTravel, setIntegritySpoof, refreshIntegritySpoof, __NH_T.startGlobalMovementProtection)
	if not ok then return fail("功能代码运行出错: " .. tostring(err)) end
	if Cfg.Debug then print("[NASA-Hub] 功能代码加载完成") end
end)

--------------------------------------------------------------------
-- 功能内容
--------------------------------------------------------------------



--------------------------------------------------------------------
-- 工具函数
--------------------------------------------------------------------
local alive = true
local Conns = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    Conns[#Conns + 1] = c
    return c
end
-- 页面里每个控件自己的事件：控件被销毁时会自动断开，所以不放进 Conns
-- （以前每重建一次页面都会多留一批没用的连接，越积越多）
local function ev(signal, fn) return signal:Connect(fn) end

local function tween(obj, props, time, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function setProp(obj, p, v) obj[p] = v end

-- 字体统一：Gotham 系列 → Builder Sans 系列（更清晰、小字更好读；Cfg.BetterFont = false 可还原）
-- 字体整体放大一点：16 以下的字号 +1（标题等大字不变）
function __NH_T.FS(n)
    if type(n) == "number" and n <= 16 then return n + 1 end
    return n
end
__NH_T.FM = {}
if Cfg.BetterFont then
    for a, b in pairs({Gotham = "BuilderSans", GothamMedium = "BuilderSansMedium", GothamSemibold = "BuilderSansMedium",
        GothamBold = "BuilderSansBold", GothamBlack = "BuilderSansExtraBold"}) do
        local ok1, fa = pcall(function() return Enum.Font[a] end)
        local ok2, fb = pcall(function() return Enum.Font[b] end)
        if ok1 and ok2 and fa and fb then __NH_T.FM[fa] = fb end
    end
end

-- 点击反馈：按下去轻轻缩一点，松开带一点回弹（sig 传 ev 或 connect）
function __NH_T.pressFx(b, amt, sig)
    local sc
    local function up() if sc then tween(sc, {Scale = 1}, 0.24, Enum.EasingStyle.Back) end end
    sig(b.MouseButton1Down, function()
        if not sc then   -- 第一次按下才创建（建页面时省掉几百个 UIScale 和事件连接）
            sc = Instance.new("UIScale")
            sc.Parent = b
            b.MouseButton1Up:Connect(up)
            b.MouseLeave:Connect(up)
        end
        tween(sc, {Scale = amt or 0.95}, 0.08)
    end)
end

local function new(className, props, parent)
    props = props or {}
    local obj = Instance.new(className)
    for p, v in pairs(props) do
        if p == "Font" then v = __NH_T.FM[v] or v
        elseif p == "TextSize" then v = __NH_T.FS(v) end
        if p ~= "Parent" then pcall(setProp, obj, p, v) end
    end
    obj.Parent = props.Parent or parent
    return obj
end

local function corner(parent, r) return new("UICorner", {CornerRadius = UDim.new(0, r)}, parent) end
local function full(parent) return new("UICorner", {CornerRadius = UDim.new(1, 0)}, parent) end
local function stroke(parent, color, thick, transp)
    return new("UIStroke", {Color = color or C.stroke, Thickness = thick or 1, Transparency = transp or 0}, parent)
end
local function pad(parent, l, r, t, b)
    return new("UIPadding", {PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0)}, parent)
end
local function list(parent, vertical, gap, order)
    return new("UIListLayout", {
        FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, gap or 0),
        SortOrder = order or Enum.SortOrder.LayoutOrder,
    }, parent)
end

local function text(parent, props)
    local p = {
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextColor3 = C.text,
        TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }
    for k, v in pairs(props) do p[k] = v end
    return new("TextLabel", p, parent)
end

function __NH_T.shortNum(v)
    local units = {{1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}}
    for _, u in ipairs(units) do
        if v >= u[1] then
            local s = string.format("%.2f", v / u[1])
            s = s:gsub("0+$", ""):gsub("%.$", "")
            return s .. u[2]
        end
    end
    return tostring(math.floor(v + 0.5))
end

function __NH_T.parseNum(s)
    s = tostring(s or "")
    s = s:gsub("%s+", "")
    s = string.lower(s)
    if s == "" or s == "off" then return 0 end
    local n, unit = s:match("^([%d%.]+)([kmbt]?)")
    n = tonumber(n)
    if not n then return nil end
    local mult = {k = 1e3, m = 1e6, b = 1e9, t = 1e12}
    return n * (mult[unit] or 1)
end

--------------------------------------------------------------------
-- 白色线条图标
--------------------------------------------------------------------
local ICONS = {}
ICONS.home = function(d) d.poly({{2,10},{10,3},{18,10}}); d.poly({{4,8.5},{4,17},{16,17},{16,8.5}}); d.poly({{8,17},{8,12.5},{12,12.5},{12,17}}) end
ICONS.egg = function(d) d.poly({{10,2.2},{13,5},{15,9},{15.4,12.6},{13.6,16},{10,17.8},{6.4,16},{4.6,12.6},{5,9},{7,5},{10,2.2}}) end
ICONS.sprout = function(d)
    d.line(10, 17.5, 10, 9.5)
    d.poly({{10,12.5},{6,12.3},{3.2,9.2},{3,6},{6.5,6.2},{9.6,9},{10,12.5}})
    d.poly({{10,9.8},{10.6,6},{13.2,3.4},{16.8,3.2},{16.8,7},{14,9.6},{10,9.8}})
    d.line(6.5, 17.5, 13.5, 17.5)
end
ICONS.sparkle = function(d) d.poly({{10,1},{12.2,7.8},{19,10},{12.2,12.2},{10,19},{7.8,12.2},{1,10},{7.8,7.8},{10,1}}); d.line(16.5, 2, 16.5, 5); d.line(15, 3.5, 18, 3.5) end
ICONS.user = function(d) d.circle(10, 6.5, 3.3); d.poly({{3.5,17.5},{4.5,13.5},{7,11.8},{13,11.8},{15.5,13.5},{16.5,17.5}}) end
ICONS.gear = function(d)
    d.circle(10, 10, 2.6)
    d.circle(10, 10, 6)
    for i = 0, 7 do
        local a = math.rad(i * 45)
        d.line(10 + math.cos(a) * 6.4, 10 + math.sin(a) * 6.4, 10 + math.cos(a) * 8.6, 10 + math.sin(a) * 8.6)
    end
end
ICONS.search = function(d) d.circle(8.5, 8.5, 5.5); d.line(12.6, 12.6, 17, 17) end
ICONS.minus = function(d) d.line(4, 10, 16, 10) end
ICONS.close = function(d) d.line(5.5, 5.5, 14.5, 14.5); d.line(14.5, 5.5, 5.5, 14.5) end
ICONS.chevronDown = function(d) d.poly({{3.5,7},{10,13.5},{16.5,7}}) end
ICONS.check = function(d) d.poly({{4,10.5},{8,14.5},{16,5.5}}) end
ICONS.bolt = function(d) d.poly({{11.5,2},{4.5,11},{9.5,11},{8.5,18},{15.5,8.5},{10.5,8.5},{11.5,2}}) end
ICONS.target = function(d) d.circle(10, 10, 7.5); d.circle(10, 10, 4); d.circle(10, 10, 1.2, true) end
ICONS.pulse = function(d) d.poly({{1.5,10},{6,10},{8.5,3.5},{12,16.5},{14.5,10},{18.5,10}}) end
ICONS.discord = function(d)
    d.poly({{3.2,15.2},{2.6,8.8},{4.6,5},{7.8,3.4},{8.7,4.8},{11.3,4.8},{12.2,3.4},{15.4,5},{17.4,8.8},{16.8,15.2},{13.6,16.6},{12.6,14.9},{7.4,14.9},{6.4,16.6},{3.2,15.2}})
    d.circle(7.6, 10.4, 1.35, true)
    d.circle(12.4, 10.4, 1.35, true)
end
ICONS.crown = function(d) d.poly({{2.5,15.5},{2.5,6},{7,10.5},{10,4},{13,10.5},{17.5,6},{17.5,15.5},{2.5,15.5}}) end
ICONS.list = function(d) d.line(3, 5, 17, 5); d.line(3, 10, 17, 10); d.line(3, 15, 12, 15) end
ICONS.globe = function(d) d.circle(10, 10, 7.5); d.line(2.5, 10, 17.5, 10); d.poly({{10,2.5},{7,10},{10,17.5}}); d.poly({{10,2.5},{13,10},{10,17.5}}) end
ICONS.snow = function(d) d.line(10, 2, 10, 18); d.line(3.1, 6, 16.9, 14); d.line(3.1, 14, 16.9, 6); d.poly({{8,3.8},{10,5.8},{12,3.8}}); d.poly({{8,16.2},{10,14.2},{12,16.2}}) end
ICONS.meteor = function(d) d.circle(14, 6, 2.6); d.line(11.9, 8.1, 3, 17); d.line(14.5, 9.6, 8.5, 15.6); d.line(9.4, 5.6, 4.4, 10.6) end
ICONS.music = function(d) d.circle(6.5, 15, 2.6); d.circle(14.5, 13, 2.6); d.line(9.1, 15, 9.1, 4.5); d.line(17.1, 13, 17.1, 2.5); d.line(9.1, 4.5, 17.1, 2.5) end
ICONS.flame = function(d) d.poly({{10,2},{14,7},{16,12},{13.5,17.5},{10,18.5},{6.5,17.5},{4,12},{6,8.5},{8,10.5},{10,2}}) end
ICONS.sliders = function(d) d.line(3, 5, 5.2, 5); d.circle(7.4, 5, 2.2); d.line(9.6, 5, 17, 5); d.line(3, 10, 10.8, 10); d.circle(13, 10, 2.2); d.line(15.2, 10, 17, 10); d.line(3, 15, 5.8, 15); d.circle(8, 15, 2.2); d.line(10.2, 15, 17, 15) end

ICONS.party = function(d)      -- 派对彩炮（Admin Abuse）
    d.poly({{3,17},{6.5,7},{13,13.5},{3,17}})
    d.line(4.75, 12, 8, 15.25)
    d.line(11, 2.8, 11, 5.6)
    d.line(14.4, 6, 16.6, 4.4)
    d.line(15.4, 10, 18, 9.4)
    d.circle(8.2, 3.6, 0.9, true)
    d.circle(17, 13.6, 0.9, true)
    d.circle(14.2, 2.8, 0.7, true)
end
ICONS.receipt = function(d)
    d.poly({{4.5,2.5},{15.5,2.5},{15.5,17.5},{13,15.8},{10,17.5},{7,15.8},{4.5,17.5},{4.5,2.5}})
    d.line(7.5, 6.5, 12.5, 6.5); d.line(7.5, 9.5, 12.5, 9.5); d.line(7.5, 12.5, 10.5, 12.5)
end
ICONS["repeat"] = function(d) d.poly({{3,11},{3,7},{16,7}}); d.poly({{13,4},{16,7},{13,10}}); d.poly({{17,9},{17,13},{4,13}}); d.poly({{7,10},{4,13},{7,16}}) end
ICONS.users = function(d) d.circle(7, 6.5, 3.2); d.poly({{2,17},{2,15.5},{4,12.8},{7,12},{10,12.8},{12,15.5},{12,17}}); d.circle(14.2, 6.5, 2.5); d.poly({{15.5,12.2},{17.5,14},{18,17}}) end

local function Icon(parent, name, size, color)
    color = color or C.text
    local root = new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size)}, parent)
    local sc = size / 20
    local thick = math.max(1.3, 1.6 * sc)
    local parts = {}
    local d = {}

    function d.line(x1, y1, x2, y2)
        x1, y1, x2, y2 = x1 * sc, y1 * sc, x2 * sc, y2 * sc
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
            Size = UDim2.fromOffset(len + thick * 0.5, thick),
            Rotation = math.deg(math.atan2(dy, dx)),
            BackgroundColor3 = color, BorderSizePixel = 0,
        }, root)
        full(f)
        parts[#parts + 1] = {inst = f, kind = "fill"}
    end
    function d.poly(points)
        for i = 1, #points - 1 do
            local a, b = points[i], points[i + 1]
            d.line(a[1], a[2], b[1], b[2])
        end
    end
    function d.circle(cx, cy, r, filled)
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(cx * sc, cy * sc),
            Size = UDim2.fromOffset(r * 2 * sc, r * 2 * sc),
            BackgroundColor3 = color, BackgroundTransparency = filled and 0 or 1, BorderSizePixel = 0,
        }, root)
        full(f)
        if filled then
            parts[#parts + 1] = {inst = f, kind = "fill"}
        else
            parts[#parts + 1] = {inst = new("UIStroke", {Color = color, Thickness = thick}, f), kind = "stroke"}
        end
    end

    local draw = ICONS[name]
    if draw then draw(d) end

    local icon = {root = root}
    function icon.setColor(c, time)
        for _, p in ipairs(parts) do
            local prop = (p.kind == "fill") and "BackgroundColor3" or "Color"
            if time and time > 0 then tween(p.inst, {[prop] = c}, time) else p.inst[prop] = c end
        end
    end
    return icon
end

--------------------------------------------------------------------
-- 全局拖动处理（滑条 / 窗口 / 缩放 / 悬浮 Logo 共用）
--------------------------------------------------------------------
local Drag = {}
local function isTouch(i) return i and i.UserInputType == Enum.UserInputType.Touch end
local function inputLive(i) return i ~= nil and i.UserInputState ~= Enum.UserInputState.End end
local function endDrag()
    -- 先把还没处理的最后一次移动补上，松手时位置才准
    if Drag.fn and Drag.dirty and Drag.cur then pcall(Drag.fn, Drag.cur) end
    local done = Drag.done
    Drag.fn, Drag.done, Drag.input, Drag.cur, Drag.dirty, Drag.idOK = nil, nil, nil, nil, false, false
    if done then pcall(done) end
end
-- 现在有没有某个 UI 已经被手指“锁定”了（拖动中）
function __NH_T.dragBusyOther()          -- 只看“手动拖动”（窗口 / 滑条 / 缩放把手）
    return Drag.fn ~= nil and inputLive(Drag.input)
end
function __NH_T.dragBusy()
    -- 手动拖动中，或者 logo 正在被引擎拖动检测拖着（extDragUntil 每次拖动事件都会续期，漏了结束事件也会自己过期）
    return (Drag.fn ~= nil and inputLive(Drag.input)) or os.clock() < (__NH_T.extDragUntil or 0)
end
-- input：按下去的那个输入（手指 / 鼠标）。谁先按下谁锁定：
-- 拖动期间别的手指按到别的 UI / logo / 滑条，一律不会抢走，也不会带着别的 UI 一起动
local function startDrag(onMove, onEnd, input)
    if Drag.fn then
        if inputLive(Drag.input) then return false end
        endDrag()   -- 上一次拖动的输入已经松开但没正常结束（事件丢了）→ 先清掉
    end
    Drag.fn, Drag.done, Drag.input = onMove, onEnd, input
    Drag.cur, Drag.dirty, Drag.idOK = nil, false, false
    Drag.lastPos = input and input.Position or nil
    return true
end
connect(UIS.InputChanged, function(input)
    if not Drag.fn then return end
    local mine
    if isTouch(Drag.input) then
        -- 手机：优先用“同一个输入对象”认手指；只有这个执行器根本认不出来（idOK 一直是 false）时，
        -- 才退而用距离判断，而且范围放大到 220（以前只有 10，手指滑快一点就“跟丢”，logo 就停在后面离手很远）
        if input == Drag.input then
            mine = true
            Drag.idOK = true
        elseif not Drag.idOK and isTouch(input) and Drag.lastPos ~= nil
            and (input.Position - Drag.lastPos).Magnitude < 220 then
            mine = true
        end
    else
        mine = input.UserInputType == Enum.UserInputType.MouseMovement
    end
    if mine then
        Drag.lastPos = input.Position
        Drag.cur, Drag.dirty = input, true
    end
end)
connect(UIS.InputEnded, function(input)
    if not Drag.fn then return end
    local ends
    if isTouch(Drag.input) then
        ends = (input == Drag.input)
    else
        ends = input.UserInputType == Enum.UserInputType.MouseButton1
    end
    if ends then endDrag() end
end)

-- 平滑器：拖动时目标位置每帧只更新一次，画面用指数插值追过去，低帧率下也顺滑
__NH_T.smoothers = {}
function __NH_T.makeSmoother(apply)
    local sm = {cur = Vector2.zero, tar = Vector2.zero, on = false, apply = apply}
    function sm.begin(v) sm.cur, sm.tar, sm.on = v, v, true end
    function sm.finish(flush)
        sm.on = false
        if flush then sm.cur = sm.tar apply(sm.tar) end
    end
    __NH_T.smoothers[#__NH_T.smoothers + 1] = sm
    return sm
end
connect(RunService.RenderStepped, function(dt)
    if Drag.fn then
        if Drag.input and Drag.input.UserInputState == Enum.UserInputState.End then
            endDrag()   -- 保险：输入已经松开但事件丢了
        else
            -- 每一帧直接读手指当前位置（只在确认“输入对象是活的”时），不依赖 InputChanged 有没有漏事件
            if Drag.idOK and isTouch(Drag.input) then
                local p = Drag.input.Position
                if Drag.lastPos == nil or p ~= Drag.lastPos then
                    Drag.lastPos = p
                    Drag.cur, Drag.dirty = Drag.input, true
                end
            end
            if Drag.dirty and Drag.cur then
                Drag.dirty = false
                pcall(Drag.fn, Drag.cur)
            end
        end
    end
    local a = 1 - math.exp(-dt * 26)
    for _, sm in ipairs(__NH_T.smoothers) do
        if sm.on then
            sm.cur = sm.cur:Lerp(sm.tar, a)
            sm.apply(sm.cur)
        end
    end
end)
local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

--------------------------------------------------------------------
-- ScreenGui / 主面板
--------------------------------------------------------------------
local SG = Instance.new("ScreenGui")
SG.Name = GUI_NAME
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

do
    if Env.HIDEUI then
        SG.Parent = Env.HIDEUI
    elseif gethui then
        SG.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(SG)
        SG.Parent = game:GetService("CoreGui")
    else
        SG.Parent = game:GetService("CoreGui")
    end
end

local Size = {w = Cfg.Width, h = Cfg.Height}

local main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, (Cfg.SafeTop - 8) / 2),
    Size = UDim2.fromOffset(Size.w, Size.h),
    BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false, ZIndex = 1,
}, SG)

-- 左边（侧边栏）和右边（内容）是两块独立的面板，中间留一格空隙，不黏在一起
do
    local gap = Cfg.PanelGap or 12
    local sw = Cfg.SidebarW or 180
    local function panel(name, pos, size)
        local p = new("Frame", {
            Name = name, Position = pos, Size = size, BackgroundColor3 = C.bg,
            BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2,
        }, main)
        corner(p, 14)
        stroke(p, C.stroke, 1.5, 0.1)
        new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(19, 19, 22), Color3.fromRGB(13, 13, 15))}, p)
        return p
    end
    __NH_T.sidePanel = panel("SidePanel", UDim2.fromOffset(0, 0), UDim2.new(0, sw, 1, 0))
    __NH_T.mainPanel = panel("MainPanel", UDim2.fromOffset(sw + gap, 0), UDim2.new(1, -(sw + gap), 1, 0))

    -- 白光环绕：左边侧栏、右边内容面板的最外围各一圈（只有边框，里面的内容不加）
    __NH_T.rings = {}
    local function ring(name, pos, size, speed)
        local rf = new("Frame", {
            Name = name, Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0,
            Active = false, ZIndex = 3,
        }, main)
        corner(rf, 14)
        local st = new("UIStroke", {
            Color = Color3.new(1, 1, 1), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, rf)
        local g = new("UIGradient", {
            Color = ColorSequence.new(Color3.new(1, 1, 1)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.40, 1),
                NumberSequenceKeypoint.new(0.50, 0.05), NumberSequenceKeypoint.new(0.60, 1),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, st)
        __NH_T.rings[#__NH_T.rings + 1] = {g = g, st = st, speed = speed, rot = 0}
    end
    ring("SideRing", UDim2.fromOffset(0, 0), UDim2.new(0, sw, 1, 0), 95)
    ring("ContentRing", UDim2.fromOffset(sw + gap, 0), UDim2.new(1, -(sw + gap), 1, 0), 95)

    -- 光圈颜色（UI Settings → Ring color）：所有光圈 + 左边选中框一起变
    __NH_T.ringRainbow = false
    __NH_T.RING_COLORS = {
        White = Color3.fromRGB(255, 255, 255), Cyan = Color3.fromRGB(80, 220, 255), Blue = Color3.fromRGB(90, 140, 255),
        Purple = Color3.fromRGB(175, 115, 255), Pink = Color3.fromRGB(255, 120, 190), Red = Color3.fromRGB(255, 90, 90),
        Orange = Color3.fromRGB(255, 160, 70), Yellow = Color3.fromRGB(255, 222, 90), Green = Color3.fromRGB(90, 230, 130),
    }
    for k, v in pairs({["Ring color"] = "光圈颜色", White = "白色", Cyan = "青色", Blue = "蓝色", Purple = "紫色",
        Pink = "粉色", Red = "红色", Orange = "橙色", Yellow = "黄色", Green = "绿色", Rainbow = "彩虹"}) do
        if __NH_T.ZH[k] == nil then __NH_T.ZH[k] = v end
    end
    function __NH_T.paintRing(c)
        for _, r in ipairs(__NH_T.rings) do
            if r.st then r.st.Color = c end
        end
        if __NH_T.selBar then __NH_T.selBar.BackgroundColor3 = c end
    end
    function __NH_T.setRingColor(name)
        if name == "Rainbow" then __NH_T.ringRainbow = true return end
        __NH_T.ringRainbow = false
        __NH_T.paintRing(__NH_T.RING_COLORS[name] or Color3.new(1, 1, 1))
    end

    local rr = 0
    connect(RunService.RenderStepped, function(dt)
        if not main.Visible then return end
        local tier = __NH_T.fxTier or 0
        if tier >= 2 then return end                     -- FPS 真的很低（<24）：光圈先停，恢复后自动继续
        if __NH_T.animating and __NH_T.animating() then return end
        local now = os.clock()
        local period = (tier >= 1) and 0.056 or 0.042     -- 正常约 24 次/秒，FPS 偏低时约 18 次/秒
        local rings, n = __NH_T.rings, #__NH_T.rings
        -- 三个光圈轮流更新：每帧最多 1 个（帧率低于约 42 时 2 个），不会三个挤在同一帧里，帧时间更平稳
        local budget = (dt > 0.024) and 2 or 1
        for _ = 1, n do
            rr = rr % n + 1
            local r = rings[rr]
            local last = r.t or now
            if now - last >= period then
                r.rot = (r.rot + math.min(now - last, 0.1) * r.speed) % 360
                r.t = now
                r.g.Rotation = r.rot
                budget -= 1
                if budget <= 0 then break end
            elseif not r.t then
                r.t = now
            end
        end
        if __NH_T.ringRainbow and now - (__NH_T.rbT or 0) > 0.1 then
            __NH_T.rbT = now
            __NH_T.paintRing(Color3.fromHSV((now * 0.12) % 1, 0.55, 1))
        end
    end)
end

local scaler = new("UIScale", {Scale = 1}, main)
local animV = Instance.new("NumberValue")
animV.Value = 1
local Fit = {fit = 1, user = 1}
local function applyScale()
    scaler.Scale = math.max(Fit.fit * Fit.user * animV.Value, 0.001)
end
local function updateFit()
    local s = SG.AbsoluteSize
    if s.X <= 0 or s.Y <= 0 then return end
    Fit.fit = math.max(math.min(1, (s.X - 20) / Size.w, (s.Y - Cfg.SafeTop - 8) / Size.h), 0.3)
    applyScale()
end
do
    local lastScaleT = 0
    connect(animV.Changed, function()
        local v, now = animV.Value, os.clock()
        if v <= 0.001 or math.abs(v - 1) < 0.0005 or now - lastScaleT >= 0.028 then
            lastScaleT = now
            applyScale()
        end
    end)
end
function __NH_T.animating() return os.clock() < (__NH_T.animUntil or 0) end
updateFit()
connect(SG:GetPropertyChangedSignal("AbsoluteSize"), updateFit)

--------------------------------------------------------------------
-- 小提示（底部居中）
--------------------------------------------------------------------
local Toast = {token = 0}
do
    Toast.box = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34),
        Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = C.card, BackgroundTransparency = 1, Visible = false, ZIndex = 300,
    }, SG)
    full(Toast.box)
    Toast.stroke = stroke(Toast.box, C.stroke, 1, 1)
    pad(Toast.box, 16, 16, 0, 0)
    Toast.label = text(Toast.box, {
        Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X,
        Font = Enum.Font.GothamSemibold, TextSize = 14, TextTransparency = 1, ZIndex = 301,
    })
end
local function toast(msg)
    Toast.token += 1
    local my = Toast.token
    Toast.label.Text = T(msg)
    Toast.box.Visible = true
    tween(Toast.box, {BackgroundTransparency = 0.05}, 0.15)
    tween(Toast.stroke, {Transparency = 0}, 0.15)
    tween(Toast.label, {TextTransparency = 0}, 0.15)
    task.delay(1.8, function()
        if Toast.token ~= my or not alive then return end
        tween(Toast.box, {BackgroundTransparency = 1}, 0.25)
        tween(Toast.stroke, {Transparency = 1}, 0.25)
        tween(Toast.label, {TextTransparency = 1}, 0.25)
        task.delay(0.3, function()
            if Toast.token == my and alive then Toast.box.Visible = false end
        end)
    end)
end

--------------------------------------------------------------------
-- 头像（异步读取一次）
--------------------------------------------------------------------
local Avatar = {img = nil, waiting = {}}
local function bindAvatar(label)
    if Avatar.img then label.Image = Avatar.img else Avatar.waiting[#Avatar.waiting + 1] = label end
end
task.spawn(function()
    local ok, content = pcall(function()
        return (Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100))
    end)
    if ok and content then
        Avatar.img = content
        for _, lb in ipairs(Avatar.waiting) do pcall(setProp, lb, "Image", content) end
    end
end)

--------------------------------------------------------------------
-- 顶部栏
--------------------------------------------------------------------
local header = new("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1, ZIndex = 2}, __NH_T.mainPanel)

-- Logo + 名字放在左边面板最上面；版本号 / 状态放在右边面板顶栏的左边
__NH_T.brand = new("Frame", {Name = "Brand", Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1, ZIndex = 2}, __NH_T.sidePanel)
local left = new("Frame", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
}, __NH_T.brand)
do
    local l = list(left, false, 10)
    l.VerticalAlignment = Enum.VerticalAlignment.Center
end
__NH_T.hdrLeft = new("Frame", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0),
    Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
}, header)
do
    local l = list(__NH_T.hdrLeft, false, 8)
    l.VerticalAlignment = Enum.VerticalAlignment.Center
end

__NH_T.logoImg = new("ImageLabel", {
    LayoutOrder = 1, Size = UDim2.fromOffset(42, 42), BackgroundColor3 = Color3.fromRGB(14, 14, 18),
    BorderSizePixel = 0, Image = Cfg.Logo, ScaleType = Enum.ScaleType.Fit,
}, left)
corner(__NH_T.logoImg, 9)

-- 两行文字：上面 NASA-Hub（闪烁），下面是自动读取的游戏名
local titleBox = new("Frame", {LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 48), AutomaticSize = Enum.AutomaticSize.X}, left)
do
    local l = list(titleBox, true, 0)
    l.VerticalAlignment = Enum.VerticalAlignment.Center
end
__NH_T.nameLabel = text(titleBox, {
    LayoutOrder = 1, Text = Cfg.Name, Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.fromRGB(255, 255, 255),
    Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
})
local gameLabel = text(titleBox, {
    LayoutOrder = 2, Text = Cfg.Game, Font = Enum.Font.GothamSemibold, TextColor3 = C.sub, TextSize = 15,
    Size = UDim2.fromOffset(0, 19), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.AtEnd,
})
new("UISizeConstraint", {MaxSize = Vector2.new(120, 19)}, gameLabel)

-- NASA-Hub 扫光动画（从 1NasaHub 搬过来的）：
-- 一道灰白渐变光从左到右扫过文字，循环播放。窗口隐藏 / FPS 很低时会自动暂停（见 applyFx）
local fxTweens = {}
local blinkTweens = {}
if Cfg.Blink then
    local shine = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 190, 198)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 198)),
        }),
        Offset = Vector2.new(-1, 0),
    }, __NH_T.nameLabel)
    blinkTweens[1] = TweenService:Create(shine,
        TweenInfo.new(Cfg.BlinkTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false),
        {Offset = Vector2.new(1, 0)})
    blinkTweens[1]:Play()
    fxTweens[#fxTweens + 1] = blinkTweens[1]
end

-- 自动读取你现在进入的游戏名字
function __NH_T.readGameName()
    local name
    local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
    if ok and type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
        name = info.Name
    end
    if not name then
        local okN, n = pcall(function() return game.Name end)
        if okN and type(n) == "string" and n ~= "" and n ~= "Game" and n ~= "Place" and n ~= "Baseplate" then name = n end
    end
    return name
end
if Cfg.AutoGameName then
    task.spawn(function()
        local name = __NH_T.readGameName()
        if name and alive then
            Cfg.Game = name
            gameLabel.Text = name
        end
    end)
end

if Cfg.HeaderLink and Cfg.HeaderLink ~= "" then
    -- 顶栏：Discord 图标 + 链接 + Copy 按钮（点一下自动复制链接）
    for k, v in pairs({["Copy"] = "复制", ["Copied"] = "已复制", ["Can't copy"] = "复制失败"}) do
        if __NH_T.ZH[k] == nil then __NH_T.ZH[k] = v end
    end
    local dc = new("Frame", {
        LayoutOrder = 4, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = C.pill, BorderSizePixel = 0,
    }, __NH_T.hdrLeft)
    __NH_T.dcPill = dc
    corner(dc, 7)
    pad(dc, 8, 3, 0, 0)
    do
        local l = list(dc, false, 7)
        l.VerticalAlignment = Enum.VerticalAlignment.Center
    end
    local dcIcon = Icon(dc, "discord", 15, C.mid)
    dcIcon.root.LayoutOrder = 1
    text(dc, {
        LayoutOrder = 2, Text = Cfg.HeaderLink, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
        Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = C.mid,
    })
    local cp = new("TextButton", {
        LayoutOrder = 3, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = C.pillOn, AutoButtonColor = false, BorderSizePixel = 0,
        Text = T("Copy"), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
    }, dc)
    corner(cp, 5)
    pad(cp, 9, 9, 0, 0)
    __NH_T.pressFx(cp, 0.92, connect)
    connect(cp.MouseEnter, function() tween(cp, {BackgroundColor3 = C.card}, 0.1) end)
    connect(cp.MouseLeave, function() tween(cp, {BackgroundColor3 = C.pillOn}, 0.1) end)
    local copyTok = 0
    connect(cp.MouseButton1Click, function()
        local ok = pcall(function()
            if setclipboard then setclipboard(Cfg.HeaderLink)
            elseif toclipboard then toclipboard(Cfg.HeaderLink)
            else error("no clipboard") end
        end)
        copyTok += 1
        local my = copyTok
        cp.Text = T(ok and "Copied" or "Can't copy")
        task.delay(1.6, function()
            if copyTok == my and cp.Parent then cp.Text = T("Copy") end
        end)
    end)
end

local verPill = text(__NH_T.hdrLeft, {
    LayoutOrder = 5, Text = Cfg.Version, Font = Enum.Font.GothamSemibold, TextSize = 13, TextColor3 = C.mid,
    BackgroundTransparency = 0, BackgroundColor3 = C.pill, TextXAlignment = Enum.TextXAlignment.Center,
    Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
})
corner(verPill, 7)
pad(verPill, 9, 9, 0, 0)

local statusPill = new("Frame", {
    LayoutOrder = 6, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
    BackgroundColor3 = C.pill, BorderSizePixel = 0,
}, __NH_T.hdrLeft)
full(statusPill)
pad(statusPill, 12, 14, 0, 0)
do
    local l = list(statusPill, false, 8)
    l.VerticalAlignment = Enum.VerticalAlignment.Center
end
__NH_T.statusDot = new("Frame", {LayoutOrder = 1, Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.good, BorderSizePixel = 0}, statusPill)
full(__NH_T.statusDot)
local statusLabel = text(statusPill, {
    LayoutOrder = 2, Text = T(Cfg.Status), Font = Enum.Font.GothamSemibold, TextSize = 14, TextColor3 = C.mid,
    Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
})

-- 搜索框
local searchWrap = new("Frame", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0), Size = UDim2.fromOffset(176, 36),
    BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 3,
}, header)
corner(searchWrap, 9)
stroke(searchWrap, C.stroke, 1)
local searchIcon = Icon(searchWrap, "search", 16, C.sub)
searchIcon.root.AnchorPoint = Vector2.new(0, 0.5)
searchIcon.root.Position = UDim2.new(0, 12, 0.5, 0)
local searchBox = new("TextBox", {
    Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1,
    Text = "", PlaceholderText = T("Search"), PlaceholderColor3 = C.sub, TextColor3 = C.text,
    Font = Enum.Font.GothamMedium, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false, ZIndex = 4,
}, searchWrap)

-- 最小化
local minBtn = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -56, 0.5, 0), Size = UDim2.fromOffset(36, 36),
    BackgroundColor3 = C.card, AutoButtonColor = false, Text = "", ZIndex = 3,
}, header)
corner(minBtn, 9)
stroke(minBtn, C.stroke, 1)
do
    local ic = Icon(minBtn, "minus", 14, C.mid)
    ic.root.AnchorPoint = Vector2.new(0.5, 0.5)
    ic.root.Position = UDim2.fromScale(0.5, 0.5)
end
connect(minBtn.MouseEnter, function() tween(minBtn, {BackgroundColor3 = C.pill}, 0.1) end)
connect(minBtn.MouseLeave, function() tween(minBtn, {BackgroundColor3 = C.card}, 0.1) end)

-- 关闭按钮 X：点一下先弹出确认警告，再点确认才会整个关闭
__NH_T.closeBtn = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(36, 36),
    BackgroundColor3 = C.card, AutoButtonColor = false, Text = "", ZIndex = 3,
}, header)
corner(__NH_T.closeBtn, 9)
stroke(__NH_T.closeBtn, C.stroke, 1)
do
    local cb = __NH_T.closeBtn
    local ic = Icon(cb, "close", 14, C.mid)
    ic.root.AnchorPoint = Vector2.new(0.5, 0.5)
    ic.root.Position = UDim2.fromScale(0.5, 0.5)
    connect(cb.MouseEnter, function() tween(cb, {BackgroundColor3 = Color3.fromRGB(64, 28, 30)}, 0.1) ic.setColor(C.bad, 0.1) end)
    connect(cb.MouseLeave, function() tween(cb, {BackgroundColor3 = C.card}, 0.1) ic.setColor(C.mid, 0.1) end)
end

--------------------------------------------------------------------
-- 左侧栏（图标 + 文字，样子和 1NasaHub 一样；选中框会滑动）
--------------------------------------------------------------------
local SIDEBAR_W = Cfg.SidebarW or 180
local TAB_H, TAB_STEP, TAB_Y0 = 42, 48, 10
local function tabY(i) return TAB_Y0 + (i - 1) * TAB_STEP end

local rail = new("Frame", {Name = "Rail", Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 1, -HEADER_H), BackgroundTransparency = 1, ZIndex = 2}, __NH_T.sidePanel)
local railList = new("ScrollingFrame", {
    Name = "RailList", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -64),
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 2,
}, rail)

-- 选中框：深色底 + 白色光边（光边会绕着转）+ 左边白色竖条
local selector = new("Frame", {
    Name = "Selector", BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.93, BorderSizePixel = 0,
    Position = UDim2.fromOffset(10, tabY(1)), Size = UDim2.fromOffset(SIDEBAR_W - 20, TAB_H), ZIndex = 3,
}, railList)
corner(selector, 11)
__NH_T.selStroke = new("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 1.6}, selector)
__NH_T.selGrad = new("UIGradient", {Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.88), NumberSequenceKeypoint.new(0.5, 0.02), NumberSequenceKeypoint.new(1, 0.88),
})}, __NH_T.selStroke)
__NH_T.rings[#__NH_T.rings + 1] = {g = __NH_T.selGrad, st = __NH_T.selStroke, speed = 165, rot = 0}   -- 选中框的白色光圈一直绕圈
local selBar = new("Frame", {
    AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -7, 0.5, 0), Size = UDim2.fromOffset(3, 18),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 4,
}, selector)
corner(selBar, 2)
__NH_T.selBar = selBar

local avatarBtn = new("ImageLabel", {
    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -14), Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = C.pill, BorderSizePixel = 0, Image = "", ScaleType = Enum.ScaleType.Crop,
}, rail)
full(avatarBtn)
stroke(avatarBtn, C.stroke, 1)
bindAvatar(avatarBtn)
__NH_T.sideAvatar = avatarBtn

-- 头像旁边：第一行名字，第二行 Free + 皇冠（皇冠是白灰色，没有颜色）
__NH_T.sideNameL = text(rail, {
    Name = "SideName", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 60, 1, -32),
    Size = UDim2.new(1, -72, 0, 18), Text = LP.DisplayName,
    Font = Enum.Font.GothamBold, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
})
do
    local row = new("Frame", {
        Name = "SideBadge", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 60, 1, -14),
        Size = UDim2.new(1, -72, 0, 16), BackgroundTransparency = 1, ZIndex = 3,
    }, rail)
    local l = list(row, false, 5)
    l.VerticalAlignment = Enum.VerticalAlignment.Center
    local cr = Icon(row, "crown", 13, C.mid)
    cr.root.LayoutOrder = 1
    text(row, {
        LayoutOrder = 2, Text = T(Cfg.Badge), Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
        TextSize = 12, Font = Enum.Font.GothamSemibold, TextColor3 = C.sub, ZIndex = 3,
    })
end

--------------------------------------------------------------------
-- 特效开关：窗口隐藏 / FPS 很低 / 手动关闭时，暂停一直在转的光边和 NASA-Hub 扫光
--------------------------------------------------------------------
local Fx = {low = false, reduce = true}
local function applyFx()
    local run = main.Visible and not Fx.low and not Fx.reduce
    for _, t in ipairs(fxTweens) do
        pcall(function()
            local playing = t.PlaybackState == Enum.PlaybackState.Playing
            if run and not playing then t:Play()
            elseif not run and playing then t:Pause() end
        end)
    end
end
connect(main:GetPropertyChangedSignal("Visible"), applyFx)

-- 自适应特效档位：0 = 全开；1 = FPS 偏低（光圈降到 12 次/秒、扫光暂停）；2 = FPS 很低（光圈也停）
-- 平均 FPS < 46 持续 2 秒进 1 档，< 36 进 2 档；恢复要平均 >= 54 并持续一段时间（每次反复掉下来恢复时间会加倍，避免来回抖）
__NH_T.fxTier = 0
local Perf = {avg = 60, downN = 0, upN = 0, need = 16, recovered = false, adaptive = true}
__NH_T.Perf = Perf
function Perf.setTier(t)
    if t == (__NH_T.fxTier or 0) then return end
    __NH_T.fxTier = t
    Fx.low = t >= 1
    applyFx()
end
function Perf.onFps(fps)       -- 每 0.5 秒调用一次
    if not Perf.adaptive then
        if (__NH_T.fxTier or 0) ~= 0 then Perf.setTier(0) end
        return
    end
    if fps < 3 then return end                 -- 游戏在后台 / 暂停，不算
    Perf.avg = Perf.avg * 0.7 + fps * 0.3
    local tier = __NH_T.fxTier or 0
    local want = (Perf.avg < 24) and 2 or ((Perf.avg < 32) and 1 or 0)     -- 游戏本身 30~50 帧属于正常，不降特效
    if want > tier then
        Perf.downN += 1
        Perf.upN = 0
        if Perf.downN >= 4 then
            Perf.downN = 0
            if Perf.recovered then Perf.need = math.min(Perf.need * 2, 80) Perf.recovered = false end
            Perf.setTier(want)
        end
    else
        Perf.downN = 0
        if tier > 0 and Perf.avg >= 38 then
            Perf.upN += 1
            if Perf.upN >= Perf.need then
                Perf.upN = 0
                Perf.recovered = true
                Perf.setTier(tier - 1)
            end
        else
            Perf.upN = 0
        end
    end
end

--------------------------------------------------------------------
-- 右边大 Logo（放在内容区正中间，在所有内容的后面；只显示图片，没有动画）
--------------------------------------------------------------------
if Cfg.RightLogoId ~= "" then
    new("ImageLabel", {
        Name = "RightLogo", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, HEADER_H / 2),     -- 右边面板内容区的正中心（窗口缩放时会跟着走）
        Size = UDim2.fromOffset(Cfg.RightLogoSize, Cfg.RightLogoSize),
        Image = Cfg.RightLogoId, ImageTransparency = Cfg.RightLogoTransparency,
        ScaleType = Enum.ScaleType.Fit, Interactable = false, ZIndex = 1,
    }, __NH_T.mainPanel)
end

--------------------------------------------------------------------
-- 内容区
--------------------------------------------------------------------
local content = new("Frame", {Name = "Content", Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 1, -HEADER_H), BackgroundTransparency = 1, ZIndex = 2}, __NH_T.mainPanel)

local titleLabel = text(content, {
    Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.5, -18, 0, 46),
    Font = Enum.Font.GothamBold, TextSize = 26,
})

local pillGroup = new("Frame", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 5), Size = UDim2.fromOffset(0, 36),
    BackgroundColor3 = C.card, BorderSizePixel = 0, ClipsDescendants = true,
}, content)
full(pillGroup)
stroke(pillGroup, C.stroke, 1)
-- 滑动选中块：放在子标签后面，点另一个标签时滑过去（按钮每次都会重建，所以选中块单独放、一直存在）
__NH_T.pillSel = new("Frame", {
    Name = "PillSel", Visible = false, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(0, 30),
    BackgroundColor3 = C.pillOn, BorderSizePixel = 0,
}, pillGroup)
full(__NH_T.pillSel)
-- 子标签放在一个可左右滑动的容器里：英文很长时先自动缩小间距，还放不下就可以滑动，不会再超出面板
__NH_T.pillScroll = new("ScrollingFrame", {
    Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
    CanvasSize = UDim2.new(), ElasticBehavior = Enum.ElasticBehavior.Never,
}, pillGroup)
do
    local l = list(__NH_T.pillScroll, false, 2)
    l.VerticalAlignment = Enum.VerticalAlignment.Center
end
connect(__NH_T.pillScroll:GetPropertyChangedSignal("CanvasPosition"), function()
    local t, sel = __NH_T.selTarget, __NH_T.pillSel
    local running = __NH_T.selTween and __NH_T.selTween.PlaybackState == Enum.PlaybackState.Playing
    if t and not running then sel.Position = UDim2.fromOffset(3 + t.x - __NH_T.pillScroll.CanvasPosition.X, 3) end
end)

local scroll = new("ScrollingFrame", {
    Name = "Scroll", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = Color3.fromRGB(80, 80, 88), CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, content)
list(scroll, true, 14)
pad(scroll, 18, 16, 0, 18)

--------------------------------------------------------------------
-- 下拉弹窗层
--------------------------------------------------------------------
local Pop = {}
local overlay = new("TextButton", {
    Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
    AutoButtonColor = false, Visible = false, ZIndex = 50,
}, main)
function Pop.close()
    overlay.Visible = false
    for _, ch in ipairs(overlay:GetChildren()) do ch:Destroy() end
end
connect(overlay.MouseButton1Click, Pop.close)

-- field：下拉框；items：选项名；multi：是否多选；isOn(name)：是否选中；pick(name)：点击回调
function Pop.open(field, items, multi, isOn, pick)
    Pop.close()
    overlay.Visible = true
    local s = scaler.Scale
    local rel = (field.AbsolutePosition - main.AbsolutePosition) / s
    local w = field.AbsoluteSize.X / s
    local fh = field.AbsoluteSize.Y / s
    local itemH = 34
    local h = math.min(#items * itemH + 8, 208)
    local x, y = rel.X, rel.Y + fh + 4
    if y + h > Size.h - 8 then y = math.max(8, rel.Y - h - 4) end

    local box = new("Frame", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.field,
        BorderSizePixel = 0, ZIndex = 51,
    }, overlay)
    corner(box, 10)
    stroke(box, C.stroke, 1)
    local sf = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = Color3.fromRGB(90, 90, 98), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 52,
    }, box)
    list(sf, true, 0)
    pad(sf, 4, 4, 4, 4)

    local rows = {}
    local function refresh()
        for name, r in pairs(rows) do
            local on = isOn(name)
            r.btn.BackgroundTransparency = on and 0.55 or 1
            r.label.TextColor3 = on and C.text or C.mid
            if r.check then r.check.root.Visible = on end
        end
    end
    for i, name in ipairs(items) do
        local btn = new("TextButton", {
            LayoutOrder = i, Size = UDim2.new(1, 0, 0, itemH - 2), BackgroundColor3 = C.pillOn, BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 53,
        }, sf)
        corner(btn, 7)
        local label = text(btn, {Text = T(name), Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = C.mid, ZIndex = 54, TextTruncate = Enum.TextTruncate.AtEnd})
        local check
        if multi then      -- 只有多选才需要勾，单选不用建这个图标
            check = Icon(btn, "check", 14, C.text)
            check.root.AnchorPoint = Vector2.new(1, 0.5)
            check.root.Position = UDim2.new(1, -10, 0.5, 0)
            check.root.ZIndex = 54
            for _, d in ipairs(check.root:GetDescendants()) do
                if d:IsA("GuiObject") then d.ZIndex = 54 end
            end
        end
        rows[name] = {btn = btn, label = label, check = check}
        ev(btn.MouseButton1Click, function()
            pick(name)
            if multi then refresh() else Pop.close() end
        end)
    end
    refresh()
end

--------------------------------------------------------------------
-- 状态 / 页面注册表
--------------------------------------------------------------------
local State = {}          -- 所有控件的值（切页 / 切语言后保留）
local Live = {}           -- 当前页上需要实时刷新的文字
local Cards, Secs = {}, {}
local BuildLive = {}      -- 正在创建的那一页的 Live 表（控件创建时往这里登记）
local curPage, curSub = 1, 1
local PAGES = {}
local renderPage

local function applySearch()
    local q = string.lower(searchBox.Text or "")
    for _, sec in ipairs(Secs) do
        local anySec = false
        for _, card in ipairs(sec.cards) do
            local anyCard = false
            local titleHit = q ~= "" and card.key:find(q, 1, true) ~= nil
            for _, r in ipairs(card.rows) do
                local show = (q == "") or titleHit or (r.key ~= "" and r.key:find(q, 1, true) ~= nil)
                r.frame.Visible = show
                if show then anyCard = true end
            end
            card.frame.Visible = anyCard or q == ""
            if card.frame.Visible then anySec = true end
        end
        sec.frame.Visible = anySec or q == ""
    end
end
connect(searchBox:GetPropertyChangedSignal("Text"), applySearch)

--------------------------------------------------------------------
-- 控件
--------------------------------------------------------------------
local function baseRow(card, def, opts)
    opts = opts or {}
    local idx = #card.rows + 1
    local row = new("Frame", {Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, def.h or 46), LayoutOrder = idx}, card.body)
    local div = new("Frame", {
        Name = "Div", BackgroundColor3 = C.line, BorderSizePixel = 0,
        Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 1, -1), Visible = false,
    }, row)
    if idx > 1 then card.rows[idx - 1].div.Visible = true end
    local nm = def.name or ""
    local entry = {frame = row, div = div, key = string.lower(T(nm)) .. " " .. string.lower(nm)}
    card.rows[idx] = entry
    if nm ~= "" and not opts.nolabel then
        -- 标签的宽度 = 这一行减去右边控件的宽度；太长会自动换行 / 截断，不会压到右边的控件
        local cw = 0
        if def.t == "toggle" then cw = 50
        elseif def.t == "dropdown" then cw = def.w or 190
        elseif def.t == "slider" then cw = 66 + 10 + (def.trackW or 128)
        elseif def.t == "button" then cw = def.w or 100
        elseif def.t == "input" then cw = def.w or 180 end
        text(row, {
            Text = T(nm), Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -(14 + cw + 26), 1, 0),
            TextSize = 15, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end
    return row, entry
end

-- ===== UI 开关 ↔ 功能代码 接线 =====
-- 功能代码把设置放在 Config 里（getgenv().NasaV1Config），部分功能还要调用对应模块的开关函数才会生效。
-- 这里按控件名字把 UI 的操作转成这两件事；没有对应功能的控件保持原样。
do
	local GE = (getgenv and getgenv()) or _G
	local function cfg() return GE.NasaV1Config end
	-- 多选下拉的值 -> 数组；空 = {"None"}（功能代码里 "None" 表示不过滤）
	local function toList(set)
		local out = {}
		if type(set) == "table" then
			for name, on in pairs(set) do
				if on == true and name ~= "None" then out[#out + 1] = name end
			end
		end
		table.sort(out)
		if #out == 0 then out[1] = "None" end
		return out
	end
	local function applyFilter(c, field, rtKey, rtFlag, set)
		local arr = toList(set)
		c[field] = arr
		local rt = GE.__NasaV1EggRuntime
		if rt then
			local active = {}
			for _, n in ipairs(arr) do if n ~= "None" then active[#active + 1] = n end end
			pcall(rt.setFilter, rt, rtKey, active)
			pcall(rt.setFilterEnabled, rt, rtFlag, #active > 0)
		end
	end
	local B = {}
	B["Auto steal"] = {
		get = function(c) return c.AutoSteal == true end,
		set = function(c, v)
			c.AutoSteal = v == true
			local rt = GE.__NasaV1EggRuntime
			if rt then pcall(rt.setEnabled, rt, v == true) end
		end,
	}
	B["Steal from other players"] = {
		get = function(c) return c.StealPlayers == true end,
		set = function(c, v)
			c.StealPlayers = v == true
			local ps = GE.__NasaV1PlayerSteal
			if ps then pcall(ps.setEnabled, ps, v == true) end
		end,
	}
	B["Anti guard"] = {
		get = function(c) return c.AntiGuardKnockback == true end,
		set = function(c, v)
			c.AntiGuardKnockback = v == true
			local ag = GE.__NasaV1AntiGuard
			if ag then pcall(ag.setEnabled, ag, v == true) end
		end,
	}
	B["Sell cheapest egg when bag is full"] = {
		get = function(c) return c.AutoSellEgg == true end,
		set = function(c, v) c.AutoSellEgg = v == true end,
	}
	B["Move to egg"] = {
		get = function(c)
			if c.StealMode ~= "Fly" then return "Teleport" end
			return c.FlyAerial == true and "Fly in the air" or "Walk"
		end,
		set = function(c, v)
			local aerial = (v == "Fly in the air")
			local mode = (v == "Teleport") and "Semi Teleport" or "Fly"
			c.StealMode = mode
			c.FlyAerial = aerial
			c.FlyZigzag = false
			local rt = GE.__NasaV1EggRuntime
			if rt then pcall(rt.setStealMode, rt, mode == "Semi Teleport" and "Instant" or mode, aerial, false) end
		end,
	}
	B["Zones"] = { set = function(c, v) applyFilter(c, "StealAreas", "areas", "area", v) end }
	B["Rarities"] = { set = function(c, v) applyFilter(c, "StealRarities", "rarities", "rarity", v) end }
	B["Min value /s"] = {
		get = function(c) return tonumber(c.StealMinValue) or 0 end,
		set = function(c, v)
			v = tonumber(v) or 0
			c.StealMinValue = v
			local rt = GE.__NasaV1EggRuntime
			if rt then pcall(rt.setMinValuePerSec, rt, v) end
		end,
	}
	B["Enable Webhook"] = {
		get = function(c) return c.WebhookEnabled == true end,
		set = function(c, v) c.WebhookEnabled = v == true end,
	}
	B["Webhook URL"] = {
		get = function(c) return tostring(c.WebhookURL or "") end,
		set = function(c, v) c.WebhookURL = tostring(v or "") end,
	}
	__NH_T.BindReg = B
	function __NH_T.attachBind(def, key)
		local b = B[def.name]
		if not b or def.cb or def.bound then return end
		def.bound = true
		local c = cfg()
		-- 先让控件显示功能代码里当前的真实值（比如 Anti guard 默认是开的）
		if b.get and c and State[key] == nil then
			local ok, v = pcall(b.get, c)
			if ok and v ~= nil and not (v == "" or v == 0) then State[key] = v end
		end
		def.cb = function(v)
			local c2 = cfg()
			if not c2 then toast("功能代码还没加载好") return end
			local t0 = os.clock()
			local ok, err = pcall(b.set, c2, v)
			if GE.NasaProfile then
				local ms = (os.clock() - t0) * 1000
				if ms >= 8 then warn(("[NASA-Profile] 开关 %s 耗时 %.0f ms"):format(tostring(def.name), ms)) end
			end
			if not ok then warn("[NASA-Hub] 设置失败 (" .. tostring(def.name) .. "): " .. tostring(err)) end
		end
	end
end

function __NH_T.buildToggle(card, def, key)
    local row = baseRow(card, def)
    if State[key] == nil then State[key] = def.default and true or false end
    local track = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(50, 28),
        Text = "", AutoButtonColor = false, BackgroundColor3 = State[key] and C.text or C.off, BorderSizePixel = 0,
    }, row)
    full(track)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, State[key] and 25 or 3, 0.5, 0),
        Size = UDim2.fromOffset(22, 22), BackgroundColor3 = State[key] and C.bg2 or C.text, BorderSizePixel = 0,
    }, track)
    full(knob)
    local function paint(instant)
        local on = State[key]
        local t = instant and 0 or 0.18
        tween(track, {BackgroundColor3 = on and C.text or C.off}, t)
        if instant then
            tween(knob, {Position = UDim2.new(0, on and 25 or 3, 0.5, 0), BackgroundColor3 = on and C.bg2 or C.text}, 0)
        else
            tween(knob, {Position = UDim2.new(0, on and 25 or 3, 0.5, 0), BackgroundColor3 = on and C.bg2 or C.text}, 0.28, Enum.EasingStyle.Back)
            -- 旋钮滑动时先压扁一点再弹回来
            tween(knob, {Size = UDim2.fromOffset(27, 20)}, 0.09)
            task.delay(0.09, function()
                if knob.Parent then tween(knob, {Size = UDim2.fromOffset(22, 22)}, 0.22, Enum.EasingStyle.Back) end
            end)
        end
    end
    __NH_T.pressFx(track, 0.94, ev)
    ev(track.MouseButton1Click, function()
        State[key] = not State[key]
        paint(false)
        if def.cb then pcall(def.cb, State[key]) end
    end)
end

function __NH_T.buildDropdown(card, def, key)
    local row = baseRow(card, def)
    local multi = def.multi
    if State[key] == nil then
        if multi then
            local set = {}
            for _, n in ipairs(def.default or {}) do set[n] = true end
            State[key] = set
        else
            State[key] = def.default or def.list[1]
        end
    end
    local field = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(def.w or 190, 34),
        Text = "", AutoButtonColor = false, BackgroundColor3 = C.field, BorderSizePixel = 0,
    }, row)
    corner(field, 8)
    stroke(field, C.stroke, 1, 0.2)
    __NH_T.pressFx(field, 0.97, ev)
    ev(field.MouseEnter, function() tween(field, {BackgroundColor3 = C.pill}, 0.12) end)
    ev(field.MouseLeave, function() tween(field, {BackgroundColor3 = C.field}, 0.12) end)
    local txt = text(field, {
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), Font = Enum.Font.GothamSemibold,
        TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local chev = Icon(field, "chevronDown", 12, C.sub)
    chev.root.AnchorPoint = Vector2.new(1, 0.5)
    chev.root.Position = UDim2.new(1, -10, 0.5, 0)
    local badge = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -30, 0.5, 0), Size = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.pillOn, BorderSizePixel = 0, Visible = false,
    }, field)
    full(badge)
    pad(badge, 7, 7, 0, 0)
    local badgeLabel = text(badge, {Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextSize = 13, Font = Enum.Font.GothamSemibold, TextColor3 = C.mid})

    local function refresh()
        if multi then
            local first, n = nil, 0
            for _, name in ipairs(def.list) do
                if State[key][name] then
                    n += 1
                    if not first then first = name end
                end
            end
            txt.Text = first and T(first) or T("None")
            badge.Visible = n > 1
            badgeLabel.Text = "+" .. (n - 1)
            txt.Size = UDim2.new(1, n > 1 and -86 or -40, 1, 0)
            txt.TextColor3 = first and C.text or C.mid
        else
            txt.Text = T(State[key])
        end
    end
    refresh()

    ev(field.MouseButton1Click, function()
        Pop.open(field, def.list, multi,
            function(name)
                if multi then return State[key][name] == true end
                return State[key] == name
            end,
            function(name)
                if multi then
                    State[key][name] = not State[key][name] or nil
                else
                    State[key] = name
                end
                refresh()
                if def.cb then pcall(def.cb, State[key]) end
            end)
    end)
end

function __NH_T.buildSlider(card, def, key)
    local row = baseRow(card, def)
    local log = def.log
    local minV, maxV = def.min or 0, def.max or 100
    local exp = def.exp or 9
    if State[key] == nil then State[key] = def.default or minV end

    local TW = def.trackW or 128
    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(66, 34),
        BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "", ClearTextOnFocus = false,
        Font = Enum.Font.GothamSemibold, TextSize = 14, TextColor3 = C.text,
    }, row)
    corner(box, 8)
    stroke(box, Color3.fromRGB(78, 78, 86), 1)

    local area = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14 - 66 - 10, 0.5, 0), Size = UDim2.fromOffset(TW, 28),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    }, row)
    local track = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.off, BorderSizePixel = 0}, area)
    full(track)
    local fill = new("Frame", {Size = UDim2.fromOffset(0, 3), BackgroundColor3 = C.text, BorderSizePixel = 0}, track)
    full(fill)
    local knob = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.text, BorderSizePixel = 0}, area)
    full(knob)

    local function toT(v)
        if log then
            if v <= 0 then return 0 end
            return math.clamp(math.log10(v) / exp, 0, 1)
        end
        if maxV == minV then return 0 end
        return math.clamp((v - minV) / (maxV - minV), 0, 1)
    end
    local function fromT(t)
        if log then
            if t < 0.03 then return 0 end
            return math.floor(10 ^ (t * exp) + 0.5)
        end
        local step = def.step or 1
        local v = minV + t * (maxV - minV)
        return math.clamp(math.floor(v / step + 0.5) * step, minV, maxV)
    end
    local function fmt(v)
        if (log and v <= 0) or (def.offAtMin and v <= minV) then return T("Off") end
        local s = log and __NH_T.shortNum(v) or tostring(math.floor(v * 100 + 0.5) / 100)
        return s .. (def.suffix or "")
    end
    local function paint(v)
        local t = toT(v)
        local x = 9 + t * (TW - 18)
        knob.Position = UDim2.fromOffset(x, 14)
        fill.Size = UDim2.fromOffset(x, 3)
        box.Text = fmt(v)
    end
    local function set(v, silent)
        State[key] = v
        paint(v)
        if def.cb and not silent then pcall(def.cb, v) end
    end
    paint(State[key])

    local function applyX(x)
        local s = area.AbsoluteSize.X / TW
        local t = math.clamp((x - area.AbsolutePosition.X - 9 * s) / ((TW - 18) * s), 0, 1)
        set(fromT(t))
    end
    ev(area.InputBegan, function(input)
        if isPress(input) and not __NH_T.dragBusy() then
            applyX(input.Position.X)
            startDrag(function(inp) applyX(inp.Position.X) end, nil, input)
        end
    end)
    ev(box.FocusLost, function()
        local n = __NH_T.parseNum(box.Text)
        if n == nil then
            paint(State[key])
        else
            if log then n = math.clamp(math.floor(n + 0.5), 0, 10 ^ exp) else n = math.clamp(n, minV, maxV) end
            set(n)
        end
    end)
end

function __NH_T.buildButton(card, def, key)
    local row = baseRow(card, def)
    local b = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(def.w or 100, 32),
        BackgroundColor3 = C.field, AutoButtonColor = false, Text = T(def.text or "Run"),
        Font = Enum.Font.GothamSemibold, TextSize = 14, TextColor3 = C.text, BorderSizePixel = 0,
    }, row)
    corner(b, 8)
    stroke(b, C.stroke, 1, 0.2)
    __NH_T.pressFx(b, 0.95, ev)
    ev(b.MouseEnter, function() tween(b, {BackgroundColor3 = C.pillOn}, 0.1) end)
    ev(b.MouseLeave, function() tween(b, {BackgroundColor3 = C.field}, 0.1) end)
    ev(b.MouseButton1Click, function()
        if def.cb then pcall(def.cb) else toast("Not available") end
    end)
end

function __NH_T.buildInput(card, def, key)
    local row = baseRow(card, def)
    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(def.w or 180, 34),
        BackgroundColor3 = C.field, BorderSizePixel = 0, Text = State[key] or "", ClearTextOnFocus = false,
        PlaceholderText = T(def.placeholder or ""), PlaceholderColor3 = C.sub, TextColor3 = C.text,
        Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    corner(box, 8)
    stroke(box, C.stroke, 1, 0.2)
    pad(box, 10, 10, 0, 0)
    ev(box.FocusLost, function(enter)
        State[key] = box.Text
        if enter and def.cb then pcall(def.cb, box.Text) end
    end)
end

function __NH_T.buildInfo(card, def, key)
    local row = baseRow(card, def)
    local v = text(row, {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0.5, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamSemibold, TextColor3 = C.mid, TextSize = 15,
        Text = def.get and def.get() or "",
    })
    if def.id then BuildLive[def.id] = v end
end

function __NH_T.buildNote(card, def, key)
    local row = baseRow(card, {h = 0, name = def.text}, {nolabel = true})
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.Size = UDim2.new(1, 0, 0, 0)
    local l = text(row, {
        Text = "•  " .. T(def.text), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextColor3 = C.mid, TextSize = 14,
    })
    pad(l, 14, 14, 10, 10)
end

-- 蛋价值列表（只读：读取游戏自己的蛋快照，不做任何偷蛋 / 传送）
local EggData = {}
do
    local cache = {}
    local function find(root, ...)
        local cur = root
        for _, name in ipairs({...}) do cur = cur and cur:FindFirstChild(name) end
        return cur
    end
    local function loadModule(key, ...)
        if cache[key] ~= nil then return cache[key] or nil end
        local inst = find(ReplicatedStorage, ...)
        if not inst then return nil end
        local ok, mod = pcall(require, inst)
        cache[key] = ok and mod or false
        return ok and mod or nil
    end
    function EggData.money(value)
        local units = {{1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}}
        for _, u in ipairs(units) do
            if value >= u[1] then return string.format("$%.2f%s/s", value / u[1], u[2]) end
        end
        return string.format("$%d/s", math.floor(value + 0.5))
    end
    local function describe(record, Assets, Mutations)
        local directory = type(Assets) == "table" and Assets.Directory or nil
        local entry = type(directory) == "table" and directory[tostring(record.AssetCategory)] or nil
        local info = {Uid = record.Uid, Name = tostring(record.AssetCategory), Icon = "", Value = 0}
        if type(entry) == "table" then
            info.Name = tostring(entry.DisplayName or record.AssetCategory)
            local icon = entry.Icon
            if icon ~= nil and tostring(icon) ~= "" then
                icon = tostring(icon)
                info.Icon = tonumber(icon) and ("rbxassetid://" .. icon) or icon
            end
            local scale = tonumber(record.AssetScale) or 1
            local factor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
            local mutation = 1
            if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
                local okM, resM = pcall(Mutations.EarningsFor, type(record.Mutations) == "table" and record.Mutations or {})
                if okM and type(resM) == "number" then mutation = resM end
            end
            info.Value = (tonumber(entry.EarningRate) or 0) * factor * mutation
        end
        return info
    end
    function EggData.fetch()
        local rf = find(ReplicatedStorage, "Packages", "Networking", "RF/EggWorld/AskFieldEggSnapshot")
        if not rf then return nil, "unavailable" end
        local ok, result = pcall(function() return rf:InvokeServer() end)
        local records = ok and type(result) == "table" and result.Records or nil
        if type(records) ~= "table" then return nil, "failed" end
        local Assets = loadModule("assets", "Data", "Assets")
        local Mutations = loadModule("mutations", "Shared", "Modules", "Mutations")
        local out = {}
        for _, record in pairs(records) do
            if type(record) == "table" and type(record.Uid) == "string" then
                local okD, info = pcall(describe, record, Assets, Mutations)
                if okD and info then out[#out + 1] = info end
            end
        end
        table.sort(out, function(a, b)
            if a.Value ~= b.Value then return a.Value > b.Value end
            return a.Uid < b.Uid
        end)
        return out
    end
end

-- 判断一个控件是不是真的显示在屏幕上（它自己和所有上层都可见）
local function shown(inst)
    local cur = inst
    while cur and cur ~= SG do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        cur = cur.Parent
    end
    return cur == SG
end

function __NH_T.buildEggList(card, def, key)
    local row = baseRow(card, {h = 0, name = ""}, {nolabel = true})
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.Size = UDim2.new(1, 0, 0, 0)
    local holder = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, row)
    list(holder, true, 2)
    pad(holder, 0, 0, 0, 6)

    local busy, lastSig = false, nil
    local function clear()
        for _, ch in ipairs(holder:GetChildren()) do
            if ch:IsA("GuiObject") then ch:Destroy() end
        end
    end
    local function message(msg)
        clear()
        local l = text(holder, {Text = T(msg), Size = UDim2.new(1, 0, 0, 36), TextColor3 = C.sub, TextSize = 14})
        pad(l, 14, 14, 0, 0)
    end
    local function render()
        if busy or not shown(holder) then return end     -- 没显示在屏幕上就不去读取
        busy = true
        if lastSig == nil then message("Loading...") end
        task.spawn(function()
            local data, why = EggData.fetch()
            busy = false
            if not alive or not holder.Parent then return end
            -- 用"内容的签名"判断有没有变化，没变就不重画（以前每 6 秒都整个重建一次）
            local sig
            if not data then
                sig = "err:" .. tostring(why)
            else
                local parts = {tostring(#data)}
                for i = 1, math.min(#data, 12) do
                    parts[#parts + 1] = tostring(data[i].Uid) .. ":" .. tostring(math.floor(data[i].Value))
                end
                sig = table.concat(parts, "|")
            end
            if sig == lastSig then return end
            lastSig = sig
            if not data then
                message(why == "unavailable" and "Egg data isn't available in this game" or "Couldn't read eggs, try Refresh")
                return
            end
            if #data == 0 then message("No eggs found") return end
            clear()
            local total = 0
            for _, e in ipairs(data) do total += e.Value end
            local head = text(holder, {
                LayoutOrder = 0, Text = string.format("%s: %d   ·   %s: %s", T("Eggs"), #data, T("Total"), EggData.money(total)),
                Size = UDim2.new(1, 0, 0, 28), TextColor3 = C.sub, TextSize = 14,
            })
            pad(head, 14, 14, 0, 0)
            local top = math.min(#data, 12)
            for i = 1, top do
                local e = data[i]
                local r = new("Frame", {LayoutOrder = i, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1}, holder)
                new("ImageLabel", {
                    Position = UDim2.fromOffset(14, 4), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1,
                    Image = e.Icon, ScaleType = Enum.ScaleType.Fit,
                }, r)
                text(r, {Text = e.Name, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd})
                text(r, {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.fromOffset(100, 30),
                    Text = EggData.money(e.Value), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamSemibold,
                    TextColor3 = C.green, TextSize = 14,
                })
            end
        end)
    end
    message("Loading...")
    BuildLive.eggRefresh = function() lastSig = nil render() end   -- Refresh 按钮：强制重画
    BuildLive.onShow = render                                      -- 切到这一页时读取一次
    task.spawn(function()
        while alive and holder.Parent do
            task.wait(6)
            if alive and holder.Parent and shown(holder) then render() end
        end
    end)
end

function __NH_T.buildProfile(card, def, key)
    local row = baseRow(card, {h = 72, name = ""}, {nolabel = true})
    local av = new("ImageLabel", {
        Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.pill, BorderSizePixel = 0,
        Image = "", ScaleType = Enum.ScaleType.Crop,
    }, row)
    full(av)
    stroke(av, C.stroke, 1)
    bindAvatar(av)
    local nameL = text(row, {Position = UDim2.fromOffset(70, 14), Size = UDim2.new(1, -150, 0, 22), Font = Enum.Font.GothamBold, TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd})
    local handleL = text(row, {Position = UDim2.fromOffset(70, 36), Size = UDim2.new(1, -150, 0, 20), TextColor3 = C.sub, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd})
    local badge = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.pill, BorderSizePixel = 0,
    }, row)
    full(badge)
    pad(badge, 10, 12, 0, 0)
    do
        local l = list(badge, false, 6)
        l.VerticalAlignment = Enum.VerticalAlignment.Center
    end
    local cr = Icon(badge, "crown", 12, C.ok)
    cr.root.LayoutOrder = 1
    text(badge, {LayoutOrder = 2, Text = T(Cfg.Badge), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, TextSize = 13, Font = Enum.Font.GothamSemibold, TextColor3 = C.mid})

    local function paint()
        local hideN = State["home/Home/Hide name"]
        local hideA = State["home/Home/Hide avatar"]
        nameL.Text = hideN and "••••••••" or LP.DisplayName
        handleL.Text = hideN and "@••••••" or ("@" .. LP.Name)
        av.ImageTransparency = hideA and 1 or 0
        av.BackgroundTransparency = hideA and 0.3 or 0
        if __NH_T.sideNameL then __NH_T.sideNameL.Text = hideN and "••••••••" or LP.DisplayName end
        if __NH_T.sideAvatar then
            __NH_T.sideAvatar.ImageTransparency = hideA and 1 or 0
            __NH_T.sideAvatar.BackgroundTransparency = hideA and 0.3 or 0
        end
    end
    paint()
    BuildLive.profilePaint = paint
end

__NH_T.BUILDERS = {
    toggle = __NH_T.buildToggle, dropdown = __NH_T.buildDropdown, slider = __NH_T.buildSlider, button = __NH_T.buildButton,
    input = __NH_T.buildInput, info = __NH_T.buildInfo, note = __NH_T.buildNote, eggs = __NH_T.buildEggList, profile = __NH_T.buildProfile,
}

--------------------------------------------------------------------
-- 卡片 / 分区 / 页面渲染
--------------------------------------------------------------------
-- 后台分批创建页面时用：这一帧已经用够时间了，就先让出去，下一帧接着建
__NH_T.BUILD_BUDGET = 0.002
function __NH_T.yieldPoint(entry)
    if entry and entry.async and os.clock() - entry.t0 > __NH_T.BUILD_BUDGET then
        coroutine.yield()
    end
end

function __NH_T.makeCard(parent, cardDef, order)
    local frame = new("Frame", {
        Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = order,
    }, parent)
    corner(frame, 12)
    stroke(frame, C.stroke, 1, 0.1)
    list(frame, true, 0)

    local head = new("TextButton", {Name = "Head", Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1}, frame)
    local ic = Icon(head, cardDef.icon or "list", 18, cardDef.color or C.text)
    ic.root.AnchorPoint = Vector2.new(0, 0.5)
    ic.root.Position = UDim2.new(0, 14, 0.5, 0)
    text(head, {Text = string.upper(T(cardDef.title)), Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -76, 1, 0), Font = Enum.Font.GothamBold, TextSize = 14})
    local chev = Icon(head, "chevronDown", 12, C.sub)
    chev.root.AnchorPoint = Vector2.new(1, 0.5)
    chev.root.Position = UDim2.new(1, -14, 0.5, 0)

    local body = new("Frame", {Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2}, frame)
    list(body, true, 0)

    local card = {frame = frame, body = body, rows = {}, key = string.lower(T(cardDef.title)) .. " " .. string.lower(cardDef.title)}
    local open = true
    ev(head.MouseButton1Click, function()
        open = not open
        body.Visible = open
        tween(chev.root, {Rotation = open and 0 or -90}, 0.15)
    end)
    return card
end

function __NH_T.makeSection(secDef, ctx, order)
    local frame = new("Frame", {
        Name = "Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = order,
    }, ctx.parent)
    list(frame, true, 8)

    local head = new("TextButton", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1}, frame)
    text(head, {Text = string.upper(T(secDef.title)), Size = UDim2.new(1, -30, 1, 0), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.sub})
    local chev = Icon(head, "chevronDown", 12, C.sub)
    chev.root.AnchorPoint = Vector2.new(1, 0.5)
    chev.root.Position = UDim2.new(1, -2, 0.5, 0)

    local body = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2}, frame)
    local bl = list(body, false, 14)
    bl.VerticalAlignment = Enum.VerticalAlignment.Top

    local ncol = secDef.single and 1 or 2
    local cols = {}
    for i = 1, ncol do
        cols[i] = new("Frame", {
            Size = ncol == 1 and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -7, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i,
        }, body)
        list(cols[i], true, 12)
    end

    local open = true
    ev(head.MouseButton1Click, function()
        open = not open
        body.Visible = open
        tween(chev.root, {Rotation = open and 0 or -90}, 0.15)
    end)

    local sec = {frame = frame, cards = {}}
    for ci, cardDef in ipairs(secDef.cards) do
        local col = cols[math.min(cardDef.col or 1, ncol)]
        local card = __NH_T.makeCard(col, cardDef, ci)
        sec.cards[#sec.cards + 1] = card
        ctx.Cards[#ctx.Cards + 1] = card
        for _, def in ipairs(cardDef.rows) do
            local b = __NH_T.BUILDERS[def.t]
            if b then
                local key = ctx.page .. "/" .. ctx.sub .. "/" .. (def.name or def.text or def.t)
                __NH_T.attachBind(def, key)
                BuildLive = ctx.Live
                local ok, err = pcall(b, card, def, key)
                if not ok then warn("[NASA-Hub] 控件创建失败: " .. tostring(err)) end
                __NH_T.yieldPoint(ctx.entry)
            end
        end
    end
    ctx.Secs[#ctx.Secs + 1] = sec
end

function __NH_T.renderTitle()
    local page = PAGES[curPage]
    titleLabel.Text = T(page.title)
    for _, ch in ipairs(__NH_T.pillScroll:GetChildren()) do
        if ch:IsA("TextButton") then ch:Destroy() end
    end
    pillGroup.Visible = #page.subs > 1
    __NH_T.pillBtns = {}
    local TS = game:GetService("TextService")
    for i, sub in ipairs(page.subs) do
        local on = (i == curSub)
        local label = T(sub.name)
        local okw, tw = pcall(function()
            return TS:GetTextSize(label, __NH_T.FS(14), __NH_T.FM[Enum.Font.GothamSemibold] or Enum.Font.GothamSemibold, Vector2.new(1000, 40)).X
        end)
        if not okw then tw = #label * 8 end
        local b = new("TextButton", {
            LayoutOrder = i, Size = UDim2.fromOffset(tw + 24, 30),
            BackgroundColor3 = C.pillOn, BackgroundTransparency = 1, AutoButtonColor = false,
            Text = label, Font = Enum.Font.GothamSemibold, TextSize = 14,
            TextColor3 = C.sub, BorderSizePixel = 0,
        }, __NH_T.pillScroll)
        full(b)
        -- 选中的底色由 PillSel 滑过去；这里只处理文字颜色（点击时新旧两个文字颜色渐变）
        local anim = __NH_T.pillAnimate and __NH_T.lastPillPage == curPage
        if anim and on then
            tween(b, {TextColor3 = C.text}, 0.3)
        elseif anim and i == __NH_T.lastPillOn then
            b.TextColor3 = C.text
            tween(b, {TextColor3 = C.sub}, 0.3)
        elseif on then
            b.TextColor3 = C.text
        end
        __NH_T.pressFx(b, 0.94, ev)
        ev(b.MouseButton1Click, function()
            if curSub == i then return end
            curSub = i
            __NH_T.pillAnimate = true          -- 让选中块滑过去
            __NH_T.pageIn()
            renderPage()
        end)
        __NH_T.pillBtns[i] = {btn = b, tw = tw}
    end
    __NH_T.fitPills()
    __NH_T.lastPillPage, __NH_T.lastPillOn = curPage, curSub
end

-- 把选中块移到第 selX 像素、宽 selW（__NH_T.pillAnimate = true 时滑过去，否则直接放好）
function __NH_T.moveSel(selX, selW)
    local sel, ps = __NH_T.pillSel, __NH_T.pillScroll
    if not sel then return end
    if __NH_T.selTween then __NH_T.selTween:Cancel() __NH_T.selTween = nil end
    __NH_T.selTarget = {x = selX, w = selW}
    local pos = UDim2.fromOffset(3 + selX - ps.CanvasPosition.X, 3)
    local size = UDim2.fromOffset(selW, 30)
    local animate = __NH_T.pillAnimate and sel.Visible and selW > 0
    __NH_T.pillAnimate = false
    if animate then
        __NH_T.selTween = tween(sel, {Position = pos, Size = size}, 0.42, Enum.EasingStyle.Quint)
    else
        sel.Position, sel.Size = pos, size
        sel.Visible = selW > 0
    end
end

-- 根据窗口宽度算出子标签栏该多宽；太长就先缩小间距，再不行就变成可滑动，并把当前选中的滑到中间
function __NH_T.fitPills()
    local items = __NH_T.pillBtns
    if not items or #items == 0 then return end
    -- 左边的页面标题（Main / Admin Abuse …）先留出位置，子标签不能再把它挤掉
    local titleW = 0
    pcall(function()
        titleW = game:GetService("TextService"):GetTextSize(titleLabel.Text, titleLabel.TextSize, titleLabel.Font, Vector2.new(1000, 60)).X
    end)
    titleLabel.Size = UDim2.fromOffset(titleW + 4, 46)
    local avail = math.max(Size.w - (Cfg.SidebarW or 180) - (Cfg.PanelGap or 12) - 36 - titleW - 14, 160)
    local steps = {{12, 14}, {8, 14}, {5, 14}, {5, 13}, {4, 12}}
    local function total(p, ts)
        local t = (#items - 1) * 2
        for _, it in ipairs(items) do t += it.tw * ts / 14 + p * 2 end
        return t
    end
    local padX, ts = steps[#steps][1], steps[#steps][2]
    for _, st in ipairs(steps) do
        if total(st[1], st[2]) <= avail - 6 then padX, ts = st[1], st[2] break end
    end
    local inner = total(padX, ts)
    local x, selX, selW = 0, 0, 0
    for i, it in ipairs(items) do
        local w = it.tw * ts / 14 + padX * 2
        it.btn.Size = UDim2.fromOffset(w, 30)
        it.btn.TextSize = __NH_T.FS(ts)
        if i == curSub then selX, selW = x, w end
        x += w + 2
    end
    local w = math.min(inner + 6, avail)
    pillGroup.Size = UDim2.fromOffset(w, 36)
    local ps = __NH_T.pillScroll
    ps.CanvasSize = UDim2.fromOffset(inner, 0)
    if inner > w - 6 then
        ps.CanvasPosition = Vector2.new(math.clamp(selX - ((w - 6) - selW) / 2, 0, inner - (w - 6)), 0)
    else
        ps.CanvasPosition = Vector2.zero
    end
    __NH_T.moveSel(selX, selW)
end

--------------------------------------------------------------------
-- 页面缓存：每一页（每个子分页）只创建一次，之后切换只是显示 / 隐藏。
-- 以前每点一次左边按钮都会把整页销毁再重建，Main 页有几百个控件，所以一点就卡。
-- 现在：①第一次打开时才创建（或者 UI 出来后在后台一帧 3 毫秒慢慢提前建好）
--       ②创建时容器没有挂在界面上，建完才挂上去，不会一边建一边反复排版
--------------------------------------------------------------------
local PageCache = {}
local activeEntry
local Prebuild = {gen = 0}

function __NH_T.buildEntry(e)
    local page = PAGES[e.pi]
    local sub = page.subs[e.si] or page.subs[1]
    local ctx = {
        page = page.id, sub = sub.name, parent = e.container,
        Cards = e.Cards, Secs = e.Secs, Live = e.Live, entry = e,
    }
    for i, secDef in ipairs(sub.sections) do
        __NH_T.makeSection(secDef, ctx, i)
    end
    e.container.Parent = scroll
    e.done = true
end

local function getEntry(pi, si)
    local key = pi .. ":" .. si
    local e = PageCache[key]
    if e then return e end
    e = {key = key, pi = pi, si = si, Cards = {}, Secs = {}, Live = {}, async = false, t0 = 0, done = false, dead = false}
    e.container = new("Frame", {
        Name = "Page_" .. key, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Visible = false,
    })                                   -- 先不挂到界面上
    list(e.container, true, 14)
    e.co = coroutine.create(function() __NH_T.buildEntry(e) end)
    PageCache[key] = e
    return e
end

-- 往下建一步。async = true：用完这一帧的预算就停；async = false：一口气建完
local function stepEntry(e, async)
    if e.done or e.dead then return end
    if coroutine.status(e.co) == "dead" then e.done = true return end
    e.async = async
    e.t0 = os.clock()
    local ok, err = coroutine.resume(e.co)
    if not ok then
        warn("[NASA-Hub] 页面创建失败: " .. tostring(err))
        e.container.Parent = scroll
        e.done = true
    end
end

function __NH_T.dropEntry(e)
    e.dead = true
    if PageCache[e.key] == e then PageCache[e.key] = nil end
    if activeEntry == e then activeEntry = nil end
    pcall(function() e.container:Destroy() end)
end

function __NH_T.resetPageCache()          -- 切换语言时用：所有页面都要重新生成文字
    Prebuild.gen += 1
    for _, e in pairs(PageCache) do
        e.dead = true
        pcall(function() e.container:Destroy() end)
    end
    PageCache = {}
    activeEntry = nil
    Cards, Secs, Live = {}, {}, {}
end

-- force = true：把当前这一页丢掉重建（比如开关雪天后要刷新另一个开关的状态）
-- animate = true：右边标题淡入
function renderPage(force, animate)
    Pop.close()
    if force then
        local e0 = PageCache[curPage .. ":" .. curSub]
        if e0 then __NH_T.dropEntry(e0) end
    end
    local e = getEntry(curPage, curSub)
    stepEntry(e, false)                  -- 还没建好就现在建完（后台建好的话这里什么都不用做）
    if activeEntry and activeEntry ~= e and activeEntry.container.Parent then
        activeEntry.container.Visible = false
    end
    e.container.Visible = true
    activeEntry = e
    Cards, Secs, Live = e.Cards, e.Secs, e.Live
    scroll.CanvasPosition = Vector2.new(0, 0)
    __NH_T.renderTitle()
    if animate then
        titleLabel.TextTransparency = 1
        tween(titleLabel, {TextTransparency = 0}, 0.3)
    end
    if Live.onShow then pcall(Live.onShow) end
    applySearch()
end

-- 后台提前建好所有页面（先 Main，再其它），每帧最多花 BUILD_BUDGET 秒
local function startPrebuild(delay)
    Prebuild.gen += 1
    local my = Prebuild.gen
    task.spawn(function()
        task.wait(delay or 0)
        local order = {}
        for pi, page in ipairs(PAGES) do
            if page.id == "main" then for si = 1, #page.subs do order[#order + 1] = {pi, si} end end
        end
        for pi, page in ipairs(PAGES) do
            if page.id ~= "main" then for si = 1, #page.subs do order[#order + 1] = {pi, si} end end
        end
        for _, k in ipairs(order) do
            if not alive or my ~= Prebuild.gen then return end
            local e = getEntry(k[1], k[2])
            while alive and my == Prebuild.gen and not e.done and not e.dead do
                if not __NH_T.dragBusy() and not __NH_T.animating() and (__NH_T.fxTier or 0) < 2 then stepEntry(e, true) end   -- 拖动 UI 时先不建页面，免得掉帧
                RunService.Heartbeat:Wait()
            end
        end
    end)
end

--------------------------------------------------------------------
-- 左侧栏按钮
--------------------------------------------------------------------
local railBtns = {}
local selTween
local barToken = 0
local function paintRail(instant)
    for i, rb in ipairs(railBtns) do
        local on = (i == curPage)
        rb.icon.setColor(on and C.text or C.sub, instant and 0 or 0.2)
        tween(rb.label, {TextColor3 = on and C.text or C.sub}, instant and 0 or 0.2)
        if on and not rb.was and not instant and rb.scale then   -- 新选中的图标弹一下
            rb.scale.Scale = 0.75
            tween(rb.scale, {Scale = 1}, 0.45, Enum.EasingStyle.Back)
        end
        rb.was = on
    end
    local target = UDim2.fromOffset(10, tabY(curPage))
    if instant then
        selector.Position = target
        return
    end
    -- 选中框慢慢滑到新的位置（Quint 先快后慢）
    if selTween then selTween:Cancel() end
    selTween = tween(selector, {Position = target}, Cfg.TabSlideTime or 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    -- 左边的白色竖条：滑动时拉长，到位后缩回来
    barToken += 1
    local my = barToken
    tween(selBar, {Size = UDim2.fromOffset(3, 32)}, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    task.delay(0.16, function()
        if alive and my == barToken then
            tween(selBar, {Size = UDim2.fromOffset(3, 18)}, 0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
    end)
end

-- 换页 / 换子标签时，内容区轻轻往上滑进来
function __NH_T.pageIn()
    scroll.Position = UDim2.fromOffset(0, 64)
    tween(scroll, {Position = UDim2.fromOffset(0, 50)}, 0.32, Enum.EasingStyle.Quint)
end

function __NH_T.selectPage(i)
    if i == curPage then return end
    curPage, curSub = i, 1
    if searchBox.Text ~= "" then searchBox.Text = "" end   -- 先清掉搜索（还原旧页面的显示）
    paintRail()                                            -- 动画先开始
    task.spawn(function()
        RunService.Heartbeat:Wait()                        -- 等一帧，让滑动先动起来再换内容
        if alive and curPage == i then __NH_T.pageIn() renderPage(false, true) end
    end)
end

--------------------------------------------------------------------
-- 服务器工具 / 链接 / 音乐
--------------------------------------------------------------------
local function copyText(s)
    local ok = pcall(function()
        if setclipboard then setclipboard(s) elseif toclipboard then toclipboard(s) else error("no clipboard") end
    end)
    return ok
end

local function openLink(url)
    if type(url) ~= "string" or url == "" or url:find("your_", 1, true) then toast("Link not set") return end
    pcall(function() game:GetService("GuiService"):OpenBrowserWindow(url) end)
    if copyText(url) then toast("Link copied") else toast("Can't copy") end
end

function __NH_T.rejoin()
    toast("Rejoining...")
    local ok = pcall(function()
        if #Players:GetPlayers() <= 1 then
            LP:Kick("\nRejoining...")
            task.wait()
            TeleportService:Teleport(game.PlaceId, LP)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
        end
    end)
    if not ok then toast("Teleport failed") end
end

function __NH_T.hopLowest()
    toast("Searching servers...")
    task.spawn(function()
        local ok, res = pcall(function()
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
            return __NH_T.HttpService:JSONDecode(game:HttpGet(url))
        end)
        if ok and type(res) == "table" and type(res.data) == "table" then
            for _, sv in ipairs(res.data) do
                if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                    local ok2 = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, sv.id, LP) end)
                    if not ok2 then toast("Teleport failed") end
                    return
                end
            end
        end
        toast("No server found")
    end)
end

local Music = {}
do
    local sound = Instance.new("Sound")
    sound.Name = "NASA_Music"
    sound.Volume = Cfg.MusicVolume
    sound.Looped = true
    sound.Parent = __NH_T.SoundService
    local ms = {playing = false, id = Cfg.Music[1] and Cfg.Music[1].id or ""}
    local function norm(id)
        id = tostring(id or "")
        id = id:gsub("%s+", "")
        if id == "" then return "" end
        if id:find("rbxassetid://", 1, true) == 1 then return id end
        if id:match("^%d+$") then return "rbxassetid://" .. id end
        return id
    end
    local function refresh()
        sound:Stop()
        if not ms.playing then return end
        local id = norm(ms.id)
        if id == "" then toast("Add a song ID in Settings > Music") return end
        sound.SoundId = id
        sound.TimePosition = 0
        sound:Play()
    end
    function Music.select(name) for _, m in ipairs(Cfg.Music) do if m.name == name then ms.id = m.id break end end refresh() end
    function Music.setPlaying(on) ms.playing = on and true or false if ms.playing then refresh() else sound:Stop() end end
    function Music.setVolume(v) sound.Volume = v end
    function Music.setLoop(v) sound.Looped = v and true or false end
    function Music.custom(t) if norm(t) == "" then return end ms.id = t refresh() end
    function Music.destroy() pcall(function() sound:Stop() sound:Destroy() end) end
end

--------------------------------------------------------------------
-- 页面内容（按截图复刻 Steal 页面；其它页面沿用原来的功能内容）
--------------------------------------------------------------------

--------------------------------------------------------------------
-- 天气特效（雪天 / 流星）：粒子按时间预算分批创建、淡入淡出、FPS 低时自动减少粒子
--------------------------------------------------------------------
local Weather = {}
do
    local rand = math.random
    local LINEAR, SINE, QUAD = Enum.EasingStyle.Linear, Enum.EasingStyle.Sine, Enum.EasingStyle.Quad
    local layer = new("Frame", {Name = "WeatherLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Active = false, ZIndex = 7}, main)
    local wc = {mode = nil, quality = 1, snowCount = 100, snowSpeed = 1, snowSize = 1, snowWind = 0.3, meteorCount = 14, meteorSpeed = 1, meteorLength = 1, stars = true}

    local SLICE = 0.004
    local SWAY_N = 6
    local SNOW_COLOR = Color3.fromRGB(235, 244, 255)
    local gen = 0
    local pool = {}
    local sway = {}

    local function cancelTweens(p)
        for _, tw in ipairs(p.tweens) do pcall(tw.Cancel, tw) end
    end

    local function retire(p, fadeTime)
        if p.dead then return end
        p.dead = true
        local info = TweenInfo.new(fadeTime, LINEAR)
        for _, v in ipairs(p.vis) do
            TweenService:Create(v, info, {BackgroundTransparency = 1}):Play()
        end
        task.delay(fadeTime + 0.05, function()
            cancelTweens(p)
            p.root:Destroy()
        end)
    end

    local function retireSway(delay)
        local old = sway
        sway = {}
        task.delay(delay, function()
            for _, sw in ipairs(old) do
                pcall(sw.tween.Cancel, sw.tween)
                sw.inst:Destroy()
            end
        end)
    end

    local function clearWeather()
        gen += 1
        for _, p in ipairs(pool) do
            p.dead = true
            cancelTweens(p)
        end
        pool = {}
        for _, sw in ipairs(sway) do pcall(sw.tween.Cancel, sw.tween) end
        sway = {}
        layer:ClearAllChildren()
    end

    local function retireAll(fadeTime)
        gen += 1
        local old = pool
        pool = {}
        for _, p in ipairs(old) do retire(p, fadeTime) end
        retireSway(fadeTime + 0.1)
    end

    local function sliceLoop(myGen, count, fn)
        local t0 = os.clock()
        for i = 1, count do
            if myGen ~= gen then return false end
            fn(i)
            if os.clock() - t0 > SLICE then
                task.wait()
                t0 = os.clock()
            end
        end
        return true
    end

    ---------------- 雪天 ----------------
    local function createFlake(myGen, groups)
        local W, H = math.floor(Size.w), math.floor(Size.h)
        local depth = rand()
        local size = math.max(2, (2 + depth * 4.5) * wc.snowSize)
        local speed = (34 + depth * 78) * wc.snowSpeed * (0.85 + rand() * 0.3)
        local dx = wc.snowWind * 170 * (0.5 + depth * 0.5)
        local x0 = rand(math.floor(math.min(0, -dx)) - 10, math.floor(math.max(W, W - dx)) + 10)
        local endY = H + 4
        local startY = -size - 4
        local total = endY - startY
        local frac = rand()
        local y = startY + total * frac
        local x = x0 + dx * frac
        local alpha = 0.62 - depth * 0.47
        local endX = x0 + dx

        local band = math.clamp(math.floor(depth * SWAY_N) + 1, 1, SWAY_N)
        local flake = new("Frame", {
            BackgroundColor3 = SNOW_COLOR, BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(x, y),
        }, groups[band] or layer)
        if size >= 3 then corner(flake, 8) end

        local p = {root = flake, vis = {flake}, tweens = {}, dead = false}
        pool[#pool + 1] = p

        TweenService:Create(flake, TweenInfo.new(0.7, QUAD, Enum.EasingDirection.Out), {BackgroundTransparency = alpha}):Play()

        local fullDur = total / speed
        local firstDur = math.max(0.05, (endY - y) / speed)
        local first = TweenService:Create(flake, TweenInfo.new(firstDur, LINEAR), {Position = UDim2.fromOffset(endX, endY)})
        p.tweens[#p.tweens + 1] = first
        local conn
        conn = first.Completed:Connect(function(state)
            conn:Disconnect()
            if myGen ~= gen or p.dead or state ~= Enum.PlaybackState.Completed then return end
            flake.Position = UDim2.fromOffset(x0, startY)
            local loop = TweenService:Create(flake, TweenInfo.new(fullDur, LINEAR, Enum.EasingDirection.Out, -1), {Position = UDim2.fromOffset(endX, endY)})
            p.tweens[#p.tweens + 1] = loop
            loop:Play()
        end)
        first:Play()
    end

    local function buildSnow(myGen)
        if myGen ~= gen then return end
        local count = math.max(5, math.floor(wc.snowCount * wc.quality + 0.5))
        local groups = {}
        for k = 1, SWAY_N do
            local c = new("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1)}, layer)
            local amp = 6 + k * 4
            c.Position = UDim2.fromOffset(-amp, 0)
            local tw = TweenService:Create(c,
                TweenInfo.new(2.4 + rand() * 2.2 + k * 0.25, SINE, Enum.EasingDirection.InOut, -1, true, rand() * 1.5),
                {Position = UDim2.fromOffset(amp, 0)})
            tw:Play()
            sway[#sway + 1] = {inst = c, tween = tw}
            groups[k] = c
        end
        sliceLoop(myGen, count, function() createFlake(myGen, groups) end)
    end

    ---------------- 流星 ----------------
    local function launchMeteor(p, myGen)
        if myGen ~= gen or p.dead or not p.root.Parent then return end
        local W, H = math.floor(Size.w), math.floor(Size.h)

        local goLeft = rand() < 0.7
        local a = math.rad(rand(22, 38))
        local ca, sa = math.cos(a), math.sin(a)
        local dirX = goLeft and -ca or ca
        local len = rand(80, 190) * wc.meteorLength
        local thick = rand(2, 4)

        local startX, startY
        if rand() < 0.7 then
            startY = -30
            if goLeft then startX = rand(math.floor(W * 0.35), W + 200) else startX = rand(-200, math.floor(W * 0.65)) end
        else
            startX = goLeft and (W + 40) or -40
            startY = rand(-10, math.floor(H * 0.6))
        end

        local back = len * 0.5 + 12
        startX = startX - dirX * back
        startY = startY - sa * back

        local toBottom = (H + 60 - startY) / sa
        local toSide = goLeft and (startX + 60) / ca or (W + 60 - startX) / ca
        local dist = math.min(toBottom, toSide) + len
        local speed = rand(520, 980) * wc.meteorSpeed

        local root = p.root
        root.Size = UDim2.fromOffset(len, thick)
        root.Rotation = goLeft and (180 - math.deg(a)) or math.deg(a)
        root.BackgroundTransparency = rand() * 0.2
        root.Position = UDim2.fromOffset(startX, startY)
        p.halo.Size = UDim2.new(1, 0, 0, thick * 4)
        p.head.Size = UDim2.fromOffset(thick + 3, thick + 3)

        local tw = TweenService:Create(root, TweenInfo.new(dist / speed, LINEAR), {Position = UDim2.fromOffset(startX + dirX * dist, startY + sa * dist)})
        p.tweens = {tw}
        local conn
        conn = tw.Completed:Connect(function(state)
            conn:Disconnect()
            if myGen ~= gen or p.dead or state ~= Enum.PlaybackState.Completed then return end
            task.delay(0.05 + rand() * 1.1, launchMeteor, p, myGen)
        end)
        tw:Play()
    end

    local function createMeteor(myGen)
        local root = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.text, BorderSizePixel = 0, Position = UDim2.fromOffset(-600, -600), Size = UDim2.fromOffset(120, 3)}, layer)
        corner(root, 4)
        new("UIGradient", {
            Color = ColorSequence.new(Color3.fromRGB(120, 170, 255), Color3.fromRGB(255, 255, 255)),
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.65, 0.6), NumberSequenceKeypoint.new(1, 0)}),
        }, root)
        local halo = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(150, 190, 255), BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 12)}, root)
        corner(halo, 8)
        new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.8)})}, halo)
        local head = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.text, BorderSizePixel = 0, Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(5, 5)}, root)
        corner(head, 4)

        local p = {root = root, halo = halo, head = head, vis = {root, halo, head}, tweens = {}, dead = false}
        pool[#pool + 1] = p
        task.delay(rand() * 2.2, launchMeteor, p, myGen)
    end

    local function createStar()
        local W, H = math.floor(Size.w), math.floor(Size.h)
        local sz = (rand() < 0.2) and 3 or 2
        local star = new("Frame", {BackgroundColor3 = C.text, BackgroundTransparency = 0.95, BorderSizePixel = 0, Size = UDim2.fromOffset(sz, sz), Position = UDim2.fromOffset(rand(4, W - 4), rand(4, H - 4))}, layer)
        local p = {root = star, vis = {star}, tweens = {}, dead = false}
        pool[#pool + 1] = p
        local tw = TweenService:Create(star, TweenInfo.new(0.7 + rand() * 1.8, SINE, Enum.EasingDirection.InOut, -1, true, rand() * 1.5), {BackgroundTransparency = 0.15 + rand() * 0.3})
        p.tweens[1] = tw
        tw:Play()
    end

    local function buildMeteors(myGen)
        if wc.stars then sliceLoop(myGen, math.floor(26 * wc.quality + 0.5), createStar) end
        local count = math.max(3, math.floor(wc.meteorCount * wc.quality + 0.5))
        sliceLoop(myGen, count, function() createMeteor(myGen) end)
    end

    ---------------- 控制 ----------------
    local function rebuildWeather(soft)
        if soft and #pool > 0 then retireAll(0.35) else clearWeather() end
        if not wc.mode or not main.Visible or not alive then return end
        local myGen = gen
        task.spawn(function()
            if wc.mode == "snow" then buildSnow(myGen)
            elseif wc.mode == "meteor" then buildMeteors(myGen) end
        end)
    end

    local pendingId = 0
    local function scheduleRebuild(delay, soft)
        pendingId += 1
        local id = pendingId
        task.delay(delay or 0.3, function()
            if id == pendingId then rebuildWeather(soft) end
        end)
    end

    function Weather.set(key, value)
        wc[key] = value
        if wc.mode then scheduleRebuild(0.3, true) end
    end

    function Weather.setMode(mode, on)
        if on then
            wc.mode = mode
            wc.quality = 1
            -- 雪天和流星互斥：把另一个开关的状态关掉
            if mode == "snow" then State["settings/Weather/Enable Meteor"] = false
            else State["settings/Weather/Enable Snow"] = false end
        elseif wc.mode == mode then
            wc.mode = nil
        else
            return
        end
        pendingId += 1
        rebuildWeather(true)
    end

    local lowCount, graceUntil = 0, 0
    function Weather.onFps(fps)
        if not wc.mode or os.clock() < graceUntil then lowCount = 0 return end
        if fps < 40 and wc.quality > 0.36 then lowCount += 1 else lowCount = 0 end
        if lowCount >= 4 then
            lowCount = 0
            wc.quality = math.max(0.35, wc.quality * 0.7)
            graceUntil = os.clock() + 3
            local keep = math.max(8, math.floor(#pool * 0.7))
            while #pool > keep do
                retire(table.remove(pool, rand(#pool)), 0.3)
            end
        end
    end

    Weather.clear = clearWeather
    connect(main:GetPropertyChangedSignal("Visible"), function()
        if main.Visible then
            if wc.mode then scheduleRebuild(0.5, false) end
        else
            pendingId += 1
            clearWeather()
        end
    end)
end

local hudFrame   -- 顶部 FPS / Ping，下面会创建
local logoBtn    -- 悬浮 Logo，下面会创建
local Hub = {}

function __NH_T.allOf(listT)
    local t = {}
    for i, v in ipairs(listT) do t[i] = v end
    return t
end
function __NH_T.firstN(listT, n)
    local t = {}
    for i = 1, math.min(n, #listT) do t[i] = listT[i] end
    return t
end

-- 帧率上限（需要执行器支持 setfpscap；不支持就返回 false）
local function applyFpsCap(v)
    local n = (v == "Unlimited") and 1000 or (tonumber(v) or 60)
    local ok = pcall(function()
        local f = (getgenv and getgenv().setfpscap) or setfpscap
        if type(f) ~= "function" then error("no setfpscap") end
        f(n)
    end)
    return ok
end

local musicNames = {}
for _, m in ipairs(Cfg.Music) do musicNames[#musicNames + 1] = m.name end

PAGES = {
    ------------------------------------------------------------ Home
    {id = "home", icon = "home", title = "Home", subs = {
        {name = "Home", sections = {
            {title = "Welcome Back", cards = {
                {title = "Profile", icon = "user", col = 1, rows = {
                    {t = "profile"},
                    {t = "toggle", name = "Hide name", cb = function() if Live.profilePaint then Live.profilePaint() end end},
                    {t = "toggle", name = "Hide avatar", cb = function() if Live.profilePaint then Live.profilePaint() end end},
                }},
                {title = "Stats", icon = "pulse", col = 2, rows = {
                    {t = "info", name = "FPS", id = "fps", get = function() return "-" end},
                    {t = "info", name = "Ping", id = "ping", get = function() return "-" end},
                    {t = "info", name = "Players", id = "players", get = function() return tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers) end},
                    {t = "info", name = "Session", id = "session", get = function() return "0s" end},
                }},
            }},
            {title = "Server", cards = {
                {title = "Server Tools", icon = "globe", col = 1, rows = {
                    {t = "button", name = "Rejoin", text = "Rejoin", cb = __NH_T.rejoin},
                    {t = "button", name = "Server Hop", text = "Hop", cb = __NH_T.hopLowest},
                    {t = "button", name = "Copy Job ID", text = "Copy", cb = function()
                        if copyText(game.JobId) then toast("Job ID copied") else toast("Can't copy") end
                    end},
                }},
                {title = "Community", icon = "sparkle", col = 2, rows = {
                    {t = "button", name = "TikTok", text = "Open", cb = function() openLink(Cfg.TikTok) end},
                    {t = "button", name = "Discord", text = "Open", cb = function() openLink(Cfg.Discord) end},
                }},
            }},
            {title = "Update Log", single = true, cards = {
                {title = "Changes", icon = "list", col = 1, rows = (function()
                    local r = {}
                    for _, line in ipairs(Cfg.UpdateLog) do r[#r + 1] = {t = "note", text = line} end
                    return r
                end)()},
            }},
        }},
    }},

    ------------------------------------------------------------ Admin Abuse
    {id = "admin", icon = "party", title = "Admin Abuse", subs = {
        {name = "Admin Abuse", sections = {
            {title = "Admin Abuse", cards = {
                {title = "Admin Tools", icon = "party", col = 1, rows = {
                    {t = "toggle", name = "Option 1"},
                    {t = "toggle", name = "Option 2"},
                    {t = "toggle", name = "Option 3"},
                }},
            }},
        }},
    }},

    ------------------------------------------------------------ Main
    {id = "main", icon = "receipt", title = "Main", subs = {
        {name = "Auto Steal", sections = {
            {title = "Auto Steal", cards = {
                {title = "Auto Steal", icon = "bolt", color = C.orange, col = 1, rows = {
                    {t = "toggle", name = "Auto steal"},
                    {t = "dropdown", name = "Move to egg", list = {"Teleport", "Walk", "Fly in the air"}, default = "Walk"},
                    {t = "dropdown", name = "Delivery method", list = {"Fast tween", "Teleport", "Walk"}, default = "Fast tween"},
                    {t = "dropdown", name = "Teleport zones", multi = true, list = Cfg.Zones, default = __NH_T.firstN(Cfg.Zones, 6)},
                    {t = "toggle", name = "Steal missing index eggs"},
                    {t = "toggle", name = "Steal from other players"},
                    {t = "toggle", name = "Anti guard"},
                    {t = "toggle", name = "Drop eggs at safe zone"},
                }},
                {title = "Filter", icon = "target", color = C.green, col = 2, rows = {
                    {t = "dropdown", name = "Zones", multi = true, list = Cfg.Zones, default = {}},
                    {t = "dropdown", name = "Steal first", list = {"Best value", "Closest", "Cheapest", "Random"}, default = "Best value"},
                    {t = "dropdown", name = "Mutations", multi = true, list = Cfg.Mutations, default = {}},
                    {t = "dropdown", name = "Rarities", multi = true, list = Cfg.Rarities, default = __NH_T.allOf(Cfg.Rarities)},
                    {t = "dropdown", name = "Only these eggs", multi = true, list = Cfg.Eggs, default = {}},
                    {t = "slider", name = "Min value /s", log = true, exp = 9, default = 0},
                    {t = "toggle", name = "Sell cheapest egg when bag is full"},
                    {t = "slider", name = "Only below /s", log = true, exp = 9, default = 0},
                }},
            }},
            {title = "Safety", cards = {
                {title = "Safety", icon = "target", color = C.green, col = 1, rows = {
                    {t = "toggle", name = "Teleport Back", default = true},
                    {t = "toggle", name = "Stop When Full"},
                    {t = "slider", name = "Steal Delay", min = 0, max = 5, step = 0.1, default = 0.5, suffix = "s"},
                    {t = "button", name = "Steal Now", text = "Now"},
                }},
                {title = "Range", icon = "pulse", col = 2, rows = {
                    {t = "toggle", name = "Steal Rare Only"},
                    {t = "slider", name = "Range", min = 10, max = 200, step = 1, default = 80, suffix = "m"},
                }},
            }},
        }},
        {name = "Egg Filter", sections = {
            {title = "Egg Filter", cards = {
                {title = "Rarity", icon = "crown", color = C.ok, col = 1, rows = {
                    {t = "toggle", name = "Common", default = true},
                    {t = "toggle", name = "Rare", default = true},
                    {t = "toggle", name = "Epic"},
                    {t = "toggle", name = "Legendary"},
                    {t = "toggle", name = "Mythic"},
                }},
                {title = "Sort", icon = "list", col = 2, rows = {
                    {t = "dropdown", name = "Sort By", list = {"Value", "Rarity", "Distance"}, default = "Value"},
                    {t = "button", name = "Reset Filter", text = "Reset"},
                }},
            }},
        }},
        {name = "Egg ESP", sections = {
            {title = "Egg ESP", cards = {
                {title = "Display", icon = "target", color = C.green, col = 1, rows = {
                    {t = "toggle", name = "Enable ESP"},
                    {t = "toggle", name = "Show Name", default = true},
                    {t = "toggle", name = "Show Distance", default = true},
                    {t = "toggle", name = "Show Rarity"},
                }},
                {title = "Settings", icon = "sliders", col = 2, rows = {
                    {t = "slider", name = "Max Distance", min = 50, max = 1000, step = 10, default = 500, suffix = "m"},
                    {t = "slider", name = "Text Size", min = 10, max = 24, step = 1, default = 14},
                    {t = "dropdown", name = "Style", list = {"Box", "Outline", "Tracer"}, default = "Box"},
                }},
            }},
        }},
        {name = "Steal Webhook", sections = {
            {title = "Steal Webhook", cards = {
                {title = "Webhook", icon = "globe", col = 1, rows = {
                    {t = "toggle", name = "Enable Webhook"},
                    {t = "input", name = "Webhook URL", placeholder = "https://..."},
                    {t = "dropdown", name = "Message Type", list = {"Embed", "Plain Text"}, default = "Embed"},
                }},
                {title = "Options", icon = "sliders", col = 2, rows = {
                    {t = "toggle", name = "Include Egg Info", default = true},
                    {t = "toggle", name = "Mention User"},
                    {t = "button", name = "Send Test Message", text = "Send"},
                }},
            }},
        }},
        {name = "Egg Predictor", sections = {
            {title = "Egg Predictor", cards = {
                {title = "Predictor", icon = "sparkle", color = C.orange, col = 1, rows = {
                    {t = "toggle", name = "Enable predictor"},
                    {t = "toggle", name = "Notify on rare egg", default = true},
                    {t = "dropdown", name = "Min rarity", list = Cfg.Rarities, default = Cfg.Rarities[1]},
                    {t = "button", name = "Refresh list", text = "Refresh", cb = function()
                        if Live.eggRefresh then Live.eggRefresh() end
                    end},
                }},
                {title = "Egg Values", icon = "egg", color = C.green, col = 2, rows = {
                    {t = "eggs"},
                }},
            }},
        }},
    }},

    ------------------------------------------------------------ Auto
    {id = "auto", icon = "repeat", title = "Auto", subs = {
        {name = "Auto", sections = {
            {title = "Automation", cards = {
                {title = "Auto", icon = "bolt", color = C.orange, col = 1, rows = {
                    {t = "toggle", name = "Auto Farm"},
                    {t = "toggle", name = "Auto Collect"},
                    {t = "toggle", name = "Auto Rebirth"},
                    {t = "toggle", name = "Auto Upgrade"},
                    {t = "slider", name = "Delay", min = 0, max = 10, step = 0.5, default = 2, suffix = "s"},
                }},
                {title = "Options", icon = "sliders", col = 2, rows = {
                    {t = "dropdown", name = "Mode", list = {"Normal", "Fast", "Safe"}, default = "Normal"},
                    {t = "toggle", name = "Notifications", default = true},
                    {t = "input", name = "Custom Value", placeholder = "Enter value"},
                    {t = "button", name = "Apply Settings", text = "Apply"},
                }},
            }},
        }},
    }},

    ------------------------------------------------------------ Private Server
    {id = "private", icon = "users", title = "Private Server", subs = {
        {name = "Private Server", sections = {
            {title = "Private Server", cards = {
                {title = "Join", icon = "globe", col = 1, rows = {
                    {t = "input", name = "Server code", placeholder = "Server code"},
                    {t = "button", name = "Join Server", text = "Join"},
                    {t = "button", name = "Create Server", text = "Open"},
                    {t = "button", name = "Server List", text = "Open"},
                }},
            }},
        }},
    }},

    ------------------------------------------------------------ Pets
    {id = "pets", icon = "sparkle", title = "Pets", subs = {
        {name = "Pets", sections = {
            {title = "Pets", cards = {
                {title = "Pet Tools", icon = "sparkle", col = 1, rows = {
                    {t = "toggle", name = "Pet Viewer"},
                    {t = "toggle", name = "Pet Filter"},
                    {t = "toggle", name = "Pet ESP"},
                }},
            }},
        }},
    }},

    ------------------------------------------------------------ Events
    {id = "events", icon = "flame", title = "Events", subs = {
        {name = "Events", sections = {
            {title = "Events", cards = {
                {title = "Event Tools", icon = "flame", color = C.orange, col = 1, rows = {
                    {t = "toggle", name = "Event Info"},
                    {t = "toggle", name = "Event Rewards"},
                    {t = "toggle", name = "Event Timer"},
                }},
            }},
        }},
    }},

    ------------------------------------------------------------ UI Settings
    {id = "settings", icon = "sliders", title = "UI Settings", subs = {
        {name = "Interface", sections = {
            {title = "Interface", cards = {
                {title = "General", icon = "sliders", col = 1, rows = {
                    {t = "dropdown", name = "Language", list = {"English", "中文"}, default = "English", cb = function(v) Hub.setLang(v) end},
                    {t = "toggle", name = "Show FPS / Ping", default = Cfg.HUD, cb = function(v)
                        if __NH_T.setHudShown then __NH_T.setHudShown(v) elseif hudFrame then hudFrame.Visible = v end
                    end},
                    {t = "dropdown", name = "HUD style", list = {"Classic", "Dynamic Island"}, default = Cfg.HudStyle or "Classic",
                        cb = function(v) if __NH_T.setHudStyle then __NH_T.setHudStyle(v) end end},
                    {t = "toggle", name = "Show floating logo", default = true, cb = function(v) if logoBtn then logoBtn.Visible = v end end},
                    {t = "slider", name = "UI scale", min = 0.7, max = 1.3, step = 0.05, default = 1, suffix = "x", cb = function(v) Fit.user = v applyScale() end},
                    {t = "toggle", name = "Cyan move frame", default = true},
                    {t = "dropdown", name = "Ring color", list = {"White", "Cyan", "Blue", "Purple", "Pink", "Red", "Orange", "Yellow", "Green", "Rainbow"},
                        default = "White", cb = function(v) __NH_T.setRingColor(v) end},
                    {t = "dropdown", name = "FPS cap", list = {"60", "90", "120", "144", "240", "Unlimited"}, default = tostring(Cfg.FpsCap or 120),
                        cb = function(v) if not applyFpsCap(v) then toast("Not available") end end},
                    {t = "toggle", name = "Reduce effects", default = true, cb = function(v) Fx.reduce = v applyFx() end},
                }},
                {title = "Performance", icon = "sliders", col = 2, rows = {
                    {t = "toggle", name = "Adaptive UI effects", default = true, cb = function(v) if __NH_T.Perf then __NH_T.Perf.adaptive = v end end},
                    {t = "toggle", name = "Auto clean map", default = true, cb = function(v) if __NH_T.Cleaner then __NH_T.Cleaner.setEnabled(v) end end},
                    {t = "slider", name = "Low FPS limit", min = 20, max = 45, step = 1, default = 35, suffix = " fps", cb = function(v) if __NH_T.Cleaner then __NH_T.Cleaner.limit = v end end},
                    {t = "slider", name = "Low FPS seconds", min = 4, max = 20, step = 1, default = 8, suffix = "s", cb = function(v) if __NH_T.Cleaner then __NH_T.Cleaner.secs = v end end},
                    {t = "button", name = "Clean map now", text = "Clean", cb = function() if __NH_T.Cleaner then __NH_T.Cleaner.sweep(false) end end},
                }},
                {title = "System", icon = "gear", col = 2, rows = {
                    {t = "info", name = "Toggle key", get = function() return Cfg.ToggleKey.Name end},
                    {t = "button", name = "Unload UI", text = "Unload", cb = function() Hub.unload() end},
                }},
            }},
        }},
        {name = "Weather", sections = {
            {title = "Weather", cards = {
                {title = "Snow", icon = "snow", color = Color3.fromRGB(170, 215, 255), col = 1, rows = {
                    {t = "toggle", name = "Enable Snow", cb = function(v) Weather.setMode("snow", v) renderPage(true) end},
                    {t = "slider", name = "Snow Amount", min = 20, max = 220, step = 5, default = 100, cb = function(v) Weather.set("snowCount", v) end},
                    {t = "slider", name = "Fall Speed", min = 0.4, max = 3, step = 0.1, default = 1, suffix = "x", cb = function(v) Weather.set("snowSpeed", v) end},
                    {t = "slider", name = "Snow Size", min = 0.6, max = 2, step = 0.1, default = 1, suffix = "x", cb = function(v) Weather.set("snowSize", v) end},
                    {t = "slider", name = "Wind", min = -1, max = 1, step = 0.1, default = 0.3, cb = function(v) Weather.set("snowWind", v) end},
                }},
                {title = "Meteor", icon = "meteor", color = Color3.fromRGB(150, 190, 255), col = 2, rows = {
                    {t = "toggle", name = "Enable Meteor", cb = function(v) Weather.setMode("meteor", v) renderPage(true) end},
                    {t = "slider", name = "Meteor Amount", min = 4, max = 40, step = 1, default = 14, cb = function(v) Weather.set("meteorCount", v) end},
                    {t = "slider", name = "Meteor Speed", min = 0.5, max = 2.5, step = 0.1, default = 1, suffix = "x", cb = function(v) Weather.set("meteorSpeed", v) end},
                    {t = "slider", name = "Tail Length", min = 0.5, max = 2, step = 0.1, default = 1, suffix = "x", cb = function(v) Weather.set("meteorLength", v) end},
                    {t = "toggle", name = "Background Stars", default = true, cb = function(v) Weather.set("stars", v) end},
                }},
            }},
        }},
        {name = "Music", sections = {
            {title = "Music", cards = {
                {title = "Music", icon = "music", col = 1, rows = {
                    {t = "dropdown", name = "Select Song", list = musicNames, default = musicNames[1] or "", cb = function(v) Music.select(v) end},
                    {t = "toggle", name = "Play Music", cb = function(v) Music.setPlaying(v) end},
                    {t = "slider", name = "Volume", min = 0, max = 1, step = 0.05, default = Cfg.MusicVolume, cb = function(v) Music.setVolume(v) end},
                    {t = "toggle", name = "Loop", default = true, cb = function(v) Music.setLoop(v) end},
                    {t = "input", name = "Custom Music ID", placeholder = "Enter audio ID, press Enter", cb = function(v) Music.custom(v) end},
                }},
            }},
        }},
    }},
}

-- 建立左侧栏按钮
railList.CanvasSize = UDim2.fromOffset(0, tabY(#PAGES + 1))
for i, page in ipairs(PAGES) do
    local btn = new("TextButton", {
        Name = "Tab_" .. page.id, Position = UDim2.fromOffset(10, tabY(i)), Size = UDim2.fromOffset(SIDEBAR_W - 20, TAB_H),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 5,
    }, railList)
    local ic = Icon(btn, page.icon, 22, C.sub)
    ic.root.AnchorPoint = Vector2.new(0, 0.5)
    ic.root.Position = UDim2.new(0, 18, 0.5, 0)
    local label = text(btn, {
        Text = T(page.title), Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -60, 1, 0),
        Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.sub, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    railBtns[i] = {btn = btn, icon = ic, label = label, page = page, scale = new("UIScale", {Scale = 1}, ic.root)}
    __NH_T.pressFx(btn, 0.96, connect)
    connect(btn.MouseEnter, function()
        if curPage ~= i then tween(label, {TextColor3 = C.mid}, 0.1); ic.setColor(C.mid, 0.1) end
    end)
    connect(btn.MouseLeave, function()
        if curPage ~= i then tween(label, {TextColor3 = C.sub}, 0.1); ic.setColor(C.sub, 0.1) end
    end)
    connect(btn.MouseButton1Click, function() __NH_T.selectPage(i) end)
end

-- ===== 更多功能页：把功能代码里其余的设置接到界面 =====
-- 每一行的 name 对应 BindReg 里的处理函数：改 Config，需要的话再调用功能模块的开关函数。
do
	local GE = (getgenv and getgenv()) or _G
	local BR = __NH_T.BindReg
	local function toList(set)
		local out = {}
		if type(set) == "table" then
			for name, on in pairs(set) do if on == true and name ~= "None" then out[#out + 1] = name end end
		end
		table.sort(out)
		if #out == 0 then out[1] = "None" end
		return out
	end
	local function copySet(set)
		local o = {}
		if type(set) == "table" then for k, v in pairs(set) do if v == true then o[k] = true end end end
		return o
	end
	local function ctl(field, what)
		local o = GE[field]
		if o == nil then toast("功能代码里没找到: " .. what) end
		return o
	end
	local function m(obj, name, ...)   -- 冒号方法
		if obj and type(obj[name]) == "function" then pcall(obj[name], obj, ...) end
	end
	local function d(obj, name, ...)   -- 点号函数
		if obj and type(obj[name]) == "function" then pcall(obj[name], ...) end
	end
	local function reg(name, get, set) BR[name] = {get = get, set = set} end
	local function flag(name, key, after)
		reg(name, function(c) return c[key] == true end, function(c, v)
			c[key] = v == true
			if after then after(c, v == true) end
		end)
		return {t = "toggle", name = name}
	end
	local function listRow(name, key, options)
		reg(name, nil, function(c, v) c[key] = toList(v) end)
		return {t = "dropdown", name = name, multi = true, list = options, default = {}}
	end
	local function numRow(name, key, min, max, step, default, after, suffix)
		reg(name, function(c) return tonumber(c[key]) end, function(c, v)
			v = tonumber(v) or default
			c[key] = v
			if after then after(c, v) end
		end)
		return {t = "slider", name = name, min = min, max = max, step = step, default = default, suffix = suffix}
	end
	local function logRow(name, key)
		reg(name, function(c) return tonumber(c[key]) end, function(c, v) c[key] = tonumber(v) or 0 end)
		return {t = "slider", name = name, log = true, exp = 9, default = 0}
	end
	local function pickRow(name, key, options, default, toCfg, fromCfg)
		reg(name, function(c) return fromCfg(c[key]) end, function(c, v) c[key] = toCfg(v) end)
		return {t = "dropdown", name = name, list = options, default = default}
	end
	local function addSub(pageId, sub)
		for _, pg in ipairs(PAGES) do
			if pg.id == pageId then pg.subs[#pg.subs + 1] = sub return end
		end
	end
	local function sub(name, cards) return {name = name, sections = {{title = name, cards = cards}}} end

	-- 已有行里原来接不了的：Steal missing index eggs（引擎提供了开关函数）
	reg("Steal missing index eggs", function(c) return c.AutoIndex == true end, function(c, v)
		c.AutoIndex = v == true
		m(GE.__NasaV1EggRuntime, "setIndexObjective", v == true)
	end)
	-- 没有“卖蛋循环”可用：功能代码只在卖蛋循环忙的时候才会让路，单独打开这个开关没有任何效果，所以不接
	-- 卖蛋循环现在由拼上去的结尾提供，这一行重新接上
	local function ap(name, v)
		local A = GE.__NasaV1Apply
		if A and type(A[name]) == "function" then pcall(A[name], v)
		elseif v then toast("功能代码里没找到: " .. name) end
	end
	local function cleanRow(name, key, options)
		reg(name, nil, function(c, v)
			local out = {}
			for _, x in ipairs(toList(v)) do if x ~= "None" then out[#out + 1] = x end end
			c[key] = out
		end)
		return {t = "dropdown", name = name, multi = true, list = options, default = {}}
	end
	local function buttonRow(name, text, fn) return {t = "button", name = name, text = text, cb = fn} end
	reg("Sell cheapest egg when bag is full", function(c) return c.AutoSellEgg == true end, function(c, v)
		c.AutoSellEgg = v == true
		ap("AutoSellEgg", v == true)
	end)

	-------------------------------------------------------------- Pets
	addSub("pets", sub("Pet Automation", {
		{title = "Pet Barn", icon = "sparkle", col = 1, rows = {
			flag("Auto equip best pets", "AutoEquipBest"),
			flag("Auto claim offline rewards", "AutoClaimOffline"),
			flag("Auto favorite pets", "AutoFavorite"),
			listRow("Favorite rarities", "FavRarities", Cfg.Rarities),
		}},
		{title = "Pet Fusing", icon = "repeat", col = 2, rows = {
			flag("Auto fuse pets", "AutoFusePets"),
			flag("Fuse selected rarities only", "FuseSelectedOnly"),
			listRow("Fuse rarities", "FuseRarities", Cfg.Rarities),
		}},
	}))
	addSub("auto", sub("Upgrades", {
		{title = "Base", icon = "bolt", col = 1, rows = {
			flag("Auto base upgrade", "AutoBaseUpgrade"),
			flag("Auto claim almanac", "AutoClaimAlmanac"),
		}},
	}))

	-------------------------------------------------------------- Main
	reg("Snipe areas", function(c) return copySet(c.SnipeAreas) end, function(c, v) c.SnipeAreas = copySet(v) end)
	reg("Set drop point here", nil, function(c)
		local ch = game:GetService("Players").LocalPlayer.Character
		local r = ch and ch:FindFirstChild("HumanoidRootPart")
		if not r then toast("找不到角色") return end
		c.FarRouteDropPoint = r.Position
		GE.NasaDropPoint = r.Position
		toast(("丢蛋点已记录 (%d, %d, %d)"):format(math.floor(r.Position.X), math.floor(r.Position.Y), math.floor(r.Position.Z)))
	end)
	reg("Reset drop point", nil, function(c)
		c.FarRouteDropPoint = nil
		GE.NasaDropPoint = nil
		toast("丢蛋点已恢复默认（Forest 丢蛋地面）")
	end)
	addSub("main", sub("Steal Extras", {
		{title = "Behavior", icon = "bolt", col = 1, rows = {
			flag("Help friend", "HelpFriend"),
			flag("Low speed boost", "LowSpeedBoost"),
			numRow("Relay segment length", "FlySegmentLength", 300, 10000, 100, 10000, nil, "studs"),
			numRow("Relay pause", "FlySegmentPause", 0.1, 1.5, 0.01, 0.43, nil, "s"),
			numRow("Fly return speed", "FlyReturnSpeed", 500, 6000, 50, 2421, nil, "studs/s"),
			flag("Sky hop at egg", "FlySkyHop"),
			flag("Far route (beyond Volcano)", "FarRoute"),
			numRow("Far route speed", "FarRouteSpeed", 500, 6000, 50, 2450, nil, "studs/s"),
			numRow("Guard dance count", "FarRouteDance", 0, 8, 1, 4),
			numRow("Guard dance speed", "FarRouteDanceSpeed", 50, 2000, 25, 100, nil, "studs/s"),
			numRow("Guard chase range", "FarRouteGuardRange", 20, 400, 10, 120, nil, "studs"),
			numRow("Far route return speed", "FarRouteReturnSpeed", 100, 6000, 25, 200, nil, "studs/s"),
			{t = "button", name = "Set drop point here", text = "Set"},
			{t = "button", name = "Reset drop point", text = "Reset"},
			numRow("Steal hold seconds", "StealHoldSeconds", 1, 10, 1, 5, nil, "s"),
			flag("Steal jump", "StealJump"),
			flag("Skip toll areas", "StealSkipTollAreas"),
			flag("Star alert", "StarAlert"),
		}},
		{title = "Snipe & Pull", icon = "target", col = 2, rows = {
			flag("Snipe dropped eggs", "SnipeDroppedEggs"),
			{t = "dropdown", name = "Snipe areas", multi = true, list = Cfg.Zones, default = {}},
			flag("Snipe punch", "SnipePunch"),
			flag("Fast pull", "FastPull"),
			numRow("Fast pull speed", "FastPullSpeed", 1000, 8000, 100, 3500),
		}},
		{title = "Steal players", icon = "users", col = 1, rows = {
			listRow("Player rarities", "StealPlayerRarities", Cfg.Rarities),
			logRow("Player min value /s", "StealPlayerMinValue"),
			(function()
				reg("Target player", function(c) return tostring(c.StealPlayerTarget or "") end,
					function(c, v) v = tostring(v or "") if v == "" then v = "Any Player" end c.StealPlayerTarget = v end)
				return {t = "input", name = "Target player", placeholder = "Any Player"}
			end)(),
		}},
	}))
	addSub("main", sub("Movement", {
		{title = "Movement", icon = "pulse", col = 1, rows = {
			flag("Infinite jump", "InfiniteJump", function(c, v) m(ctl("__NasaV1MovementExtras", "MovementExtras"), "setInfiniteJump", v) end),
			flag("Instant grab", "InstantGrab", function(c, v) m(ctl("__NasaV1MovementExtras", "MovementExtras"), "setInstantGrab", v) end),
			flag("Fly for capture", "FlyForCapture", function(c, v) m(ctl("__NasaV1MovementExtras", "MovementExtras"), "setFlyForCapture", v) end),
			numRow("Walk speed multiplier", "WalkSpeedMultiplier", 1, 2.1, 0.05, 1, function(c, v) m(ctl("__NasaV1MovementExtras", "MovementExtras"), "setSpeedMultiplier", v) end, "x"),
			flag("Noclip", "Noclip", function(c, v) d(ctl("__NasaV1Roaming", "Roaming"), "setNoclip", v) end),
			flag("Botting mode", "BottingMode", function(c, v) d(ctl("__NasaV1Roaming", "Roaming"), "setBottingMode", v) end),
		}},
		{title = "Protection", icon = "target", color = C.green, col = 2, rows = {
			flag("Anti cutscene", "AntiCutscene"),
			flag("God mode", "GodMode", function(c, v) m(ctl("__NasaV1GodMode", "GodMode"), "setEnabled", v) end),
			flag("Anti hit guard", "AntiHitGuard", function(c, v) m(ctl("__NasaV1AntiHitGuard", "AntiHitGuard"), "setEnabled", v) end),
			flag("Anti AFK", "AntiAFK", function(c, v)
				local f = ctl("__NasaV1SetAntiAfkEnabled", "AntiAFK")
				if type(f) == "function" then pcall(f, v) end
			end),
		}},
	}))
	addSub("main", sub("Treadmill", {
		{title = "Treadmill", icon = "repeat", col = 1, rows = {
			flag("Auto treadmill idle", "AutoTreadmillIdle", function(c, v) m(ctl("__NasaV1TreadmillManager", "TreadmillManager"), "setIdleFarm", v) end),
			flag("Auto treadmill upgrade", "AutoTreadmillUpgrade", function(c, v) m(ctl("__NasaV1TreadmillManager", "TreadmillManager"), "setAutoUpgrade", v) end),
			flag("Anti treadmill", "AntiTreadmill", function(c, v)
				if v then d(ctl("__NasaV1Extras", "NasaExtras"), "startAntiTreadmillLoop") end
			end),
			flag("Backpack rate ESP", "BackpackRateEsp", function(c, v) d(ctl("__NasaV1Extras", "NasaExtras"), "setBackpackRates", v) end),
		}},
	}))
	addSub("main", sub("Webhook Extras", {
		{title = "Webhook", icon = "list", col = 1, rows = {
			flag("Notify on disconnect", "WebhookDisconnect"),
			logRow("Webhook min value /s", "WebhookMinValue"),
			listRow("Webhook rarities", "WebhookRarities", Cfg.Rarities),
		}},
	}))

	-------------------------------------------------------------- Events
	local MODE_IDS = {["Tween to Butterfly"] = "Tween", Stand = "Stand", Zigzag = "Zigzag", Circle = "Circle"}
	local MODE_LABELS = {"Tween to Butterfly", "Stand", "Zigzag", "Circle"}
	local RECIPE_IDS = {["All Recipes"] = "All", ["For Essence (shortfall only)"] = "Smart", ["Emerald to Sapphire"] = "Green",
		["Sapphire to Amethyst"] = "Blue", ["Amethyst to Radiant"] = "Purple"}
	local RECIPE_LABELS = {"All Recipes", "For Essence (shortfall only)", "Emerald to Sapphire", "Sapphire to Amethyst", "Amethyst to Radiant"}
	local TIERS = {"Green", "Blue", "Purple", "Golden"}
	local function labelOf(map, id, fallback)
		for label, v in pairs(map) do if v == id then return label end end
		return fallback
	end
	reg("Butterfly tiers", function(c)
		local o = {}
		for _, id in ipairs(type(c.ButterflyTiers) == "table" and c.ButterflyTiers or {}) do o[id] = true end
		return o
	end, function(c, v)
		local ids = {}
		for _, id in ipairs(TIERS) do if type(v) == "table" and v[id] == true then ids[#ids + 1] = id end end
		c.ButterflyTiers = ids
	end)
	addSub("events", sub("Butterfly", {
		{title = "Net & Catch", icon = "sparkle", col = 1, rows = {
			flag("Auto butterfly net", "ButterflyAutoNet"),
			flag("Auto catch butterflies", "ButterflyAutoCatch"),
			pickRow("Catch mode", "ButterflyCatchMode", MODE_LABELS, "Tween to Butterfly",
				function(v) return MODE_IDS[tostring(v)] or "Tween" end,
				function(id) return labelOf(MODE_IDS, id, "Tween to Butterfly") end),
			flag("Butterfly ESP", "ButterflyEsp"),
		}},
		{title = "Trade & Craft", icon = "repeat", col = 2, rows = {
			flag("Auto trade butterflies", "ButterflyAutoTrade"),
			pickRow("Trade recipe", "ButterflyTradeRecipe", RECIPE_LABELS, "All Recipes",
				function(v) return RECIPE_IDS[tostring(v)] or "All" end,
				function(id) return labelOf(RECIPE_IDS, id, "All Recipes") end),
			{t = "dropdown", name = "Butterfly tiers", multi = true, list = TIERS, default = {}},
			flag("Auto craft butterflies", "ButterflyAutoCraft"),
		}},
		{title = "Quests", icon = "list", col = 1, rows = {
			flag("Wisp auto quest", "WispAutoQuest"),
			flag("Banjo auto", "BanjoAuto"),
		}},
	}))
	local function hw() d(GE.__NasaV1Halloween, "refresh") end
	local function train() d(GE.__NasaV1Train, "refresh") end
	addSub("events", sub("Halloween", {
		{title = "Farm", icon = "flame", col = 1, rows = {
			flag("Halloween auto steal", "AutoStealHalloween", hw),
			flag("Halloween hit mobs", "HalloweenHitMobs", hw),
			flag("Halloween collect pumpkins", "HalloweenCollectPumpkin", hw),
			flag("Halloween auto fish", "HalloweenAutoFish", hw),
			flag("Halloween auto buy", "HalloweenAutoBuy", hw),
			flag("Halloween zone priority", "HalloweenZonePriority", hw),
			flag("Halloween cross world", "HalloweenCrossWorld", hw),
		}},
		{title = "Train event", icon = "bolt", col = 2, rows = {
			flag("Phantom express", "HalloweenPhantomExpress", train),
			flag("Trade souls", "HalloweenTradeSouls", train),
			listRow("Halloween egg rarities", "HalloweenEggRarities", Cfg.Rarities),
		}},
	}))

	-------------------------------------------------------------- Private Server / 连接
	addSub("private", sub("Server Hop", {
		{title = "Hop", icon = "users", col = 1, rows = {
			flag("Hop when no eggs match", "HopNoMatch", function(c, v) if v then d(ctl("__NasaV1Extras", "NasaExtras"), "startHopLoop") end end),
			numRow("Hop cooldown", "HopCooldown", 1, 60, 1, 5, nil, "s"),
			flag("Auto private server", "PrivateServerAuto", function(c, v) if v then d(ctl("__NasaV1Extras", "NasaExtras"), "startPrivateAutoHop") end end),
			pickRow("Private server max players", "PrivateServerMax", {"1", "2", "3", "4", "5", "6", "7", "8"}, "2",
				function(v) return tostring(v) end, function(x) return tostring(x or "2") end),
		}},
		{title = "Connection", icon = "pulse", col = 2, rows = {
			flag("Auto reconnect", "AutoReconnect"),
		}},
	}))

	-- 断线自动重连：功能代码里有这个设置项，但没有任何地方读取它，这里补上
	do
		local GuiService, TeleportService, Players = game:GetService("GuiService"), game:GetService("TeleportService"), game:GetService("Players")
		local attempts, windowStart, busy = 0, 0, false
		pcall(function()
			GuiService.ErrorMessageChanged:Connect(function(msg)
				local c = GE.NasaV1Config
				if busy or not c or c.AutoReconnect ~= true or tostring(msg or "") == "" then return end
				if os.clock() - windowStart > 300 then attempts, windowStart = 0, os.clock() end
				if attempts >= 3 then return end   -- 5 分钟内最多重连 3 次，避免被踢后一直循环
				attempts += 1
				busy = true
				task.delay(3, function()
					pcall(function() TeleportService:Teleport(game.PlaceId, Players.LocalPlayer) end)
					busy = false
				end)
			end)
		end)
	end

	-------------------------------------------------------------- 补上的功能：放蛋 / 孵化 / 突变 / 环活动 / 卖宠物 / 卖蛋
	reg("Retry until mutated", function(c) return c.MutationRetry ~= false end, function(c, v) c.MutationRetry = v == true end)
	addSub("auto", sub("Egg Automation", {
		{title = "Place & Hatch", icon = "bolt", color = C.orange, col = 1, rows = {
			flag("Auto place eggs", "AutoPlace", function(c, v) ap("AutoPlace", v) end),
			cleanRow("Place rarities", "PlaceRarities", Cfg.Rarities),
			buttonRow("Place all now", "Run", function() ap("PlaceNow", true) end),
			flag("Auto hatch eggs", "AutoHatch", function(c, v) ap("AutoHatch", v) end),
			buttonRow("Hatch all ready now", "Run", function() ap("HatchNow", true) end),
		}},
		{title = "Mutation", icon = "sparkle", col = 2, rows = {
			pickRow("Mutation type", "MutationChoice", {"Scrambled", "Fractured", "Enchanted", "Nitro"}, "Scrambled",
				function(v) if type(v) == "table" then v = v[1] end return v or "Scrambled" end, function(x) return x or "Scrambled" end),
			cleanRow("Mutate rarities", "MutationRarities", Cfg.Rarities),
			logRow("Mutate min value /s", "MutationMinRate"),
			{t = "toggle", name = "Retry until mutated", default = true},
			flag("Auto apply mutation", "AutoMutation", function(c, v) ap("AutoMutation", v) end),
			buttonRow("Apply mutation now", "Run", function() ap("MutationNow", true) end),
		}},
		{title = "Ring Event", icon = "repeat", col = 1, rows = {
			flag("Auto ring event", "AutoRingEvent", function(c, v) ap("AutoRingEvent", v) end),
		}},
	}))
	addSub("pets", sub("Selling", {
		{title = "Sell pets", icon = "sparkle", col = 1, rows = {
			flag("Auto sell pets", "AutoSell", function(c, v) ap("AutoSell", v) end),
			cleanRow("Sell pet rarities", "SellRarities", Cfg.Rarities),
			logRow("Sell pet max value /s", "SellPetMaxRate"),
		}},
		{title = "Sell eggs", icon = "bolt", col = 2, rows = {
			cleanRow("Sell egg rarities", "SellEggRarities", Cfg.Rarities),
			logRow("Sell egg max value /s", "SellEggMaxRate"),
		}},
	}))

	-------------------------------------------------------------- 中文名
	local zh = {
		["Pet Automation"] = "宠物自动化", ["Pet Barn"] = "宠物仓库", ["Auto equip best pets"] = "自动装备最强宠物",
		["Auto claim offline rewards"] = "自动领取离线奖励", ["Auto favorite pets"] = "自动收藏宠物", ["Favorite rarities"] = "收藏的稀有度",
		["Pet Fusing"] = "宠物合成", ["Auto fuse pets"] = "自动合成宠物", ["Fuse selected rarities only"] = "只合成选中的稀有度",
		["Fuse rarities"] = "合成的稀有度", ["Upgrades"] = "升级", ["Base"] = "基地", ["Auto base upgrade"] = "自动升级基地",
		["Auto claim almanac"] = "自动领取图鉴奖励", ["Steal Extras"] = "偷蛋附加", ["Behavior"] = "行为", ["Help friend"] = "帮助好友",
		["Low speed boost"] = "低速加成", ["Far route (beyond Volcano)"] = "远区路线(Volcano 之后)", ["Relay segment length"] = "接力每段最长", ["Relay pause"] = "接力段间停顿", ["Fly return speed"] = "回程滑行速度", ["Sky hop at egg"] = "到蛋后天上一跳", ["Fly in the air"] = "空中飞行", ["Far route speed"] = "远区飞行速度", ["Guard dance count"] = "守卫头部来回次数", ["Guard dance speed"] = "守卫动作速度", ["Guard chase range"] = "守卫追击范围", ["Far route return speed"] = "回程速度", ["Set drop point here"] = "把这里记为丢蛋点", ["Reset drop point"] = "恢复默认丢蛋点", ["Set"] = "记录", ["Reset"] = "恢复", ["Angels & Demons"] = "天使与恶魔", ["Enchanted Forest"] = "魔法森林", ["Steal hold seconds"] = "偷取停留秒数", ["Steal jump"] = "偷取时跳跃",
		["Skip toll areas"] = "跳过收费区域", ["Star alert"] = "星星提醒", ["Snipe & Pull"] = "狙击与拉取",
		["Snipe dropped eggs"] = "狙击掉落的蛋", ["Snipe areas"] = "狙击区域", ["Snipe punch"] = "狙击出拳", ["Fast pull"] = "快速拉取",
		["Fast pull speed"] = "快速拉取速度", ["Steal players"] = "偷玩家", ["Player rarities"] = "玩家蛋稀有度",
		["Player min value /s"] = "玩家蛋最低价值 /s", ["Target player"] = "目标玩家", ["Movement"] = "移动", ["Infinite jump"] = "无限跳",
		["Instant grab"] = "瞬间抓取", ["Fly for capture"] = "飞行抓取", ["Walk speed multiplier"] = "行走速度倍数", ["Noclip"] = "穿墙",
		["Botting mode"] = "挂机模式", ["Protection"] = "保护", ["Anti cutscene"] = "跳过过场动画", ["God mode"] = "无敌模式",
		["Anti hit guard"] = "防被击中", ["Anti AFK"] = "防挂机踢出", ["Treadmill"] = "跑步机", ["Auto treadmill idle"] = "自动挂跑步机",
		["Auto treadmill upgrade"] = "自动升级跑步机", ["Anti treadmill"] = "防跑步机干扰", ["Backpack rate ESP"] = "背包收益显示",
		["Webhook Extras"] = "Webhook 附加", ["Webhook"] = "Webhook", ["Notify on disconnect"] = "断线通知",
		["Webhook min value /s"] = "Webhook 最低价值 /s", ["Webhook rarities"] = "Webhook 稀有度", ["Butterfly"] = "蝴蝶",
		["Net & Catch"] = "抓网与捕捉", ["Auto butterfly net"] = "自动领捕虫网", ["Auto catch butterflies"] = "自动抓蝴蝶",
		["Catch mode"] = "捕捉方式", ["Tween to Butterfly"] = "飞向蝴蝶", ["Stand"] = "站立", ["Zigzag"] = "之字形", ["Circle"] = "绕圈",
		["Butterfly ESP"] = "蝴蝶透视", ["Trade & Craft"] = "交易与合成", ["Auto trade butterflies"] = "自动交易蝴蝶",
		["Trade recipe"] = "交易配方", ["All Recipes"] = "全部配方", ["For Essence (shortfall only)"] = "补足精华(仅缺口)",
		["Emerald to Sapphire"] = "绿宝石换蓝宝石", ["Sapphire to Amethyst"] = "蓝宝石换紫水晶", ["Amethyst to Radiant"] = "紫水晶换光辉",
		["Butterfly tiers"] = "蝴蝶档位", ["Auto craft butterflies"] = "自动合成蝴蝶", ["Quests"] = "任务", ["Wisp auto quest"] = "精灵自动任务",
		["Banjo auto"] = "班卓琴自动", ["Halloween"] = "万圣节", ["Farm"] = "刷取", ["Halloween auto steal"] = "万圣节自动偷蛋",
		["Halloween hit mobs"] = "万圣节打怪", ["Halloween collect pumpkins"] = "万圣节捡南瓜", ["Halloween auto fish"] = "万圣节自动钓鱼",
		["Halloween auto buy"] = "万圣节自动购买", ["Halloween zone priority"] = "万圣节区域优先", ["Halloween cross world"] = "万圣节跨世界",
		["Train event"] = "火车活动", ["Phantom express"] = "幽灵快车", ["Trade souls"] = "交易灵魂", ["Halloween egg rarities"] = "万圣节蛋稀有度",
		["Server Hop"] = "换服", ["Hop"] = "换服", ["Hop when no eggs match"] = "没有匹配蛋时换服", ["Hop cooldown"] = "换服冷却",
		["Auto private server"] = "自动私人服务器", ["Private server max players"] = "私人服务器最大人数", ["Connection"] = "连接",
		["Auto reconnect"] = "断线自动重连",
	}
	for k, v in pairs(zh) do if __NH_T.ZH[k] == nil then __NH_T.ZH[k] = v end end
	for k, v in pairs({
		["Egg Automation"] = "蛋自动化", ["Place & Hatch"] = "放蛋与孵化", ["Auto place eggs"] = "自动放蛋", ["Place rarities"] = "放置的稀有度",
		["Place all now"] = "立即放蛋", ["Auto hatch eggs"] = "自动孵化", ["Hatch all ready now"] = "立即孵化已就绪的蛋", ["Run"] = "执行",
		["Mutation"] = "突变", ["Mutation type"] = "突变种类", ["Mutate rarities"] = "突变的稀有度", ["Mutate min value /s"] = "突变最低价值 /s",
		["Retry until mutated"] = "失败重试直到突变", ["Auto apply mutation"] = "自动施加突变", ["Apply mutation now"] = "立即施加突变",
		["Ring Event"] = "环活动", ["Auto ring event"] = "自动环活动", ["Selling"] = "出售", ["Sell pets"] = "卖宠物", ["Auto sell pets"] = "自动卖宠物",
		["Sell pet rarities"] = "卖出的宠物稀有度", ["Sell pet max value /s"] = "卖出宠物价值上限 /s", ["Sell eggs"] = "卖蛋",
		["Sell egg rarities"] = "卖出的蛋稀有度", ["Sell egg max value /s"] = "卖出蛋价值上限 /s",
		["Scrambled"] = "打乱", ["Fractured"] = "碎裂", ["Enchanted"] = "附魔", ["Nitro"] = "氮气",
		["Sell cheapest egg when bag is full"] = "背包满时卖蛋（按下面的稀有度）",
	}) do if __NH_T.ZH[k] == nil then __NH_T.ZH[k] = v end end
	__NH_T.PAGES = PAGES
end

--------------------------------------------------------------------
-- 语言切换
--------------------------------------------------------------------
function Hub.setLang(name)
    lang = (name == "中文") and "zh" or "en"
    if __NH_T.syncLang then __NH_T.syncLang() end
    searchBox.PlaceholderText = T("Search")
    statusLabel.Text = T(Cfg.Status)
    for _, rb in ipairs(railBtns) do rb.label.Text = T(rb.page.title) end
    __NH_T.resetPageCache()
    renderPage()
    startPrebuild(0.5)
end

function Hub.setStatus(s)
    Cfg.Status = s
    statusLabel.Text = T(s)
end

--------------------------------------------------------------------
-- 顶部 FPS / Ping
--------------------------------------------------------------------
-- 顶部 FPS / Ping / 语言：小号、扁平、没有花哨效果
if true then
    hudFrame = new("Frame", {
        Name = "StatsHUD", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4),
        Size = UDim2.fromOffset(244, 26), BackgroundColor3 = C.bg, BackgroundTransparency = 0.1,
        BorderSizePixel = 0, Visible = Cfg.HUD, ZIndex = 12,
    }, SG)
    corner(hudFrame, 6)
    stroke(hudFrame, C.stroke, 1, 0.1)
end

__NH_T.hudDot = new("Frame", {
    AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = C.good, BorderSizePixel = 0,
}, hudFrame)
full(__NH_T.hudDot)
__NH_T.hudFps = text(hudFrame, {
    Text = "60 FPS", Font = Enum.Font.GothamMedium, TextSize = 12,
    Position = UDim2.fromOffset(22, 0), Size = UDim2.fromOffset(58, 26),
})
__NH_T.hudPing = text(hudFrame, {
    Text = "0 ms", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.good,
    Position = UDim2.fromOffset(84, 0), Size = UDim2.fromOffset(54, 26),
})
new("Frame", {
    BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0,
    Position = UDim2.fromOffset(140, 6), Size = UDim2.fromOffset(1, 14),
}, hudFrame)

do
    local langBtn = new("TextButton", {
        Position = UDim2.fromOffset(144, 2), Size = UDim2.fromOffset(98, 22), Text = "", AutoButtonColor = false,
        BackgroundColor3 = C.pill, BackgroundTransparency = 1, BorderSizePixel = 0,
    }, hudFrame)
    corner(langBtn, 5)
    __NH_T.hudLang = text(langBtn, {
        Text = "English", Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -26, 1, 0),
        Font = Enum.Font.GothamMedium, TextSize = 12,
    })
    local chev = Icon(langBtn, "chevronDown", 9, C.sub)
    chev.root.AnchorPoint = Vector2.new(1, 0.5)
    chev.root.Position = UDim2.new(1, -8, 0.5, 0)
    connect(langBtn.MouseEnter, function() tween(langBtn, {BackgroundTransparency = 0}, 0.1) end)
    connect(langBtn.MouseLeave, function() tween(langBtn, {BackgroundTransparency = 1}, 0.1) end)

    local dd = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, 193, 1, 4), Size = UDim2.fromOffset(98, 62),
        BackgroundColor3 = C.field, BorderSizePixel = 0, Visible = false, ZIndex = 5,
    }, hudFrame)
    corner(dd, 8)
    stroke(dd, C.stroke, 1)
    local ddOpen, opts = false, {}
    local function setDD(v)
        ddOpen = v
        dd.Visible = v
    end
    for i, o in ipairs({{"zh", "中文"}, {"en", "English"}}) do
        local b = new("TextButton", {
            Position = UDim2.fromOffset(4, 4 + (i - 1) * 28), Size = UDim2.fromOffset(90, 26), Text = o[2],
            AutoButtonColor = false, BackgroundColor3 = C.pillOn, BackgroundTransparency = 1, BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.mid, ZIndex = 6,
        }, dd)
        corner(b, 5)
        opts[o[1]] = b
        connect(b.MouseButton1Click, function()
            setDD(false)
            State["settings/Interface/Language"] = o[2]   -- 让 UI Settings 里的语言下拉框也跟着变
            Hub.setLang(o[2])
        end)
    end
    connect(langBtn.MouseButton1Click, function() setDD(not ddOpen) end)
    connect(hudFrame:GetPropertyChangedSignal("Visible"), function()
        if not hudFrame.Visible then setDD(false) end
    end)
    function __NH_T.syncLang()
        __NH_T.hudLang.Text = (lang == "zh") and "中文" or "English"
        for code, b in pairs(opts) do
            b.BackgroundTransparency = (code == lang) and 0.55 or 1
            b.TextColor3 = (code == lang) and C.text or C.mid
        end
    end
    __NH_T.syncLang()
end

local HUDC = {}
local function colorFps(v) if v >= 55 then return C.good elseif v >= 30 then return C.ok else return C.bad end end
local function colorPing(v) if v <= 100 then return C.good elseif v <= 200 then return C.ok else return C.bad end end
local function getPing()
    if not (HUDC.item and HUDC.item.Parent) then
        local ok, item = pcall(function() return __NH_T.Stats.Network.ServerStatsItem["Data Ping"] end)
        HUDC.item = ok and item or nil
    end
    if not HUDC.item then return 0 end
    local ok, v = pcall(HUDC.item.GetValue, HUDC.item)
    return (ok and v) and math.floor(v + 0.5) or 0
end
local function fmtSession(s)
    s = math.max(0, math.floor(s))
    if s < 60 then return s .. "s" end
    if s < 3600 then return string.format("%dm %ds", math.floor(s / 60), s % 60) end
    return string.format("%dh %dm", math.floor(s / 3600), math.floor((s % 3600) / 60))
end

local startTime = os.time()
local lastFps, lastPing
local function updateStats(fps, ping)
    if __NH_T.islandUpdate then __NH_T.islandUpdate(fps, ping) end
    -- 数字没变就不重写富文本；窗口隐藏时不刷新里面的小字（省掉无用的排版）
    if (fps ~= lastFps or ping ~= lastPing) and hudFrame.Visible then
        lastFps, lastPing = fps, ping
        local pc = colorPing(ping)
        __NH_T.hudFps.Text = fps .. " FPS"
        __NH_T.hudPing.Text = ping .. " ms"
        __NH_T.hudPing.TextColor3 = pc
        __NH_T.hudDot.BackgroundColor3 = pc
    end
    if not main.Visible or __NH_T.animating() then return end
    -- 文字 / 颜色没变就不写（每次写都会让这个标签重新排版）
    local function setLive(l, s, c)
        if l and l.Parent then
            if l.Text ~= s then l.Text = s end
            if c and l.TextColor3 ~= c then l.TextColor3 = c end
        end
    end
    setLive(Live.fps, tostring(fps), colorFps(fps))
    setLive(Live.ping, ping .. " ms", colorPing(ping))
    setLive(Live.players, tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers))
    setLive(Live.session, fmtSession(os.time() - startTime))
end
updateStats(60, 0)

do
    local frames, last = 0, os.clock()
    connect(RunService.Heartbeat, function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            local fps = math.floor(frames / (now - last) + 0.5)
            updateStats(fps, getPing())
            Weather.onFps(fps)
            Perf.onFps(fps)
            if __NH_T.cleanerOnFps then __NH_T.cleanerOnFps(fps) end
            frames, last = 0, now
        end
    end)
end

--------------------------------------------------------------------
-- 悬浮 Logo / 移动 / 缩放 / 开关
--------------------------------------------------------------------
local uiOpen = true
local SLIDE = UDim2.fromOffset(0, 28)
-- 分两步显示：先出框架（侧栏 + 顶栏），过 2 帧再出右边内容。
-- 把“同一帧里一下子显示几百个控件”的那一下卡顿摊开，滑入动画只有 0.28 秒，看不出区别
__NH_T.revealTok = 0
function __NH_T.revealContent()
    __NH_T.revealTok += 1
    local my = __NH_T.revealTok
    content.Visible = false
    task.spawn(function()
        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
        if my == __NH_T.revealTok then content.Visible = true end
    end)
end
local function showMain()
    uiOpen = true
    animV.Value = 1                          -- 窗口大小固定，不再做缩放动画
    if Cfg.OpenAnim then
        -- 只移动位置（不缩放）：不会让整个窗口的文字每帧重新排版 / 重绘，打开界面不再掉帧
        local base = __NH_T.slideBase or main.Position
        __NH_T.slideBase = base
        __NH_T.animUntil = os.clock() + 0.35
        main.Position = base + SLIDE
        __NH_T.revealContent()
        main.Visible = true
        tween(main, {Position = base}, 0.28, Enum.EasingStyle.Quint)
        task.delay(0.32, function() if uiOpen then __NH_T.slideBase = nil end end)
    else
        __NH_T.revealContent()
        main.Visible = true
    end
end
local function hideMain(after)
    uiOpen = false
    Pop.close()
    if not Cfg.OpenAnim then
        main.Visible = false
        if after then after() end
        return
    end
    local base = __NH_T.slideBase or main.Position
    __NH_T.slideBase = base
    __NH_T.animUntil = os.clock() + 0.3
    local t = tween(main, {Position = base + SLIDE}, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    t.Completed:Connect(function()
        if not uiOpen then
            main.Visible = false
            main.Position = base
            __NH_T.slideBase = nil
        end
        if after then after() end
    end)
end
local function toggleMain()
    if uiOpen then hideMain() else showMain() end
end

logoBtn = new("ImageButton", {
    Name = "FloatingLogo", Position = Cfg.LogoPos, Size = UDim2.fromOffset(Cfg.LogoSize, Cfg.LogoSize),
    BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, Image = Cfg.Logo,
    ScaleType = Enum.ScaleType.Fit, AutoButtonColor = false, ZIndex = 10,
}, SG)
corner(logoBtn, math.floor(Cfg.LogoSize * 0.24))
stroke(logoBtn, C.stroke, 1.5, 0.1)
local logoScale = new("UIScale", {Scale = 1}, logoBtn)
local logoMoved = false
__NH_T.logoCtx = {}
__NH_T.logoSm = __NH_T.makeSmoother(function(v)
    local p = __NH_T.logoCtx.pos
    if p then logoBtn.Position = UDim2.new(p.X.Scale, p.X.Offset + v.X, p.Y.Scale, p.Y.Offset + v.Y) end
end)
-- 悬浮 logo 的拖动：优先用引擎自带的 UIDragDetector。它自己认“按下的那根手指”，
-- 不会被别的手指（比如摇杆）、屏幕边距影响，所以不会再出现“手没动、logo 自己往右下跳”。
-- 引擎不支持时自动退回下面的手动拖动。想强制手动：Cfg.LogoDragMode = "Manual"
__NH_T.logoDet = nil
if Cfg.LogoDragMode ~= "Manual" then
    pcall(function()
        local bound = new("Frame", {
            Name = "LogoBounds", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            Active = false, Interactable = false, ZIndex = 0,
        }, SG)
        local d = Instance.new("UIDragDetector")
        pcall(function() d.DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane end)
        pcall(function() d.ResponseStyle = Enum.UIDragDetectorResponseStyle.Offset end)
        pcall(function()
            d.BoundingUI = bound                                  -- logo 不会被拖出屏幕
            d.BoundingBehavior = Enum.UIDragDetectorBoundingBehavior.EntireObject
        end)
        d.Parent = logoBtn
        __NH_T.logoDet = d
    end)
end
__NH_T.logoStart = nil
__NH_T.logoLastClick = 0
function __NH_T.logoClick()
    if os.clock() - __NH_T.logoLastClick < 0.3 then return end        -- 防止“松手”和“点击”两个事件各触发一次
    __NH_T.logoLastClick = os.clock()
    __NH_T.logoPop(not uiOpen)      -- 打开时往一边晃，关闭时往另一边晃
    toggleMain()
end
if __NH_T.logoDet then
    local det = __NH_T.logoDet
    connect(det.DragStart, function()
        logoMoved = false
        __NH_T.logoStart = logoBtn.Position
        __NH_T.extDragUntil = os.clock() + 0.5
    end)
    connect(det.DragContinue, function()
        __NH_T.extDragUntil = os.clock() + 0.5
        if logoMoved or not __NH_T.logoStart then return end
        local p = logoBtn.Position
        local ls = __NH_T.logoStart
        local dx, dy = p.X.Offset - ls.X.Offset, p.Y.Offset - ls.Y.Offset
        if dx * dx + dy * dy > 36 then
            logoMoved = true
            __NH_T.logoTok += 1                          -- 取消还没播完的点击小动画
            tween(logoBtn, {Rotation = 0}, 0.05)
        end
    end)
    connect(det.DragEnd, function()
        __NH_T.extDragUntil = 0
        if __NH_T.logoStart and not logoMoved then
            logoBtn.Position = __NH_T.logoStart                 -- 只是点一下：手指抖动带来的几个像素要还原
            __NH_T.logoClick()
        end
    end)
end
connect(logoBtn.InputBegan, function(input)
    if not isPress(input) then return end
    logoMoved = false
    if __NH_T.logoDet then
        if __NH_T.dragBusyOther() then      -- 别的 UI 正被手指锁定：这次按下不拖动、也不当成点击
            logoMoved = true
            local det = __NH_T.logoDet
            det.Enabled = false
            task.delay(0.4, function() if det.Parent then det.Enabled = true end end)
        end
        return
    end
    local startPos = logoBtn.Position
    __NH_T.logoCtx.pos = startPos
    -- 以前用“按下那一刻”的手指坐标当起点；但按下事件和后面移动事件的坐标有时不在同一个坐标系
    -- （差一个屏幕边距），第一次一动 logo 就会突然往右下跳、之后一直离手一段距离。
    -- 现在起点改成“第一次移动事件”里的手指位置，之后每个事件都和它比，就不会再偏。
    local ref
    local ok = startDrag(function(inp)
        local cp = inp.Position
        if not ref then ref = cp return end
        local d = cp - ref
        if not logoMoved then
            if d.Magnitude <= 6 then return end
            logoMoved = true
            __NH_T.logoTok += 1                          -- 取消还没播完的点击小动画，免得和拖动打架
            tween(logoBtn, {Rotation = 0}, 0.05)
            ref = cp                                     -- 从开始拖动的这一刻起算，logo 一开始不会“蹿”一下
            return
        end
        local ab, sz = SG.AbsoluteSize, logoBtn.AbsoluteSize
        local x = math.clamp(startPos.X.Offset + d.X, 0, math.max(ab.X - sz.X, 0))
        local y = math.clamp(startPos.Y.Offset + d.Y, 0, math.max(ab.Y - sz.Y, 0))
        local cur = logoBtn.Position
        local jx, jy = x - cur.X.Offset, y - cur.Y.Offset
        if jx * jx + jy * jy > 140 * 140 then
            -- 一帧跳这么远一定不是手指（可能读到了别的触点）：不动，重新对齐
            ref = cp - Vector3.new(cur.X.Offset - startPos.X.Offset, cur.Y.Offset - startPos.Y.Offset, 0)
            return
        end
        logoBtn.Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
    end, function()
        if not logoMoved then return end      -- 只是点一下：不移动
    end, input)
    if not ok then
        logoMoved = true      -- 别的 UI 正被手指锁定：这次按下不拖动、也不当成点击
    end
end)
-- 点击 Logo 的小动画：只缩一点点再弹回来，几乎看不出来（不会很夸张）
__NH_T.logoTok = 0
function __NH_T.logoPop(opening)
    __NH_T.logoTok += 1
    local my = __NH_T.logoTok
    tween(logoScale, {Scale = 0.95}, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    tween(logoBtn, {Rotation = opening and -2 or 2}, 0.06, Enum.EasingStyle.Quad)
    task.delay(0.06, function()
        if __NH_T.logoTok ~= my then return end
        tween(logoScale, {Scale = 1}, 0.22, Enum.EasingStyle.Back)
        tween(logoBtn, {Rotation = 0}, 0.22, Enum.EasingStyle.Quad)
    end)
end
connect(logoBtn.MouseButton1Click, function()
    if logoMoved then return end
    __NH_T.logoClick()
end)

--------------------------------------------------------------------
-- 灵动岛（Dynamic Island）
-- UI Settings → HUD style 里随时切换：Classic = 原来的 FPS / Ping / 语言小条，Dynamic Island = 这个
-- 点一下展开（FPS / Ping / 玩家数 / FPS 记录条 / 语言切换 / 打开关闭 Hub），7 秒没操作自动收回
-- FPS 太低 / Ping 太高 / 切换语言时，会自己弹出一条小提示再收回去
--------------------------------------------------------------------
do
    local okIsl, errIsl = pcall(function()
        local D = {
            open = false, visible = false, tok = 0, noteTok = 0, idleTok = 0, bad = false,
            fps = 60, ping = 0, hist = {}, bars = {},
            shown = Cfg.HUD, style = Cfg.HudStyle or "Classic",
        }
        __NH_T.island = D
        local MINI_W, MINI_H = 200, 34
        local FULL_W, FULL_H = 316, 160
        local NOTE_W, BARS = 244, 28
        local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
        local miniSize = UDim2.fromOffset(MINI_W, MINI_H)
        local BACK, QUINT = Enum.EasingStyle.Back, Enum.EasingStyle.Quint

        for k, v in pairs({
            ["HUD style"] = "顶部样式", ["Classic"] = "经典", ["Dynamic Island"] = "灵动岛",
            ["Open Hub"] = "打开 Hub", ["Hide Hub"] = "收起 Hub", ["Low FPS"] = "帧率过低",
            ["High ping"] = "延迟过高", ["FPS history"] = "FPS 记录",
        }) do
            if __NH_T.ZH[k] == nil then __NH_T.ZH[k] = v end
        end

        ------------------------------------------------------------ 外壳
        D.root = new("Frame", {
            Name = "DynamicIsland", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
            Size = miniSize, BackgroundColor3 = BLACK, BorderSizePixel = 0, ClipsDescendants = true,
            Visible = false, ZIndex = 20,
        }, SG)
        D.corner = corner(D.root, MINI_H / 2)
        stroke(D.root, C.stroke, 1, 0.35)
        D.scale = new("UIScale", {Scale = 1}, D.root)
        D.hit = new("TextButton", {
            Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, ZIndex = 1,
        }, D.root)

        local function group(name, w, h, z)
            return new("CanvasGroup", {
                Name = name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
                Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, BorderSizePixel = 0,
                GroupTransparency = 1, ZIndex = z,
            }, D.root)
        end

        ------------------------------------------------------------ 收起状态：点 + FPS | Ping | 语言
        D.mini = group("Mini", MINI_W, MINI_H, 2)
        D.pulse = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(17, MINI_H / 2), Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = C.good, BackgroundTransparency = 1, BorderSizePixel = 0,
        }, D.mini)
        full(D.pulse)
        D.dot = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(17, MINI_H / 2), Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = C.good, BorderSizePixel = 0,
        }, D.mini)
        full(D.dot)
        D.mFps = text(D.mini, {
            Text = "60 FPS", Font = Enum.Font.GothamBold, TextSize = 12,
            Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(66, MINI_H),
        })
        new("Frame", {
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, BorderSizePixel = 0,
            Position = UDim2.fromOffset(98, 10), Size = UDim2.fromOffset(1, 14),
        }, D.mini)
        D.mPing = text(D.mini, {
            Text = "0 ms", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.good,
            Position = UDim2.fromOffset(106, 0), Size = UDim2.fromOffset(56, MINI_H),
        })
        new("Frame", {
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, BorderSizePixel = 0,
            Position = UDim2.fromOffset(164, 10), Size = UDim2.fromOffset(1, 14),
        }, D.mini)
        D.mLang = text(D.mini, {
            Text = "EN", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.mid,
            Position = UDim2.fromOffset(167, 0), Size = UDim2.fromOffset(30, MINI_H),
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        ------------------------------------------------------------ 小提示（临时变宽显示一句话）
        D.note = group("Note", NOTE_W, MINI_H, 2)
        D.noteLabel = text(D.note, {
            Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        ------------------------------------------------------------ 展开状态
        D.full = group("Full", FULL_W, FULL_H, 3)
        D.full.Visible = false
        local function statCol(x)
            local cap = text(D.full, {
                Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.sub,
                Position = UDim2.fromOffset(x, 14), Size = UDim2.fromOffset(92, 14),
            })
            local val = text(D.full, {
                Font = Enum.Font.GothamBold, TextSize = 24,
                Position = UDim2.fromOffset(x, 28), Size = UDim2.fromOffset(92, 32),
            })
            return cap, val
        end
        D.capFps, D.vFps = statCol(18)
        D.capPing, D.vPing = statCol(116)
        D.capPly, D.vPly = statCol(214)

        D.spark = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 68), Size = UDim2.fromOffset(280, 28)}, D.full)
        for i = 1, BARS do
            local b = new("Frame", {
                AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(math.floor((i - 1) * (273 / (BARS - 1))), 28),
                Size = UDim2.fromOffset(7, 3), BackgroundColor3 = C.off, BorderSizePixel = 0,
            }, D.spark)
            corner(b, 2)
            D.bars[i] = b
        end
        D.capHist = text(D.full, {
            Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.sub,
            Position = UDim2.fromOffset(18, 100), Size = UDim2.fromOffset(140, 14),
        })
        D.vSess = text(D.full, {
            Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Right,
            Position = UDim2.fromOffset(158, 100), Size = UDim2.fromOffset(140, 14),
        })

        -- 语言切换（滑动高亮）
        D.seg = new("Frame", {
            Position = UDim2.fromOffset(18, 120), Size = UDim2.fromOffset(172, 32),
            BackgroundColor3 = Color3.fromRGB(30, 30, 34), BorderSizePixel = 0,
        }, D.full)
        corner(D.seg, 16)
        D.hl = new("Frame", {
            Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(83, 26),
            BackgroundColor3 = Color3.fromRGB(66, 66, 74), BorderSizePixel = 0,
        }, D.seg)
        corner(D.hl, 13)
        local function segBtn(label, x)
            return new("TextButton", {
                Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(83, 32), BackgroundTransparency = 1,
                Text = label, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.sub,
            }, D.seg)
        end
        D.btnEn = segBtn("English", 3)
        D.btnZh = segBtn("中文", 86)

        -- 打开 / 收起 Hub
        D.hubBtn = new("TextButton", {
            Position = UDim2.fromOffset(198, 120), Size = UDim2.fromOffset(100, 32), BackgroundColor3 = WHITE,
            BorderSizePixel = 0, Text = "Open Hub", AutoButtonColor = false, Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = BLACK,
        }, D.full)
        corner(D.hubBtn, 16)

        ------------------------------------------------------------ 刷新
        function D.relabel()
            D.capFps.Text = T("FPS")
            D.capPing.Text = T("Ping")
            D.capPly.Text = T("Players")
            D.capHist.Text = T("FPS history")
            D.hubBtn.Text = T(uiOpen and "Hide Hub" or "Open Hub")
        end

        function D.refreshMini()
            local pc = colorPing(D.ping)
            local dc = (D.fps < 30) and C.bad or pc
            D.mFps.Text = D.fps .. " FPS"
            D.mPing.Text = D.ping .. " ms"
            D.mPing.TextColor3 = pc
            D.dot.BackgroundColor3 = dc
            if D.visible and not D.open and (__NH_T.fxTier or 0) < 1 then      -- 小圆点每次刷新“呼吸”一下（FPS 偏低时不播）
                D.pulse.BackgroundColor3 = dc
                D.pulse.Size = UDim2.fromOffset(8, 8)
                D.pulse.BackgroundTransparency = 0.45
                tween(D.pulse, {Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1}, 0.9)
            end
        end

        function D.refreshFull(dur)
            D.vFps.Text = tostring(D.fps)
            D.vFps.TextColor3 = colorFps(D.fps)
            D.vPing.Text = D.ping .. " ms"
            D.vPing.TextColor3 = colorPing(D.ping)
            D.vPly.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
            D.vSess.Text = T("Session") .. "  " .. fmtSession(os.time() - startTime)
            local n, top = #D.hist, 60
            for _, v in ipairs(D.hist) do if v > top then top = v end end
            for i = 1, BARS do
                local v, bar = D.hist[n - BARS + i], D.bars[i]
                if v then
                    tween(bar, {
                        Size = UDim2.fromOffset(7, math.max(3, math.floor(28 * math.min(v / top, 1)))),
                        BackgroundColor3 = colorFps(v),
                    }, dur or 0.25)
                else
                    bar.Size = UDim2.fromOffset(7, 3)
                    bar.BackgroundColor3 = C.off
                end
            end
        end

        ------------------------------------------------------------ 动画：提示 / 展开 / 收起 / 出现
        function D.notify(msg, col)
            if not D.visible or D.open then return end
            D.noteTok += 1
            local my = D.noteTok
            D.noteLabel.Text = msg
            D.noteLabel.TextColor3 = col or WHITE
            tween(D.root, {Size = UDim2.fromOffset(NOTE_W, MINI_H)}, 0.45, BACK)
            tween(D.mini, {GroupTransparency = 1}, 0.12)
            task.delay(0.1, function()
                if D.noteTok == my and not D.open then tween(D.note, {GroupTransparency = 0}, 0.2) end
            end)
            task.delay(1.9, function()
                if D.noteTok ~= my or D.open then return end
                tween(D.note, {GroupTransparency = 1}, 0.15)
                tween(D.root, {Size = miniSize}, 0.4, QUINT)
                task.delay(0.12, function()
                    if D.noteTok == my and not D.open then tween(D.mini, {GroupTransparency = 0}, 0.2) end
                end)
            end)
        end

        function D.arm()          -- 7 秒没操作自动收回
            D.idleTok += 1
            local my = D.idleTok
            task.delay(7, function()
                if D.idleTok == my and D.open then D.setOpen(false) end
            end)
        end

        function D.setOpen(v)
            if v == D.open or not D.visible then return end
            D.open = v
            D.tok += 1
            D.noteTok += 1
            D.idleTok += 1
            local my = D.tok
            if v then
                D.relabel()
                for _, b in ipairs(D.bars) do b.Size = UDim2.fromOffset(7, 3) end     -- 记录条从底下“长出来”
                D.refreshFull(0.5)
                D.full.Visible = true
                D.full.GroupTransparency = 1
                tween(D.root, {Size = UDim2.fromOffset(FULL_W, FULL_H)}, 0.52, BACK)
                tween(D.corner, {CornerRadius = UDim.new(0, 30)}, 0.45, QUINT)
                tween(D.mini, {GroupTransparency = 1}, 0.12)
                tween(D.note, {GroupTransparency = 1}, 0.1)
                task.delay(0.1, function()
                    if D.tok == my then tween(D.full, {GroupTransparency = 0}, 0.3) end
                end)
                D.arm()
            else
                tween(D.full, {GroupTransparency = 1}, 0.14)
                tween(D.root, {Size = miniSize}, 0.42, QUINT)
                tween(D.corner, {CornerRadius = UDim.new(0, MINI_H / 2)}, 0.42, QUINT)
                task.delay(0.14, function()
                    if D.tok == my then tween(D.mini, {GroupTransparency = 0}, 0.22) end
                end)
                task.delay(0.45, function()
                    if D.tok == my then D.full.Visible = false end
                end)
            end
        end

        function D.setVisible(v)
            if v == D.visible then return end
            D.visible = v
            D.open = false
            D.tok += 1
            D.noteTok += 1
            D.idleTok += 1
            D.full.Visible = false
            D.full.GroupTransparency = 1
            D.note.GroupTransparency = 1
            D.corner.CornerRadius = UDim.new(0, MINI_H / 2)
            D.scale.Scale = 1
            if v then      -- 像灵动岛一样：先是一个小圆，再向两边“长”成药丸
                D.relabel()
                D.refreshMini()
                D.root.Size = UDim2.fromOffset(MINI_H, MINI_H)
                D.mini.GroupTransparency = 1
                D.root.Visible = true
                tween(D.root, {Size = miniSize}, 0.6, BACK)
                task.delay(0.14, function()
                    if D.visible and not D.open then tween(D.mini, {GroupTransparency = 0}, 0.25) end
                end)
            else
                D.root.Visible = false
                D.mini.GroupTransparency = 1
            end
        end

        ------------------------------------------------------------ 交互
        connect(D.hit.MouseButton1Down, function()
            if not D.open then tween(D.scale, {Scale = 0.94}, 0.1) end
        end)
        local function release() tween(D.scale, {Scale = 1}, 0.28, BACK) end
        connect(D.hit.MouseButton1Up, release)
        connect(D.hit.MouseLeave, release)
        connect(D.hit.MouseButton1Click, function() D.setOpen(not D.open) end)

        for _, o in ipairs({{D.btnEn, "English"}, {D.btnZh, "中文"}}) do
            __NH_T.pressFx(o[1], 0.94, connect)
            connect(o[1].MouseButton1Click, function()
                D.arm()
                if (o[2] == "中文") == (lang == "zh") then return end
                State["settings/Interface/Language"] = o[2]      -- UI Settings 里的语言下拉框一起变
                Hub.setLang(o[2])
            end)
        end
        __NH_T.pressFx(D.hubBtn, 0.94, connect)
        connect(D.hubBtn.MouseButton1Click, function()
            D.arm()
            __NH_T.logoPop(not uiOpen)
            toggleMain()
            D.relabel()
        end)

        ------------------------------------------------------------ 语言同步（挂在原来的 syncLang 后面）
        function D.onLang(silent)
            local zh = (lang == "zh")
            D.mLang.Text = zh and "中文" or "EN"
            D.btnEn.TextColor3 = zh and C.sub or WHITE
            D.btnZh.TextColor3 = zh and WHITE or C.sub
            tween(D.hl, {Position = UDim2.fromOffset(zh and 86 or 3, 3)}, 0.32, BACK)
            D.relabel()
            if not silent then D.notify(zh and "语言：中文" or "Language: English", WHITE) end
        end
        local oldSync = __NH_T.syncLang
        function __NH_T.syncLang(...)
            if oldSync then oldSync(...) end
            D.onLang()
        end
        D.onLang(true)

        ------------------------------------------------------------ 数据更新（每 0.5 秒由 updateStats 调用）
        function __NH_T.islandUpdate(fps, ping)
            D.fps, D.ping = fps, ping
            local h = D.hist
            h[#h + 1] = fps
            if #h > BARS then table.remove(h, 1) end
            if not D.visible then return end
            D.refreshMini()
            if D.open then D.refreshFull() end
            local bad = fps < 25 or ping > 300
            if bad and not D.bad and not D.open then
                D.notify(T(fps < 25 and "Low FPS" or "High ping"), C.bad)
            end
            D.bad = bad
        end

        ------------------------------------------------------------ 样式切换（UI Settings → HUD style / Show FPS / Ping）
        local function applyHud()
            local isl = (D.style == "Dynamic Island")
            local wasClassic = hudFrame.Visible
            hudFrame.Visible = D.shown and not isl
            if hudFrame.Visible and not wasClassic then      -- 切回原来的小条：先把数字补上
                local pc = colorPing(D.ping)
                __NH_T.hudFps.Text = D.fps .. " FPS"
                __NH_T.hudPing.Text = D.ping .. " ms"
                __NH_T.hudPing.TextColor3 = pc
                __NH_T.hudDot.BackgroundColor3 = pc
            end
            D.setVisible(D.shown and isl)
        end
        function __NH_T.setHudStyle(v) D.style = v applyHud() end
        function __NH_T.setHudShown(v) D.shown = v applyHud() end
        applyHud()
    end)
    if not okIsl then warn("[NASA-Hub] Dynamic Island failed: " .. tostring(errIsl)) end
end

--------------------------------------------------------------------
-- 地图自动清理：手机 FPS 连续 N 秒低于设定值（默认 8 秒 / 35 FPS）时，
-- 自动删除地图上的特效（粒子 / 拖尾 / 光束 / 火 / 烟 / 闪光 / 爆炸 / 后期特效）和贴图（Decal / Texture / 材质贴图 / 网格贴图），
-- 之后新出现的特效和贴图也会被自动删掉。UI Settings → Performance 里可以开关、改阈值、立即清理。
-- 不会动：你自己的角色上的特效、所有玩家角色上的贴图、灯光、BillboardGui / SurfaceGui、Highlight、NASA-Hub 自己的东西
--------------------------------------------------------------------
do
    local okCl, errCl = pcall(function()
        local Lighting = game:GetService("Lighting")
        local Cl = {
            enabled = true, limit = 35, secs = 8, cleaned = false, running = false, active = false,
            removed = 0, lowAcc = 0, startedAt = os.clock(), queue = {}, qi = 1,
        }
        __NH_T.Cleaner = Cl

        for k, v in pairs({
            ["Performance"] = "性能", ["Adaptive UI effects"] = "自适应 UI 特效", ["Auto clean map"] = "低帧率自动清理地图",
            ["Low FPS limit"] = "低帧率线", ["Low FPS seconds"] = "持续秒数", ["Clean map now"] = "立即清理地图",
            ["Clean"] = "清理", ["Map cleaned"] = "已清理地图特效和贴图",
        }) do
            if __NH_T.ZH[k] == nil then __NH_T.ZH[k] = v end
        end

        local EFFECT = {ParticleEmitter = true, Trail = true, Beam = true, Fire = true, Smoke = true, Sparkles = true, Explosion = true}
        local TEXTURE = {Decal = true, Texture = true, SurfaceAppearance = true}
        local POST = {BloomEffect = true, BlurEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true, Atmosphere = true, Clouds = true}

        local function under(inst, set)       -- inst 是不是在 set 里的某个模型下面
            local p = inst.Parent
            while p and p ~= Workspace do
                if set[p] then return true end
                p = p.Parent
            end
            return false
        end

        local function process(inst, chars, mine)
            local cn = inst.ClassName
            if EFFECT[cn] then
                if not under(inst, mine) then
                    pcall(inst.Destroy, inst)
                    Cl.removed += 1
                end
            elseif TEXTURE[cn] then
                if not under(inst, chars) then
                    pcall(inst.Destroy, inst)
                    Cl.removed += 1
                end
            elseif cn == "SpecialMesh" then
                if inst.TextureId ~= "" and not under(inst, chars) then inst.TextureId = "" Cl.removed += 1 end
            elseif cn ~= "Terrain" and inst:IsA("BasePart") then
                if string.sub(inst.Name, 1, 6) == "__Nasa" or under(inst, chars) then return end
                if cn == "MeshPart" and inst.TextureID ~= "" then inst.TextureID = "" Cl.removed += 1 end
                local m = inst.Material
                if m ~= Enum.Material.SmoothPlastic and m ~= Enum.Material.Plastic then inst.Material = Enum.Material.SmoothPlastic end
                if inst.Reflectance ~= 0 then inst.Reflectance = 0 end
                if inst.CastShadow then inst.CastShadow = false end
            end
        end

        local function charSets()
            local chars, mine = {}, {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Character then chars[pl.Character] = true end
            end
            if LP.Character then mine[LP.Character] = true end
            return chars, mine
        end

        local function relevant(inst)
            local cn = inst.ClassName
            return EFFECT[cn] or TEXTURE[cn] or cn == "SpecialMesh" or (cn ~= "Terrain" and inst:IsA("BasePart"))
        end

        function Cl.startFilter()      -- 之后新出现的特效 / 贴图也自动删掉
            Cl.active = true
            if Cl.conn then return end
            Cl.conn = connect(Workspace.DescendantAdded, function(inst)
                if Cl.active and #Cl.queue - Cl.qi < 3000 and relevant(inst) then Cl.queue[#Cl.queue + 1] = inst end
            end)
        end
        function Cl.stopFilter()
            Cl.active = false
            Cl.queue, Cl.qi = {}, 1
        end
        connect(RunService.Heartbeat, function()
            if not Cl.active or Cl.qi > #Cl.queue then
                if Cl.qi > 1 then Cl.queue, Cl.qi = {}, 1 end
                return
            end
            local chars, mine = charSets()
            local t0 = os.clock()
            while Cl.qi <= #Cl.queue and os.clock() - t0 < 0.0015 do      -- 每帧最多花 1.5ms
                local inst = Cl.queue[Cl.qi]
                Cl.queue[Cl.qi] = false
                Cl.qi += 1
                if inst and inst.Parent then pcall(process, inst, chars, mine) end
            end
        end)

        function Cl.sweep(auto)
            if Cl.running then return end
            Cl.running = true
            Cl.startFilter()
            task.spawn(function()
                local before = Cl.removed
                pcall(function() Lighting.GlobalShadows = false end)
                pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
                pcall(function()
                    for _, o in ipairs(Lighting:GetDescendants()) do
                        if POST[o.ClassName] then o:Destroy() Cl.removed += 1 end
                    end
                end)
                pcall(function()
                    local T = Workspace:FindFirstChildOfClass("Terrain")
                    if T then
                        pcall(function() T.WaterWaveSize = 0 end)
                        pcall(function() T.WaterReflectance = 0 end)
                        pcall(function() T.WaterTransparency = 1 end)
                        pcall(function() T.Decoration = false end)
                    end
                end)
                local chars, mine = charSets()
                local t0, n = os.clock(), 0
                local cam = Workspace.CurrentCamera
                for _, child in ipairs(Workspace:GetChildren()) do
                    if not alive then break end
                    if child ~= cam and child.ClassName ~= "Terrain" then
                        chars, mine = charSets()
                        local list = child:GetDescendants()
                        list[#list + 1] = child
                        for _, d in ipairs(list) do
                            pcall(process, d, chars, mine)
                            n += 1
                            if n % 40 == 0 and os.clock() - t0 > 0.003 then      -- 每帧最多花 3ms，清理本身不会卡
                                task.wait()
                                t0 = os.clock()
                            end
                        end
                        task.wait()
                    end
                end
                Cl.running = false
                Cl.cleaned = true
                if Cfg.Debug then print("[NASA-Hub] map cleaned, removed " .. (Cl.removed - before)) end
                if alive then toast("Map cleaned") end
            end)
        end

        function Cl.setEnabled(v)
            Cl.enabled = v and true or false
            Cl.lowAcc = 0
            if not Cl.enabled and not Cl.running then Cl.stopFilter() end
            if Cl.enabled and Cl.cleaned then Cl.startFilter() end
        end

        -- 每 0.5 秒由 FPS 计数器调用
        function __NH_T.cleanerOnFps(fps)
            if not Cl.enabled or Cl.cleaned or Cl.running then Cl.lowAcc = 0 return end
            if os.clock() - Cl.startedAt < 25 then Cl.lowAcc = 0 return end     -- 刚进游戏 / 加载地图时帧率本来就低，先不算
            if fps < 3 then return end                                           -- 游戏在后台 / 暂停，不算
            if fps < Cl.limit then Cl.lowAcc += 0.5 else Cl.lowAcc = 0 end
            if Cl.lowAcc >= Cl.secs then
                Cl.lowAcc = 0
                Cl.sweep(true)
            end
        end
    end)
    if not okCl then warn("[NASA-Hub] Map cleaner failed: " .. tostring(errCl)) end
end

-- 移动 UI 的青色框：拖动时面板先不动，出现青色框跟着手指走；
-- 松手后面板带动画滑到青色框的位置，青色框淡出。（Settings > Cyan move frame 可关闭）
local Ghost = {hideTok = 0}
do
    local COL = Cfg.GhostColor
    Ghost.root = new("Frame", {
        Name = "MoveGhost", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = COL, BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.fromOffset(Size.w, Size.h), Position = main.Position, Visible = false,
        Active = false, ZIndex = 60,
    }, SG)
    corner(Ghost.root, 14)
    Ghost.stroke = new("UIStroke", {Color = COL, Thickness = 2, Transparency = 1}, Ghost.root)
    Ghost.scale = new("UIScale", {Scale = 1}, Ghost.root)

    Ghost.parts = {}
    local ARM, TH = 28, 4
    for _, c in ipairs({{0, 0}, {1, 0}, {0, 1}, {1, 1}}) do
        local ax, ay = c[1], c[2]
        local ox = (ax == 0) and -2 or 2
        local oy = (ay == 0) and -2 or 2
        for _, dim in ipairs({Vector2.new(ARM, TH), Vector2.new(TH, ARM)}) do
            local f = new("Frame", {
                AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(ax, ox, ay, oy),
                Size = UDim2.fromOffset(dim.X, dim.Y), BackgroundColor3 = COL, BackgroundTransparency = 1, BorderSizePixel = 0,
            }, Ghost.root)
            corner(f, 2)
            Ghost.parts[#Ghost.parts + 1] = f
        end
    end

    Ghost.sm = __NH_T.makeSmoother(function(v) Ghost.root.Position = UDim2.fromOffset(v.X, v.Y) end)

    function Ghost.show()
        Ghost.hideTok += 1
        local sz = main.AbsoluteSize
        Ghost.root.Size = UDim2.fromOffset(sz.X, sz.Y)
        Ghost.root.Position = main.Position
        Ghost.pos = main.Position
        do
            local vs, mp = SG.AbsoluteSize, main.Position
            Ghost.sm.begin(Vector2.new(mp.X.Scale * vs.X + mp.X.Offset, mp.Y.Scale * vs.Y + mp.Y.Offset))
        end
        Ghost.root.Visible = true
        Ghost.scale.Scale = 0.94
        tween(Ghost.scale, {Scale = 1}, 0.25, Enum.EasingStyle.Back)
        tween(Ghost.root, {BackgroundTransparency = 0.92}, 0.2)
        tween(Ghost.stroke, {Transparency = 0.1}, 0.2)
        for _, f in ipairs(Ghost.parts) do tween(f, {BackgroundTransparency = 0}, 0.2) end
    end

    function Ghost.hide()
        Ghost.hideTok += 1
        local my = Ghost.hideTok
        tween(Ghost.root, {BackgroundTransparency = 1}, 0.25)
        tween(Ghost.stroke, {Transparency = 1}, 0.25)
        tween(Ghost.scale, {Scale = 1.04}, 0.25)
        for _, f in ipairs(Ghost.parts) do tween(f, {BackgroundTransparency = 1}, 0.25) end
        task.delay(0.3, function()
            if my == Ghost.hideTok and alive then
                Ghost.root.Visible = false
                Ghost.scale.Scale = 1
            end
        end)
    end

    -- 青色框跟着手指走（不会拖出屏幕）
    function Ghost.follow(startPos, delta)
        local vs = SG.AbsoluteSize
        local sz = main.AbsoluteSize
        local hx, hy = sz.X / 2, sz.Y / 2
        local cx = startPos.X.Scale * vs.X + startPos.X.Offset + delta.X
        local cy = startPos.Y.Scale * vs.Y + startPos.Y.Offset + delta.Y
        cx = (vs.X > sz.X) and math.clamp(cx, hx, vs.X - hx) or vs.X / 2
        cy = (vs.Y > sz.Y) and math.clamp(cy, hy, vs.Y - hy) or vs.Y / 2
        Ghost.pos = UDim2.new(startPos.X.Scale, cx - startPos.X.Scale * vs.X, startPos.Y.Scale, cy - startPos.Y.Scale * vs.Y)
        Ghost.sm.tar = Vector2.new(cx, cy)
    end

    -- 松手：面板滑到青色框的位置
    function Ghost.commit()
        Ghost.sm.finish(true)
        if not Ghost.pos then Ghost.hide() return end
        if Ghost.moveTween then Ghost.moveTween:Cancel() end
        local tw = tween(main, {Position = Ghost.pos}, Cfg.MoveTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        Ghost.moveTween = tw
        tw.Completed:Connect(function(state)
            if Ghost.moveTween == tw and state == Enum.PlaybackState.Completed then
                Ghost.moveTween = nil
                Ghost.hide()
            end
        end)
    end

    -- 面板还在滑动时又按住：先停下滑动
    function Ghost.cancelMove()
        if Ghost.moveTween then
            Ghost.moveTween:Cancel()
            Ghost.moveTween = nil
        end
    end
end

__NH_T.winCtx = {}
__NH_T.winSm = __NH_T.makeSmoother(function(v)
    local p = __NH_T.winCtx.pos
    if p then main.Position = UDim2.new(p.X.Scale, p.X.Offset + v.X, p.Y.Scale, p.Y.Offset + v.Y) end
end)
function __NH_T.beginWindowDrag(input)
    if not isPress(input) then return end
    if __NH_T.dragBusy() then return end      -- 别的 UI（logo / 滑条 …）已经被手指锁定，这次按下不抢
    Pop.close()
    Ghost.cancelMove()
    local useGhost = State["settings/Interface/Cyan move frame"] ~= false
    local startPos, startMouse = main.Position, input.Position
    local moved = false
    local ok = startDrag(function(inp)
        local d = inp.Position - startMouse
        if not moved and d.Magnitude > 6 then
            moved = true
            if useGhost then
                Ghost.show()
            else
                __NH_T.winCtx.pos = startPos
                __NH_T.winSm.begin(Vector2.new(d.X, d.Y))
            end
        end
        if not moved then return end
        if useGhost then
            Ghost.follow(startPos, d)
        else
            __NH_T.winSm.tar = Vector2.new(d.X, d.Y)
        end
    end, function()
        if not moved then return end
        if useGhost then Ghost.commit() else __NH_T.winSm.finish(true) end
    end, input)
end
connect(header.InputBegan, __NH_T.beginWindowDrag)
connect(__NH_T.brand.InputBegan, __NH_T.beginWindowDrag)   -- 左边面板顶部的 Logo 区也能拖动窗口

-- 右下角缩放把手
local grip = new("TextButton", {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(20, 20),
    BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 20,
}, main)
for i, off in ipairs({3, 8}) do
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -off - 2, 1, -off - 2),
        Size = UDim2.fromOffset(i == 1 and 8 or 14, 1.5), Rotation = -45, BackgroundColor3 = C.sub,
        BorderSizePixel = 0, ZIndex = 21,
    }, grip)
end
local function onResized()
    if __NH_T.fitPills then __NH_T.fitPills() end
    statusPill.Visible = Size.w >= 700
    verPill.Visible = Size.w >= 640
    if __NH_T.dcPill then __NH_T.dcPill.Visible = Size.w >= 980 end      -- 窗口太窄时先隐藏长链接，免得挤到搜索框
    searchWrap.Size = UDim2.fromOffset(Size.w >= 640 and 176 or 130, 36)
end
connect(grip.InputBegan, function(input)
    if isPress(input) and not __NH_T.dragBusy() then
        local startMouse, startW, startH, startPos = input.Position, Size.w, Size.h, main.Position
        local s = scaler.Scale
        Pop.close()
        startDrag(function(inp)
            local d = inp.Position - startMouse
            local nw = math.clamp(startW + d.X / s, Cfg.MinW, Cfg.MaxW)
            local nh = math.clamp(startH + d.Y / s, Cfg.MinH, Cfg.MaxH)
            Size.w, Size.h = nw, nh
            main.Size = UDim2.fromOffset(nw, nh)
            -- 左上角保持不动：中心点随尺寸变化平移一半
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (nw - startW) * s / 2,
                startPos.Y.Scale, startPos.Y.Offset + (nh - startH) * s / 2)
            onResized()
        end, nil, input)
    end
end)
onResized()

connect(minBtn.MouseButton1Click, function() hideMain() end)

-- 关闭确认：点右上角 X → 弹出警告 → 再点“Close”才会整个卸载 UI（和 UI Settings 里的 Unload 一样）
do
    for k, v in pairs({
        ["Close NASA-Hub?"] = "关闭 NASA-Hub？",
        ["This will close the whole UI. To open it again you need to run the script again."] = "这会把整个 UI 关闭。想再打开需要重新运行脚本。",
        ["Cancel"] = "取消", ["Close"] = "关闭",
    }) do if __NH_T.ZH[k] == nil then __NH_T.ZH[k] = v end end

    local dim = new("TextButton", {
        Name = "CloseConfirm", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 400,
    }, SG)
    local card = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 176),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, ZIndex = 401,
    }, dim)
    corner(card, 14)
    stroke(card, C.stroke, 1.5, 0.1)
    local cardScale = new("UIScale", {Scale = 0.9}, card)

    local badge = new("Frame", {
        Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(38, 38),
        BackgroundColor3 = Color3.fromRGB(58, 44, 22), BorderSizePixel = 0, ZIndex = 402,
    }, card)
    full(badge)
    text(badge, {
        Text = "!", Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = C.orange,
        TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 403,
    })
    local titleL = text(card, {
        Position = UDim2.fromOffset(70, 18), Size = UDim2.new(1, -86, 0, 24),
        Font = Enum.Font.GothamBold, TextSize = 19, ZIndex = 402,
    })
    local msgL = text(card, {
        Position = UDim2.fromOffset(70, 46), Size = UDim2.new(1, -86, 0, 58), TextSize = 14, TextColor3 = C.sub,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 402,
    })

    local function mkBtn(x, bg, hover, fg)
        local b = new("TextButton", {
            Position = UDim2.fromOffset(x, 120), Size = UDim2.fromOffset(155, 38), Text = "", AutoButtonColor = false,
            BackgroundColor3 = bg, BorderSizePixel = 0, ZIndex = 402,
        }, card)
        corner(b, 9)
        local l = text(b, {
            Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = fg, TextXAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.fromScale(1, 1), ZIndex = 403,
        })
        connect(b.MouseEnter, function() tween(b, {BackgroundColor3 = hover}, 0.1) end)
        connect(b.MouseLeave, function() tween(b, {BackgroundColor3 = bg}, 0.1) end)
        return b, l
    end
    local cancelB, cancelL = mkBtn(20, C.pill, C.pillOn, C.mid)
    local closeB, closeL = mkBtn(185, Color3.fromRGB(196, 58, 58), Color3.fromRGB(220, 74, 74), Color3.new(1, 1, 1))

    local shown = false
    local function setShown(v)
        shown = v
        if v then
            Pop.close()
            titleL.Text = T("Close NASA-Hub?")
            msgL.Text = T("This will close the whole UI. To open it again you need to run the script again.")
            cancelL.Text = T("Cancel")
            closeL.Text = T("Close")
            dim.Visible = true
            cardScale.Scale = 0.9
            tween(dim, {BackgroundTransparency = 0.45}, 0.15)
            tween(cardScale, {Scale = 1}, 0.28, Enum.EasingStyle.Back)
        else
            tween(dim, {BackgroundTransparency = 1}, 0.15)
            tween(cardScale, {Scale = 0.9}, 0.15)
            task.delay(0.16, function() if not shown then dim.Visible = false end end)
        end
    end
    connect(dim.MouseButton1Click, function() setShown(false) end)
    connect(cancelB.MouseButton1Click, function() setShown(false) end)
    connect(closeB.MouseButton1Click, function()
        setShown(false)
        Hub.unload()
    end)
    function __NH_T.askClose() if not shown then setShown(true) end end
end
connect(__NH_T.closeBtn.MouseButton1Click, function() __NH_T.askClose() end)
connect(UIS.InputBegan, function(input, gpe)
    if gpe then return end
    if input.KeyCode == Cfg.ToggleKey then toggleMain() end
end)

--------------------------------------------------------------------
-- 清理 / 卸载
--------------------------------------------------------------------
local cleaned = false
local function cleanup()
    if cleaned then return end
    cleaned = true
    alive = false
    if ALLOW_RERUN_AFTER_CLOSE then Env.NASA_HUB_RUNNING = nil end
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Music.destroy()
    for _, t in ipairs(blinkTweens) do pcall(function() t:Cancel() end) end
    pcall(applyFpsCap, "60")          -- 卸载时把帧率上限还原成 60
    pcall(Weather.clear)
    pcall(function() animV:Destroy() end)
end
function Hub.unload()
    hideMain(function()
        cleanup()
        SG:Destroy()
    end)
end
SG.Destroying:Connect(cleanup)
Env.NASA_HUB_API = Hub

--------------------------------------------------------------------
-- 初始化 + 入场动画
--------------------------------------------------------------------
paintRail(true)
renderPage()                 -- 先把当前页（Home）建好
applyFpsCap(tostring(Cfg.FpsCap or 120))
startPrebuild(2.5)           -- 入场动画结束后，在后台把其它页面（Main 最先）提前建好
animV.Value = 0
main.Visible = false
logoBtn.Visible = false

local function playIntro()
    local BALL = 72
    local BALL_LOGO = (Cfg.IntroBall == false) and 64 or 48      -- 有圆形底时缩小一点，让方形 logo 完全在圆里面
    local ball = new("Frame", {
        Name = "IntroBall", Size = UDim2.fromOffset(BALL, BALL), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 1.2, 0), BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 999,
    }, SG)
    full(ball)
    local ballStroke = stroke(ball, C.stroke, 2, 0)
    if Cfg.IntroBall == false then ball.BackgroundTransparency = 1 ballStroke.Transparency = 1 end
    local ballLogo = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(BALL_LOGO, BALL_LOGO), BackgroundColor3 = Color3.fromRGB(14, 14, 18),
        BorderSizePixel = 0, Image = Cfg.Logo, ScaleType = Enum.ScaleType.Fit,
    }, ball)
    -- logo 不加圆角
    local ballLogoScale = new("UIScale", {Scale = 1}, ballLogo)

    TweenService:Create(ball, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
    task.wait(1.7)

    local quad = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(ball, quad, {Size = UDim2.fromOffset(1000, 1000), BackgroundTransparency = 1}):Play()
    TweenService:Create(ballStroke, quad, {Transparency = 1}):Play()
    TweenService:Create(ballLogo, quad, {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
    TweenService:Create(ballLogoScale, quad, {Scale = 1.8}):Play()

    logoBtn.Size = UDim2.fromOffset(0, 0)
    logoBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
    logoBtn.Visible = true
    TweenService:Create(logoBtn, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.fromOffset(Cfg.LogoSize, Cfg.LogoSize), Position = Cfg.LogoPos}):Play()
    showMain()
    task.delay(0.5, function() if ball then ball:Destroy() end end)
end

task.spawn(function()
    local ok, err = pcall(playIntro)
    if not ok then
        warn("[NASA-Hub] 入场动画出错，已直接显示界面: " .. tostring(err))
        local leftover = SG:FindFirstChild("IntroBall")
        if leftover then leftover:Destroy() end
        logoBtn.Size = UDim2.fromOffset(Cfg.LogoSize, Cfg.LogoSize)
        logoBtn.Position = Cfg.LogoPos
        logoBtn.Visible = true
        showMain()
    end
end)
