#pragma once
#include "util.h"

#include <memory>
#include <forward_list>
#include <unordered_map>
#include <map>
#include <string>
#include <windows.h>

//defined Globals.h, do not include Globals.h, because Globals.h also include this file
struct Globals;

//ABSTRACT, Inheritted by AssignmentCommand, IfCommand, CommandPlaceholder
class CommandListCommand {
public:
	std::wstring ini_line;

	virtual ~CommandListCommand() {};

	virtual void run() = 0;
	virtual bool optimise() { return false; }
	virtual bool noop(Globals& G, bool post, bool ignore_cto_pre, bool ignore_cto_post) { return false; }
};

enum class VariableFlags {
	NONE = 0,
	GLOBAL = 0x00000001,
	PERSIST = 0x00000002,
	INVALID = (signed)0xffffffff,
};
SENSIBLE_ENUM(VariableFlags);
static EnumName_t<const wchar_t*, VariableFlags> VariableFlagNames[] = {
	{L"global", VariableFlags::GLOBAL},
	{L"persist", VariableFlags::PERSIST},

	{NULL, VariableFlags::INVALID}
};

//CONCRETE
class CommandListVariable {
public:
	std::wstring name;
	float fval;
	VariableFlags flags;

	CommandListVariable(std::wstring name, float fval, VariableFlags flags) :
		name(name), fval(fval), flags(flags)
	{
	}
};

typedef std::unordered_map<std::wstring, class CommandListVariable> CommandListVariables;

typedef std::forward_list<std::unordered_map<std::wstring, CommandListVariable*>> CommandListScope;

//CONCRETE
class CommandList {
public:

	typedef std::vector<std::shared_ptr<CommandListCommand>> Commands;
	Commands commands;

	std::forward_list<CommandListVariable> static_vars;
	CommandListScope* scope;

	std::wstring ini_section;
	bool post;

	void clear();

	CommandList() :
		post(false),
		scope(NULL)
	{
	}
};

//CONCRETE
class ExplicitCommandListSection
{
public:
	CommandList command_list;
	CommandList post_command_list;
};

typedef std::unordered_map<std::wstring, class ExplicitCommandListSection> ExplicitCommandListSections;

//CONCRETE
class CustomResource
{
public:
	std::wstring name;

	CustomResource();
	~CustomResource();

};

typedef std::unordered_map<std::wstring, class CustomResource> CustomResources;

enum class ResourceCopyTargetType {
	INVALID,
	EMPTY,
	CONSTANT_BUFFER,
	SHADER_RESOURCE,
	VERTEX_BUFFER,
	INDEX_BUFFER,
	STREAM_OUTPUT,
	RENDER_TARGET,
	DEPTH_STENCIL_TARGET,
	UNORDERED_ACCESS_VIEW,
	CUSTOM_RESOURCE,
	INI_PARAMS,
	CURSOR_MASK,
	CURSOR_COLOR,
	THIS_RESOURCE,
	SWAP_CHAIN,
	REAL_SWAP_CHAIN,
	FAKE_SWAP_CHAIN,
	CPU,
};

//CONCRETE
class ResourceCopyTarget {
public:
	ResourceCopyTargetType type;
	wchar_t shader_type;
	unsigned slot;
	CustomResource* custom_resource;

	ResourceCopyTarget() :
		type(ResourceCopyTargetType::INVALID),
		shader_type(L'\0'),
		slot(0),
		custom_resource(NULL)
	{
	}

	bool ParseTarget(Globals& G, const wchar_t* target, bool is_source, const std::wstring* ini_namespace);

};

//CONCRETE, Inheritted by CommandListSyntaxTree, CommandListOperand, CommandListOperatorToken
class CommandListToken {
public:
	std::wstring token;
	size_t token_pos;

	CommandListToken(size_t token_pos, std::wstring token = L"") :
		token_pos(token_pos), token(token)
	{
	}
	virtual ~CommandListToken() {};
};

//ABSTRACT, Inheritted by CommandListOperand, CommandListOperator
class CommandListEvaluatable {
public:
	virtual ~CommandListEvaluatable() {};

	virtual float evaluate() = 0;
	virtual bool static_evaluate(float* ret) = 0;
	virtual bool optimise(std::shared_ptr<CommandListEvaluatable>* replacement) = 0;
};

