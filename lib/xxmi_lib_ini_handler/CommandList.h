#pragma once
#include "util.h"

#include <memory>
#include <array>
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
	LOCKED = 0x00000004,
	INVALID = (signed)0xffffffff,
};
SENSIBLE_ENUM(VariableFlags);
static EnumName_t<const wchar_t*, VariableFlags> VariableFlagNames[] = {
	{L"global", VariableFlags::GLOBAL},
	{L"persist", VariableFlags::PERSIST},
	{L"locked",  VariableFlags::LOCKED},

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

	bool runtime_populated = false;

	void clear();

	CommandList* ResolveCommandList();
	bool CommandList::noop();

	CommandList() :
		post(false),
		scope(NULL)
	{
	}

private:
	CommandList* source_command_list = nullptr;
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
};

typedef std::unordered_map<std::wstring, class CustomResource> CustomResources;

enum class PoolIndexType : uint8_t {
	INVALID = 0b00000000,

	// Direct Index Types
	RING = 0b00000001,
	STATIC = 0b00000010,

	// Index Table Based Types
	FIFO = 0b00000100,
	SPATIAL = 0b00001000,

	INDEX_TABLE_MASK = 0b00001100,
};
SENSIBLE_ENUM(PoolIndexType);

static EnumName_t<const wchar_t*, PoolIndexType> PoolIndexTypeNames[] = {
	{L"ring",    PoolIndexType::RING},
	{L"fifo",    PoolIndexType::FIFO},
	{L"static",  PoolIndexType::STATIC},
	{L"spatial", PoolIndexType::SPATIAL},
	{NULL, PoolIndexType::INVALID} // End of list marker
};

//CONCRETE
class CustomResourcePool
{
public:
	std::wstring name;
	PoolIndexType index_type = PoolIndexType::RING;
};

typedef std::unordered_map<std::wstring, class CustomResourcePool> CustomResourcePools;

enum class ResourceCopyTargetType : uint32_t {
	INVALID = 0b00000000000000000000000000000000, // 0x00000000

	// D3D resources
	EMPTY = 0b00000000000000000000000000000001, // 0x00000001
	CONSTANT_BUFFER = 0b00000000000000000000000000000010, // 0x00000002
	SHADER_RESOURCE = 0b00000000000000000000000000000100, // 0x00000004
	// SAMPLER             = 0b00000000000000000000000000001000, // 0x00000008
	VERTEX_BUFFER = 0b00000000000000000000000000010000, // 0x00000010
	INDEX_BUFFER = 0b00000000000000000000000000100000, // 0x00000020
	STREAM_OUTPUT = 0b00000000000000000000000001000000, // 0x00000040
	RENDER_TARGET = 0b00000000000000000000000010000000, // 0x00000080
	DEPTH_STENCIL_TARGET = 0b00000000000000000000000100000000, // 0x00000100
	UNORDERED_ACCESS_VIEW = 0b00000000000000000000001000000000, // 0x00000200
	CUSTOM_RESOURCE = 0b00000000000000000000010000000000, // 0x00000400

	D3D_RESOURCE_MASK = 0b00000000000000000000011111111110, // 0x000007FE

	// Swap chains
	SWAP_CHAIN = 0b00000000000000000000100000000000, // 0x00000800 - Meaning depends on whether or not upscaling has run yet this frame
	REAL_SWAP_CHAIN = 0b00000000000000000001000000000000, // 0x00001000 - need this for upscaling used with "r_bb"
	FAKE_SWAP_CHAIN = 0b00000000000000000010000000000000, // 0x00002000 - need this for upscaling used with "f_bb"

	SWAP_CHAIN_MASK = 0b00000000000000000011100000000000, // 0x00003800

	// Special resources / pseudo-resources
	INI_PARAMS = 0b00000000000000000100000000000000, // 0x00004000
	CURSOR_MASK = 0b00000000000000001000000000000000, // 0x00008000
	CURSOR_COLOR = 0b00000000000000010000000000000000, // 0x00010000
	THIS_RESOURCE = 0b00000000000000100000000000000000, // 0x00020000
	POOL = 0b00000000000001000000000000000000, // 0x00040000
	CPU = 0b00000000000010000000000000000000, // 0x00080000
	VARIABLE = 0b00000000000100000000000000000000, // 0x00100000

