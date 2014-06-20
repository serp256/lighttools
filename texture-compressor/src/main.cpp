#include <getopt.h>
#include "QCompressLib.h"
#include <unistd.h>
#include <sys/stat.h>

#define ERR_IF(cond, fmt, args...) if (cond) { printf("\n"); printf(fmt, ## args); printf("\n"); exit(1); }
#define PRINT(fmt, args...) if (!silent) { printf(fmt, ## args); fflush(stdout); }

#define PVR_EXT "pvr"
#define AST_EXT "atc"
#define DXT_EXT "dxt"
#define ETC_EXT "etc"
#define ETC2_EXT "etc2"
#define KTX_EXT "ktx"

#define COMPRESSED_EXT "cmprs"

int pvr = 0, atc = 0, dxt = 0, etc_fast = 0, etc_slow = 0, etc2_fast = 0, etc2_slow = 0, ffff = 0, no_alpha = 0, silent = 0, help = 0;

char *change_ext(char *inp, char *new_ext) {
	char *cur_ext = strrchr(inp, '.');
	int inp_len = cur_ext ? inp_len = strlen(inp) - strlen(cur_ext) : strlen(inp);
	char *ret = (char*)malloc(inp_len + strlen(new_ext) + 2);

	memcpy(ret, inp, inp_len);
	strcpy(ret + inp_len + 1, new_ext);
	ret[inp_len] = '.';

	return ret;
}

char *insert_dirname(char *inp, char *dirname, char make_dir, char *ext) {
	char *fname = strrchr(inp, '/');
	char *with_dir = NULL;
	size_t dirname_len = strlen(dirname);

	if (!fname) {
		size_t inp_len = strlen(inp);
		with_dir = (char*)malloc(dirname_len + 1 + inp_len + 1);

		strcpy(with_dir, dirname);
		mkdir(dirname, 0775);
			 *(with_dir + dirname_len) = '/';
		strcpy(with_dir + dirname_len + 1, inp);
	} else {
		fname++;
		size_t fname_len = strlen(fname);
		size_t basedir_len = strlen(inp) - fname_len;
		
		with_dir = (char*)malloc(basedir_len + dirname_len + fname_len + 2);

		memcpy(with_dir, inp, basedir_len);
		strcpy(with_dir + basedir_len, dirname);
		mkdir(with_dir, 0775);
			 *(with_dir + basedir_len + dirname_len) = '/';
		strcpy(with_dir + basedir_len + dirname_len + 1, fname);
	}

	char *ret;
	if (ext) {
		ret = change_ext(with_dir, ext);
		free(with_dir);
	} else {
		ret = with_dir;
	}

	return ret;
}

void compress_using_qonvert(char *inp, char *out, unsigned int format) {
	TQonvertImage *src_tex = CreateEmptyTexture();

	ERR_IF(!LoadImage(inp, src_tex), "error when loading '%s'", inp);
	TQonvertImage *mips[1] = { CreateEmptyTexture() };
	printf("w %d h %d\n", src_tex->nWidth, src_tex->nHeight);
	ERR_IF(!MipMapAndCompress(src_tex, mips, format, src_tex->nWidth, src_tex->nHeight, 1), "error when compressing '%s'", inp);

	/* qcompress lib bug workaround */
	if (format == Q_FORMAT_ATC_RGBA_EXPLICIT_ALPHA) mips[0]->nFormat = Q_FORMAT_ATC_RGBA_INTERPOLATED_ALPHA;
	if (format == Q_FORMAT_ATC_RGBA_INTERPOLATED_ALPHA) mips[0]->nFormat = Q_FORMAT_ATC_RGBA_EXPLICIT_ALPHA;
	
	ERR_IF(!SaveImageDDS(out, mips, 1), "error when saving compressed '%s' to '%s'", inp, out);

	FreeTexture(src_tex);
	FreeTexture(mips[0]);
}