//ABSTRACT, Inheritted by CommandListSyntaxTree, CommandListOperand, CommandListOperator
class CommandListOperandBase {
public:
};

//ABSTRACT, Inheritted by CommandListSyntaxTree, CommandListOperator
class CommandListFinalisable {
public:
	virtual std::shared_ptr<CommandListEvaluatable> finalise() = 0;
};

//ABSTRACT, Inheritted by CommandListSyntaxTree, CommandListOperator
class CommandListWalkable {
public:
	typedef std::vector<std::shared_ptr<CommandListWalkable>> Walk;
	virtual Walk walk() = 0;
};

//CONCRETE
//INHERITS
class CommandListSyntaxTree :
	public CommandListToken,
	public CommandListOperandBase,
	public CommandListFinalisable,
	public CommandListWalkable {
public:
	typedef std::vector<std::shared_ptr<CommandListToken>> Tokens;
	Tokens tokens;

	CommandListSyntaxTree(size_t token_pos) :
		CommandListToken(token_pos)
	{
	}

	std::shared_ptr<CommandListEvaluatable> finalise() override; //CommandListFinalisable
	Walk walk() override; //CommandListWalkable
};

//INHERITS, Inheritted by CommandListOperator
class CommandListOperatorToken : public CommandListToken {
public:
	CommandListOperatorToken(size_t token_pos, std::wstring token = L"") :
		CommandListToken(token_pos, token)
	{
	}
};

//CONCRETE
//INHERITS
class CommandListOperator :
	public CommandListOperatorToken,
	public CommandListEvaluatable,
	public CommandListFinalisable,
	public CommandListOperandBase,
	public CommandListWalkable {
public:
	std::shared_ptr<CommandListToken> lhs_tree;
	std::shared_ptr<CommandListToken> rhs_tree;
	std::shared_ptr<CommandListEvaluatable> lhs;
	std::shared_ptr<CommandListEvaluatable> rhs;

	CommandListOperator(
		std::shared_ptr<CommandListToken> lhs,
		CommandListOperatorToken& t,
		std::shared_ptr<CommandListToken> rhs
	) : CommandListOperatorToken(t), lhs_tree(lhs), rhs_tree(rhs)
	{
	}

	//CommandListFinalisable
	std::shared_ptr<CommandListEvaluatable> finalise() override;

	//CommandListEvaluatable
	float evaluate() override;
	bool static_evaluate(float* ret) override;
	bool optimise(std::shared_ptr<CommandListEvaluatable>* replacement) override;

	//CommandListWalkable
	Walk walk() override;

	static const wchar_t* pattern() { return L"<IMPLEMENT ME>"; }
	virtual float evaluate(float lhs, float rhs) = 0;
};

//ABSTRACT, Inheritted by CommandListOperatorFactory
class CommandListOperatorFactoryBase {
public:
	virtual const wchar_t* pattern() = 0;
	virtual std::shared_ptr<CommandListOperator> create(
		std::shared_ptr<CommandListToken> lhs,
		CommandListOperatorToken& t,
		std::shared_ptr<CommandListToken> rhs) = 0;
};

//CONCRETE
//INHERITS
template <class T>
class CommandListOperatorFactory : public CommandListOperatorFactoryBase {
public:
	const wchar_t* pattern() override {
		return T::pattern();
	}

	std::shared_ptr<CommandListOperator> create(
		std::shared_ptr<CommandListToken> lhs,
		CommandListOperatorToken& t,
		std::shared_ptr<CommandListToken> rhs) override
	{
		return std::make_shared<T>(lhs, t, rhs);
	}
};