	SPECIAL_RESOURCE_MASK = 0b00000000000111111100000000000000, // 0x001FC000

};
SENSIBLE_ENUM(ResourceCopyTargetType);
static EnumName_t<const wchar_t*, ResourceCopyTargetType> ResourceCopyTargetTypeNames[] = {
	{L"Empty", ResourceCopyTargetType::EMPTY},
	{L"ConstantBuffer", ResourceCopyTargetType::CONSTANT_BUFFER},
	{L"ShaderResource", ResourceCopyTargetType::SHADER_RESOURCE},
	{L"VertexBuffer", ResourceCopyTargetType::VERTEX_BUFFER},
	{L"IndexBuffer", ResourceCopyTargetType::INDEX_BUFFER},
	{L"StreamOutput", ResourceCopyTargetType::STREAM_OUTPUT},
	{L"RenderTarget", ResourceCopyTargetType::RENDER_TARGET},
	{L"DepthStencilTarget", ResourceCopyTargetType::DEPTH_STENCIL_TARGET},
	{L"UnorderedAccessView", ResourceCopyTargetType::UNORDERED_ACCESS_VIEW},
	{L"CustomResource", ResourceCopyTargetType::CUSTOM_RESOURCE},
	{L"IniParams", ResourceCopyTargetType::INI_PARAMS},
	{L"CursorMask", ResourceCopyTargetType::CURSOR_MASK},
	{L"CursorColor", ResourceCopyTargetType::CURSOR_COLOR},
	{L"ThisResource", ResourceCopyTargetType::THIS_RESOURCE},
	{L"Pool", ResourceCopyTargetType::POOL},
	{L"SwapChain", ResourceCopyTargetType::SWAP_CHAIN},
	{L"RealSwapChain", ResourceCopyTargetType::REAL_SWAP_CHAIN},
	{L"FakeSwapChain", ResourceCopyTargetType::FAKE_SWAP_CHAIN},
	{L"CPU", ResourceCopyTargetType::CPU},

	{NULL, ResourceCopyTargetType::INVALID} // End of list marker
};

enum class ResourceCopyTargetEvaluationMode : uint32_t {
	INVALID                = 0b00000000000000000000000000000000,

	// RESOURCE
	RESOURCE               = 0b00000000000000000000000000000001,
	RESOURCE_IDENTITY      = 0b00000000000000000000000000000010,
	RESOURCE_STRIDE        = 0b00000000000000000000000000000100,
	RESOURCE_SOURCE_STRIDE = 0b00000000000000000000000000001000,
	RESOURCE_SIZE          = 0b00000000000000000000000000010000,
	RESOURCE_OFFSET        = 0b00000000000000000000000000100000,
	RESOURCE_REGION_HASH   = 0b00000000000000000000000001000000,
	RESOURCE_SPATIAL_HASH  = 0b00000000000000000000000010000000,
	RESOURCE_REGION        = 0b00000000000000000000000100000000,

	RESOURCE_MASK          = 0b00000000000000000000000111111111,

	// POOL
	POOL_IDENTITY          = 0b00000000000000000000001000000000,
	POOL_SIZE              = 0b00000000000000000000010000000000,
	POOL_INDEX             = 0b00000000000000000000100000000000,
	POOL_FULL_RANGE        = 0b00000000000000000001000000000000,
	POOL_LAST_FRAME        = 0b00000000000000000010000000000000,

	POOL_MASK              = 0b00000000000000000011111000000000,

	// VARIABLE
	VARIABLE               = 0b00000000000000000100000000000000,

	// LAYOUT
	LAYOUT_ELEMENT_FORMAT  = 0b00000000000000001000000000000000,
	LAYOUT_ELEMENT_OFFSET  = 0b00000000000000010000000000000000,

