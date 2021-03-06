#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>
#include <dirent.h>
#include <unistd.h>

#define ONE_MB	(1024 * 1024)
#define DEFAULT_ROLL_SIZE (1024 * ONE_MB)  // 单个文件大小大于xGB的时候新建log文件
#define FILE_TIME (3600) // 每小时生成新的log文件

struct logger {
	FILE * handle;
	char * filename;
	char * pathname;
	int close;
	int filesize;
	int index;
	time_t filetime;
};

struct logger *
syslog_create(void) {
	struct logger * inst = skynet_malloc(sizeof(*inst));
	inst->handle = NULL;
	inst->close = 0;
	inst->filesize = 0;
	inst->index = 0;
	inst->filetime = 0;
	inst->filename = NULL;
	inst->pathname = NULL;

	return inst;
}

void
syslog_release(struct logger * inst) {
	if (inst->close) {
		fclose(inst->handle);
	}
	skynet_free(inst->filename);
	skynet_free(inst->pathname);
	skynet_free(inst);
}

void
gen_file_name(struct logger * inst, time_t now) {
	char filename[128] = {0};
	char dirname[128] = {0};
	struct tm tm;
	localtime_r(&now, &tm);
	sprintf(dirname, "%s/%d-%d-%d", inst->pathname, tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
	
	// 检查文件夹是否存在，如果不存在则创建
	DIR* dir;
	dir = opendir(dirname);
	if (dir == NULL)
	{
		int saved_errno = errno;
		if (saved_errno == ENOENT)
		{
			if (mkdir(dirname, 0755) == -1)
			{
				saved_errno = errno;
				fprintf(stderr, "mkdir error: %s\n", strerror(saved_errno));
				exit(EXIT_FAILURE);
			}
		}
		else
		{
			fprintf(stderr, "opendir error: %s\n", strerror(saved_errno));
			exit(EXIT_FAILURE);
		}
	}
	else
		closedir(dir);

	do{
		if(inst->filename != NULL)
			skynet_free(inst->filename);

		sprintf(filename, "%d-%d-%d-%d_%d.log", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, inst->index);
		inst->filename = skynet_malloc(strlen(dirname) + strlen(filename) + 1);
		sprintf(inst->filename, "%s/%s", dirname, filename);
		inst->index += 1;
	} while (access(inst->filename, F_OK) == 0);
}

bool
try_create_new_log_file(struct logger * inst, time_t now){
	if(inst->pathname == NULL)
		return false;

	if(inst->filetime != now/FILE_TIME)
	{
		inst->filetime = now/FILE_TIME;
		inst->index = 0;
		inst->filesize = 0;
		gen_file_name(inst, now);
		return true;
	}
	else if(inst->filesize >= DEFAULT_ROLL_SIZE)
	{
		inst->filesize = 0;
		gen_file_name(inst, now);
		return true;
	}
	return false;
}

static int
syslog_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	struct logger * inst = ud;
	switch (type) {
	case PTYPE_SYSTEM:
		if (inst->filename) {
			inst->handle = freopen(inst->filename, "a", inst->handle);
		}
		break;
	case PTYPE_TEXT:
		{
			struct tm tm;
			time_t now = time(NULL);
			if(try_create_new_log_file(inst, now))
			{
				fclose(inst->handle);
				inst->handle = fopen(inst->filename,"a");
				if (inst->handle == NULL) {
					skynet_error(context, "create log file fail![%s]\n", inst->filename);
				}
			}
			localtime_r(&now, &tm);
			fprintf(inst->handle, "[%d-%02d-%02d %02d:%02d:%02d][:%08x] ", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec, source);
			fwrite(msg, sz , 1, inst->handle);
			fprintf(inst->handle, "\n");
			inst->filesize += fflush(inst->handle);
		}
		break;
	}

	return 0;
}

int 
folder_mkdirs(char *folder_path)
{	
	if(!access(folder_path, F_OK)){
		return 1;
	}

	char path[256];
	char *path_buf;
	char temp_path[256];
	char *temp;
	int temp_len;
	
	memset(path, 0, sizeof(path));
	memset(temp_path, 0, sizeof(temp_path));
	strcat(path, folder_path);
	path_buf = path;

	while((temp = strsep(&path_buf, "/")) != NULL){
		temp_len = strlen(temp);	
		if(0 == temp_len){
			continue;
		}
		strcat(temp_path, "/");
		strcat(temp_path, temp);
		printf("temp_path = %s\n", temp_path);
		if(-1 == access(temp_path, F_OK)){
			if(-1 == mkdir(temp_path, 0755)){
				return 2;
			}
		}
	}
	return 1;
}

int
syslog_init(struct logger * inst, struct skynet_context *ctx, const char * parm) {
	if (parm) {
		inst->pathname = skynet_malloc(strlen(parm)+1);
		strcpy(inst->pathname, parm);
		if(1 != folder_mkdirs(inst->pathname))
		{
			skynet_free(inst->pathname);
			return 1;
		}
		try_create_new_log_file(inst, time(NULL));
		inst->handle = fopen(inst->filename,"a");
		if (inst->handle == NULL) {
			skynet_free(inst->filename);
			skynet_free(inst->pathname);
			return 1;
		}
		inst->close = 1;
	} else {
		inst->handle = stdout;
	}
	if (inst->handle) {
		skynet_callback(ctx, inst, syslog_cb);
		return 0;
	}
	return 1;
}