enum class ParamOverrideType {
	INVALID,
	VALUE,
	INI_PARAM,
	VARIABLE,
	RT_WIDTH,
	RT_HEIGHT,
	RES_WIDTH,
	RES_HEIGHT,
	WINDOW_WIDTH,
	WINDOW_HEIGHT,
	TEXTURE,
	SHADER,
	VERTEX_COUNT,
	INDEX_COUNT,
	INSTANCE_COUNT,
	FIRST_VERTEX,
	FIRST_INDEX,
	FIRST_INSTANCE,
	THREAD_GROUP_COUNT_X,
	THREAD_GROUP_COUNT_Y,
	THREAD_GROUP_COUNT_Z,
	INDIRECT_OFFSET,
	DRAW_TYPE,
	CURSOR_VISIBLE,
	CURSOR_SCREEN_X,
	CURSOR_SCREEN_Y,
	CURSOR_WINDOW_X,
	CURSOR_WINDOW_Y,
	CURSOR_X,
	CURSOR_Y,
	CURSOR_HOTSPOT_X,
	CURSOR_HOTSPOT_Y,
	TIME,
	SCISSOR_LEFT,
	SCISSOR_TOP,
	SCISSOR_RIGHT,
	SCISSOR_BOTTOM,
	HUNTING,
	FRAME_ANALYSIS,
	EFFECTIVE_DPI,
	SLI,
	STEREO_ACTIVE,
	STEREO_AVAILABLE,
};
static EnumName_t<const wchar_t*, ParamOverrideType> ParamOverrideTypeNames[] = {
	{L"rt_width", ParamOverrideType::RT_WIDTH},
	{L"rt_height", ParamOverrideType::RT_HEIGHT},
	{L"res_width", ParamOverrideType::RES_WIDTH},
	{L"res_height", ParamOverrideType::RES_HEIGHT},
	{L"window_width", ParamOverrideType::WINDOW_WIDTH},
	{L"window_height", ParamOverrideType::WINDOW_HEIGHT},
	{L"vertex_count", ParamOverrideType::VERTEX_COUNT},
	{L"index_count", ParamOverrideType::INDEX_COUNT},
	{L"instance_count", ParamOverrideType::INSTANCE_COUNT},
	{L"first_vertex", ParamOverrideType::FIRST_VERTEX},
	{L"first_index", ParamOverrideType::FIRST_INDEX},
	{L"first_instance", ParamOverrideType::FIRST_INSTANCE},
	{L"thread_group_count_x", ParamOverrideType::THREAD_GROUP_COUNT_X},
	{L"thread_group_count_y", ParamOverrideType::THREAD_GROUP_COUNT_Y},
	{L"thread_group_count_z", ParamOverrideType::THREAD_GROUP_COUNT_Z},
	{L"indirect_offset", ParamOverrideType::INDIRECT_OFFSET},
	{L"draw_type", ParamOverrideType::DRAW_TYPE},
	{L"cursor_showing", ParamOverrideType::CURSOR_VISIBLE},
	{L"cursor_screen_x", ParamOverrideType::CURSOR_SCREEN_X},
	{L"cursor_screen_y", ParamOverrideType::CURSOR_SCREEN_Y},
	{L"cursor_window_x", ParamOverrideType::CURSOR_WINDOW_X},
	{L"cursor_window_y", ParamOverrideType::CURSOR_WINDOW_Y},
	{L"cursor_x", ParamOverrideType::CURSOR_X},
	{L"cursor_y", ParamOverrideType::CURSOR_Y},
	{L"cursor_hotspot_x", ParamOverrideType::CURSOR_HOTSPOT_X},
	{L"cursor_hotspot_y", ParamOverrideType::CURSOR_HOTSPOT_Y},
	{L"time", ParamOverrideType::TIME},
	{L"scissor_left", ParamOverrideType::SCISSOR_LEFT},
	{L"scissor_top", ParamOverrideType::SCISSOR_TOP},
	{L"scissor_right", ParamOverrideType::SCISSOR_RIGHT},
	{L"scissor_bottom", ParamOverrideType::SCISSOR_BOTTOM},
	{L"hunting", ParamOverrideType::HUNTING},
	{L"frame_analysis", ParamOverrideType::FRAME_ANALYSIS},
	{L"effective_dpi", ParamOverrideType::EFFECTIVE_DPI},
	{L"sli", ParamOverrideType::SLI},
	{L"stereo_active", ParamOverrideType::STEREO_ACTIVE},
	{L"stereo_available", ParamOverrideType::STEREO_AVAILABLE},
	{NULL, ParamOverrideType::INVALID} // End of list marker
};

