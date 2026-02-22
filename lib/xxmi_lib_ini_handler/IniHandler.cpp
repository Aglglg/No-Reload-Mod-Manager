#include "Globals.h"

#include "IniHandler.h"
#include "CommandList.h"
#include "ResourceHash.h"
#include <algorithm>
#include <fstream>
#include <sstream>
#include <codecvt>
#include <windows.h>
#include <unordered_set>
#include <pcre2.h>
#include <vector>
#include <set>
#include <string>
#include <cwctype>

struct Section {
	wchar_t* section;
	bool prefix;
};
static Section CommandListSections[] = {
	{L"TextureOverride", true},
	{L"CommandList", true},
	{L"Constants", false},
	{L"Present", false},
	{L"ShaderOverride", true},
	{L"CustomShader", true},
	{L"ShaderRegex", true},
	{L"BuiltInCommandList", true},
	{L"BuiltInCustomShader", true},
	{L"ClearRenderTargetView", false},
	{L"ClearDepthStencilView", false},
	{L"ClearUnorderedAccessViewUint", false},
	{L"ClearUnorderedAccessViewFloat", false},
};
static Section RegularSections[] = {
	{L"Resource", true},
	{L"Key", true},
	{L"Include", true},
	{L"Preset", true},
	{L"Hunting", false},
	{L"Logging", false},
	{L"System", false},
	{L"Device", false},
	{L"Rendering", false},
	{L"Loader", false},
	{L"Profile", false},
	{L"Stereo", false},
	{L"ConvergenceMap", false},
};
static Section AllowLinesWithoutEquals[] = {
	{L"ShaderRegex", true},
	{L"Profile", false},
};

static bool whitelisted_duplicate_key(const wchar_t* section, const wchar_t* key)
{
	if (!_wcsnicmp(section, L"key", 3)) {
		if (!_wcsicmp(key, L"key") || !_wcsicmp(key, L"back") || !_wcsicmp(key, L"condition"))
			return true;
	}

	if (!_wcsicmp(section, L"include"))
		return true;

	return false;
}

static bool SectionInList(const wchar_t* section, Section section_list[], int list_size)
{
	size_t len;
	int i;

	for (i = 0; i < list_size; i++) {
		if (section_list[i].prefix) {
			len = wcslen(section_list[i].section);
			if (!_wcsnicmp(section, section_list[i].section, len))
				return true;
		}
		else {
			if (!_wcsicmp(section, section_list[i].section))
				return true;
		}
	}

	return false;
}

static bool IsCommandListSection(const wchar_t* section)
{
	return SectionInList(section, CommandListSections, ARRAYSIZE(CommandListSections));
}

static bool IsRegularSection(const wchar_t* section)
{
	return SectionInList(section, RegularSections, ARRAYSIZE(RegularSections));
}

static bool DoesSectionAllowLinesWithoutEquals(const wchar_t* section)
{
	return SectionInList(section, AllowLinesWithoutEquals, ARRAYSIZE(AllowLinesWithoutEquals))
		|| IsCommandListSection(section);
}

static const wchar_t* SectionPrefixFromList(const wchar_t* section, Section section_list[], int list_size)
{
	size_t len;
	int i;

	for (i = 0; i < list_size; i++) {
		if (section_list[i].prefix) {
			len = wcslen(section_list[i].section);
			if (!_wcsnicmp(section, section_list[i].section, len))
				return section_list[i].section;
		}
	}

	return false;
}

static const wchar_t* SectionPrefix(const wchar_t* section)
{
	const wchar_t* ret;

	ret = SectionPrefixFromList(section, CommandListSections, ARRAYSIZE(CommandListSections));
	if (!ret)
		ret = SectionPrefixFromList(section, RegularSections, ARRAYSIZE(RegularSections));
	return ret;
}

static IniSections::iterator prefix_upper_bound(IniSections& sections, std::wstring& prefix)
{
	IniSections::iterator i;

	for (i = sections.lower_bound(prefix); i != sections.end(); i++) {
		if (_wcsnicmp(i->first.c_str(), prefix.c_str(), prefix.length()) > 0)
			return i;
	}

	return sections.end();
}

static bool get_namespaced_section_name(const std::wstring* section, const std::wstring* ini_namespace, std::wstring* ret)
{
	const wchar_t* section_prefix = SectionPrefix(section->c_str());
	if (!section_prefix)
		return false;

	*ret = std::wstring(section_prefix) + std::wstring(L"\\") + *ini_namespace +
		std::wstring(L"\\") + section->substr(wcslen(section_prefix));
	return true;
}

bool get_namespaced_section_name_lower(const std::wstring* section, const std::wstring* ini_namespace, std::wstring* ret)
{
	bool rc;

	rc = get_namespaced_section_name(section, ini_namespace, ret);
	if (rc)
		std::transform(ret->begin(), ret->end(), ret->begin(), ::towlower);
	return rc;
}

std::wstring get_namespaced_var_name_lower(const std::wstring var, const std::wstring* ini_namespace)
{
	std::wstring ret = std::wstring(L"$\\") + *ini_namespace + std::wstring(L"\\") + var.substr(1);
	std::transform(ret.begin(), ret.end(), ret.begin(), ::towlower);
	return ret;
}

static bool _get_section_namespace(IniSections* custom_ini_sections, const wchar_t* section, std::wstring* ret)
{
	try {
		*ret = custom_ini_sections->at(std::wstring(section)).ini_namespace;
	}
	catch (std::out_of_range) {
		return false;
	}
	return (!ret->empty());
}

bool get_section_namespace(Globals& G, const wchar_t* section, std::wstring* ret)
{
	return _get_section_namespace(&G.ini_sections, section, ret);
}

static bool _get_section_path(IniSections* custom_ini_sections, const wchar_t* section, std::wstring* ret)
{
	IniSection* entry;

	try {
		entry = &custom_ini_sections->at(std::wstring(section));
	}
	catch (std::out_of_range) {
		return false;
	}

	if (entry->ini_path.empty())
		*ret = entry->ini_namespace;
	else
		*ret = entry->ini_path;

	return (!ret->empty());
}

static size_t get_section_namespace_endpos(Globals& G, const wchar_t* section)
{
	const wchar_t* section_prefix;
	std::wstring ini_namespace;

	section_prefix = SectionPrefix(section);
	if (!section_prefix)
		return 0;

	if (!get_section_namespace(G, section, &ini_namespace))
		return wcslen(section_prefix);

	return wcslen(section_prefix) + ini_namespace.length() + 2;
}

static bool _get_namespaced_section_path(IniSections* custom_ini_sections, const wchar_t* section, std::wstring* ret)
{
	std::wstring::size_type pos;

	if (!_get_section_path(custom_ini_sections, section, ret))
		return false;

	pos = ret->rfind(L"\\");
	if (pos != ret->npos)
		ret->resize(pos + 1);
	else
		*ret = L"";
	return true;
}