	LAYOUT_MASK            = 0b00000000000000011000000000000000
};
SENSIBLE_ENUM(ResourceCopyTargetEvaluationMode);
static EnumName_t<const wchar_t*, ResourceCopyTargetEvaluationMode> ResourceCopyTargetEvaluationModeNames[] = {
	{L"Resource", ResourceCopyTargetEvaluationMode::RESOURCE},
	{L"ResourceIdentity", ResourceCopyTargetEvaluationMode::RESOURCE_IDENTITY},
	{L"ResourceStride", ResourceCopyTargetEvaluationMode::RESOURCE_STRIDE},
	{L"ResourceSourceStride", ResourceCopyTargetEvaluationMode::RESOURCE_SOURCE_STRIDE},
	{L"ResourceSize", ResourceCopyTargetEvaluationMode::RESOURCE_SIZE},
	{L"ResourceOffset", ResourceCopyTargetEvaluationMode::RESOURCE_OFFSET},
	{L"ResourceRegionHash", ResourceCopyTargetEvaluationMode::RESOURCE_REGION_HASH},
	{L"ResourceSpatialHash", ResourceCopyTargetEvaluationMode::RESOURCE_SPATIAL_HASH},

	{L"PoolIdentity", ResourceCopyTargetEvaluationMode::POOL_IDENTITY},
	{L"PoolSize", ResourceCopyTargetEvaluationMode::POOL_SIZE},
	{L"PoolIndex", ResourceCopyTargetEvaluationMode::POOL_INDEX},
	{L"PoolFullRange", ResourceCopyTargetEvaluationMode::POOL_FULL_RANGE},

	{L"Variable", ResourceCopyTargetEvaluationMode::VARIABLE},

	{L"LayoutElementFormat", ResourceCopyTargetEvaluationMode::LAYOUT_ELEMENT_FORMAT},
	{L"LayoutElementOffset", ResourceCopyTargetEvaluationMode::LAYOUT_ELEMENT_OFFSET},

	{NULL, ResourceCopyTargetEvaluationMode::INVALID} // End of list marker
};

class CommandListExpression;

struct MemberArg
{
	enum class Type {
		None = 0,
		Float,
		Signed,
		Unsigned,
		String,
	};

	Type type = Type::None;

	std::unique_ptr<CommandListExpression> expression;

	std::wstring constant_string;

	//float GetValue(CommandListState* state);
	const std::wstring& GetString() const;
};

enum class IniParserResult : uint8_t {
	TOKEN_NOT_FOUND = 0,
	TOKEN_FOUND = 1,
	SYNTAX_ERROR = 2,
};

//CONCRETE
class SyntaxTarget
{
public:
	static constexpr size_t MAX_MEMBER_ARGS_COUNT = 4;
	std::array<MemberArg, MAX_MEMBER_ARGS_COUNT> member_args{};

private:
	static IniParserResult extract_arguments(const wchar_t* target, size_t& length, const wchar_t*& args_start, const wchar_t*& args_end);
	static bool suffix_equals(const wchar_t* str, size_t len, const wchar_t* suffix, size_t suffix_len);

protected:

	template<typename Mode>
	struct MemberInfo {
		const wchar_t* keyword;
		size_t len;
		Mode mode;
		std::array<MemberArg::Type, MAX_MEMBER_ARGS_COUNT> args{};

		size_t num_args() const
		{
			size_t n = 0;
			while (n < args.size() && args[n] != MemberArg::Type::None)
				++n;
			return n;
		}
	};

	template<typename Mode>
	bool ParseMemberArguments(
		Globals& G,
		const MemberInfo<Mode>& member,
		const wchar_t* args_start,
		const wchar_t* args_end,
		const std::wstring* ini_namespace,
		CommandListScope* scope);

	template<typename Mode, size_t N>
	IniParserResult ParseTargetMember(
		Globals& G,
		const MemberInfo<Mode>(&members)[N],
		const wchar_t*& target,
		size_t& length,
		std::wstring& temp_target,
		Mode& evaluation_mode,
		const std::wstring* ini_namespace,
		CommandListScope* scope);
};

enum class ShaderTargetEvaluationMode : uint32_t {
	INVALID = 0b00000000000000000000000000000000,

	SHADER = 0b00000000000000000000000000000001,

	DCL_CB_MASK = 0b00000000000000000000000000000010,
	DCL_CB_TYPE = 0b00000000000000000000000000000100,
	DCL_CB_SIZE = 0b00000000000000000000000000001000,

