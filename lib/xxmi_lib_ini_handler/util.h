#pragma once
#include "util_min.h"

#include <wchar.h>
#include <cstring>
#include <stdio.h>
#include <cstdlib>
#include <d3d11.h>

static int _autoicmp(const wchar_t* s1, const wchar_t* s2)
{
	return _wcsicmp(s1, s2);
}

static int _autoicmp(const char* s1, const char* s2)
{
	return _stricmp(s1, s2);
}

template <class T1, class T2>
static T2 lookup_enum_val(struct EnumName_t<T1, T2>* enum_names, T1 name, T2 default_value, bool* found = NULL)
{
	for (; enum_names->name; enum_names++) {
		if (!_autoicmp(name, enum_names->name)) {
			if (found)
				*found = true;
			return enum_names->val;
		}
	}

	if (found)
		*found = false;

	return default_value;
}

template <class T1, class T2>
static T2 lookup_enum_val(struct EnumName_t<T1, T2>* enum_names, T1 name, size_t len, T2 default, bool* found = NULL)
{
	for (; enum_names->name; enum_names++) {
		if (!_wcsnicmp(name, enum_names->name, len)) {
			if (found)
				*found = true;
			return enum_names->val;
		}
	}

	if (found)
		*found = false;

	return default;
}

template <class T1, class T2>
static T1 lookup_enum_name(struct EnumName_t<T1, T2>* enum_names, T2 val)
{
	for (; enum_names->name; enum_names++) {
		if (val == enum_names->val)
			return enum_names->name;
	}

	return NULL;
}

template <class T1, class T2>
static T2 parse_enum_option_string_prefix(struct EnumName_t<T1, T2>* enum_names, T1 option_string, T1* unrecognised)
{
	T1 ptr = option_string, cur;
	T2 ret = (T2)0;
	T2 tmp = T2::INVALID;
	size_t len;

	if (unrecognised)
		*unrecognised = NULL;

	while (*ptr) {
		for (; *ptr == L' '; ptr++) {}

		cur = ptr;

		for (; *ptr && *ptr != L' '; ptr++) {}

		len = ptr - cur;

		if (*ptr)
			ptr++;

		tmp = lookup_enum_val<T1, T2>(enum_names, cur, len, T2::INVALID);
		if (tmp != T2::INVALID) {
			ret |= tmp;
		}
		else {
			if (unrecognised)
				*unrecognised = cur;
			return ret;
		}
	}
	return ret;
}

static bool ParseIniParamName(const wchar_t* name, int* idx)
{
	int ret, len1, len2;
	wchar_t component_chr;
	size_t length = wcslen(name);

	ret = swscanf_s(name, L"%lc%n%u%n", &component_chr, 1, &len1, idx, &len2);

	if (ret == 1 && len1 == length) {
		*idx = 0;
	}
	else if (ret == 2 && len2 == length) {
		//#if MIGOTO_DX == 9
		//		// Added gating for this DX9 specific limitation that we definitely do
		//		// not want to enforce in DX11 as that would break a bunch of mods -DSS
		//		if (*idx >= 225)
		//			return false;
		//#endif // MIGOTO_DX == 9
	}
	else {
		return false;
	}

	switch (towlower(component_chr)) {
	case L'x':
		//*component = &DirectX::XMFLOAT4::x;
		return true;
	case L'y':
		//*component = &DirectX::XMFLOAT4::y;
		return true;
	case L'z':
		//*component = &DirectX::XMFLOAT4::z;
		return true;
	case L'w':
		//*component = &DirectX::XMFLOAT4::w;
		return true;
	}

	return false;
}