static void ParseIniSectionLine(Globals& G, std::wstring* wline, std::wstring* section,
	int* warn_duplicates, bool* warn_lines_without_equals,
	IniSectionVector** section_vector, const std::wstring* ini_namespace,
	const std::wstring* ini_path, const std::wstring& full_path, int line_index)
{
	bool allow_duplicate_sections = false;
	size_t first, last;
	bool inserted;
	bool namespaced_section = false;

	*warn_duplicates = 1;
	*warn_lines_without_equals = true;

	last = wline->find(L']');
	if (last == wline->npos)
		last = wline->length();

	first = wline->find_first_not_of(L" \t", 1);

	//In case line is "[ " or empty section name without closing bracket, in the original xxmi lib, it crash entirely. XXMI BUG

	if (first == wline->npos)
	{
		G.errored_lines.insert(ErroredLine{ full_path, line_index, wline->c_str(), L"CRASH LINE"});
		first = 0;
	}

	last = wline->find_last_not_of(L" \t", last - 1);
	*section = wline->substr(first, last - first + 1);

	if (!ini_namespace->empty()) {
		if (get_namespaced_section_name(section, ini_namespace, section)) {
			namespaced_section = true;
		}
		else {
			allow_duplicate_sections = true;
			*warn_duplicates = 2;
		}
	}

	inserted = G.ini_sections.emplace(*section, IniSection{}).second;
	if (!inserted && !allow_duplicate_sections) {
		//wprintf(L"[WARNING] Duplicate section found - [%ls]\n", section->c_str());

		//If duplicate section on known lib namespaces, that means user having multiple known libraries
		if (ini_namespace != nullptr)
		{
			auto item = G.known_lib_namespaces.find(*ini_namespace);
			if (item != G.known_lib_namespaces.end()) {

				//The current file that have same namespace and same section name & only if not added yet to avoid multiple warnings for same file
				auto dup_path1 = G.already_known_duplicate_lib_path.find(full_path);
				if (dup_path1 == G.already_known_duplicate_lib_path.end())
				{
					G.already_known_duplicate_lib_path.insert(full_path);
					G.errored_lines.insert(ErroredLine{
					full_path,
					line_index,
					wline->c_str(),
					L"DUPLICATE LIB:" + *ini_namespace
						});
				}
				

				//The already registered section & only if not added yet to avoid multiple warnings for same file
				auto dup_path2 = G.already_known_duplicate_lib_path.find(G.ini_sections[*section].full_path);
				if (dup_path2 == G.already_known_duplicate_lib_path.end())
				{
					G.already_known_duplicate_lib_path.insert(G.ini_sections[*section].full_path);
					G.errored_lines.insert(ErroredLine{
					G.ini_sections[*section].full_path,
					line_index,
					wline->c_str(),
					L"DUPLICATE LIB:" + *ini_namespace
						});
				}
			}
		}

		section->clear();
		*section_vector = NULL;
		return;
	}

	*section_vector = &G.ini_sections[*section].kv_vec;
	G.ini_sections[*section].full_path = full_path;

	if (namespaced_section) {
		G.ini_sections[*section].ini_namespace = *ini_namespace;
		if (*ini_path != *ini_namespace)
			G.ini_sections[*section].ini_path = *ini_path;
	}

	if (IsCommandListSection(section->c_str())) {
		if (*warn_duplicates == 1)
			*warn_duplicates = 0;
	}
	else if (!IsRegularSection(section->c_str())) {
		//wprintf(L"[WARNING] Unknown section type - [%ls] @ [%ls]\n", section->c_str(), ini_namespace->c_str());
	}

	if (DoesSectionAllowLinesWithoutEquals(section->c_str()))
		*warn_lines_without_equals = false;
}

bool check_include_condition(Globals& G, std::wstring* val, const std::wstring* ini_namespace, const std::wstring& full_path, int line_index, const std::wstring& ini_line)
{
	CommandListExpression condition;
	std::wstring sbuf(*val);
	float ret;

	std::transform(sbuf.begin(), sbuf.end(), sbuf.begin(), ::towlower);

	//In case line is "condition = " or empty expression, in the original xxmi lib, it crash entirely. XXMI BUG

	if (sbuf.empty())
	{
		G.errored_lines.insert(ErroredLine{ full_path, line_index, ini_line, L"CRASH LINE" });
		return true;
	}

	if (!condition.parse(G, &sbuf, ini_namespace, NULL)) {
		//wprintf(L"[WARNING] Unable to parse include condition: %ls - [%ls]\n", val->c_str(), ini_namespace->c_str());
		return false;
	}

	if (!condition.static_evaluate(&ret)) {
		//wprintf(L"[WARNING] Include condition could not be statically evaluated: %ls - [%ls]\n", val->c_str(), ini_namespace->c_str());
		return false;
	}

	//if (!ret)
		//printf("        condition = false, skipping \"%S\"\n", ini_namespace->c_str());

	return !!ret;
}

static bool ParseIniPreamble(Globals& G, std::wstring* wline, std::wstring* ini_namespace, const std::wstring& full_path, int line_index)
{
	size_t first, last, delim;
	std::wstring key, val;

	//printf("      %S\n", wline->c_str());

	delim = wline->find(L"=");
	if (delim != wline->npos) {
		last = wline->find_last_not_of(L" \t", delim - 1);
		key = wline->substr(0, last + 1);
		first = wline->find_first_not_of(L" \t", delim + 1);
		if (first != wline->npos)
			val = wline->substr(first);

		if (!_wcsicmp(key.c_str(), L"condition")) {
			return check_include_condition(G, &val, ini_namespace, full_path, line_index, wline->c_str());
		}

		if (!_wcsicmp(key.c_str(), L"namespace")) {
			//printf("        Renaming namespace \"%S\" -> \"%S\"\n", ini_namespace->c_str(), val.c_str());
			*ini_namespace = val;
			return true;
		}
	}

	//wprintf(L"[WARNING] Entry outside of section: %ls - [%ls]\n", wline->c_str(), ini_namespace->c_str());
	return true;
}

static void ParseIniKeyValLine(Globals& G, std::wstring* wline, std::wstring* section,
	int warn_duplicates, bool warn_lines_without_equals,
	IniSectionVector* section_vector, const std::wstring* ini_namespace, const std::wstring* full_path, int line_index)
{
	size_t first, last, delim;
	std::wstring key, val;
	bool inserted;

	if (section->empty() || section_vector == NULL) {
		//wprintf(L"[WARNING] Entry outside of section: %ls - [%ls]\n", wline->c_str(), ini_namespace->c_str());
		return;
	}

	delim = wline->find(L"=");
	if (delim != wline->npos) {
		last = wline->find_last_not_of(L" \t", delim - 1);
		key = wline->substr(0, last + 1);
		first = wline->find_first_not_of(L" \t", delim + 1);
		if (first != wline->npos)
			val = wline->substr(first);
		else {
			//wprintf(L"[WARNING] No value found for: \"%ls\" - [%ls] @ [%ls]\n", wline->c_str(), section->c_str(), ini_namespace->c_str());
			return;
		}

		if (warn_duplicates == 2) {
			G.ini_sections.at(*section).kv_map[key] = val;
		}
		else {
			inserted = G.ini_sections.at(*section).kv_map.emplace(key, val).second;
			if ((warn_duplicates == 1) && !inserted && !whitelisted_duplicate_key(section->c_str(), key.c_str())) {
				//wprintf(L"[WARNING] Duplicate key found: %ls - [%ls] @ [%ls]\n", wline->c_str(), section->c_str(), ini_namespace->c_str());
			}
		}
	}
	else {
		if (warn_lines_without_equals) {
			//wprintf(L"[WARNING] Malformed line: \"%ls\" - [%ls] @ [%ls]\n", wline->c_str(), section->c_str(), ini_namespace->c_str());
			return;
		}
	}

	section_vector->emplace_back(key, val, *wline, *ini_namespace, *full_path, line_index);
}

