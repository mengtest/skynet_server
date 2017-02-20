local skynet = require "skynet"
local log = require "syslog"
require "skynet.manager"

local CMD = {}
local OBJ = {}
local aoi

skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	pack = function(text) return text end,
	unpack = function(buf, sz) return skynet.tostring(buf,sz) end,
}

function CMD.aoicallback(w,m)
  assert(OBJ[w])
  assert(OBJ[m])
  log.debug("AOI CALLBACK:%d(%d,%d) => %d(%d,%d)",w,OBJ[w].movement.pos.x,OBJ[w].movement.pos.y,m,OBJ[m].movement.pos.x,OBJ[m].movement.pos.y)
  --将视野内的玩家通知agent
  assert(OBJ[w].agent)
  skynet.send(OBJ[w].agent,"lua","addaoiobj",OBJ[m].info,OBJ[m].agent)
end

--添加到aoi
function CMD.characterenter(agent,obj)
  assert(agent)
  assert(obj)
  log.debug("AOI ENTER %d %s %d %d %d",obj.tempid,obj.movement.mode,obj.movement.pos.x,obj.movement.pos.y,obj.movement.pos.z)
  OBJ[obj.tempid] = obj
  OBJ[obj.tempid].agent = agent
	assert(pcall(skynet.send,aoi, "text", "update "..obj.tempid.." "..obj.movement.mode.." "..obj.movement.pos.x.." "..obj.movement.pos.y.." "..obj.movement.pos.z))
end

--从aoi中移除
function CMD.characterleave(obj)
  assert(obj)
  log.debug("%d leave aoi",obj.tempid)
	assert(pcall(skynet.send,aoi, "text", "update "..obj.tempid.." d "..obj.movement.pos.x.." "..obj.movement.pos.y.." "..obj.movement.pos.z))
  OBJ[obj.tempid] = nil
end

function CMD.open()
  aoi = assert(skynet.launch("caoi", skynet.self()))
end

function CMD.close(name)
  log.notice("close aoi(%s)...",name)

end

skynet.start(function()
	skynet.dispatch("text", function (session, source, cmd)
		local t = cmd:split(" ")
		local f = CMD[t[1]]
		if f then
			f(tonumber(t[2]),tonumber(t[3]))
		else
			log.notice("Unknown command : [%s]", cmd)
		end
	end)

	skynet.dispatch("lua", function (_,_, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log.notice("Unknown command : [%s]", cmd)
			skynet.response()(false)
		end
	end)
end)
