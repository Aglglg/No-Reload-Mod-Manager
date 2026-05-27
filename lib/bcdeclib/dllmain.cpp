#include "pch.h"

#define BCDEC_IMPLEMENTATION
#include "bcdec.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#pragma pack(push, 1)
struct DDS_PIXELFORMAT {
    uint32_t dwSize, dwFlags, dwFourCC, dwRGBBitCount;
    uint32_t dwRBitMask, dwGBitMask, dwBBitMask, dwABitMask;
};
struct DDS_HEADER {
    uint32_t dwSize, dwFlags, dwHeight, dwWidth;
    uint32_t dwPitchOrLinearSize, dwDepth, dwMipMapCount;
    uint32_t dwReserved1[11];
    DDS_PIXELFORMAT ddspf;
    uint32_t dwCaps, dwCaps2, dwCaps3, dwCaps4, dwReserved2;
};
struct DDS_HEADER_DXT10 {
    uint32_t dxgiFormat, resourceDimension, miscFlag, arraySize, miscFlags2;
};
#pragma pack(pop)

#define FOURCC(a,b,c,d) ((uint32_t)(a)|((uint32_t)(b)<<8)|((uint32_t)(c)<<16)|((uint32_t)(d)<<24))

enum BCFmt { BC_UNKNOWN, BC1, BC2, BC3, BC4, BC5, BC6H_U, BC6H_S, BC7 };

static BCFmt detectFormat(const DDS_HEADER* h, const DDS_HEADER_DXT10* dx10) {
    uint32_t fcc = h->ddspf.dwFourCC;
    if (!(h->ddspf.dwFlags & 0x4)) return BC_UNKNOWN;

    if (fcc == FOURCC('D', 'X', 'T', '1')) return BC1;
    if (fcc == FOURCC('D', 'X', 'T', '3')) return BC2;
    if (fcc == FOURCC('D', 'X', 'T', '5')) return BC3;
    if (fcc == FOURCC('B', 'C', '4', 'U') || fcc == FOURCC('A', 'T', 'I', '1')) return BC4;
    if (fcc == FOURCC('B', 'C', '5', 'U') || fcc == FOURCC('A', 'T', 'I', '2')) return BC5;

    if (fcc == FOURCC('D', 'X', '1', '0') && dx10) {
        switch (dx10->dxgiFormat) {
        case 71: case 72: return BC1;
        case 74: case 75: return BC2;
        case 77: case 78: return BC3;
        case 80: case 81: return BC4;
        case 83: case 84: return BC5;
        case 95:          return BC6H_U;
        case 96:          return BC6H_S;
        case 98: case 99: return BC7;
        }
    }
    return BC_UNKNOWN;
}

extern "C" __declspec(dllexport)
void FreeDdsBuffer(uint8_t* buf) {
    free(buf);
}