static void ParseIniBuffer(Globals& G, const char* data, size_t size, const std::wstring* _ini_namespace, std::wstring& full_path)
{
	// Use a stringstream to iterate lines without disk I/O
	std::string content(data, size);
	std::istringstream stream(content);
	std::string line;

	// Converter for UTF8 to UTF16
	std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;

	std::wstring wline, section, ini_path;
	IniSectionVector* section_vector = NULL;
	int warn_duplicates = 1;
	bool warn_lines_without_equals = true;
	std::wstring ini_namespace = _ini_namespace ? *_ini_namespace : L"";
	ini_path = ini_namespace;
	bool preamble = true;
	int line_index = 0;

	while (std::getline(stream, line)) {
		struct LineIndexGuard {
			int& i;
			~LineIndexGuard() { ++i; }
		} guard{ line_index };

		// Convert only the current line to wstring
		try {
			wline = converter.from_bytes(line);
		}
		catch (...) {
			// Fallback for malformed UTF8 characters to prevent crash
			continue;
		}

		size_t first = wline.find_first_not_of(L" \t\r\n"); // Added \r\n for safety
		size_t last = wline.find_last_not_of(L" \t\r\n");

		if (first == wline.npos) continue;
		wline = wline.substr(first, last - first + 1);

		if (wline[0] == L';') {
			if (wline.size() >= 3 && wline[0] == L';' && wline[1] == L'-' && wline[2] == L';') {
				size_t pos = 3;
				while (pos < wline.size() && (wline[pos] == L' ' || wline[pos] == L'\t')) {
					++pos;
				}
				wline.erase(0, pos);
				if (wline.find_first_not_of(L" \t") == std::wstring::npos) continue;
			}
			else {
				continue;
			}
		}

		if (wline[0] == L'[') {
			preamble = false;
			ParseIniSectionLine(G, &wline, &section, &warn_duplicates, &warn_lines_without_equals,
				&section_vector, &ini_namespace, &ini_path, full_path, line_index);
			continue;
		}

		if (preamble) {
			if (!ParseIniPreamble(G, &wline, &ini_namespace, full_path, line_index))
				return;
			continue;
		}

		ParseIniKeyValLine(G, &wline, &section, warn_duplicates, warn_lines_without_equals,
			section_vector, &ini_namespace, &full_path, line_index);
	}
}

static void ParseNamespacedIniFile(Globals& G, const wchar_t* ini, const std::wstring* ini_namespace)
{
	// Open in binary mode to prevent CRLF to LF translation
	std::ifstream f(ini, std::ios::binary | std::ios::ate);
	if (!f) return;

	std::streamsize size = f.tellg();
	f.seekg(0, std::ios::beg);

	std::string buffer;
	buffer.resize(static_cast<size_t>(size));
	if (!f.read(&buffer[0], size)) return;

	// Remove UTF-8 BOM if present
	size_t offset = 0;
	if (size >= 3 && (unsigned char)buffer[0] == 0xEF &&
		(unsigned char)buffer[1] == 0xBB &&
		(unsigned char)buffer[2] == 0xBF) {
		offset = 3;
	}

	std::wstring full_path(ini);
	ParseIniBuffer(G, buffer.data() + offset, size - offset, ini_namespace, full_path);
}

static void ParseIniFile(Globals& G, const wchar_t* ini)
{
	G.ini_sections.clear();

	return ParseNamespacedIniFile(G, ini, NULL);
}

static pcre2_code* glob_to_regex(std::wstring& pattern)
{
	PCRE2_UCHAR* converted = NULL;
	PCRE2_SIZE blength = 0;
	pcre2_code* regex = NULL;
	std::string apattern(pattern.begin(), pattern.end());
	PCRE2_SIZE err_off;
	int err;

	if (pcre2_pattern_convert((PCRE2_SPTR)apattern.c_str(),
		apattern.length(), PCRE2_CONVERT_GLOB,
		&converted, &blength, NULL)) {
		//printf("Bad pattern: exclude_recursive=%S\n", pattern.c_str());
		return NULL;
	}

	regex = pcre2_compile(converted, blength, PCRE2_CASELESS, &err, &err_off, NULL);
	//if (!regex)
		//printf("exclude_recursive PCRE2 regex compilation failed");

	pcre2_converted_pattern_free(converted);
	return regex;
}

static std::vector<pcre2_code*> globbing_vector_to_regex(std::vector<std::wstring>& globbing_patterns)
{
	std::vector<pcre2_code*> ret;
	pcre2_code* regex;

	for (std::wstring pattern : globbing_patterns) {
		regex = glob_to_regex(pattern);
		if (regex)
			ret.push_back(regex);
	}

	return ret;
}

static void free_globbing_vector(std::vector<pcre2_code*>& patterns) {
	for (pcre2_code* regex : patterns)
		pcre2_code_free(regex);
}

static std::string to_utf8(const std::wstring& wstr) {
	if (wstr.empty())
		return std::string();
	int len = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, NULL, 0, NULL, NULL);
	if (len == 0)
		return std::string();
	std::string utf8_str(len, 0);
	WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &utf8_str[0], len, NULL, NULL);
	return utf8_str;
}

static bool matches_globbing_vector(wchar_t* filename, std::vector<pcre2_code*>& patterns) {
	std::string afilename;
	pcre2_match_data* md;
	int rc;

	afilename = to_utf8(filename);

	for (pcre2_code* regex : patterns) {
		md = pcre2_match_data_create_from_pattern(regex, NULL);
		rc = pcre2_match(regex, (PCRE2_SPTR)afilename.c_str(), PCRE2_ZERO_TERMINATED, 0, 0, md, NULL);
		pcre2_match_data_free(md);
		if (rc > 0)
			return true;
	}

	return false;
}

static void ParseIniFilesRecursive(Globals& G, wchar_t* migoto_path, const std::wstring& rel_path, std::vector<pcre2_code*>& exclude)
{
	std::set<std::wstring, WStringInsensitiveLess> ini_files, directories;
	WIN32_FIND_DATA find_data;
	HANDLE hFind;
	std::wstring search_path, ini_path, ini_namespace;

	search_path = std::wstring(migoto_path) + rel_path + L"\\*";
	//printf("    Searching \"%S\"\n", search_path.c_str());

	hFind = FindFirstFile(search_path.c_str(), &find_data);
	if (hFind == INVALID_HANDLE_VALUE) {
		//printf("    Recursive include path \"%S\" not found\n", search_path.c_str());
		return;
	}

	do {
		if (matches_globbing_vector(find_data.cFileName, exclude)) {
			//printf("    Excluding \"%S\"\n", find_data.cFileName);
			continue;
		}

		if (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
			if (wcscmp(find_data.cFileName, L".") && wcscmp(find_data.cFileName, L".."))
				directories.insert(std::wstring(find_data.cFileName));
		}
		else if (!wcscmp(find_data.cFileName + wcslen(find_data.cFileName) - 4, L".ini")) {
			ini_files.insert(std::wstring(find_data.cFileName));
		}
	} while (FindNextFile(hFind, &find_data));

	FindClose(hFind);

	for (std::wstring i : ini_files) {
		ini_namespace = rel_path + std::wstring(L"\\") + i;
		ini_path = std::wstring(migoto_path) + ini_namespace;
		//printf("    Processing \"%S\"\n", ini_path.c_str());
		ParseNamespacedIniFile(G, ini_path.c_str(), &ini_namespace);
	}

	for (std::wstring i : directories) {
		ini_namespace = rel_path + std::wstring(L"\\") + i;
		ParseIniFilesRecursive(G, migoto_path, ini_namespace, exclude);
	}
}

