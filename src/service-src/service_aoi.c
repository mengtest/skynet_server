#include "aoi.h"
#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct alloc_cookie {
	int count;
	int max;
	int current;
};

struct aoi_space_plus {
	struct alloc_cookie* cookie;
	struct aoi_space * space;
	struct skynet_context * ctx;
	int map_handle;
};

static void *
my_alloc(void * ud, void *ptr, size_t sz) {
	struct alloc_cookie * cookie = ud;
	if (ptr == NULL) {
		void *p = skynet_malloc(sz);
		++ cookie->count;
		cookie->current += sz;
		if (cookie->max < cookie->current) {
			cookie->max = cookie->current;
		}
//		printf("%p + %u\n",p, sz);
		return p;
	}
	-- cookie->count;
	cookie->current -= sz;
//	printf("%p - %u \n",ptr, sz);
	skynet_free(ptr);
	return NULL;
}

static void
call_back_message(void *ud, uint32_t watcher, uint32_t marker) {
	struct aoi_space_plus * space_plus = ud;

	char temp[64];
	int n = sprintf(temp, "aoi_callback %d %d", watcher, marker);
	skynet_send(space_plus->ctx, 0, space_plus->map_handle, PTYPE_TEXT, 0, temp, n);
}

static void
_parm(char *msg, int sz, int command_sz) {
	while (command_sz < sz) {
		if (msg[command_sz] != ' ')
			break;
		++command_sz;
	}
	int i;
	for (i=command_sz;i<sz;i++) {
		msg[i-command_sz] = msg[i];
	}
	msg[i-command_sz] = '\0';
}

static void
_ctrl(struct skynet_context * ctx, struct aoi_space_plus * space_plus, const void * msg, int sz) {
	char tmp[sz+1];
	memcpy(tmp, msg, sz);
	tmp[sz] = '\0';
	char * command = tmp;
	int i;
	if (sz == 0)
		return;
	for (i=0;i<sz;i++) {
		if (command[i]==' ') {
			break;
		}
	}
	if (memcmp(command,"update",i)==0) {
		_parm(tmp, sz, i);
		char * text = tmp;
		char * idstr = strsep(&text, " ");
		if (text == NULL) {
			return;
		}
		int id = strtol(idstr , NULL, 10);
		char * mode = strsep(&text, " ");
		if (text == NULL) {
			return;
		}
		float pos[3] = {0};
		char * posstr = strsep(&text, " ");
		if (text == NULL) {
			return;
		}
		pos[0] = strtof(posstr , NULL);
		posstr = strsep(&text, " ");
		if (text == NULL) {
			return;
		}
		pos[1] = strtof(posstr , NULL);
		posstr = strsep(&text, " ");
		pos[2] = strtof(posstr , NULL);
		
		aoi_update(space_plus->space, id, mode, pos);
		return;
	}
	if (memcmp(command,"message",i)==0) {
		aoi_message(space_plus->space, call_back_message, space_plus);
		return;
	}
	skynet_error(ctx, "[aoi] Unkown command : %s", command);
}

struct aoi_space_plus *
caoi_create(void) {
	struct aoi_space_plus * space_plus = skynet_malloc(sizeof(struct aoi_space_plus));
	memset(space_plus, 0, sizeof(*space_plus));

	space_plus->cookie = skynet_malloc(sizeof(struct alloc_cookie));
	memset(space_plus->cookie, 0, sizeof(*(space_plus->cookie)));

	space_plus->space = aoi_create(my_alloc , space_plus->cookie);
	return space_plus;
}

void
caoi_release(struct aoi_space_plus * space_plus) {
	aoi_release(space_plus->space);
	skynet_free(space_plus->cookie);
	skynet_free(space_plus);
}

static int
caoi_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	struct aoi_space_plus * space_plus = ud;
	switch (type) {
	case PTYPE_TEXT:
		_ctrl(context , space_plus , msg , (int)sz);
		break;
	}

	return 0;
}

int
caoi_init(struct aoi_space_plus * space_plus, struct skynet_context *ctx, const char * args) {
	space_plus->map_handle = atoi(args);
	space_plus->ctx = ctx;
	skynet_callback(ctx, space_plus, caoi_cb);
	return 0;
}
