#include <getopt.h>
#include "QCompressLib.h"
#include <unistd.h>

#define ERR_IF(cond, fmt, args...) if (cond) { printf("\n"); printf(fmt, ## args); printf("\n"); exit(1); }
#define PRINT(fmt, args...) if (!silent) { printf(fmt, ## args); fflush(stdout); }

#define PVR_EXT "pvr"
#define AST_EXT "atc"
#define DXT_EXT "dxt"
#define ETC_EXT "etc"
#define KTX_EXT "ktx"

int pvr = 0, atc = 0, dxt = 0, etc_fast = 0, etc_slow = 0, no_alpha = 0, silent = 0;

char* change_ext(char *inp, char *new_ext) {
	char *cur_ext = strrchr(inp, '.');
	int inp_len = cur_ext ? inp_len = strlen(inp) - strlen(cur_ext) : strlen(inp);
	char *ret = (char*)malloc(inp_len + strlen(new_ext) + 2);

	memcpy(ret, inp, inp_len);
	strcpy(ret + inp_len + 1, new_ext);
	ret[inp_len] = '.';

	return ret;
}

void compress_using_qonvert(char *inp, char *out, unsigned int format) {
	TQonvertImage *src_tex = CreateEmptyTexture();

	ERR_IF(!LoadImage(inp, src_tex), "error when loading '%s'", inp);
	TQonvertImage *mips[1] = { CreateEmptyTexture() };
	ERR_IF(!MipMapAndCompress(src_tex, mips, format, src_tex->nHeight, src_tex->nHeight, 1), "error when compressing '%s'", inp);

	/* qcompress lib bug workaround */
	if (format == Q_FORMAT_ATC_RGBA_EXPLICIT_ALPHA) mips[0]->nFormat = Q_FORMAT_ATC_RGBA_INTERPOLATED_ALPHA;
	if (format == Q_FORMAT_ATC_RGBA_INTERPOLATED_ALPHA) mips[0]->nFormat = Q_FORMAT_ATC_RGBA_EXPLICIT_ALPHA;
	
	ERR_IF(!SaveImageDDS(out, mips, 1), "error when saving compressed '%s' to '%s'", inp, out);

	FreeTexture(src_tex);
	FreeTexture(mips[0]);
}

void compress(char *inp) {
	char *out;

	if (atc) {
		PRINT("\tmaking atc... ");
		out = change_ext(inp, AST_EXT);
		compress_using_qonvert(inp, out, no_alpha ? Q_FORMAT_ATC_RGB : Q_FORMAT_ATC_RGBA_EXPLICIT_ALPHA);
		free(out);
		PRINT("done\n");
	}

	if (dxt) {
		PRINT("\tmaking dxt... ");
		out = change_ext(inp, DXT_EXT);
		compress_using_qonvert(inp, out, no_alpha ? Q_FORMAT_S3TC_DXT1_RGB : Q_FORMAT_S3TC_DXT5_RGBA);
		free(out);
		PRINT("done\n");
	}

	if (pvr) {
		PRINT("\tmaking pvr... ");
		out = change_ext(inp, PVR_EXT);
		char *fmt = "PVRTexTool -yflip0 -fOGLPVRTC4 -premultalpha -pvrtcbest -i %s -o %s > /dev/null 2>&1";
		char *cmd = (char*)malloc(strlen(fmt) - 4 + strlen(inp) + strlen(out) + 1);
		sprintf(cmd, fmt, inp, out);
		ERR_IF(system(cmd), "error when running pvr tool on %s", inp);
		free(out);
		free(cmd);
		PRINT("done\n");
	}

	if (etc_slow || etc_fast) {
		PRINT("\tmaking etc... ");

		char *tmpdir = getenv("TMPDIR");
		size_t tmpdir_len = strlen(tmpdir);
		char *speed = etc_slow ? (char*)"slow" : (char*)"fast";
		char *fmt = "etcpack %s %s -s %s -c etc1 -as -ktx > /dev/null 2>&1";
		char *cmd = (char*)malloc(strlen(fmt) - 4 + strlen(inp) + tmpdir_len + 1);
		sprintf(cmd, fmt, inp, tmpdir, speed);
		ERR_IF(system(cmd), "error when running etcpack tool on %s", inp);

		char *fname = strrchr(inp, '/');
		fname = fname ? fname + 1 : inp;
		size_t fname_len = strlen(fname);


		char *tmp_fname = (char*)malloc(tmpdir_len + fname_len + 1);
		memcpy(tmp_fname, tmpdir, tmpdir_len);
		strcpy(tmp_fname + tmpdir_len, fname);

#define ALPHA_FNAME(src, res) { \
	size_t src_len = strlen(src); \
	res = (char*)malloc(src_len + 6 + 1); \
	char *ext = strrchr(src, '.'); \
	size_t ext_len = strlen(ext); \
	memcpy(res, src, src_len); \
	strcpy(res + src_len - ext_len, "_alpha"); \
	strcpy(res + src_len - ext_len + 6, ext); \
};

#define RESAVE(inp, out) { \
	TQonvertImage *ktx_img = CreateEmptyTexture(); \
	ERR_IF(!LoadImageKTX((const char*)inp, ktx_img, true), "error when reading ktx file '%s' produced by etcpack", inp); \
	ERR_IF(!SaveImageDDS(out, &ktx_img, 1), "error when saving compressed '%s' to '%s'", inp, out); \
	FreeTexture(ktx_img); \
};

		char *ktx = change_ext(tmp_fname, KTX_EXT);
		char *ktx_alpha;
		ALPHA_FNAME(ktx, ktx_alpha);

		out = change_ext(inp, ETC_EXT);
		RESAVE(ktx, out);
		
		char *out_alpha;
		ALPHA_FNAME(out, out_alpha);
		RESAVE(ktx_alpha, out_alpha);

		unlink(ktx);
		unlink(ktx_alpha);

#undef RESAVE
#undef ALPHA_FNAME

		free(out);
		free(out_alpha);
		free(ktx);
		free(ktx_alpha);
		free(tmp_fname);
		free(cmd);

		PRINT("done\n");
	}
}

int main(int argc, char **argv) {
	struct option long_opts[] = {
		{"pvr", no_argument, &pvr, 1},
		{"atc", no_argument, &atc, 1},
		{"dxt", no_argument, &dxt, 1},
		{"etc-fast", no_argument, &etc_fast, 1},
		{"etc-slow", no_argument, &etc_slow, 1},
		{"no-alpha", no_argument, &no_alpha, 1},
		{"silent", no_argument, &silent, 1},
		{0, 0, 0, 0}
	};

	while (getopt_long_only(argc, argv, "", long_opts, NULL) != -1) {}

	for (int i = optind; i < argc; i++) {
		PRINT("processing %s\n", argv[i]);
		compress(argv[i]);
	}

	return 0;
}