static bool IniHasKey(Globals& G, const wchar_t* section, const wchar_t* key)
{
	try {
		return !!G.ini_sections.at(section).kv_map.count(key);
	}
	catch (std::out_of_range) {
		return false;
	}
}

static void _GetIniSection(IniSections* custom_ini_sections, IniSectionVector** key_vals, const wchar_t* section)
{
	static IniSectionVector empty_section_vector;

	try {
		*key_vals = &custom_ini_sections->at(section).kv_vec;
	}
	catch (std::out_of_range) {
		//printf("GetIniSection() called on a section not in the ini_sections map: %S\n", section);
		*key_vals = &empty_section_vector;
	}
}

void GetIniSection(Globals& G, IniSectionVector** key_vals, const wchar_t* section)
{
	return _GetIniSection(&G.ini_sections, key_vals, section);
}

int GetIniString(Globals& G, const wchar_t* section, const wchar_t* key, const wchar_t* def,
	wchar_t* ret, unsigned size)
{
	int rc;
	bool found = false;

	auto ini_section = G.ini_sections.find(section);

	if (ini_section != G.ini_sections.end()) {
		auto& kv_map = ini_section->second.kv_map;
		auto kv_pair = kv_map.find(key);
		if (kv_pair != kv_map.end()) {
			const std::wstring& val = kv_pair->second;
			if (wcsncpy_s(ret, size, val.c_str(), _TRUNCATE)) {
				//IniWarningW(L"\"%ls=%ls\" too long\n - [%ls]\n", key, val.c_str(), section);
				rc = size - 1;
			}
			else {
				rc = (int)wcslen(ret);
			}
			found = true;
		}
	}
	if (!found) {
		if (def) {
			if (wcscpy_s(ret, size, def)) {
				//DoubleBeepExit();
			}
			else
				rc = (int)wcslen(ret);
		}
		else {
			ret[0] = L'\0';
			rc = 0;
		}
	}

	return rc;
}

bool GetIniString(Globals& G, const wchar_t* section, const wchar_t* key, const wchar_t* def, std::string* ret)
{
	std::wstring wret;
	bool found = false;

	if (!ret) {
		//printf("BUG: Misuse of GetIniString()\n");
		//DoubleBeepExit();
	}

	auto ini_section = G.ini_sections.find(section);
	if (ini_section != G.ini_sections.end()) {
		auto& kv_map = ini_section->second.kv_map;
		auto kv_pair = kv_map.find(key);
		if (kv_pair != kv_map.end()) {
			wret = kv_pair->second;
			found = true;
		}
	}
	if (!found) {
		if (def)
			wret = def;
		else
			wret = L"";
	}

	*ret = std::string(wret.begin(), wret.end());
	return found;
}

static std::vector<std::wstring> GetIniStringMultipleKeys(Globals& G, const wchar_t* section, const wchar_t* key)
{
	std::vector<std::wstring> ret;
	IniSectionVector* sv = NULL;
	IniSectionVector::iterator entry;

	GetIniSection(G, &sv, section);
	for (entry = sv->begin(); entry < sv->end(); entry++) {
		if (!_wcsicmp(key, entry->first.c_str()))
			ret.push_back(entry->second);
	}

	return ret;
}

int GetIniStringAndLog(Globals& G, const wchar_t* section, const wchar_t* key,
	const wchar_t* def, wchar_t* ret, unsigned size)
{
	int rc = GetIniString(G, section, key, def, ret, size);

	//if (rc)
		//LogInfo("  %S=%S\n", key, ret);

	return rc;
}
static bool GetIniStringAndLog(Globals& G, const wchar_t* section, const wchar_t* key,
	const wchar_t* def, std::string* ret)
{
	bool rc = GetIniString(G, section, key, def, ret);

	//if (rc)
		//LogInfo("  %S=%s\n", key, ret->c_str());

	return rc;
}

int GetIniInt(Globals& G, const wchar_t* section, const wchar_t* key, int def, bool* found, bool warn)
{
	wchar_t val[32];
	int ret = def;
	int len;

	if (found)
		*found = false;

	if (GetIniString(G, section, key, 0, val, 32)) {
		if (swscanf_s(val, L"%d%n", &ret, &len) != 1 || len != wcslen(val)) {
			if (warn) {
				std::wstring ini_namespace = G.ini_sections[section].ini_namespace;
				if (ini_namespace.empty()) {
					ini_namespace = L"d3dx.ini";
				}
				//wprintf(L"WARNING: Integer parse error: %ls=%ls\n - [%ls] @ [%ls]\n", key, val, section, ini_namespace.c_str());
			}
			ret = def;
		}
		else {
			if (found)
				*found = true;
			//LogInfo("  %S=%d\n", key, ret);
		}
	}

	return ret;
}

static UINT64 GetIniHash(Globals& G, const wchar_t* section, const wchar_t* key, UINT64 def, bool* found)
{
	std::string val;
	UINT64 ret = def;
	int len;

	if (found)
		*found = false;

	if (GetIniString(G, section, key, NULL, &val)) {
		if (sscanf_s(val.c_str(), "%16llx%n", &ret, &len) != 1 || len != val.length()) {
			std::wstring ini_namespace = G.ini_sections[section].ini_namespace;
			//wprintf(L"[WARNING] Hash parse error: %ls=%S - [%ls] @ [%ls]\n", key, val.c_str(), section, ini_namespace.c_str());
			ret = def;
		}
		else {
			if (found)
				*found = true;
			//printf("  %S=%016llx\n", key, ret);
		}
	}

	return ret;
}

static void GetUserConfigPath(Globals& G, const wchar_t* migoto_path)
{
	std::string tmp;
	std::wstring rel_path;

	GetIniString(G, L"Include", L"user_config", L"d3dx_user.ini", &tmp);
	rel_path = std::wstring(tmp.begin(), tmp.end());
	if (tmp[1] != ':' && tmp[0] != '\\')
		G.user_config = std::wstring(migoto_path) + rel_path;
	else
		G.user_config = rel_path;
}

