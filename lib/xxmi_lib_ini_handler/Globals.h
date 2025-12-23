#pragma once
#include "CommandList.h"
#include "IniHandler.h"
#include <string>

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


	///////////


	CommandListVariables command_list_globals;
	std::vector<CommandList*> registered_command_lists;
	ExplicitCommandListSections explicitCommandListSections;
	ExplicitCommandListSections customShaderSections;
	ExplicitCommandListSections shaderOverrideSections;
	ExplicitCommandListSections textureOverrideSections;
	CustomResources customResources;
	ShaderRegexGroups shader_regex_groups;
	std::vector<std::shared_ptr<CommandList>> dynamically_allocated_command_lists;
};