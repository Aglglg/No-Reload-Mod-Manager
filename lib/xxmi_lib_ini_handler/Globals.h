#pragma once
#include "CommandList.h"
#include "IniHandler.h"
#include "ResourceHash.h"
#include <string>

struct ShaderOverride {
	std::wstring first_ini_section;

	CommandList command_list;
	CommandList post_command_list;
};
typedef std::unordered_map<UINT64, struct ShaderOverride> ShaderOverrideMap;

struct TextureOverride {
	std::wstring ini_section;
	int priority;

	CommandList command_list;
	CommandList post_command_list;

	TextureOverride() :
		priority(0)
	{
	}
};

typedef std::vector<struct TextureOverride> TextureOverrideList;
typedef std::unordered_map<uint32_t, TextureOverrideList> TextureOverrideMap;

struct Globals
{
	std::set<ErroredLine, ErroredLineLess> errored_lines;

	std::unordered_set<std::wstring, WStringInsensitiveHash, WStringInsensitiveEquality> known_lib_namespaces;
	std::unordered_set<std::wstring, WStringInsensitiveHash, WStringInsensitiveEquality> already_known_duplicate_lib_path;
	std::unordered_set<std::wstring, WStringInsensitiveHash, WStringInsensitiveEquality> already_known_nonexist_lib;

	IniSections ini_sections;

	std::wstring user_config;
	int user_config_dirty;
	CommandList present_command_list;
	CommandList post_present_command_list;
	CommandList clear_rtv_command_list;
	CommandList post_clear_rtv_command_list;
	CommandList clear_dsv_command_list;
	CommandList post_clear_dsv_command_list;
	CommandList clear_uav_float_command_list;
	CommandList post_clear_uav_float_command_list;
	CommandList clear_uav_uint_command_list;
	CommandList post_clear_uav_uint_command_list;
	CommandList constants_command_list;
	CommandList post_constants_command_list;

	ShaderOverrideMap mShaderOverrideMap;
	TextureOverrideMap mTextureOverrideMap;
	FuzzyTextureOverrides mFuzzyTextureOverrides;

	///////////


	CommandListVariables command_list_globals;
	std::vector<CommandList*> registered_command_lists;
	ExplicitCommandListSections explicitCommandListSections;
	ExplicitCommandListSections customShaderSections;
	CustomResources customResources;
	ShaderRegexGroups shader_regex_groups;
	std::vector<std::shared_ptr<CommandList>> dynamically_allocated_command_lists;
};