static void ParseIncludedIniFiles(Globals& G, const std::wstring& base_path)
{
	IniSections include_sections;
	IniSections::iterator lower, upper, i;
	const wchar_t* section_id;
	IniSectionVector* section = NULL;
	IniSectionVector::iterator entry;
	std::wstring* key, * val;
	std::unordered_set<std::wstring> seen;
	std::wstring namespace_path, rel_path, ini_path;
	std::vector<pcre2_code*> exclude;
	DWORD attrib;

	wchar_t migoto_path[MAX_PATH] = {};
	wcsncpy_s(migoto_path, MAX_PATH, base_path.c_str(), _TRUNCATE);


	GetUserConfigPath(G, migoto_path);

	exclude = globbing_vector_to_regex(GetIniStringMultipleKeys(G, L"Include", L"exclude_recursive"));

	do {
		lower = G.ini_sections.lower_bound(std::wstring(L"Include"));
		upper = prefix_upper_bound(G.ini_sections, std::wstring(L"Include"));
		include_sections.clear();
		include_sections.insert(lower, upper);
		G.ini_sections.erase(lower, upper);

		for (i = include_sections.begin(); i != include_sections.end(); i++) {
			section_id = i->first.c_str();
			//printf("[%S]\n", section_id);

			_get_namespaced_section_path(&include_sections, i->first.c_str(), &namespace_path);

			_GetIniSection(&include_sections, &section, section_id);
			for (entry = section->begin(); entry < section->end(); entry++) {
				key = &entry->first;
				val = &entry->second;
				//printf("  %S=%S\n", key->c_str(), val->c_str());

				rel_path = namespace_path + *val;

				if (seen.count(rel_path)) {
					//wprintf(L"[WARNING] File included multiple times: %ls - [%ls]\n", rel_path.c_str(), section_id);
					continue;
				}
				seen.insert(rel_path);

				if (!wcscmp(key->c_str(), L"include")) {
					ini_path = std::wstring(migoto_path) + rel_path;
					ParseNamespacedIniFile(G, ini_path.c_str(), &rel_path);
				}
				else if (!wcscmp(key->c_str(), L"include_recursive")) {
					ParseIniFilesRecursive(G, migoto_path, rel_path, exclude);
				}
				else if (!wcscmp(key->c_str(), L"exclude_recursive")) {
				}
				else if (!wcscmp(key->c_str(), L"user_config")) {
				}
				else {
					//wprintf(L"[WARNING] Unrecognised entry [Include] sections: %ls=%ls - [%ls] @ [%ls]\n", key->c_str(), val->c_str(), section_id, namespace_path.c_str());
				}
			}
		}
	} while (!include_sections.empty());

	free_globbing_vector(exclude);

	attrib = GetFileAttributes(G.user_config.c_str());
	if (attrib != INVALID_FILE_ATTRIBUTES)
		ParseNamespacedIniFile(G, G.user_config.c_str(), &G.user_config);
}

static void ParseResourceSections(Globals& G)
{
	IniSections::iterator lower, upper, i;
	std::wstring resource_id;
	CustomResource* custom_resource;
	std::wstring namespace_path;

	G.customResources.clear();

	lower = G.ini_sections.lower_bound(std::wstring(L"Resource"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"Resource"));
	for (i = lower; i != upper; i++) {
		//wprintf(L" [%s]\n", i->first.c_str());

		resource_id = i->first;
		std::transform(resource_id.begin(), resource_id.end(), resource_id.begin(), ::towlower);

		custom_resource = &G.customResources[resource_id];
		custom_resource->name = i->first;
	}
}

static bool ParseCommandListLine(Globals& G, const wchar_t* ini_section,
	const wchar_t* lhs, std::wstring* rhs, std::wstring* raw_line,
	CommandList* command_list,
	CommandList* explicit_command_list,
	CommandList* pre_command_list,
	CommandList* post_command_list,
	const std::wstring* ini_namespace, const std::wstring& full_path, int line_index)
{
	// We only care about FlowControl & VariableAssignment
	// and GeneralCommand to check "run" commandlist

	if (ParseCommandListGeneralCommands(G, lhs, rhs, ini_namespace, full_path, line_index, raw_line->c_str()))
		return true;

	/*if (ParseCommandListIniParamOverride(ini_section, lhs, rhs, command_list, ini_namespace))
		return true;*/

	if (ParseCommandListVariableAssignment(G, ini_section, lhs, rhs, raw_line, command_list, pre_command_list, post_command_list, ini_namespace))
		return true;

	/*if (ParseCommandListResourceCopyDirective(ini_section, lhs, rhs, command_list, ini_namespace))
		return true;*/

	if (raw_line && !explicit_command_list &&
		ParseCommandListFlowControl(G, ini_section, raw_line, pre_command_list, post_command_list, ini_namespace, full_path, line_index))
		return true;

	return false;
}

static void ParseCommandList(Globals& G, const wchar_t* id,
	CommandList* pre_command_list, CommandList* post_command_list,
	wchar_t* whitelist[], bool register_command_lists = true)
{
	IniSectionVector* section = NULL;
	IniSectionVector::iterator entry;
	std::wstring* key, * val, * raw_line;
	const wchar_t* key_ptr;
	CommandList* command_list, * explicit_command_list;
	IniSectionSet whitelisted_keys;
	CommandListScope scope;
	int i;

	if (!IsCommandListSection(id)) {
		//wprintf(L"BUG: ParseCommandList() called on a section not in the CommandListSections list: %s\n", id);
		//DoubleBeepExit();
	}

	scope.emplace_front();

	//printf("Registering command list: %S\n", id);
	pre_command_list->ini_section = id;
	pre_command_list->post = false;
	pre_command_list->scope = &scope;
	if (register_command_lists)
		G.registered_command_lists.push_back(pre_command_list);
	if (post_command_list) {
		post_command_list->ini_section = id;
		post_command_list->post = true;
		post_command_list->scope = &scope;
		if (register_command_lists)
			G.registered_command_lists.push_back(post_command_list);
	}

	GetIniSection(G, &section, id);
	for (entry = section->begin(); entry < section->end(); entry++) {
		key = &entry->first;
		val = &entry->second;
		raw_line = &entry->raw_line;

		std::transform(key->begin(), key->end(), key->begin(), ::towlower);
		std::transform(val->begin(), val->end(), val->begin(), ::towlower);
		std::transform(raw_line->begin(), raw_line->end(), raw_line->begin(), ::towlower);

		if (whitelist) {
			for (i = 0; whitelist[i]; i++) {
				if (!key->compare(whitelist[i]))
					break;
			}
			if (whitelist[i]) {
				if (whitelisted_keys.count(key->c_str())) {
					//wprintf(L"[WARNING] Duplicate non-command list key found: %ls - [%ls]\n", key->c_str(), id);
				}
				whitelisted_keys.insert(key->c_str());

				continue;
			}
		}

		command_list = pre_command_list;
		explicit_command_list = NULL;
		key_ptr = key->c_str();
		if (post_command_list) {
			if (!key->compare(0, 5, L"post ")) {
				key_ptr += 5;
				command_list = post_command_list;
				explicit_command_list = post_command_list;
			}
			else if (!key->compare(0, 4, L"pre ")) {
				key_ptr += 4;
				explicit_command_list = pre_command_list;
			}
		}

		if (ParseCommandListLine(G, id, key_ptr, val, raw_line, command_list, explicit_command_list, pre_command_list, post_command_list,
			&entry->ini_namespace, entry->full_path, entry->line_index)) {
			//wprintf(L"  %ls\n", raw_line->c_str());
			continue;
		}

		if (entry->ini_namespace == G.user_config && !G.user_config.empty()) {
			if (!G.user_config_dirty) {
				/*printf(
					"NOTICE: Unknown user settings will be removed from d3dx_user.ini\n"
					" This is normal if you recently removed/changed any mods\n"
					" Press ? to update the config now, or ? to reset all settings to default\n"
					" The first unrecognised entry was: \"%S\"\n",
					raw_line->c_str());*/
				G.user_config_dirty |= 2;
			}
			//wprintf(L"[WARNING] Unrecognised entry in %ls: %ls\n", G->user_config.c_str(), raw_line->c_str());
			continue;
		}

		//wprintf(L"[WARNING] Ignored entry CommandList sections: %ls - [%ls] @ [%ls]\n", raw_line->c_str(), id, entry->ini_namespace.c_str());
	}

	if (std::distance(begin(scope), end(scope)) != 1) {
		//wprintf(L"[WARNING] Scope unbalanced - [%ls]\n", id);
	}

	pre_command_list->scope = NULL;
	if (post_command_list)
		post_command_list->scope = NULL;
}

