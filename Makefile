THIRD_LIB_ROOT ?= 3rd
SKYNET_ROOT ?= $(THIRD_LIB_ROOT)/skynet
include $(SKYNET_ROOT)/platform.mk
SKYNET_SRC ?= $(SKYNET_ROOT)/skynet-src
LUA_INC ?= $(SKYNET_ROOT)/3rd/lua
SERVICE_BIN ?=bin

CFLAGS = -g -O2 -Wall -I$(LUA_INC) -I$(SKYNET_SRC)

#lua
LUACLIB_PATH ?= $(SERVICE_BIN)/luaclib
LUACLIB_SRC_PATH ?= src/lualib-src

#获取$(LUACLIB_SRC_PATH)目录下所有文件名
LUA_CLIB_NAME = $(patsubst lua-%.c, %, $(notdir $(wildcard $(LUACLIB_SRC_PATH)/*.c)))
LUACLIB_OBJ = $(foreach v, $(LUA_CLIB_NAME), $(LUACLIB_PATH)/$(v).so)

#service
CSERVICE_PATH ?= $(SERVICE_BIN)/cservice
CSERVICE_CSRC_PATH ?= src/service-src

CSERVICE_NAME = caoi syslog
CSERVICE_OBJ = $(foreach v, $(CSERVICE_NAME), $(CSERVICE_PATH)/$(v).so)

VPATH += $(LUACLIB_SRC_PATH)
VPATH += $(CSERVICE_CSRC_PATH)

linux macosx freebsd : skynet createdir lib copyskynet copysnapshot

skynet :
	@$(MAKE) $(PLAT) -C $(SKYNET_ROOT) --no-print-directory

createdir:
	@mkdir -p $(SERVICE_BIN)
	@mkdir -p $(SERVICE_BIN)/pids
	@mkdir -p $(LUACLIB_PATH)
	@mkdir -p $(CSERVICE_PATH)

lib:$(LUACLIB_OBJ) $(CSERVICE_OBJ) ${LUACLIB_PATH}/lfs.so ${LUACLIB_PATH}/cjson.so ${LUACLIB_PATH}/snapshot.so

copyskynet:
	@cp -rf $(SKYNET_ROOT)/skynet $(SERVICE_BIN)
	@cp -rf $(SKYNET_ROOT)/cservice $(SERVICE_BIN)
	@cp -rf $(SKYNET_ROOT)/luaclib $(SERVICE_BIN)
	@cp -rf $(SKYNET_ROOT)/lualib $(SERVICE_BIN)
	@cp -rf $(SKYNET_ROOT)/service $(SERVICE_BIN)

$(LUACLIB_OBJ) : $(LUACLIB_PATH)/%.so : lua-%.c 
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(CSERVICE_PATH)/caoi.so : service_aoi.c aoi.c
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(CSERVICE_PATH)/%.so : service_%.c
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

# cjson
LUA_CJSON_ROOT ?= $(THIRD_LIB_ROOT)/lua-cjson
CJSON_SOURCE = $(LUA_CJSON_ROOT)/lua_cjson.c \
				$(LUA_CJSON_ROOT)/strbuf.c \
				$(LUA_CJSON_ROOT)/fpconv.c

${LUACLIB_PATH}/cjson.so:${CJSON_SOURCE}
	${CC} $(CFLAGS) $(SHARED) -I$(LUA_CJSON_ROOT) $^ -o $@ $(LDFLAGS)

$(LUA_CJSON_ROOT)/lua_cjson.c:
	git submodule update --init $(LUA_CJSON_ROOT)

# lfs
LFS_ROOT ?= $(THIRD_LIB_ROOT)/lfs
LFS_SOURCE=$(LFS_ROOT)/src/lfs.c

${LFS_SOURCE}:
	git submodule update --init $(LFS_ROOT)

${LUACLIB_PATH}/lfs.so: ${LFS_SOURCE}
	${CC} $(CFLAGS) $(SHARED) -I$(LFS_ROOT)/src/ $^ -o $@ $(LDFLAGS)

# snapshot
SNAPSHOT_ROOT ?= $(THIRD_LIB_ROOT)/lua-snapshot
SNAPSHOT_SOURCE=$(SNAPSHOT_ROOT)/snapshot.c

${SNAPSHOT_SOURCE}:
	git submodule update --init $(SNAPSHOT_ROOT)

${LUACLIB_PATH}/snapshot.so: ${SNAPSHOT_SOURCE}
	${CC} $(CFLAGS) $(SHARED) -I$(SNAPSHOT_ROOT)/src/ $^ -o $@ $(LDFLAGS)

copysnapshot:
	@cp -rf $(SNAPSHOT_ROOT)/snapshot_utils.lua $(SERVICE_BIN)/lualib

clean :
	$(RM) -rf $(LUACLIB_OBJ) $(CSERVICE_OBJ) $(SERVICE_BIN)

cleanall: clean
	@$(MAKE) -C $(LUA_CJSON_ROOT) clean --no-print-directory
	@$(MAKE) -C $(SKYNET_ROOT) cleanall --no-print-directory

.PHONY : linux macosx freebsd skynet createdir lib copyskynet copysnapshot clean cleanall