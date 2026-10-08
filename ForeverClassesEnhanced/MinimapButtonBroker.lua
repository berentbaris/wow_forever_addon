----------------------------------------------------------------------
-- ForeverClassesEnhanced — LibDataBroker/LibDBIcon minimap backend
----------------------------------------------------------------------

FCE = FCE or {}

local Broker = {}
FCE.MinimapButtonBroker = Broker

local OBJECT_NAME = "ForeverClassesEnhanced"
local ICON_PATH = "Interface\\AddOns\\ForeverClassesEnhanced\\Textures\\minimap_cce"

local iconLibrary

local function Libraries()
    if not LibStub then return nil, nil end
    return LibStub:GetLibrary("LibDataBroker-1.1", true),
           LibStub:GetLibrary("LibDBIcon-1.0", true)
end

function Broker.Create(options)
    if iconLibrary then return true end

    local dataBroker, dbIcon = Libraries()
    if not dataBroker or not dbIcon then return false end

    local settings = options.GetSettings()
    if settings.minimapPos == nil then
        settings.minimapPos = settings.angle or 215
    end

    local dataObject = dataBroker:NewDataObject(OBJECT_NAME, {
        type = "launcher",
        text = "Forever Classes Enhanced",
        label = "Forever Classes Enhanced",
        icon = ICON_PATH,
        OnClick = options.OnClick,
        OnTooltipShow = options.OnTooltipShow,
    })

    dbIcon:Register(OBJECT_NAME, dataObject, settings)
    iconLibrary = dbIcon
    return true
end

function Broker.Show()
    if iconLibrary then
        iconLibrary:Show(OBJECT_NAME)
    end
end

function Broker.Hide()
    if iconLibrary then
        iconLibrary:Hide(OBJECT_NAME)
    end
end