static void ParseConstantsSection(Globals& G)
{
	VariableFlags flags;
	IniSectionVector* section = NULL;
	IniSectionVector::iterator entry, next;
	std::wstring* key, * val, name;
	const wchar_t* name_pos;
	const std::wstring* ini_namespace;
	std::pair<CommandListVariables::iterator, bool> inserted;
	float fval;
	int len;

	//LogInfo("[Constants]\n");

	G.command_list_globals.clear();
	//persistent_variables.clear();
	GetIniSection(G, &section, L"Constants");
	for (next = section->begin(), entry = next; entry < section->end(); entry = next) {
		next++;
		key = &entry->first;
		val = &entry->second;
		ini_namespace = &entry->ini_namespace;

		if (!key->empty())
			name = *key;
		else
			name = entry->raw_line;

		std::transform(name.begin(), name.end(), name.begin(), ::towlower);

		flags = parse_enum_option_string_prefix<const wchar_t*, VariableFlags>
			(VariableFlagNames, name.c_str(), &name_pos);
		if (!(flags & VariableFlags::GLOBAL))
			continue;
		name = name_pos;

		if (!valid_variable_name(name)) {
			//wprintf(L"[WARNING] Illegal global variable name: \"%ls\" - [Constants] @ [%ls]\n", name.c_str(), entry->ini_namespace.c_str());
			continue;
		}

		if (!ini_namespace->empty())
			name = get_namespaced_var_name_lower(name, ini_namespace);

		fval = 0.0f;
		if (!val->empty()) {
			if (swscanf_s(val->c_str(), L"%f%n", &fval, &len) != 1 || len != val->length()) {
				//wprintf(L"[WARNING] Floating point parse error: %ls=%ls - [Constants] @ [%ls]\n", key->c_str(), val->c_str(), entry->ini_namespace.c_str());
				continue;
			}
		}

		inserted = G.command_list_globals.emplace(name, CommandListVariable{ name, fval, flags });
		if (!inserted.second) {
			//wprintf(L"[WARNING] Redeclaration of %ls - [Constants] @ [%ls]\n", name.c_str(), entry->ini_namespace.c_str());
			continue;
		}

		/*if (flags & VariableFlags::PERSIST)
			persistent_variables.emplace_back(&inserted.first->second);*/

		/*if (val->empty())
			LogInfo("  global %S\n", name.c_str());
		else
			LogInfo("  global %S=%f\n", name.c_str(), fval);*/

		next = section->erase(entry);
	}

	G.constants_command_list.clear();
	G.post_constants_command_list.clear();
	ParseCommandList(G, L"Constants", &G.constants_command_list, &G.post_constants_command_list, NULL);
}

wchar_t* ShaderOverrideIniKeys[] = {
	L"hash",
	L"allow_duplicate_hash",
	L"depth_filter",
	L"partner",
	L"model",
	L"disable_scissor",
	L"filter_index",
	NULL
};

static void ParseShaderOverrideSections(Globals& G)
{
	IniSections::iterator lower, upper, i;
	const wchar_t* id;
	ShaderOverride* shader_override;
	UINT64 hash;
	bool duplicate, found;

	G.mShaderOverrideMap.clear();

	lower = G.ini_sections.lower_bound(std::wstring(L"ShaderOverride"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"ShaderOverride"));
	for (i = lower; i != upper; i++) {
		id = i->first.c_str();


		hash = GetIniHash(G, id, L"Hash", 0, &found);
		if (!found) {
			//wprintf(L"WARNING: Section missing Hash=\n - [%ls]\n", id);
			continue;
		}

		duplicate = !!G.mShaderOverrideMap.count(hash);
		shader_override = &G.mShaderOverrideMap[hash];
		if (!duplicate)
			shader_override->first_ini_section = id;

		// We only care about command list, so just use explicit command list section
		ParseCommandList(G, id, &shader_override->command_list, &shader_override->post_command_list, ShaderOverrideIniKeys);
	}
}

static std::vector<std::wstring> split_string(const std::wstring* str, wchar_t sep)
{
	std::wistringstream tokens(*str);
	std::wstring token;
	std::vector<std::wstring> list;

	while (std::getline(tokens, token, sep))
		list.push_back(token);

	return list;
}

wchar_t* ShaderRegexIniKeys[] = {
	L"shader_model",
	L"temps",
	L"filter_index",
	NULL
};
static bool parse_shader_regex_section_main(Globals& G, const std::wstring* section_id, ShaderRegexGroup* regex_group)
{
	std::string setting;
	std::vector<std::string> items;

	if (!GetIniStringAndLog(G, section_id->c_str(), L"shader_model", NULL, &setting)) {
		//wprintf(L"[WARNING] RegEx section missing shader_model\n - [%ls]\n", section_id->c_str());
		return false;
	}

	regex_group->ini_section = *section_id;


	ParseCommandList(G, section_id->c_str(), &regex_group->command_list, &regex_group->post_command_list, ShaderRegexIniKeys);
	return true;
}

static ShaderRegexGroup* get_regex_group(Globals& G, std::wstring* regex_id, bool allow_creation)
{
	if (allow_creation)
		return &G.shader_regex_groups[*regex_id];

	try {
		return &G.shader_regex_groups.at(*regex_id);
	}
	catch (std::out_of_range) {
		//wprintf(L"[WARNING] Missing section - [%ls]\n", regex_id->c_str());
		return NULL;
	}
}

static void delete_regex_group(Globals& G, std::wstring* regex_id)
{
	ShaderRegexGroups::iterator i;

	i = G.shader_regex_groups.find(*regex_id);
	
	if (i != G.shader_regex_groups.end())
	{
		auto it = std::find(G.registered_command_lists.begin(), G.registered_command_lists.end(), &i->second.command_list);
		if (it != G.registered_command_lists.end())
			G.registered_command_lists.erase(it);
		it = std::find(G.registered_command_lists.begin(), G.registered_command_lists.end(), &i->second.post_command_list);
		if (it != G.registered_command_lists.end())
			G.registered_command_lists.erase(it);

		i->second.command_list.clear();
		i->second.post_command_list.clear();
	}

	G.shader_regex_groups.erase(i);
}

