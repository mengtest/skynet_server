#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include "atomic.h"

static uint32_t sid = 0;

static int
lsid (lua_State *L) {
	if (sid >= 0xffff)
		return 0;
	ATOM_INC(&sid);
	lua_pushinteger (L, sid);
	return 1;
}

int
luaopen_uuid_core (lua_State *L) {
	luaL_checkversion (L);
	luaL_Reg l[] = {
		{ "sid", lsid },
		{ NULL, NULL },
	};
	luaL_newlib (L,l);
	return 1;
}
