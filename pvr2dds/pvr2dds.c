#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

typedef unsigned int uint;

typedef struct 
{
    uint32_t  u32Version;     //Version of the file header, used to identify it.
    uint32_t  u32Flags;     //Various format flags.
    uint64_t  u64PixelFormat;   //The pixel format, 8cc value storing the 4 channel identifiers and their respective sizes.
    uint32_t u32ColourSpace;   //The Colour Space of the texture, currently either linear RGB or sRGB.
    uint32_t u32ChannelType;   //Variable type that the channel is stored in. Supports signed/unsigned int/short/byte or float for now.
    uint32_t  u32Height;      //Height of the texture.
    uint32_t  u32Width;     //Width of the texture.
    uint32_t  u32Depth;     //Depth of the texture. (Z-slices)
    uint32_t  u32NumSurfaces;   //Number of members in a Texture Array.
    uint32_t  u32NumFaces;    //Number of faces in a Cube Map. Maybe be a value other than 6.
    uint32_t  u32MIPMapCount;   //Number of MIP Maps in the texture - NB: Includes top level.
    uint32_t  u32MetaDataSize;  //Size of the accompanying meta data.
} __attribute__((packed)) PVRTextureHeader3;

typedef struct
{
    uint size;
    uint flags;
    uint fourcc;
    uint bitcount;
    uint rmask;
    uint gmask;
    uint bmask;
    uint amask;
} DDSPixelFormat;

typedef struct
{
    uint caps1;
    uint caps2;
    uint caps3;
    uint caps4;
} DDSCaps;

typedef struct
{
    uint fourcc;
    uint size;
    uint flags;
    uint height;
    uint width;
    uint pitch;
    uint depth;
    uint mipmapcount;
    uint reserved[11];
    DDSPixelFormat pf;
    DDSCaps caps;
    uint notused;
} DDSHeader;

typedef int8_t int8;

#if !defined(MAKEFOURCC)
#define MAKEFOURCC(ch0, ch1, ch2, ch3) \
        ((uint)((int8)(ch0)) | ((uint)((int8)(ch1)) << 8) | \
        ((uint)((int8)(ch2)) << 16) | ((uint)((int8)(ch3)) << 24 ))
#endif

#define ERROR(mes) printf("%s\n", mes); return 1;

int main(int argc, char* argv[]) {
    if (argc != 3) {
        ERROR("pvr2dds takes two arguments: pvr source file and dds destination file");
    }
    
    FILE* pvrf;

    if (!(pvrf = fopen(argv[1], "r"))) {
        ERROR(strerror(errno));
    }

    fseek(pvrf, 0, SEEK_END);
    int pvrflen = ftell(pvrf);
    fseek(pvrf, 0, SEEK_SET);

    PVRTextureHeader3 pvrh;
    
    if (fread(&pvrh,sizeof(PVRTextureHeader3),1,pvrf) != 1) {
        ERROR("error when reading pvr header");
    }

    if (pvrh.u32MetaDataSize > 0) fseek(pvrf,pvrh.u32MetaDataSize,SEEK_CUR);

    int pvrdatalen = pvrflen - sizeof(PVRTextureHeader3) - pvrh.u32MetaDataSize;
    unsigned char* pvrdata = (unsigned char*)malloc(pvrdatalen);

    if (fread(pvrdata,pvrdatalen,1,pvrf) != 1) {
        ERROR("error when reading pvr data");
    }

    DDSHeader ddsh;

    ddsh.fourcc = MAKEFOURCC('D', 'D', 'S', ' ');
    ddsh.height = pvrh.u32Height;
    ddsh.width = pvrh.u32Width;
    ddsh.mipmapcount = pvrh.u32MIPMapCount;
    ddsh.pf.fourcc = MAKEFOURCC('4', '4', '4', '4');

    FILE* ddsf;

    if (!(ddsf = fopen(argv[2], "w"))) {
        ERROR(strerror(errno));
    }

    if (fwrite(&ddsh, sizeof(DDSHeader), 1, ddsf) != 1) {
        ERROR("error when writing dds header");
    }

    if (fwrite(pvrdata, pvrdatalen, 1, ddsf) != 1) {
        ERROR("error when writing pvr data to destination");
    }

    fclose(pvrf);
    fclose(ddsf);

    return 0;
}