	DCL_SRV_MASK = 0b00000000000000000000000000010000,
	DCL_SRV_TYPE = 0b00000000000000000000000000100000,
	DCL_SRV_DIMENSION = 0b00000000000000000000000001000000,
	DCL_SRV_STRIDE = 0b00000000000000000000000010000000,
};
SENSIBLE_ENUM(ShaderTargetEvaluationMode);
//static EnumName_t<const wchar_t*, ShaderTargetEvaluationMode> ShaderTargetEvaluationModeNames[] = {
//	{L"Shader", ShaderTargetEvaluationMode::SHADER},
//
//	{NULL, ShaderTargetEvaluationMode::INVALID} // End of list marker
//};

class ShaderTarget : public SyntaxTarget
{
public:
	using MemberInfo = SyntaxTarget::MemberInfo<ShaderTargetEvaluationMode>;

	ShaderTargetEvaluationMode evaluation_mode = ShaderTargetEvaluationMode::SHADER;
	wchar_t shader_type = L'\0';

	bool ParseTarget(Globals& G, const wchar_t* target, bool is_source, const std::wstring* ini_namespace, CommandListScope* scope);

private:
	IniParserResult ParseTargetMember(Globals& G, const wchar_t*& target, size_t& length, std::wstring& temp_target, const std::wstring* ini_namespace, CommandListScope* scope);
	IniParserResult ParseShaderPipelineSlot(const wchar_t*& target, size_t length, bool is_source);
};

class ResourceCopyTarget : public SyntaxTarget
{
public:
	using MemberInfo = SyntaxTarget::MemberInfo<ResourceCopyTargetEvaluationMode>;

	ResourceCopyTargetType type = ResourceCopyTargetType::INVALID;
	ResourceCopyTargetEvaluationMode evaluation_mode = ResourceCopyTargetEvaluationMode::RESOURCE;
	wchar_t shader_type = L'\0';
	unsigned slot = 0;

	CustomResourcePool* custom_resource_pool = nullptr;
	std::unique_ptr<CommandListExpression> pool_dynamic_index_expression = nullptr;

	bool forbid_view_cache = false;

	bool ParseTarget(Globals& G, const wchar_t* target, bool is_source, const std::wstring* ini_namespace, CommandListScope* scope, bool allow_custom = true);

private:
	IniParserResult ParseTargetPrefix(const wchar_t*& target, size_t& length);
	IniParserResult ParseTargetMember(Globals& G, const wchar_t*& target, size_t& length, std::wstring& temp_target, const std::wstring* ini_namespace, CommandListScope* scope);
	IniParserResult ParseTargetPipelineSlot(const wchar_t*& target, size_t length, bool is_source);
	IniParserResult ParseTargetCustomResource(Globals& G, const wchar_t*& target, size_t length, const std::wstring* ini_namespace, CommandListScope* scope);
	IniParserResult ParseTargetPool(Globals& G, const wchar_t*& target, size_t length, const std::wstring* ini_namespace, CommandListScope* scope, bool is_source);

	//CustomResource* static_custom_resource = nullptr;  // Read access should go via GetCustomResource
	//CommandListVariable* static_pool_variable = nullptr;
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
	virtual bool static_evaluate(float* ret, bool evaluate_variables = false) = 0;
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
	bool static_evaluate(float* ret, bool evaluate_variables = false) override;
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
	FRAME_NUMBER,
	DRAW_NUMBER,
	DISPATCH_NUMBER,
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
	{L"frame_number", ParamOverrideType::FRAME_NUMBER},
	{L"draw_number", ParamOverrideType::DRAW_NUMBER},
	{L"dispatch_number", ParamOverrideType::DISPATCH_NUMBER},
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
	ShaderTarget shader_target;

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

	bool parse_float(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope, size_t& out_length);
	bool parse_ini_param(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope);
	bool parse_variable(Globals& G, const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope);
	bool parse_slot(Globals& G, const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope);
	bool parse_target(Globals& G, const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope);
	bool parse_shader(Globals& G, const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope);
	bool parse_scissor(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope);
	bool parse_ini_keywords(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope);

