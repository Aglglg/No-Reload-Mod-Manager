#pragma once
#include <vector>
#include <string>
#include <set>
#include <algorithm>
#include <unordered_set>
#include <unordered_map>
#include <map>

//defined Globals.h, do not include Globals.h, because Globals.h also include this file
struct Globals;

struct ErroredLine
{
	std::wstring file_path;
	int line_index;
	std::wstring trimmed_line;

	std::wstring reason;
};

struct ErroredLineLess
{
	bool operator()(const ErroredLine& a, const ErroredLine& b) const noexcept
	{
		if (a.file_path != b.file_path)
			return a.file_path < b.file_path;

		if (a.line_index != b.line_index)
			return a.line_index < b.line_index;

		return a.trimmed_line < b.trimmed_line;
	}
};


///
///
///


void LoadConfigFile(Globals& G, const std::wstring& ini_file, const std::wstring& base_path);

struct IniLine {
	std::wstring first;
	std::wstring second;

	std::wstring raw_line;

	std::wstring ini_namespace;

	std::wstring full_path;
	int line_index;

	IniLine(std::wstring& key, std::wstring& val, std::wstring& line, const std::wstring& ini_namespace, const std::wstring& full_path, int line_index) :
		first(key),
		second(val),
		raw_line(line),
		ini_namespace(ini_namespace),
		full_path(full_path),
		line_index(line_index)
	{
	}
};

typedef std::vector<IniLine> IniSectionVector;

struct WStringInsensitiveLess {
	bool operator() (const std::wstring& x, const std::wstring& y) const
	{
		return _wcsicmp(x.c_str(), y.c_str()) < 0;
	}
};

struct WStringInsensitiveHash {
	size_t operator()(const std::wstring& s) const
	{
		std::wstring l;
		std::hash<std::wstring> whash;

		l.resize(s.size());
		std::transform(s.begin(), s.end(), l.begin(), ::towlower);
		return whash(l);
	}
};
struct WStringInsensitiveEquality {
	size_t operator()(const std::wstring& x, const std::wstring& y) const
	{
		return _wcsicmp(x.c_str(), y.c_str()) == 0;
	}
};

typedef std::unordered_map<std::wstring, std::wstring, WStringInsensitiveHash, WStringInsensitiveEquality> IniSectionMap;
typedef std::unordered_set<std::wstring, WStringInsensitiveHash, WStringInsensitiveEquality> IniSectionSet;

struct IniSection {
	IniSectionMap kv_map;
	IniSectionVector kv_vec;

	std::wstring ini_namespace;
	std::wstring ini_path;


	std::wstring full_path;
};

typedef std::map<std::wstring, IniSection, WStringInsensitiveLess> IniSections;

int GetIniInt(Globals& G, const wchar_t* section, const wchar_t* key, int def, bool* found, bool warn = true);

bool get_namespaced_section_name_lower(const std::wstring* section, const std::wstring* ini_namespace, std::wstring* ret);
std::wstring get_namespaced_var_name_lower(const std::wstring var, const std::wstring* ini_namespace);