void compress_using_pvrtextool(char *inp, char *out, char *format) {
	char *pvr_out = change_ext(out, PVR_EXT);
	char *fmt = "PVRTexTool -yflip0 -f%s -premultalpha -pvrtcbest -i %s -o %s > /dev/null 2>&1";
	char *cmd = (char*)malloc(strlen(fmt) - 6 + strlen(inp) + strlen(pvr_out) + 1);
	sprintf(cmd, fmt, format, inp, pvr_out);
	// printf("cmd %s\n", cmd);
	ERR_IF(system(cmd), "error when running pvr tool on %s", inp);
	ERR_IF(rename(pvr_out, out), "error when renaming '%s' to '%s'", pvr_out, out);
	free(cmd);
	free(pvr_out);
}

void compress(char *inp) {
	char *out;

	if (atc) {
		PRINT("\tmaking atc... ");
		out = insert_dirname(inp, AST_EXT, 1, COMPRESSED_EXT);
		compress_using_qonvert(inp, out, no_alpha ? Q_FORMAT_ATC_RGB : Q_FORMAT_ATC_RGBA_EXPLICIT_ALPHA);
		free(out);
		PRINT("done\n");
	}

	if (dxt) {
		PRINT("\tmaking dxt... ");
		out = insert_dirname(inp, DXT_EXT, 1, COMPRESSED_EXT);
		compress_using_qonvert(inp, out, no_alpha ? Q_FORMAT_S3TC_DXT1_RGB : Q_FORMAT_S3TC_DXT5_RGBA);
		free(out);
		PRINT("done\n");
	}

	if (ffff) {
		PRINT("\tmaking 4444... ");
		out = change_ext(inp, COMPRESSED_EXT);
		compress_using_pvrtextool(inp, out, "OGL4444");
		free(out);
		PRINT("done\n");
	}

	if (pvr) {
		PRINT("\tmaking pvr... ");
		out = insert_dirname(inp, PVR_EXT, 1, COMPRESSED_EXT);
		compress_using_pvrtextool(inp, out, "OGLPVRTC4");
		free(out);
		PRINT("done\n");
	}

#define RESAVE(inp, out) { \
	TQonvertImage *ktx_img = CreateEmptyTexture(); \
	ERR_IF(!LoadImageKTX((const char*)inp, ktx_img, true), "error when reading ktx file '%s' produced by etcpack", inp); \
	ERR_IF(!SaveImageDDS(out, &ktx_img, 1), "error when saving compressed '%s' to '%s'", inp, out); \
	FreeTexture(ktx_img); \
};

#define TMPDIR char *tmpdir = getenv("TMPDIR"); \
	if (!tmpdir) tmpdir = "./"; \
	size_t tmpdir_len = strlen(tmpdir);

#define FNAMES char *fname = strrchr(inp, '/'); \
	fname = fname ? fname + 1 : inp; \
	size_t fname_len = strlen(fname); \
	char *tmp_fname = (char*)malloc(tmpdir_len + fname_len + 1); \
	memcpy(tmp_fname, tmpdir, tmpdir_len); \
	strcpy(tmp_fname + tmpdir_len, fname);

	if (etc_slow || etc_fast) {
		PRINT("\tmaking etc... ");

		TMPDIR;

		const char *speed = etc_slow ? "slow" : "fast";
		const char *alpha = no_alpha ? "" : "-as ";
		char *fmt = "etcpack %s %s -s %s -c etc1 %s-ktx 1>&- 2>&-";
		char *cmd = (char*)malloc(strlen(fmt) - 8 + strlen(inp) + tmpdir_len + strlen(speed) + strlen(alpha) + 1);
		sprintf(cmd, fmt, inp, tmpdir, speed, alpha);
		ERR_IF(system(cmd), "error when running etcpack tool on %s", inp);

		FNAMES;

#define ALPHA_FNAME(src, res) { \
	size_t src_len = strlen(src); \
	res = (char*)malloc(src_len + 6 + 1); \
	char *ext = strrchr(src, '.'); \
	size_t ext_len = strlen(ext); \
	memcpy(res, src, src_len); \
	memcpy(res + src_len - ext_len, "_alpha", 6); \
	strcpy(res + src_len - ext_len + 6, ext); \
};

		char *ktx = change_ext(tmp_fname, KTX_EXT);
		out = insert_dirname(inp, ETC_EXT, 1, COMPRESSED_EXT);
		RESAVE(ktx, out);

		if (!no_alpha) {
			char *ktx_alpha;
			ALPHA_FNAME(ktx, ktx_alpha);

			char *out_alpha;
			ALPHA_FNAME(out, out_alpha);
			RESAVE(ktx_alpha, out_alpha);

			unlink(ktx_alpha);
			free(out_alpha);
			free(ktx_alpha);
		}

		unlink(ktx);

