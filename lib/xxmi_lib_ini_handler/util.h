#pragma once
#include "util_min.h"

#include <wchar.h>

static int _autoicmp(const wchar_t* s1, const wchar_t* s2)
{
	return _wcsicmp(s1, s2);
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