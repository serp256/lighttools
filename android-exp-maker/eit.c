#include <stdio.h>
#include <assert.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>

int main(int argc, char* argv[]) {
	if (argc != 2) {
		printf("expansion index tracer should take only one argument -- expansion filename\n");
		return 1;
	}

	FILE* in = fopen(argv[1], "r");

	assert(in != NULL);
	int32_t index_entries_num;		
	assert(1 == fread(&index_entries_num, sizeof(int32_t), 1, in));

	printf("index entries number: %d\n", index_entries_num);

	size_t delim = 0;
	int i = 0;

	while (i++ < index_entries_num) {
		int8_t filename_len;		
		assert(1 == fread(&filename_len, sizeof(int8_t), 1, in));

		char* filename = malloc(filename_len + 1);
		int32_t offset;
		int32_t size;

		assert(filename_len == fread(filename, 1, filename_len, in));
		*(filename + filename_len) = '\0';
		assert(1 == fread(&offset, sizeof(int32_t), 1, in));
		assert(1 == fread(&size, sizeof(int32_t), 1, in));

		printf("\tfilename: %s; offset: %d; size: %d\n", filename, offset, size);

		free(filename);
	}

	fclose(in);

	return 0;
}