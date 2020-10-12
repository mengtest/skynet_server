THIRD_LIB_ROOT ?= 3rd
LUA_CJSON_ROOT ?= $(THIRD_LIB_ROOT)/lua-cjson
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
#获取$(LUACLIB_SRC_PATH)目录下所有文件名
LUACLIB_OBJ = $(foreach v, $(LUA_CLIB_NAME), $(LUACLIB_PATH)/$(v).so)

#service
CSERVICE_PATH ?= $(SERVICE_BIN)/cservice
CSERVICE_CSRC_PATH ?= src/service-src

CSERVICE_NAME = caoi syslog
CSERVICE_OBJ = $(foreach v, $(CSERVICE_NAME), $(CSERVICE_PATH)/$(v).so)

VPATH += $(LUACLIB_SRC_PATH)
VPATH += $(CSERVICE_CSRC_PATH)

linux macosx freebsd : make3rd createdir  copyfiles lib

make3rd :
	@$(MAKE) $(PLAT) -C $(SKYNET_ROOT) --no-print-directory
	#lua-cjson需要指定lua的目录，这边用skynet自带的lua先生成一下
	gcc -c -O3 -Wall -pedantic -DNDEBUG  -I$(LUA_INC) -fpic -o $(LUA_CJSON_ROOT)/lua_cjson.o $(LUA_CJSON_ROOT)/lua_cjson.c
	@$(MAKE) -C $(LUA_CJSON_ROOT) --no-print-directory

createdir:
	@mkdir -p $(SERVICE_BIN)
	@mkdir -p $(LUACLIB_PATH)
	@mkdir -p $(CSERVICE_PATH)
	@mkdir -p $(SERVICE_BIN)/lua-cjson
	@mkdir -p $(SERVICE_BIN)/pids

lib:$(LUACLIB_OBJ) $(CSERVICE_OBJ) ${LUACLIB_PATH}/lfs.so

copyfiles:
	@cp -rf $(SKYNET_ROOT)/skynet $(SERVICE_BIN)
	@cp -rf $(LUA_CJSON_ROOT)/cjson.so $(SERVICE_BIN)/lua-cjson

$(LUACLIB_OBJ) : $(LUACLIB_PATH)/%.so : lua-%.c 
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(CSERVICE_PATH)/caoi.so : service_aoi.c aoi.c
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(CSERVICE_PATH)/%.so : service_%.c
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

# lfs
LFS_SOURCE=3rd/lfs/src/lfs.c

${LFS_SOURCE}:
	git submodule update --init 3rd/lfs

${LUACLIB_PATH}/lfs.so: ${LFS_SOURCE}
	gcc $(CFLAGS) $(SHARED) -I3rd/lfs/src/ $^ -o $@ $(LDFLAGS)

clean :
	$(RM) -rf $(LUACLIB_OBJ) $(CSERVICE_OBJ) $(SERVICE_BIN)

cleanall: clean
	@$(MAKE) -C $(LUA_CJSON_ROOT) clean --no-print-directory
	@$(MAKE) -C $(SKYNET_ROOT) cleanall --no-print-directory

.PHONY : linux macosx freebsd make3rd createdir clean cleanall