static void ParseShaderRegexSections(Globals& G)
{
	IniSections::iterator lower, upper, i;
	const std::wstring* section_id;
	std::wstring section_prefix, section_suffix;
	std::vector<std::wstring> subsection_names;
	ShaderRegexGroup* regex_group;
	size_t namespace_endpos = 0;

	G.shader_regex_groups.clear();

	lower = G.ini_sections.lower_bound(std::wstring(L"ShaderRegex"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"ShaderRegex"));
	for (i = lower; i != upper; i++) {
		section_id = &i->first;
		namespace_endpos = get_section_namespace_endpos(G, section_id->c_str());
		section_prefix = section_id->substr(0, namespace_endpos);
		section_suffix = section_id->substr(namespace_endpos);
		subsection_names = split_string(&section_suffix, L'.');
		if (subsection_names.size())
			subsection_names[0] = section_prefix + subsection_names[0];
		else
			subsection_names.push_back(section_prefix);

		regex_group = get_regex_group(G, &subsection_names[0], subsection_names.size() == 1);
		if (!regex_group)
			continue;

		switch (subsection_names.size()) {
		case 1:
			//Only care about command list in main
			if (parse_shader_regex_section_main(G, section_id, regex_group))
				continue;
			break;
		case 2:
			if (!_wcsicmp(subsection_names[1].c_str(), L"Pattern")) {
					continue;
			}
			else if (!_wcsicmp(subsection_names[1].c_str(), L"InsertDeclarations")) {
					continue;
			}
			break;
		case 3:
			if (!_wcsnicmp(subsection_names[1].c_str(), L"Pattern", 7)
				&& !_wcsicmp(subsection_names[2].c_str(), L"Replace")) {
				
					continue;
			}
			break;
		}

		//wprintf(L"Disabling entire shader regex group - [%ls]\n", subsection_names[0].c_str());
		delete_regex_group(G, &subsection_names[0]);
	}
}

#define TEXTURE_OVERRIDE_FUZZY_MATCHES \
	L"match_type", \
	L"match_usage", \
	L"match_bind_flags", \
	L"match_cpu_access_flags", \
	L"match_misc_flags", \
	L"match_byte_width", \
	L"match_stride", \
	L"match_mips", \
	L"match_format", \
	L"match_width", \
	L"match_height", \
	L"match_depth", \
	L"match_array", \
	L"match_msaa", \
	L"match_msaa_quality"

#define TEXTURE_OVERRIDE_DRAW_CALL_MATCHES \
	L"match_first_vertex", \
	L"match_first_index", \
	L"match_first_instance", \
	L"match_vertex_count", \
	L"match_index_count", \
	L"match_instance_count"

wchar_t* TextureOverrideIniKeys[] = {
	L"hash",
	L"format",
	L"width",
	L"height",
	L"width_multiply",
	L"height_multiply",
	L"override_byte_stride",
	L"override_vertex_count",
	L"uav_byte_stride",
	L"iteration",
	L"filter_index",
	L"expand_region_copy",
	L"deny_cpu_read",
	L"match_priority",
	TEXTURE_OVERRIDE_FUZZY_MATCHES,
	TEXTURE_OVERRIDE_DRAW_CALL_MATCHES,
	NULL
};

wchar_t* TextureOverrideFuzzyMatchesIniKeys[] = {
	TEXTURE_OVERRIDE_FUZZY_MATCHES,
	NULL
};

static void parse_texture_override_common(Globals& G, const wchar_t* id, TextureOverride* override, bool register_command_lists)
{
	bool found;
	override->priority = GetIniInt(G, id, L"match_priority", 0, &found);
	ParseCommandList(G, id, &override->command_list, &override->post_command_list, TextureOverrideIniKeys, register_command_lists);
}

static bool texture_override_section_has_fuzzy_match_keys(Globals& G, const wchar_t* section)
{
	int i;

	for (i = 0; TextureOverrideFuzzyMatchesIniKeys[i]; i++) {
		if (IniHasKey(G, section, TextureOverrideFuzzyMatchesIniKeys[i]))
			return true;
	}

	return false;
}

static void parse_texture_override_fuzzy_match(Globals& G, const wchar_t* section)
{
	FuzzyMatchResourceDesc* fuzzy;

	fuzzy = new FuzzyMatchResourceDesc(section);

	parse_texture_override_common(G, section, fuzzy->texture_override, true);

	if (!G.mFuzzyTextureOverrides.insert(std::shared_ptr<FuzzyMatchResourceDesc>(fuzzy)).second) {
		//printf("BUG: Unexpected error inserting fuzzy texture override\n");
		//DoubleBeepExit();
	}
}

static void ParseTextureOverrideSections(Globals& G)
{
	// We only care about command list, so just use explicit command list section
	IniSections::iterator lower, upper, i;
	const wchar_t* id;
	TextureOverride* override;
	uint32_t hash;
	bool found;
	std::map<uint32_t, int> max_byte_width_map;


	G.mTextureOverrideMap.clear();
	G.mFuzzyTextureOverrides.clear();

	lower = G.ini_sections.lower_bound(std::wstring(L"TextureOverride"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"TextureOverride"));

	for (i = lower; i != upper; i++) {
		id = i->first.c_str();

		hash = (uint32_t)GetIniHash(G, id, L"Hash", 0, &found);
		if (!found) {
			if (texture_override_section_has_fuzzy_match_keys(G, id)) {
				parse_texture_override_fuzzy_match(G, id);
				continue;
			}

			//wprintf(L"WARNING: Section missing Hash= or valid match options - [%ls]\n", id);
			continue;
		}

		if (texture_override_section_has_fuzzy_match_keys(G, id))
		{
			//wprintf(L"WARNING: Cannot use hash= and match options together!\n - [%ls]\n", id);
		}

		G.mTextureOverrideMap[hash].emplace_back();
		override = &G.mTextureOverrideMap[hash].back();
		override->ini_section = id;

		parse_texture_override_common(G, id, override, false);
	}

	for (auto& tolkv : G.mTextureOverrideMap) {
		std::sort(tolkv.second.begin(), tolkv.second.end(), TextureOverrideLess);

		for (TextureOverride& to : tolkv.second) {
			G.registered_command_lists.push_back(&to.command_list);
			G.registered_command_lists.push_back(&to.post_command_list);
		}
	}
}

bool iequals(const std::wstring& a, const std::wstring& b)
{
	if (a.size() != b.size()) return false;

	for (size_t i = 0; i < a.size(); ++i)
		if (std::towlower(a[i]) != std::towlower(b[i]))
			return false;

	return true;
}

const IniLine* find_first_ini_line(
	const std::vector<IniLine>& lines,
	const std::wstring& key,
	const std::wstring& val
)
{
	for (const IniLine& l : lines) {
		if (iequals(l.first, key) && iequals(l.second, val))
			return &l;
	}
	return nullptr;
}

static void RegisterPresetKeyBindings(Globals& G)
{
	// We only care about "condition = " line
	// This has function has been completely modified from the original xxmi lib source code

	IniSections::iterator lower, upper, i;

	CommandListExpression condition;
	std::wstring ini_namespace;
	std::vector<std::wstring> conditions;

	lower = G.ini_sections.lower_bound(std::wstring(L"Key"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"Key"));

	for (i = lower; i != upper; ++i) {
		const wchar_t* section = i->first.c_str();

		conditions = GetIniStringMultipleKeys(G, section, L"Condition");

		if (conditions.empty()) {
			continue;
		}

		for (std::wstring conditionVal : conditions)
		{
			std::wstring sbuf(conditionVal);
			std::transform(sbuf.begin(), sbuf.end(), sbuf.begin(), ::towlower);

			std::wstring ini_namespace;
			get_section_namespace(G, section, &ini_namespace);

			CommandListExpression condition;

			if (!condition.parse(G, &sbuf, &ini_namespace, nullptr)) {
				/*wprintf(
					L"[WARNING] Invalid [Key] condition = \"%ls\" - [%ls] @ [%ls]\n",
					conditionVal.c_str(), section, ini_namespace.c_str()
				);*/

				const IniLine* line = find_first_ini_line(i->second.kv_vec, L"condition", sbuf);

				if (line) {
					G.errored_lines.insert(ErroredLine{ line->full_path, line->line_index, line->raw_line, L"Invalid expression in [Key] section \"condition\"" });
				}
			}
		}
	}
}