//CONCRETE
//INHERITS
class CommandListOperand :
	public CommandListToken,
	public CommandListOperandBase,
	public CommandListEvaluatable {
public:
	ParamOverrideType type;
	float val;

	int param_idx;

	float* var_ftarget;

	ResourceCopyTarget texture_filter_target;
	wchar_t shader_filter_target;

	unsigned scissor;

	CommandListOperand(size_t pos, std::wstring token = L"") :
		CommandListToken(pos, token),
		type(ParamOverrideType::INVALID),
		val(FLT_MAX),
		param_idx(0),
		var_ftarget(NULL),
		scissor(0)
	{
	}

	bool parse(Globals& G, const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope);

	//CommandListEvaluatable
	float evaluate() override;
	bool static_evaluate(float* ret) override;
	bool optimise(std::shared_ptr<CommandListEvaluatable>* replacement) override;
};

//CONCRETE
class CommandListExpression {
public:
	std::shared_ptr<CommandListEvaluatable> evaluatable;

	bool parse(Globals& G, const std::wstring* expression, const std::wstring* ini_namespace, CommandListScope* scope);
	float evaluate();
	bool static_evaluate(float* ret);
	bool optimise();
};


//CONCRETE, Inheritted by VariableAssignment
//INHERITS
class AssignmentCommand : public CommandListCommand {
public:
	CommandListExpression expression;

	bool optimise() override; // CommandListCommand
};

//CONCRETE
//INHERITS
class VariableAssignment : public AssignmentCommand {
public:
	CommandListVariable* var;

	VariableAssignment() :
		var(NULL)
	{
	}

	void run() override; // AssignmentCommand << CommandListCommand 
};

//CONCRETE, Inheritted by ElseIfCommand
//INHERITS
class IfCommand : public CommandListCommand {
public:
	CommandListExpression expression;
	bool pre_finalised, post_finalised;
	bool has_nested_else_if;
	std::wstring section;

	std::shared_ptr<CommandList> true_commands_pre;
	std::shared_ptr<CommandList> true_commands_post;
	std::shared_ptr<CommandList> false_commands_pre;
	std::shared_ptr<CommandList> false_commands_post;

	std::wstring full_path;
	std::wstring line;
	int line_index;

	IfCommand(Globals& G, const wchar_t* section, const std::wstring& full_path, const std::wstring& line, int line_index);

	//CommandListCommand
	void run() override;
	bool optimise() override;
	bool noop(Globals& G, bool post, bool ignore_cto_pre, bool ignore_cto_post) override;
};


//CONCRETE
//INHERITS
class ElseIfCommand : public IfCommand {
public:
	ElseIfCommand(Globals& G, const wchar_t* section, const std::wstring& full_path, const std::wstring& line, int line_index) :
		IfCommand(G, section, full_path, line, line_index)
	{
	}
};

//CONCRETE, Inheritted by ElsePlaceholder
//INHERITS
class CommandPlaceholder : public CommandListCommand {
public:
	std::wstring full_path;
	std::wstring line;
	int line_index;

	CommandPlaceholder(const std::wstring& full_path, const std::wstring& line, int line_index) :
		full_path(full_path),
		line(line),
		line_index(line_index)
	{
	}

	//CommandListCommand
	void run() override;
	bool noop(Globals& G, bool post, bool ignore_cto_pre, bool ignore_cto_post) override;
};
class ElsePlaceholder : public CommandPlaceholder {
public:
	ElsePlaceholder(const std::wstring& full_path, const std::wstring& line, int line_index) :
		CommandPlaceholder(full_path, line, line_index)
	{
	}
};

//Was in ShaderRegex.h
//CONCRETE
class ShaderRegexGroup {
public:
	std::wstring ini_section;

	CommandList command_list;
	CommandList post_command_list;
};
typedef std::map<std::wstring, ShaderRegexGroup> ShaderRegexGroups;

bool ParseCommandListVariableAssignment(Globals& G, const wchar_t* section,
	const wchar_t* key, std::wstring* val, const std::wstring* raw_line,
	CommandList* command_list, CommandList* pre_command_list, CommandList* post_command_list,
	const std::wstring* ini_namespace);
bool ParseCommandListFlowControl(Globals& G, const wchar_t* section, const std::wstring* line,
	CommandList* pre_command_list, CommandList* post_command_list,
	const std::wstring* ini_namespace, const std::wstring& full_path, int line_index);

bool parse_command_list_var_name(Globals& G, const std::wstring& name, const std::wstring* ini_namespace, CommandListVariable** target);
bool valid_variable_name(const std::wstring& name);

