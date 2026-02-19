local LA = select(2, ...)

local private = {modules = {}}

-- Global API object
LA_API = {}
LA.LA_API = LA_API

function LA_API.RegisterModule(theModule)
    LA.Debug.Log("RegisterModule")
    LA.Debug.TableToString(theModule)

    if not private.modules then private.modules = {} end
    private.modules[theModule.name] = theModule
end

function LA_API.GetVersion() return LA.CONST.METADATA.VERSION end

function LA_API.GetCurrentSession() return LA.Session.GetCurrentSession() end

function LA_API.PauseSession() LA.Session.Pause() end

function LA_API.StartSession(qualityFilter, priceSource, ...)
    if not qualityFilter or not priceSource then return end

    local startPaused
    for i = 1, select('#', ...) do
        local opt = select(i, ...)
        if opt == nil then
            -- do nothing
        elseif opt == "START_PAUSED" then
            startPaused = true
        end
    end

    LA.db.profile.notification.qualityFilter = qualityFilter
    LA.db.profile.pricesource.source = priceSource

    LA.Session.Start(true)
    LA.Session.New()

    if startPaused then LA.Session.Pause() end
end

function LA.GetModules() return private.modules end

-- Legacy API for older LAC versions
function LA:RegisterModule(theModule) LA_API.RegisterModule(theModule) end