#undef ALPHA_FNAME

		free(out);
		free(ktx);
		free(tmp_fname);
		free(cmd);

		PRINT("done\n");
	}

	if (etc2_slow || etc2_fast) {
		PRINT("\tmaking etc2... ");

		TMPDIR;

		const char *speed = etc_slow ? "slow" : "fast";
		const char *pxl_fmt = no_alpha ? "RGB" : "RGBA";
		char *fmt = "etcpack %s %s -s %s -f %s -c etc2 -ktx 1>&- 2>&-";
		char *cmd = (char*)malloc(strlen(fmt) - 8 + strlen(inp) + tmpdir_len + strlen(speed) + strlen(pxl_fmt) + 1);
		sprintf(cmd, fmt, inp, tmpdir, speed, pxl_fmt);
		ERR_IF(system(cmd), "error when running etcpack tool on %s", inp);

		FNAMES;

		char *ktx = change_ext(tmp_fname, KTX_EXT);
		out = insert_dirname(inp, ETC2_EXT, 1, COMPRESSED_EXT);
		RESAVE(ktx, out);
		unlink(ktx);

		free(out);
		free(ktx);
		free(tmp_fname);
		free(cmd);

		PRINT("done\n");
	}

#undef RESAVE
#undef TMPDIR
}

int main(int argc, char **argv) {
	char usage[] = "Universal textures compressor.\nUsage: texcmprss [-atc] [-dxt] [-etc-fast | -etc-slow] [-etc2-fast | -etc2-slow ] [-4444] [-no-alpha] [-silent] [-h] [ source ... ]\nOptions:\n\t-atc\t\tCreate ATC texture.\n\t-dxt\t\tCreate DXT texture.\n\t-etc-fast\tCreate ETC texture as fast as possible.\n\t-etc-slow\tCreate best-quality ETC texture.\n\t-etc2-fast\tCreate ETC2 texture as fast as possible.\n\t-etc2-slow\tCreate best-quality ETC2 texture.\n\t-no-alpha\tCreate texture without alpha channel. In case of ETC texture do not create separate alpha texture.\n\t-4444\t\tCreate RGBA_4444 texture.\n\t-silent\t\tSwitch off all verbose.\n\t-h\t\tDisplay this message.";

	struct option long_opts[] = {
		{"pvr", no_argument, &pvr, 1},
		{"atc", no_argument, &atc, 1},
		{"dxt", no_argument, &dxt, 1},
		{"etc-fast", no_argument, &etc_fast, 1},
		{"etc2-fast", no_argument, &etc2_fast, 1},
		{"etc-slow", no_argument, &etc_slow, 1},
		{"etc2-slow", no_argument, &etc2_slow, 1},
		{"no-alpha", no_argument, &no_alpha, 1},
		{"4444", no_argument, &ffff, 1},
		{"silent", no_argument, &silent, 1},
		{"h", no_argument, &help, 1},
		{0, 0, 0, 0}
	};

	int c;

	while ((c = getopt_long_only(argc, argv, "", long_opts, NULL)) != -1) {
		if (c) {
			printf("%s\n", usage);
			return 0;			
		}
	}

	if (help) {
		printf("%s\n", usage);
		return 0;
	}

	for (int i = optind; i < argc; i++) {
		PRINT("processing %s\n", argv[i]);
		compress(argv[i]);
	}

	return 0;
}