extern "C" __declspec(dllexport)
uint8_t* DecodeDdsScaled(const wchar_t* path, int dstW, int dstH,
    int* outWidth, int* outHeight) {

    HANDLE hFile = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ,
        nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (hFile == INVALID_HANDLE_VALUE) return nullptr;
    LARGE_INTEGER fileSize;
    GetFileSizeEx(hFile, &fileSize);
    HANDLE hMap = CreateFileMappingW(hFile, nullptr, PAGE_READONLY, 0, 0, nullptr);
    CloseHandle(hFile);
    if (!hMap) return nullptr;
    const uint8_t* data = (const uint8_t*)MapViewOfFile(hMap, FILE_MAP_READ, 0, 0, 0);
    CloseHandle(hMap);
    if (!data) return nullptr;

    if (memcmp(data, "DDS ", 4) != 0) { UnmapViewOfFile(data); return nullptr; }
    const DDS_HEADER* header = (const DDS_HEADER*)(data + 4);
    const uint8_t* pixels = data + 4 + 124;
    const DDS_HEADER_DXT10* dx10 = nullptr;
    if ((header->ddspf.dwFlags & 0x4) &&
        header->ddspf.dwFourCC == FOURCC('D', 'X', '1', '0')) {
        dx10 = (const DDS_HEADER_DXT10*)pixels;
        pixels += 20;
    }

    BCFmt fmt = detectFormat(header, dx10);
    if (fmt == BC_UNKNOWN) { UnmapViewOfFile(data); return nullptr; }

    int srcW = (int)header->dwWidth;
    int srcH = (int)header->dwHeight;

    float srcAspect = (float)srcW / (float)srcH;
    int actualW, actualH;
    if (srcAspect >= 1.0f) {
        actualW = dstW;
        actualH = max(1, (int)roundf(dstW / srcAspect));
    }
    else {
        actualH = dstH;
        actualW = max(1, (int)roundf(dstH * srcAspect));
    }

    int blocksX = (srcW + 3) / 4;
    int blockBytes = (fmt == BC1 || fmt == BC4) ? 8 : 16;

    uint8_t* output = (uint8_t*)malloc(actualW * actualH * 4);
    if (!output) { UnmapViewOfFile(data); return nullptr; }

    double xr = (double)srcW / actualW;
    double yr = (double)srcH / actualH;

    int lastBlockIdx = -1;

    float bc6h_block[4 * 4 * 3] = {};
    uint8_t bc137_block[4 * 4 * 4] = {};
    uint8_t bc4_block[4 * 4] = {};
    uint8_t bc5_block[4 * 4 * 2] = {};

    for (int dy = 0; dy < actualH; dy++) {
        int srcY = (int)(dy * yr);
        int blockRow = srcY / 4;
        int inY = srcY % 4;

        for (int dx = 0; dx < actualW; dx++) {
            int srcX = (int)(dx * xr);
            int blockCol = srcX / 4;
            int inX = srcX % 4;

            int currentBlockIdx = blockRow * blocksX + blockCol;
            const uint8_t* src = pixels + currentBlockIdx * blockBytes;
            uint8_t* dp = output + (dy * actualW + dx) * 4;

            if (currentBlockIdx != lastBlockIdx) {
                lastBlockIdx = currentBlockIdx;

                switch (fmt) {
                case BC1:  bcdec_bc1(src, bc137_block, 16); break;
                case BC2:  bcdec_bc2(src, bc137_block, 16); break;
                case BC3:  bcdec_bc3(src, bc137_block, 16); break;
                case BC7:  bcdec_bc7(src, bc137_block, 16); break;
                case BC4:  bcdec_bc4(src, bc4_block, 4); break;
                case BC5:  bcdec_bc5(src, bc5_block, 8); break;
                case BC6H_U: case BC6H_S:
                    bcdec_bc6h_float(src, bc6h_block,
                        4 * 3,
                        fmt == BC6H_S ? 1 : 0);
                    break;
                default: break;
                }
            }

            switch (fmt) {
            case BC1: case BC2: case BC3: case BC7: {
                uint8_t* sp = bc137_block + (inY * 4 + inX) * 4;
                dp[0] = sp[0]; dp[1] = sp[1]; dp[2] = sp[2]; dp[3] = sp[3];
                break;
            }
            case BC4: {
                uint8_t v = bc4_block[inY * 4 + inX];
                dp[0] = v; dp[1] = v; dp[2] = v; dp[3] = 255;
                break;
            }
            case BC5: {
                uint8_t* sp = bc5_block + (inY * 4 + inX) * 2;
                dp[0] = sp[0]; dp[1] = sp[1]; dp[2] = 0; dp[3] = 255;
                break;
            }
            case BC6H_U: case BC6H_S: {
                float* sp = bc6h_block + (inY * 4 + inX) * 3;
                float r = sp[0], g = sp[1], b = sp[2];

                r = fmaxf(r, 0.f); g = fmaxf(g, 0.f); b = fmaxf(b, 0.f);

                dp[0] = (uint8_t)(r / (r + 1.f) * 255.f);
                dp[1] = (uint8_t)(g / (g + 1.f) * 255.f);
                dp[2] = (uint8_t)(b / (b + 1.f) * 255.f);
                dp[3] = 255;
                break;
            }
            default:
                dp[0] = dp[1] = dp[2] = 0; dp[3] = 255;
                break;
            }
        }
    }

    UnmapViewOfFile(data);
    *outWidth = actualW;
    *outHeight = actualH;
    return output;
}