	//CommandListEvaluatable
	float evaluate() override;
	bool static_evaluate(float* ret, bool evaluate_variables = false) override;
	bool optimise(std::shared_ptr<CommandListEvaluatable>* replacement) override;
};

//CONCRETE
class CommandListExpression {
public:
	std::shared_ptr<CommandListEvaluatable> evaluatable;

	bool parse(Globals& G, const std::wstring* expression, const std::wstring* ini_namespace, CommandListScope* scope);
	float evaluate();
	bool static_evaluate(float* ret, bool evaluate_variables = false);
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

bool ParseCommandListGeneralCommands(Globals& G, const wchar_t* key, std::wstring* val, const std::wstring* ini_namespace,
	const std::wstring& full_path, int line_index, const std::wstring line);
bool ParseCommandListVariableAssignment(Globals& G, const wchar_t* section,
	const wchar_t* key, std::wstring* val, const std::wstring* raw_line,
	CommandList* command_list, CommandList* pre_command_list, CommandList* post_command_list,
	const std::wstring* ini_namespace);
bool ParseCommandListFlowControl(Globals& G, const wchar_t* section, const std::wstring* line,
	CommandList* pre_command_list, CommandList* post_command_list,
	const std::wstring* ini_namespace, const std::wstring& full_path, int line_index);

bool parse_command_list_var_name(Globals& G, const std::wstring& name, const std::wstring* ini_namespace, CommandListVariable** target);
bool valid_variable_name(const std::wstring& name);

enum class SeparatorMode
{
	Comma,
	Space,
};

class CommandArgumentReader
{
public:
	enum class PeekMode
	{
		// Stops at whitespace or commas. Used for individual tokens such as identifiers, variables, enums and numeric values.
		Token,
		// Stops only at commas, allowing embedded whitespace. Used for parsing expressions that may contain spaces.
		Argument,
	};

	CommandArgumentReader(const wchar_t* command, const std::wstring& input, const wchar_t* section, const std::wstring* ini_namespace, CommandListScope* scope) :
		m_command(command),
		m_input(input),
		m_pos(0),
		m_section(section),
		m_ini_namespace(ini_namespace),
		m_scope(scope)
	{
		//LogDebugW(L"Parsing `%ls` arguments: \"%ls\"\n", m_command, m_input.c_str());
	}

	bool PeekToken(std::wstring* token, PeekMode mode = PeekMode::Token);
	bool ConsumeToken();
	bool GetToken(std::wstring* token, PeekMode mode = PeekMode::Token);

	template<typename T>
	bool GetEnum(const EnumName_t<const wchar_t*, T>* names, T invalid, T* out);
	bool GetVariable(Globals& G, CommandListVariable*& out, bool is_source, PeekMode mode = PeekMode::Token);
	bool GetTarget(Globals& G, ResourceCopyTarget* out, bool is_source, PeekMode mode = PeekMode::Token);
	bool GetFloat(float* out);
	bool GetExpression(Globals& G, std::unique_ptr<CommandListExpression>* out);

	bool ConsumeSeparator(SeparatorMode separator_mode);
	bool Finished();

	const std::wstring& Error() const { return m_error; }
	size_t ErrorPosition() const { return m_error_pos; }
	bool Fail() const;

private:
	const wchar_t* m_section;
	const std::wstring* m_ini_namespace;
	CommandListScope* m_scope;
	const wchar_t* m_command;

	const std::wstring& m_input;
	size_t m_pos;

	std::wstring m_peek_token;
	size_t m_peek_start_pos = 0;
	size_t m_peek_end_pos = 0;
	bool m_has_peek_token = false;
	PeekMode m_peek_mode = PeekMode::Token;

	std::wstring m_error;
	size_t m_error_pos = 0;

	void SetError(const std::wstring& error, size_t pos);
	void SkipWhitespace();

	// token_end_pos points to the first character after the token, before any separators or whitespace.
	bool GetTokenInternal(size_t pos, std::wstring* token, size_t* token_trimmed_end_pos = nullptr, PeekMode mode = PeekMode::Token);
};