// http://msdn.microsoft.com/en-us/library/windows/desktop/bb173059(v=vs.85).aspx
static char* DXGIFormats[] = {
	"UNKNOWN",
	"R32G32B32A32_TYPELESS",
	"R32G32B32A32_FLOAT",
	"R32G32B32A32_UINT",
	"R32G32B32A32_SINT",
	"R32G32B32_TYPELESS",
	"R32G32B32_FLOAT",
	"R32G32B32_UINT",
	"R32G32B32_SINT",
	"R16G16B16A16_TYPELESS",
	"R16G16B16A16_FLOAT",
	"R16G16B16A16_UNORM",
	"R16G16B16A16_UINT",
	"R16G16B16A16_SNORM",
	"R16G16B16A16_SINT",
	"R32G32_TYPELESS",
	"R32G32_FLOAT",
	"R32G32_UINT",
	"R32G32_SINT",
	"R32G8X24_TYPELESS",
	"D32_FLOAT_S8X24_UINT",
	"R32_FLOAT_X8X24_TYPELESS",
	"X32_TYPELESS_G8X24_UINT",
	"R10G10B10A2_TYPELESS",
	"R10G10B10A2_UNORM",
	"R10G10B10A2_UINT",
	"R11G11B10_FLOAT",
	"R8G8B8A8_TYPELESS",
	"R8G8B8A8_UNORM",
	"R8G8B8A8_UNORM_SRGB",
	"R8G8B8A8_UINT",
	"R8G8B8A8_SNORM",
	"R8G8B8A8_SINT",
	"R16G16_TYPELESS",
	"R16G16_FLOAT",
	"R16G16_UNORM",
	"R16G16_UINT",
	"R16G16_SNORM",
	"R16G16_SINT",
	"R32_TYPELESS",
	"D32_FLOAT",
	"R32_FLOAT",
	"R32_UINT",
	"R32_SINT",
	"R24G8_TYPELESS",
	"D24_UNORM_S8_UINT",
	"R24_UNORM_X8_TYPELESS",
	"X24_TYPELESS_G8_UINT",
	"R8G8_TYPELESS",
	"R8G8_UNORM",
	"R8G8_UINT",
	"R8G8_SNORM",
	"R8G8_SINT",
	"R16_TYPELESS",
	"R16_FLOAT",
	"D16_UNORM",
	"R16_UNORM",
	"R16_UINT",
	"R16_SNORM",
	"R16_SINT",
	"R8_TYPELESS",
	"R8_UNORM",
	"R8_UINT",
	"R8_SNORM",
	"R8_SINT",
	"A8_UNORM",
	"R1_UNORM",
	"R9G9B9E5_SHAREDEXP",
	"R8G8_B8G8_UNORM",
	"G8R8_G8B8_UNORM",
	"BC1_TYPELESS",
	"BC1_UNORM",
	"BC1_UNORM_SRGB",
	"BC2_TYPELESS",
	"BC2_UNORM",
	"BC2_UNORM_SRGB",
	"BC3_TYPELESS",
	"BC3_UNORM",
	"BC3_UNORM_SRGB",
	"BC4_TYPELESS",
	"BC4_UNORM",
	"BC4_SNORM",
	"BC5_TYPELESS",
	"BC5_UNORM",
	"BC5_SNORM",
	"B5G6R5_UNORM",
	"B5G5R5A1_UNORM",
	"B8G8R8A8_UNORM",
	"B8G8R8X8_UNORM",
	"R10G10B10_XR_BIAS_A2_UNORM",
	"B8G8R8A8_TYPELESS",
	"B8G8R8A8_UNORM_SRGB",
	"B8G8R8X8_TYPELESS",
	"B8G8R8X8_UNORM_SRGB",
	"BC6H_TYPELESS",
	"BC6H_UF16",
	"BC6H_SF16",
	"BC7_TYPELESS",
	"BC7_UNORM",
	"BC7_UNORM_SRGB",
	"AYUV",
	"Y410",
	"Y416",
	"NV12",
	"P010",
	"P016",
	"420_OPAQUE",
	"YUY2",
	"Y210",
	"Y216",
	"NV11",
	"AI44",
	"IA44",
	"P8",
	"A8P8",
	"B4G4R4A4_UNORM"
};

static DXGI_FORMAT ParseFormatString(const char* fmt, bool allow_numeric_format)
{
	size_t num_formats = sizeof(DXGIFormats) / sizeof(DXGIFormats[0]);
	unsigned format;
	int nargs, end;

	if (allow_numeric_format) {
		// Try parsing format string as decimal:
		nargs = sscanf_s(fmt, "%u%n", &format, &end);
		if (nargs == 1 && end == strlen(fmt))
			return (DXGI_FORMAT)format;
	}

	if (!_strnicmp(fmt, "DXGI_FORMAT_", 12))
		fmt += 12;

	// Look up format string:
	for (format = 0; format < num_formats; format++) {
		if (!_strnicmp(fmt, DXGIFormats[format], 30))
			return (DXGI_FORMAT)format;
	}

	// UNKNOWN/0 is a valid format (e.g. for structured buffers), so return
	// -1 cast to a DXGI_FORMAT to signify an error:
	return (DXGI_FORMAT)-1;
}

static DXGI_FORMAT ParseFormatString(const wchar_t* wfmt, bool allow_numeric_format)
{
	char afmt[42];
	size_t converted;

	wcstombs_s(&converted, afmt, sizeof(afmt), wfmt, _TRUNCATE);

	return ParseFormatString(afmt, allow_numeric_format);
}