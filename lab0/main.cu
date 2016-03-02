#include <cstdio>
#include <cstdlib>
#include "SyncedMemory.h"
#include <ctype.h>
#define CHECK {\
	auto e = cudaDeviceSynchronize();\
	if (e != cudaSuccess) {\
		printf("At " __FILE__ ":%d, %s\n", __LINE__, cudaGetErrorString(e));\
		abort();\
	}\
}
__global__ void SomeTransform(char *input_gpu, int fsize, int offset) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x + offset * 256;
	if (input_gpu[idx] != '\n') {
		//input_gpu[idx] = '!';
		if(input_gpu[idx]<= 'Z' && input_gpu[idx] >= 'A'){//Big alpha
			input_gpu[idx] += 32;
		}
		else if(input_gpu[idx] <= 'z' && input_gpu[idx] >= 'a'){//Little alpha
			input_gpu[idx] -= 32;
		}
	}
}

int main(int argc, char **argv)
{
	// init, and check
	if (argc != 2) {
		printf("Usage %s <input text file>\n", argv[0]);
		abort();
	}
	FILE *fp = fopen(argv[1], "r");
	if (!fp) {
		printf("Cannot open %s", argv[1]);
		abort();
	}
	// get file size
	fseek(fp, 0, SEEK_END);
	size_t fsize = ftell(fp);
	fseek(fp, 0, SEEK_SET);

	// read files
	MemoryBuffer<char> text(fsize+1);
	auto text_smem = text.CreateSync(fsize);
	CHECK;
	fread(text_smem.get_cpu_wo(), 1, fsize, fp);
	text_smem.get_cpu_wo()[fsize] = '\0';
	fclose(fp);

	// TODO: do your transform here
	char *input_gpu = text_smem.get_gpu_rw();
	// An example: transform the first 64 characters to '!'
	// Don't transform over the tail
	// And don't transform the line breaks
	int offset = 0;
	while(offset * 256 < fsize){
	SomeTransform<<<4, 64 >>>(input_gpu, fsize, offset);
	offset++;
	}
	puts(text_smem.get_cpu_ro());
	return 0;
}
