local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Timer = require(ReplicatedStorage.Packages.Timer)

local Hitbox = {}
Hitbox.__index = Hitbox

local HitboxVisualFolder = Instance.new("Folder")
HitboxVisualFolder.Name = "Visualizer"
HitboxVisualFolder.Parent = workspace

local overlap_params = OverlapParams.new()
overlap_params.FilterDescendantsInstances = { HitboxVisualFolder }
overlap_params.FilterType = Enum.RaycastFilterType.Exclude

local function get_character_model(part: BasePart)
    if part.Parent == nil or (not part:IsA("Model") and not part:IsA("BasePart")) then
        return nil
    end

    if part:HasTag("Character") then
        return part
    end

    return get_character_model(part.Parent)
end

local function get_object_model(part: BasePart)
    if part.Parent == nil or (not part:IsA("Model") and not part:IsA("BasePart")) then
        return nil
    end

    if part:HasTag("Object") then
        return part
    end

    return get_object_model(part.Parent)
end

function Hitbox.new(options: { [string]: any })
    options = options or {}

    assert(options.CFrame ~= nil or options.Part ~= nil, "Invalid CFrame & Part")
    assert(options.Size ~= nil, "Invalid Size")

    if options.Interval == nil then
        options.Interval = 1 / 60
    end

    return setmetatable({
        Part = options.Part,
        CFrame = options.CFrame or CFrame.new(),
        Size = options.Size or Vector3.new(1, 1, 1),
        DetectionMethod = options.DetectionMethod or "Box",
        TargetType = options.TargetType or "Character",
        Interval = options.Interval,
        Duration = options.Duration or 0,
        Visible = options.Visible or false,
        Blacklist = options.Blacklist or {},
        Tagged = {},
        Hit = Signal.new(),
        Janitor = Janitor.new(),
        Timer = Timer.new(options.Interval),
    }, Hitbox)
end

function Hitbox:Start()
    -- add the timer to the Janitor for cleanup purposes
    self.Janitor:Add(self.Timer)

    -- generate hitbox visualizer if visible
    if self.Visible == true then
        local part = Instance.new("Part")
        part.Transparency = 0.5
        part.Color = Color3.new(1, 0, 0)
        part.Size = self.Size
        part.Anchored = true
        part.CanCollide = false
        part.Parent = HitboxVisualFolder
        self.Visual = part
        -- add the visual part to the Janitor for cleanup
        self.Janitor:Add(part)
    end

    -- connect a function to the Timer's Tick event to perform hitbox detection
    self.Timer.Tick:Connect(function()
        local source_cframe = self.CFrame

        -- check for part to attach to
        if self.Part then
            source_cframe = self.Part.CFrame * self.CFrame
        end

        local results = {}

        -- attaches visualizer part to hitbox
        if self.Visible == true then
            self.Visual.CFrame = source_cframe
        end

        -- perform hit detection based on the specified detection method
        if self.DetectionMethod == "Box" then
            results = workspace:GetPartBoundsInBox(source_cframe, self.Size, overlap_params)
        elseif self.DetectionMethod == "Radius" then
            results = workspace:GetPartBoundsInRadius(source_cframe.Position, self.Size, overlap_params)
        elseif self.DetectionMethod == "Part" then
            results = workspace:GetPartsInPart(self.Part)
        elseif self.DetectionMethod == "Magnitude" then
            local target_table = CollectionService:GetTagged("Character")

            -- determine the target table based on the target type
            if self.TargetType == "Object" then
                target_table = CollectionService:GetTagged("Object")
            else
                for _, target in CollectionService:GetTagged("Object") do
                    table.insert(target_table, target)
                end
            end

            local source_position = source_cframe.Position

            -- iterate over potential targets and check if they are within the hitbox range
            for _, target in target_table do
                if self.Blacklist[target] == true then
                    continue
                end
                if self.Tagged[target] == true then
                    continue
                end

                local target_part = target

                if target:IsA("Model") then
                    target_part = target.PrimaryPart
                    if target_part == nil then
                        continue
                    end
                end
                if (target_part.CFrame.Position - source_position).Magnitude < self.Size then
                    results = { target_part }
                end
            end
        end

        -- process the detected results
        for _, hit in results do
            if hit.Parent == nil then
                continue
            end

            local target = nil

            -- determine the target type based on the hit object
            if self.TargetType == "Character" then
                target = get_character_model(hit)
            elseif self.TargetType == "Object" then
                target = get_object_model(hit)
            else
                target = get_character_model(hit) or get_object_model(hit)
            end

            if target == nil then
                continue
            end

            if self.Blacklist[target] == true then
                continue
            end

            if self.Tagged[target] == true then
                continue
            end

            -- fire the hit event and tag the target as hit
            self.Hit:Fire(target)
            self.Tagged[target] = true
        end

        -- decrease the duration of the hitbox
        self.Duration -= self.Interval

        -- destroy the hitbox if its duration has ended
        if self.Duration <= 0 then
            self:Destroy()
        end
    end)

    -- start the timer based on the hitbox duration
    if self.Duration > 0 then
        self.Timer:Start()
    else
        self.Timer:StartNow()
    end
end

function Hitbox:Destroy()
    self.Janitor:Cleanup()
end

return Hitbox