wchar_t* CustomShaderIniKeys[] = {
	L"vs", L"hs", L"ds", L"gs", L"ps", L"cs",
	L"max_executions_per_frame", L"flags",
	L"blend", L"alpha", L"mask",
	L"blend[0]", L"blend[1]", L"blend[2]", L"blend[3]",
	L"blend[4]", L"blend[5]", L"blend[6]", L"blend[7]",
	L"alpha[0]", L"alpha[1]", L"alpha[2]", L"alpha[3]",
	L"alpha[4]", L"alpha[5]", L"alpha[6]", L"alpha[7]",
	L"mask[0]", L"mask[1]", L"mask[2]", L"mask[3]",
	L"mask[4]", L"mask[5]", L"mask[6]", L"mask[7]",
	L"alpha_to_coverage", L"sample_mask",
	L"blend_factor[0]", L"blend_factor[1]",
	L"blend_factor[2]", L"blend_factor[3]",
	L"blend_state_merge",
	L"depth_enable", L"depth_write_mask", L"depth_func",
	L"stencil_enable", L"stencil_read_mask", L"stencil_write_mask",
	L"stencil_front", L"stencil_back", L"stencil_ref",
	L"depth_stencil_state_merge",
	L"fill", L"cull", L"front", L"depth_bias", L"depth_bias_clamp",
	L"slope_scaled_depth_bias", L"depth_clip_enable", L"scissor_enable",
	L"multisample_enable", L"antialiased_line_enable",
	L"rasterizer_state_merge",
	L"topology",
	L"sampler",
NULL
};

static void _EnumerateCustomShaderSections(Globals& G, IniSections::iterator lower, IniSections::iterator upper)
{
	IniSections::iterator i;
	std::wstring shader_id;

	for (i = lower; i != upper; i++) {
		shader_id = i->first;
		std::transform(shader_id.begin(), shader_id.end(), shader_id.begin(), ::towlower);

		G.customShaderSections[shader_id];
	}
}
static void EnumerateCustomShaderSections(Globals& G)
{
	IniSections::iterator lower, upper;

	G.customShaderSections.clear();

	lower = G.ini_sections.lower_bound(std::wstring(L"BuiltInCustomShader"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"BuiltInCustomShader"));
	_EnumerateCustomShaderSections(G, lower, upper);

	lower = G.ini_sections.lower_bound(std::wstring(L"CustomShader"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"CustomShader"));
	_EnumerateCustomShaderSections(G, lower, upper);
}

static void ParseCustomShaderSections(Globals& G)
{
	// We only care about command list, so just use explicit command list section
	ExplicitCommandListSections::iterator i;
	ExplicitCommandListSection* custom_shader_section;
	const std::wstring* section_id;

	for (i = G.customShaderSections.begin(); i != G.customShaderSections.end(); i++) {
		section_id = &i->first;
		custom_shader_section = &i->second;

		ParseCommandList(G, section_id->c_str(), &custom_shader_section->command_list, &custom_shader_section->post_command_list, CustomShaderIniKeys);
	}
}

static void _EnumerateExplicitCommandListSections(Globals& G, IniSections::iterator lower, IniSections::iterator upper)
{
	IniSections::iterator i;
	std::wstring section_id;

	for (i = lower; i != upper; i++) {
		section_id = i->first;
		std::transform(section_id.begin(), section_id.end(), section_id.begin(), ::towlower);

		G.explicitCommandListSections[section_id];
	}
}

static void EnumerateExplicitCommandListSections(Globals& G)
{
	IniSections::iterator lower, upper;

	G.explicitCommandListSections.clear();

	lower = G.ini_sections.lower_bound(std::wstring(L"BuiltInCommandList"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"BuiltInCommandList"));
	_EnumerateExplicitCommandListSections(G, lower, upper);

	lower = G.ini_sections.lower_bound(std::wstring(L"CommandList"));
	upper = prefix_upper_bound(G.ini_sections, std::wstring(L"CommandList"));
	_EnumerateExplicitCommandListSections(G, lower, upper);
}

static void ParseExplicitCommandListSections(Globals& G)
{
	ExplicitCommandListSections::iterator i;
	ExplicitCommandListSection* command_list_section;
	const std::wstring* section_id;

	for (i = G.explicitCommandListSections.begin(); i != G.explicitCommandListSections.end(); i++) {
		section_id = &i->first;
		command_list_section = &i->second;

		ParseCommandList(G, section_id->c_str(), &command_list_section->command_list, &command_list_section->post_command_list, NULL);
	}
}

void LoadConfigFile(Globals& G, const std::wstring& ini_file, const std::wstring& base_path) {

	setlocale(LC_CTYPE, "en_US.UTF-8");

	ParseIniFile(G, ini_file.c_str());

	ParseIncludedIniFiles(G, base_path);


	G.registered_command_lists.clear();

	//This enumerate function cause problem on ini_sections map cannot find the specified section if the namespace(or file path) is non utf8 english
	//But leave it as is, because the original XXMI Lib also have this problem

	EnumerateCustomShaderSections(G);
	EnumerateExplicitCommandListSections(G);
	//EnumeratePresetOverrideSections();

	//Used for parsing expression, so parse resource and constants first
	ParseResourceSections(G);
	ParseConstantsSection(G);

	//Only care about condition line in [Key] sections
	RegisterPresetKeyBindings(G);

	//ParsePresetOverrideSections();
	ParseCustomShaderSections(G);
	ParseExplicitCommandListSections(G);

	ParseShaderOverrideSections(G);

	ParseShaderRegexSections(G);

	ParseTextureOverrideSections(G);

	G.present_command_list.clear();
	G.post_present_command_list.clear();
	ParseCommandList(G, L"Present", &G.present_command_list, &G.post_present_command_list, NULL);

	G.clear_rtv_command_list.clear();
	G.post_clear_rtv_command_list.clear();
	ParseCommandList(G, L"ClearRenderTargetView", &G.clear_rtv_command_list, &G.post_clear_rtv_command_list, NULL);

	G.clear_dsv_command_list.clear();
	G.post_clear_dsv_command_list.clear();
	ParseCommandList(G, L"ClearDepthStencilView", &G.clear_dsv_command_list, &G.post_clear_dsv_command_list, NULL);

	G.clear_uav_uint_command_list.clear();
	G.post_clear_uav_uint_command_list.clear();
	ParseCommandList(G, L"ClearUnorderedAccessViewUint", &G.clear_uav_uint_command_list, &G.post_clear_uav_uint_command_list, NULL);

	G.clear_uav_float_command_list.clear();
	G.post_clear_uav_float_command_list.clear();
	ParseCommandList(G, L"ClearUnorderedAccessViewFloat", &G.clear_uav_float_command_list, &G.post_clear_uav_float_command_list, NULL);

	// Look for:
	//"if" missing "endif"
	//"else" "elif" "else if" missing "if"
	size_t i;

	for (CommandList* command_list : G.registered_command_lists) {
		for (i = 0; i < command_list->commands.size(); ) {
			if (command_list->commands[i]->noop(G, command_list->post, false, false)) {
				command_list->commands.erase(command_list->commands.begin() + i);
				continue;
			}
			i++;
		}
	}
}