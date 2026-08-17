#include "Globals.h"
#include "CommandList.h"
#include "IniHandler.h"
#include <windows.h>

#include <algorithm>


static bool AddCommandToList(CommandListCommand* command,
	CommandList* explicit_command_list,
	CommandList* sensible_command_list,
	CommandList* pre_command_list,
	CommandList* post_command_list,
	const wchar_t* section,
	const wchar_t* key, std::wstring* val)
{
	if (section && key) {
		command->ini_line = L"[" + std::wstring(section) + L"] " + std::wstring(key);
		if (val)
			command->ini_line += L" = " + *val;
	}

	if (explicit_command_list) {
		explicit_command_list->commands.push_back(std::shared_ptr<CommandListCommand>(command));
	}
	else if (sensible_command_list) {
		sensible_command_list->commands.push_back(std::shared_ptr<CommandListCommand>(command));
	}
	else {
		std::shared_ptr<CommandListCommand> p(command);
		pre_command_list->commands.push_back(p);
		if (post_command_list)
			post_command_list->commands.push_back(p);
	}

	return true;
}

int find_local_variable(const std::wstring& name, CommandListScope* scope, CommandListVariable** var)
{
	CommandListScope::iterator it;

	if (!scope)
		return false;

	if (name.length() < 2 || name[0] != L'$')
		return false;

	for (it = scope->begin(); it != scope->end(); it++) {
		auto match = it->find(name);
		if (match != it->end()) {
			*var = match->second;
			return true;
		}
	}

	return false;
}

bool declare_local_variable(Globals& G, const wchar_t* section, std::wstring& name,
	CommandList* pre_command_list, const std::wstring* ini_namespace)
{
	CommandListVariable* var = NULL;

	if (!valid_variable_name(name)) {
		//wprintf(L"[WARNING] Illegal local variable name:  \"%ls\" - [%ls]\n", name.c_str(), section);
		return false;
	}

	if (find_local_variable(name, pre_command_list->scope, &var)) {
		//wprintf(L"[WARNING] Illegal redeclaration of local variable \"%ls\" - [%ls]\n", name.c_str(), section);
		return false;
	}

	if (parse_command_list_var_name(G, name, ini_namespace, &var)) {
		//wprintf(L"Local \"%ls\" masks a global variable with the same name - [%ls]\n", name.c_str(), section);
	}

	pre_command_list->static_vars.emplace_front(name, 0.0f, VariableFlags::NONE);
	pre_command_list->scope->front()[name] = &pre_command_list->static_vars.front();

	return true;
}

static bool ParseRunShader(Globals& G, std::wstring* val, const std::wstring* ini_namespace)
{
	//Only to determine if specified customshader section is exist somewhere
	ExplicitCommandListSections::iterator shader;
	std::wstring namespaced_section;

	std::wstring shader_section(val->c_str());

	shader = G.customShaderSections.end();
	if (get_namespaced_section_name_lower(&shader_section, ini_namespace, &namespaced_section))
		shader = G.customShaderSections.find(namespaced_section);
	if (shader == G.customShaderSections.end())
		shader = G.customShaderSections.find(shader_section);
	if (shader == G.customShaderSections.end())
	{
		return false;
	}

	return true;
}

static bool FindExplicitCommandListSection(Globals& G, const wchar_t* val, const std::wstring* ini_namespace)
{
	ExplicitCommandListSections::iterator it;

	std::wstring namespaced_section;

	// We need value in lower case so our keys will be consistent in the
	// unordered_map. ParseCommandList will have already done this, but the
	// Key/Preset parsing code will not have, and rather than require it to
	// we do it here:
	std::wstring section_id(val);
	std::transform(section_id.begin(), section_id.end(), section_id.begin(), ::towlower);

	it = G.explicitCommandListSections.end();
	if (get_namespaced_section_name_lower(&section_id, ini_namespace, &namespaced_section))
		it = G.explicitCommandListSections.find(namespaced_section);
	if (it == G.explicitCommandListSections.end())
		it = G.explicitCommandListSections.find(section_id);
	if (it == G.explicitCommandListSections.end())
		//return nullptr;
		return false;

	//return &it->second;
	return true;
}

bool ParseRunExplicitCommandList(Globals& G, std::wstring* val, const std::wstring* ini_namespace)
{
	//Only to determine if specified CommandList section is exist somewhere
	
	//RunExplicitCommandList* operation = new RunExplicitCommandList();

	//operation->command_list_section = FindExplicitCommandListSection(G, val->c_str(), ini_namespace);
	return FindExplicitCommandListSection(G, val->c_str(), ini_namespace);

	//if (!operation->command_list_section)
		//goto bail;

	//// If the user indicated an explicit command list we will run the pre
	//// and post lists of the target list together. This tends to make
	//// things a little less surprising for "post run = CommandListFoo"
	//if (explicit_command_list)
	//	operation->run_pre_and_post_together = true;

	//return AddCommandToList(operation, explicit_command_list, NULL, pre_command_list, post_command_list, section, key, val);

//bail:
	//delete operation;
	//return false;
}

static std::wstring get_between_first_and_last_backslash(const std::wstring& input)
{
	const size_t first = input.find(L'\\');
	const size_t last = input.rfind(L'\\');

	if (first == std::wstring::npos ||
		last == std::wstring::npos ||
		first >= last)
	{
		return std::wstring();
	}

	return input.substr(first + 1, last - first - 1);
}

bool ParseCommandListGeneralCommands(Globals& G, const wchar_t* key, std::wstring* val, const std::wstring* ini_namespace,
	const std::wstring& full_path, int line_index, const std::wstring line)
{
	//only check for "run" key
	if (!wcscmp(key, L"run")) {
		if (!wcsncmp(val->c_str(), L"customshader", 12) || !wcsncmp(val->c_str(), L"builtincustomshader", 19))
		{
			bool success = ParseRunShader(G, val, ini_namespace);

			//If a mod is trying to run known lib, but that known lib is not present
			if (!success && val != nullptr)
			{
				//Keep in mind that the known lib namespace is on the value of "run = " and not ini_namespace in this function param
				std::wstring called_namespace = get_between_first_and_last_backslash(val->c_str());

				if (!called_namespace.empty())
				{
					auto item = G.known_lib_namespaces.find(called_namespace);
					if (item != G.known_lib_namespaces.end()) {
						//Only if haven't tracked yet && the namespace really not exist globally
						auto non_exist = G.already_known_nonexist_lib.find(called_namespace);
						auto namespace_not_exist = G.global_tracked_namespaces.find(called_namespace);
						if (non_exist == G.already_known_nonexist_lib.end() && namespace_not_exist == G.global_tracked_namespaces.end())
						{
							G.already_known_nonexist_lib.insert(called_namespace);
							G.errored_lines.insert(ErroredLine{
							full_path,
							line_index,
							line,
							L"NON EXISTENT LIB:" + called_namespace
								});
						}
					}
				}
			}

			return success;
		}

		if (!wcsncmp(val->c_str(), L"commandlist", 11) || !wcsncmp(val->c_str(), L"builtincommandlist", 18))
		{
			bool success = ParseRunExplicitCommandList(G, val, ini_namespace);

			//If a mod is trying to run known lib, but that known lib is not present
			if (!success && val != nullptr)
			{
				//Keep in mind that the known lib namespace is on the value of "run = " and not ini_namespace in this function param
				std::wstring called_namespace = get_between_first_and_last_backslash(val->c_str());

				if (!called_namespace.empty())
				{
					auto item = G.known_lib_namespaces.find(called_namespace);
					if (item != G.known_lib_namespaces.end()) {
						//Only if haven't tracked yet && the namespace really not exist globally
						auto non_exist = G.already_known_nonexist_lib.find(called_namespace);
						auto namespace_not_exist = G.global_tracked_namespaces.find(called_namespace);
						if (non_exist == G.already_known_nonexist_lib.end() && namespace_not_exist == G.global_tracked_namespaces.end())
						{
							G.already_known_nonexist_lib.insert(called_namespace);
							G.errored_lines.insert(ErroredLine{
							full_path,
							line_index,
							line,
							L"NON EXISTENT LIB:" + called_namespace
								});
						}
					}
				}
			}

			return success;
		}
	}

	return false;
}

void CommandList::clear()
{
	commands.clear();
	static_vars.clear();
}

CommandList* CommandList::ResolveCommandList()
{
	return source_command_list ? source_command_list->ResolveCommandList() : this;
}

bool CommandList::noop()
{
	CommandList* resolved = ResolveCommandList();

	if (resolved->runtime_populated)
		return false;

	return resolved->commands.empty();
}

float CommandListOperand::evaluate()
{
	//This project is to specifically parse & static evaluate included files, and parse if/elif statement.
	//But not to evaluate if/elif statement

	//DUMMY
	return 1;
}

bool CommandListOperand::static_evaluate(float* ret, bool evaluate_variables)
{
	switch (type) {
	case ParamOverrideType::VALUE:
		*ret = val;
		return true;
	case ParamOverrideType::VARIABLE:
		if (evaluate_variables) {
			*ret = *var_ftarget;
			return true;
		}
		return false;
	case ParamOverrideType::TIME:
		if (evaluate_variables) {
			//don't care
			//*ret = (float)G->gTime;
			return true;
		}
		return false;
	case ParamOverrideType::FRAME_NUMBER:
		if (evaluate_variables) {
			//don't care
			//*ret = (float)G->frame_no;
			return true;
		}
		return false;
	case ParamOverrideType::HUNTING:
	case ParamOverrideType::FRAME_ANALYSIS:

		//It's also used to determine included file, in preamble "condition = "
		//DONT CARE

		if (/*G->hunting == HUNTING_MODE_DISABLED*/false) {
			*ret = 0;
			return true;
		}
		break;
	case ParamOverrideType::SLI:
		*ret = 0.0;
		return true;
	case ParamOverrideType::STEREO_ACTIVE:
		*ret = 0.0;
		return true;
	case ParamOverrideType::STEREO_AVAILABLE:
		*ret = 0.0;
		return true;
	}

	return false;
}

bool CommandListOperand::optimise(std::shared_ptr<CommandListEvaluatable>* replacement)
{
	if (type == ParamOverrideType::VALUE)
		return false;

	if (!static_evaluate(&val))
		return false;

	/*printf("Statically evaluated %S as %f\n",
		lookup_enum_name(ParamOverrideTypeNames, type), val);*/

	type = ParamOverrideType::VALUE;
	return true;
}

class CommandListSyntaxError : public std::exception
{
public:
	std::wstring msg;
	size_t pos;

	CommandListSyntaxError(std::wstring msg, size_t pos) :
		msg(msg), pos(pos)
	{
	}
};

enum class OptionalChars : uint8_t
{
	NONE = 0b0000,
	HYPHEN = 0b0001,
	PERIOD = 0b0010,
	ALL = 0b1111,
};
SENSIBLE_ENUM(OptionalChars);

static inline bool is_identifier_char(wchar_t c, OptionalChars identifier_flags)
{
	if ((c >= L'a' && c <= L'z') || (c >= L'0' && c <= L'9') || c == L'_')
		return true;

	if ((identifier_flags & OptionalChars::HYPHEN) && c == L'-')
		return true;

	if ((identifier_flags & OptionalChars::PERIOD) && c == L'.')
		return true;

	return false;
}

static size_t FindIdentifierTokenEnd(const std::wstring& str, const size_t start = 0, OptionalChars identifier_flags = OptionalChars::NONE)
{
	for (size_t i = start; i < str.size(); ++i)
		{
		wchar_t c = str[i];

		// Test for valid identifier char.
		if (!is_identifier_char(c, identifier_flags))
			return i;
	}

	return str.size();
}

enum class NamespaceState : uint8_t
{
	Waiting,            // No namespace prefix encountered yet.
	ParsingParent,      // Inside the first namespace segment (between the first and second '\').
	ParsingChild,       // Inside nested namespace path segments after the parent segment.
	ParsingIdentifier,  // Final segment; validation is delegated to the caller.
};

class NamespaceScanner
{
public:
	bool Consume(wchar_t c, const std::wstring& str, size_t pos)
	{
		switch (state_)
		{
		case NamespaceState::Waiting:
			if (c == L'\\')
			{
				state_ = NamespaceState::ParsingParent;
				return true;
			}
			return false;

		case NamespaceState::ParsingParent:
			if (c == L'\\')
			{
				state_ = NamespaceState::ParsingChild;
				return true;
			}

			// The parent namespace segment may contain arbitrary characters.
			return true;

		case NamespaceState::ParsingChild:
			// Allow path-like namespaces (e.g. \path\to\mod.ini\var_name).
			if (c != L'\\')
			{
				// Nested namespace path segments allow identifier characters plus periods.
				// Hyphens are excluded because they may be interpreted as the minus operator.
				return is_identifier_char(c, OptionalChars(OptionalChars::PERIOD));
			}

			// A separator may either start another namespace segment or precede the final identifier segment.
					// Perform only a broad boundary check here; the caller performs the final syntax validation.
			if (IsFinalSegmentCandidate(str, pos + 1))
			{
				state_ = NamespaceState::ParsingIdentifier;
				return true;
			}

			// Another nested path segment follows.
			return true;

		case NamespaceState::ParsingIdentifier:
			// The remaining characters belong to the final identifier and are validated by the caller's identifier scanner.
			return false;
		}

		return false;
	}

private:
	static bool IsFinalSegmentCandidate(const std::wstring& str, size_t start)
	{
		if (start >= str.size())
			return false;

		for (size_t i = start; i < str.size(); ++i)
		{
			wchar_t c = str[i];

			if (c == L'\\')
				return false;

			// Broad token-boundary check only. Actual syntax validation is performed later by the dedicated parser.
			if (!is_identifier_char(c, OptionalChars::ALL))
				return false;
		}

		return true;
	}

private:
	NamespaceState state_ = NamespaceState::Waiting;
};

static size_t FindVariableTokenEnd(const std::wstring& str, size_t start = 0)
{
	// Scans a variable token and returns the end position after performing minimal syntax validation:
	// 1. Ensures identifier characters match `[a-z_0-9]+`.
	// 2. Ensures an optional namespace is properly closed while allowing arbitrary characters in the parent namespace segment.
	NamespaceScanner namespace_scanner;

	for (size_t i = start; i < str.size(); ++i)
	{
		wchar_t c = str[i];

		// Consume an optional leading namespace (e.g. "\namespace\" or "\path\like\namespace\").
		if (namespace_scanner.Consume(c, str, i))
			continue;

		// The remaining characters must be valid identifier characters.
		if (!is_identifier_char(c, OptionalChars::NONE))
			return i;
	}

	return str.size();
}

static size_t FindResourceCopyTargetTokenEnd(const std::wstring& str, size_t start = 0)
{
	// Scans a resource copy target token and returns the end position after performing minimal syntax validation:
	// 1. Ensures identifier characters match `[a-z_-.0-9]+`.
	// 2. Ensures an optional namespace is properly closed, while allowing arbitrary characters in the namespace name.
	// 3. Ensures optional bracket expressions are properly balanced while allowing arbitrary characters inside them.
	// 4. Recognizes the optional member access operator (`->`) as part of the token.
	// 
	// Note: Token prefixes ('@', '#', '$') are handled by the caller, so scanning begins after the prefix (`start = 1`).
	// 
	// Example inputs:
	//   ResourceFoo
	//   ResourceFoo->Size
	//   ResourceFoo->HashRegion($offset, $size)
	//   PoolFoo[$id]
	//   PoolFoo[$id]->ElementFormat(BLENDINDICES, 0)
	std::vector<wchar_t> brackets;

	NamespaceScanner namespace_scanner;

	for (size_t i = start; i < str.size(); ++i)
	{
		wchar_t c = str[i];

		if (!brackets.empty())
		{
			// Inside (...) or [...], accept all characters while tracking
			// nested bracket pairs so the expression is skipped as a whole.
			if (c == L'(')
				brackets.push_back(L')');
			else if (c == L'[')
				brackets.push_back(L']');
			else if (c == brackets.back())
				brackets.pop_back();

			continue;
		}

		// Outside of bracketed expressions.

		// Consume an optional leading namespace (e.g. "\namespace\" or "\path\like\namespace\").
		if (namespace_scanner.Consume(c, str, i))
			continue;

		// Start of a bracketed expression.
		if (c == L'(')
		{
			brackets.push_back(L')');
			continue;
		}
		if (c == L'[')
		{
			brackets.push_back(L']');
			continue;
		}

		// Allow the member access operator ("->") as part of the token.
		if (c == L'-')
		{
			if (i + 1 < str.size() && str[i + 1] == L'>')
			{
				++i; // Consume '>'.
				continue;
			}
		}

		// The remaining characters must be valid identifier characters.
		if (!is_identifier_char(c, OptionalChars(OptionalChars::HYPHEN | OptionalChars::PERIOD)))
			return i;
	}

	if (!brackets.empty())
		throw CommandListSyntaxError(L"Unterminated bracket expression", str.size());

	return str.size();
}

inline bool ParseFloatToken(const std::wstring& input, float& out, size_t& length)
{
	// Binary literal.
	if (input.size() >= 3 && input[0] == L'0' && input[1] == L'b')
	{
		std::uint64_t value;
		if (!ParseBinaryLiterals(input, 2, value, length))
			return false;

		out = static_cast<float>(value);
		length += 2; // Include the "0b" prefix.
		return true;
	}

	wchar_t* end = nullptr;

	errno = 0;
	out = std::wcstof(input.c_str(), &end);

	if (end == input.c_str())
		return false;

	length = static_cast<std::size_t>(end - input.c_str());

	if (errno == ERANGE)
	{
		out = std::signbit(out)
			? -std::numeric_limits<float>::infinity()
			: std::numeric_limits<float>::infinity();
	}

	return true;
}

#pragma region CommandArgumentReader

bool CommandArgumentReader::PeekToken(std::wstring* token, PeekMode mode)
{
	if (!m_has_peek_token || m_peek_mode != mode)
	{
		// Cache the last peeked token so PeekToken() can be called repeatedly
		// without rescanning the input until ConsumeToken() advances the parser.
		m_peek_start_pos = m_pos;
		m_peek_mode = mode;

		if (!GetTokenInternal(m_pos, &m_peek_token, &m_peek_end_pos, mode))
		{
			m_peek_start_pos = 0;
			m_peek_end_pos = 0;
			return false;
		}

		m_has_peek_token = true;
	}

	*token = m_peek_token;
	return true;
}

bool CommandArgumentReader::ConsumeToken()
{
	if (!m_has_peek_token)
	{
		if (!GetTokenInternal(m_pos, &m_peek_token, &m_peek_end_pos))
			return false;
	}

	m_pos = m_peek_end_pos;

	m_has_peek_token = false;
	m_peek_token.clear();
	m_peek_start_pos = 0;
	m_peek_end_pos = 0;

	return true;
}

bool CommandArgumentReader::GetToken(std::wstring* token, PeekMode mode)
{
	if (!PeekToken(token, mode))
		return false;

	ConsumeToken();

	//LogDebugW(L"  Token: '%ls'\n", token->c_str());

	return true;
}

template <typename T>
bool CommandArgumentReader::GetEnum(const EnumName_t<const wchar_t*, T>* names, T invalid, T* out)
{
	wstring token;

	if (!PeekToken(&token))
		return false;

	bool found;

	*out = lookup_enum_val(const_cast<EnumName_t<const wchar_t*, T>*>(names), token.c_str(), invalid, &found);

	if (!found)
	{
		SetError(L"Unknown option `" + token + L"`", m_peek_start_pos);
		return false;
	}

	ConsumeToken();

	//LogDebugW(L"  Enum: '%ls'\n", token.c_str());

	return true;
}

bool CommandArgumentReader::GetVariable(Globals& G, CommandListVariable*& out, bool is_source)
{
	std::wstring token;

	if (!PeekToken(&token))
		return false;

	if (token[0] != L'$')
	{
		SetError(L"Expected variable, got: " + token, m_peek_start_pos);
		return false;
	}

	if (FindVariableTokenEnd(token, 1) != token.size())
	{
		SetError(L"Invalid variable: " + token, m_peek_start_pos);
		return false;
	}

	if ((!(m_scope && find_local_variable(token, m_scope, &out))) &&
		!parse_command_list_var_name(G, token, m_ini_namespace, &out))
	{
		SetError(!m_scope
			? L"Unknown global variable: " + token
			: L"Unknown variable: " + token,
			m_peek_start_pos);
		return false;
	}

	if (out->flags & VariableFlags::LOCKED) {
		SetError(L"Unable to assign value to <locked> variable: " + token, m_peek_start_pos);
		return false;
	}

	ConsumeToken();

	//LogDebugW(L"  Variable: '%ls'\n", token.c_str());

	return true;
}

bool CommandArgumentReader::GetTarget(Globals& G, ResourceCopyTarget* out, bool is_source)
{
	std::wstring token;

	if (!PeekToken(&token))
		return false;

	bool has_prefix = token[0] == L'$' || token[0] == L'@' || token[0] == L'#';

	if (FindResourceCopyTargetTokenEnd(token, has_prefix ? 1 : 0) != token.size())
	{
		SetError(L"Invalid target: " + token, m_peek_start_pos);
		return false;
	}

	if (!out->ParseTarget(G, token.c_str(), is_source, m_ini_namespace, m_scope))
	{
		SetError(L"Unknown target: " + token, m_peek_start_pos);
		return false;
	}

	ConsumeToken();

	//LogDebugW(L"  ResourceCopyTarget: '%ls'\n", token.c_str());

	return true;
}

bool CommandArgumentReader::GetFloat(float* out)
{
	std::wstring token;

	if (!PeekToken(&token))
		return false;

	size_t len;

	if (!ParseFloatToken(token, *out, len) || len != token.size())
	{
		SetError(L"Invalid float: " + token, m_peek_start_pos);
		return false;
	}

	ConsumeToken();

	//LogDebugW(L"  Float: '%ls'\n", token.c_str());

	return true;
}

bool CommandArgumentReader::GetExpression(Globals& G, std::unique_ptr<CommandListExpression>* out)
{
	std::wstring token;

	if (!PeekToken(&token, PeekMode::Argument))
		return false;

	auto expression = std::make_unique<CommandListExpression>();

	if (!expression->parse(G, &token, m_ini_namespace, m_scope))
		return false;

	ConsumeToken();

	*out = std::move(expression);

	//LogDebugW(L"  Expression: '%ls'\n", token.c_str());

	return true;
}

bool CommandArgumentReader::ConsumeSeparator(SeparatorMode separator_mode)
{
	// Consumes the separator expected between arguments.
	// The parser does not infer separator style; callers specify whether
	// arguments are whitespace- or comma-separated.
	switch (separator_mode)
	{
	case SeparatorMode::Comma:
	{
		size_t pos = m_pos;

		SkipWhitespace();

		if (m_pos >= m_input.size() || m_input[m_pos] != L',')
		{
			SetError(L"Expected ',' between arguments", pos);
			return false;
		}

		m_pos++;

		SkipWhitespace();

		return true;
	}

	case SeparatorMode::Space:
	{
		size_t start = m_pos;

		SkipWhitespace();

		if (m_pos == start)
		{
			SetError(L"Expected whitespace between arguments", start);
			return false;
		}

		return true;
	}
	}

	SetError(L"Internal parser error", m_pos);
	return false;
}

bool CommandArgumentReader::Finished()
{
	size_t pos = m_pos;

	while (pos < m_input.size())
	{
		wchar_t c = m_input[pos];

		if (c != L' ' && c != L'\t' && c != L'\r' && c != L'\n')
		{
			SetError(L"Unexpected trailing input", pos);
			return false;
		}

		pos++;
	}

	return true;
}

bool CommandArgumentReader::Fail() const
{
	const wchar_t* error = m_error.empty() ? L"Unknown syntax error" : m_error.c_str();

	std::wstring prefix = L"Syntax Error in `" + std::wstring(m_command) + L"` command: `";

	/*LogOverlayW(LOG_WARNING_MONOSPACE,
		L"%ls%ls`\n"
		L"%*s^ %ls\n"
		L"  [%ls] @ [%ls]\n",
		prefix.c_str(), m_input.c_str(),
		(int)(min(prefix.size() + m_error_pos, prefix.size() + m_input.size())), L"", error,
		m_section, m_ini_namespace->c_str());*/

	return false;
}

void CommandArgumentReader::SetError(const std::wstring& error, size_t pos)
{
	// Preserve the first syntax error encountered, since subsequent
	// parsing failures are typically a consequence of the original one.
	if (!m_error.empty())
		return;

	m_error = error;
	m_error_pos = pos;
}

void CommandArgumentReader::SkipWhitespace()
{
	while (m_pos < m_input.size())
	{
		wchar_t c = m_input[m_pos];

		if (c != L' ' && c != L'\t' && c != L'\r' && c != L'\n')
			break;

		m_pos++;
	}
}

bool CommandArgumentReader::GetTokenInternal(size_t pos, std::wstring* token, size_t* token_trimmed_end_pos, PeekMode mode)
{
	// Scan until the next argument delimiter while respecting:
	//
	//   - quoted strings
	//   - escaped characters (namespaces)
	//   - nested [] blocks
	//   - nested () blocks
	//
	// Delimiters only terminate a token when not inside any nested structure.

	// token_trimmed_end_pos receives the position immediately after the
	// token, excluding trailing whitespace but before any separator.

	while (pos < m_input.size() && iswspace(m_input[pos]))
		pos++;

	size_t start = pos;

	int square_depth = 0;
	int paren_depth = 0;
	bool escaped = false;
	bool quoted = false;

	while (pos < m_input.size())
	{
		wchar_t c = m_input[pos];

		if (escaped)
		{
			escaped = false;
			pos++;
			continue;
		}

		if (c == L'\\')
		{
			escaped = true;
			pos++;
			continue;
		}

		if (c == L'"')
		{
			quoted = !quoted;
			pos++;
			continue;
		}

		if (!quoted)
		{
			switch (c)
			{
			case L'[':
				square_depth++;
				break;

			case L']':
				if (square_depth > 0)
					square_depth--;
				break;

			case L'(':
				paren_depth++;
				break;

			case L')':
				if (paren_depth > 0)
					paren_depth--;
				break;

			default:
				if (square_depth == 0 && paren_depth == 0)
				{
					// Exit the scan while sharing the validation and trimming logic below.
					if (mode == PeekMode::Token && (c == L',' || iswspace(c)))
						goto end;

					if (mode == PeekMode::Argument && c == L',')
						goto end;
				}
			}
		}

		pos++;
	}

end:

	if (quoted)
	{
		SetError(L"Unterminated string literal", pos);
		return false;
	}

	if (square_depth || paren_depth)
	{
		SetError(L"Unbalanced brackets", pos);
		return false;
	}

	size_t end = pos;

	while (end > start && iswspace(m_input[end - 1]))
		end--;

	if (end == start)
	{
		SetError(L"Expected argument", start);
		return false;
	}

	*token = m_input.substr(start, end - start);

	if (token_trimmed_end_pos)
		*token_trimmed_end_pos = end;

	return true;
}

#pragma endregion CommandArgumentReader

static const wchar_t* function_tokens[] = {
	L"countbits",

	L"sin",
	L"cos",
	L"tan",
	L"asin",
	L"acos",
	L"atan",

	L"abs",
	L"sign",
	L"ceil",
	L"floor",
	L"trunc",
	L"round",
	L"frac",

	L"sqrt",
	L"rsqrt",

	L"exp",
	L"exp2",
	L"log",
	L"log2",

	L"saturate",

	L"random",
	L"noise"
};

static const wchar_t* operator_tokens[] = {
	// Three character tokens first:
	L"===", L"!==",
	// Two character tokens next:
	L"<<", L">>", L"==", L"!=", L"//", L"<=", L">=", L"&&", L"||", L"**",
	// Single character tokens last:
	L"(", L")", L"!", L"~", L"&", L"|", L"^", L"*", L"/", L"%", L"+", L"-", L"<", L">",
};

static void tokenise(Globals& G, const std::wstring* expression, CommandListSyntaxTree* tree, const std::wstring* ini_namespace, CommandListScope* scope)
{
	const std::wstring& expr = *expression;

	ResourceCopyTarget texture_filter_target;
	std::shared_ptr<CommandListOperand> operand;
	std::wstring token;
	std::wstring remain;
	size_t pos = 0;
	size_t friendly_pos = 0;
	int i;
	bool last_was_operand = false;

	//printf("    Tokenising \"%S\"\n", expr.c_str());

	// TODO: C++20 refactor.
	// This rewrite stays close to the old (mostly missing) architecture to simplify transition.
	// Proper refactor should implement Lexer and CommandParser classes and use `std::wstring_view` once it's available.
	while (true)
	{
		pos = expr.find_first_not_of(L" \t", pos);
		if (pos == std::wstring::npos)
			return;
		
		friendly_pos = pos;

		remain = expr.substr(pos);

		bool matched = false;

		for (i = 0; i < ARRAYSIZE(operator_tokens); i++)
		{
			size_t len = wcslen(operator_tokens[i]);

			if (remain.compare(0, len, operator_tokens[i]) == 0)
			{
				//LogDebug("      Operator: \"%S\"\n", remain.substr(0, len).c_str());

				tree->tokens.emplace_back(std::make_shared<CommandListOperatorToken>(friendly_pos, remain.substr(0, len)));

				pos += len;
				last_was_operand = false;
				matched = true;
				break;
			}
		}

		if (matched)
			continue;

		// Functions:
		for (i = 0; i < ARRAYSIZE(function_tokens); i++)
		{
			size_t len = wcslen(function_tokens[i]);

			if (remain.size() > len && remain.compare(0, len, function_tokens[i]) == 0 && remain[len] == L'(')
			{
				//LogDebug("      Function: \"%S\"\n", function_tokens[i]);

				tree->tokens.emplace_back(std::make_shared<CommandListOperatorToken>(friendly_pos, remain.substr(0, len)));

				pos += len;
				last_was_operand = false;
				matched = true;
				break;
			}
		}

		if (matched)
			continue;

		operand = std::make_shared<CommandListOperand>(friendly_pos, token);

		// Numeric Literal
		if (std::isdigit(remain[0]))
		{
			// - Supported inputs: DECIMAL 0.0001, HEX 0x0001, BIN 0b0001.
			// - Must tokenise subtraction operation first.
			// - Static optimisation will merge unary negation.
			// - Special literals (inf, nan, etc) are being parsed last.
			size_t len = remain.size();

			if (operand->parse_float(&remain, ini_namespace, scope, len))
			{
				token = remain.substr(0, len);
				//LogDebug("      Float: \"%S\"\n", token.c_str());
				pos += len;
				goto import_operand;
			}

			throw CommandListSyntaxError(L"Float not recognized: " + remain, friendly_pos);
		}

		bool has_variable_prefix = remain[0] == L'$';

		// Variable
		if (has_variable_prefix)
		{
			size_t len = FindVariableTokenEnd(remain, 1);

			// Skip handling variable pool (e.g. `$PoolFoo[0]`).
			if (len && len < remain.size() && remain[len] == L'[')
				len = 0;

			if (len)
			{
				token = remain.substr(0, len);

				if (operand->parse_variable(G, &token, ini_namespace, scope))
				{
					//LogDebug("      Variable: \"%S\"\n", token.c_str());
					pos += len;
					goto import_operand;
				}

				throw CommandListSyntaxError(L"Variable not recognized: " + remain, friendly_pos);
			}
		}

		bool has_prefix = has_variable_prefix || remain[0] == L'@' || remain[0] == L'#';

		// ResourceCopyTarget
		{
			size_t len = FindResourceCopyTargetTokenEnd(remain, has_prefix ? 1 : 0);

			if (len)
			{
				token = remain.substr(0, len);

				if (operand->parse_target(G, &token, ini_namespace, scope))
				{
					//LogDebugW(L"      ResourceCopyTarget: \"%ls\"\n", token.c_str());
					pos += len;
					goto import_operand;
				}
			}
		}

		// Other Tokens
		if (!has_prefix)
		{
			size_t len = FindIdentifierTokenEnd(remain, 0, OptionalChars::NONE);

			if (len)
			{
				token = remain.substr(0, len);

				if (operand->parse_ini_param(&token, ini_namespace, scope))
				{
					//LogDebug("      IniParam: \"%S\"\n", token.c_str());
					pos += len;
					goto import_operand;
				}

				else if (operand->parse_ini_keywords(&token, ini_namespace, scope))
				{
					//LogDebug("      IniKeyword: \"%S\"\n", token.c_str());
					pos += len;
					goto import_operand;
				}

				else if (operand->parse_shader(&token, ini_namespace, scope))
				{
					//LogDebug("      Shader: \"%S\"\n", token.c_str());
					pos += len;
					goto import_operand;
				}

				else if (operand->parse_scissor(&token, ini_namespace, scope))
				{
					//LogDebug("      Scissor: \"%S\"\n", token.c_str());
					pos += len;
					goto import_operand;
				}
			}
		}

		// Special Float:
		{
			size_t len = remain.size();

			if (operand->parse_float(&remain, ini_namespace, scope, len))
			{
				token = remain.substr(0, len);
				//LogDebug("      Float: \"%S\"\n", token.c_str());
				pos += len;
				goto import_operand;
			}
		}

		// Operand parsing failed.
		throw CommandListSyntaxError(L"Unrecognised identifier: " + token, friendly_pos);

	import_operand:

		tree->tokens.emplace_back(std::move(operand));

		if (last_was_operand)
		{
			throw CommandListSyntaxError(L"Unexpected identifier", friendly_pos);
		}

		last_was_operand = true;
	}
}

static void group_parenthesis(CommandListSyntaxTree* tree)
{
	CommandListSyntaxTree::Tokens::iterator i;
	CommandListSyntaxTree::Tokens::reverse_iterator rit;
	CommandListOperatorToken* rbracket, * lbracket;
	std::shared_ptr<CommandListSyntaxTree> inner;

	for (i = tree->tokens.begin(); i != tree->tokens.end(); i++) {
		rbracket = dynamic_cast<CommandListOperatorToken*>(i->get());
		if (rbracket && !rbracket->token.compare(L")")) {
			for (rit = std::reverse_iterator<CommandListSyntaxTree::Tokens::iterator>(i); rit != tree->tokens.rend(); rit++) {
				lbracket = dynamic_cast<CommandListOperatorToken*>(rit->get());
				if (lbracket && !lbracket->token.compare(L"(")) {
					inner = std::make_shared<CommandListSyntaxTree>(lbracket->token_pos);
					inner->tokens.assign(rit.base(), i);
					i = tree->tokens.erase(rit.base() - 1, i + 1);
					i = tree->tokens.insert(i, std::move(inner));
					goto continue_rbracket_search;
				}
			}
			throw CommandListSyntaxError(L"Unmatched )", rbracket->token_pos);
		}
	continue_rbracket_search: false;
	}

	for (i = tree->tokens.begin(); i != tree->tokens.end(); i++) {
		lbracket = dynamic_cast<CommandListOperatorToken*>(i->get());
		if (lbracket && !lbracket->token.compare(L"("))
			throw CommandListSyntaxError(L"Unmatched (", lbracket->token_pos);
	}
}

#define DEFINE_OPERATOR(name, operator_pattern, fn) \
class name##T : public CommandListOperator { \
public: \
	name##T( \
			std::shared_ptr<CommandListToken> lhs, \
			CommandListOperatorToken &t, \
			std::shared_ptr<CommandListToken> rhs \
		) : CommandListOperator(lhs, t, rhs) \
	{} \
	static const wchar_t* pattern() { return L##operator_pattern; } \
	float evaluate(float lhs, float rhs) override { return (fn); } \
}; \
static CommandListOperatorFactory<name##T> name;

DEFINE_OPERATOR(unary_not_operator, "!", (!rhs));
DEFINE_OPERATOR(bitwise_not_operator, "~", (~(int32_t)rhs));
DEFINE_OPERATOR(unary_plus_operator, "+", (+rhs));
DEFINE_OPERATOR(unary_negate_operator, "-", (-rhs));

//real location in xxmi is in util.cpp
//DONT CARE FOR PARSING ONLY NOT EVALUATING
uint32_t popcount(uint32_t)
{
	//uint32_t count = 0;
	//while (x) {
	//	x &= (x - 1); // Clears the lowest set bit.
	//	count++;
	//}
	//return count;
	return 0;
}

//static uint32_t random_call_counter = 0;

//static uint32_t hash32(uint32_t x)
//{
//	x ^= x >> 16;
//	x *= 0x7feb352d;
//	x ^= x >> 15;
//	x *= 0x846ca68b;
//	x ^= x >> 16;
//	return x;
//}

//DONT CARE FOR PARSING ONLY NOT EVALUATING
float random(float max)
{
	//if (max == 0.0f)
	//	return 0.0f;

	//float sign = max < 0.0f ? -1.0f : 1.0f;
	//max = fabs(max);

	////uint32_t seed = G->frame_no;
	//uint32_t seed = 0;
	//seed += 0x9e3779b9 * random_call_counter++;
	//seed ^= G->gSystemTickCount;

	//uint32_t value = hash32(seed);

	//float normalized = (value & 0x00ffffff) / 16777216.0f;

	//return normalized * max * sign;
	return 0;
}

// Functions
DEFINE_OPERATOR(countbits_operator, "countbits", popcount((uint32_t)rhs));

DEFINE_OPERATOR(sin_operator, "sin", sin(rhs));
DEFINE_OPERATOR(cos_operator, "cos", cos(rhs));
DEFINE_OPERATOR(tan_operator, "tan", tan(rhs));
DEFINE_OPERATOR(asin_operator, "asin", asin(rhs));
DEFINE_OPERATOR(acos_operator, "acos", acos(rhs));
DEFINE_OPERATOR(atan_operator, "atan", atan(rhs));

DEFINE_OPERATOR(abs_operator, "abs", abs(rhs));
DEFINE_OPERATOR(sign_operator, "sign", (rhs > 0) - (rhs < 0));
DEFINE_OPERATOR(ceil_operator, "ceil", ceil(rhs));
DEFINE_OPERATOR(floor_operator, "floor", floor(rhs));
DEFINE_OPERATOR(trunc_operator, "trunc", trunc(rhs));
DEFINE_OPERATOR(round_operator, "round", round(rhs));
DEFINE_OPERATOR(frac_operator, "frac", rhs - floor(rhs));

DEFINE_OPERATOR(sqrt_operator, "sqrt", sqrt(rhs));
DEFINE_OPERATOR(rsqrt_operator, "rsqrt", 1.0 / sqrt(rhs));

DEFINE_OPERATOR(exp_operator, "exp", exp(rhs));
DEFINE_OPERATOR(exp2_operator, "exp2", exp2(rhs));
DEFINE_OPERATOR(log_operator, "log", log(rhs));
DEFINE_OPERATOR(log2_operator, "log2", log2(rhs));

DEFINE_OPERATOR(saturate_operator, "saturate", max(0.0, min(rhs, 1.0)));

DEFINE_OPERATOR(random_operator, "random", random(rhs));

DEFINE_OPERATOR(exponent_operator, "**", (pow(lhs, rhs)));

DEFINE_OPERATOR(multiplication_operator, "*", (lhs* rhs));
DEFINE_OPERATOR(division_operator, "/", (lhs / rhs));
DEFINE_OPERATOR(floor_division_operator, "//", (floor(lhs / rhs)));
DEFINE_OPERATOR(modulus_operator, "%", (fmod(lhs, rhs)));

DEFINE_OPERATOR(addition_operator, "+", (lhs + rhs));
DEFINE_OPERATOR(subtraction_operator, "-", (lhs - rhs));

DEFINE_OPERATOR(left_shift_operator, "<<", ((int32_t)lhs << (int32_t)rhs));
DEFINE_OPERATOR(right_shift_operator, ">>", ((int32_t)lhs >> (int32_t)rhs));

DEFINE_OPERATOR(less_operator, "<", (lhs < rhs));
DEFINE_OPERATOR(less_equal_operator, "<=", (lhs <= rhs));
DEFINE_OPERATOR(greater_operator, ">", (lhs > rhs));
DEFINE_OPERATOR(greater_equal_operator, ">=", (lhs >= rhs));

DEFINE_OPERATOR(equality_operator, "==", (lhs == rhs));
DEFINE_OPERATOR(inequality_operator, "!=", (lhs != rhs));
DEFINE_OPERATOR(identical_operator, "===", (*(uint32_t*)&lhs == *(uint32_t*)&rhs));
DEFINE_OPERATOR(not_identical_operator, "!==", (*(uint32_t*)&lhs != *(uint32_t*)&rhs));

DEFINE_OPERATOR(bitwise_and_operator, "&", ((int32_t)lhs& (int32_t)rhs));
DEFINE_OPERATOR(bitwise_xor_operator, "^", ((int32_t)lhs ^ (int32_t)rhs));
DEFINE_OPERATOR(bitwise_or_operator, "|", ((int32_t)lhs | (int32_t)rhs));

DEFINE_OPERATOR(and_operator, "&&", (lhs&& rhs));

DEFINE_OPERATOR(or_operator, "||", (lhs || rhs));

static CommandListOperatorFactoryBase* unary_operators[] = {
	&unary_not_operator,
	&bitwise_not_operator,
	&unary_negate_operator,
	&unary_plus_operator,

	&countbits_operator,

	&sin_operator,
	&cos_operator,
	&tan_operator,
	&asin_operator,
	&acos_operator,
	&atan_operator,

	&abs_operator,
	&sign_operator,
	&ceil_operator,
	&floor_operator,
	&trunc_operator,
	&round_operator,
	&frac_operator,

	&sqrt_operator,
	&rsqrt_operator,

	&exp_operator,
	&exp2_operator,
	&log_operator,
	&log2_operator,

	&saturate_operator,

	&random_operator,
};
static CommandListOperatorFactoryBase* exponent_operators[] = {
	&exponent_operator,
};
static CommandListOperatorFactoryBase* multi_division_operators[] = {
	&multiplication_operator,
	&division_operator,
	&floor_division_operator,
	&modulus_operator,
};
static CommandListOperatorFactoryBase* add_subtract_operators[] = {
	&addition_operator,
	&subtraction_operator,
};
static CommandListOperatorFactoryBase* shift_operators[] = {
	&left_shift_operator,
	&right_shift_operator,
};
static CommandListOperatorFactoryBase* relational_operators[] = {
	&less_operator,
	&less_equal_operator,
	&greater_operator,
	&greater_equal_operator,
};
static CommandListOperatorFactoryBase* equality_operators[] = {
	&equality_operator,
	&inequality_operator,
	&identical_operator,
	&not_identical_operator,
};
static CommandListOperatorFactoryBase* bitwise_and_operators[] = {
	&bitwise_and_operator,
};
static CommandListOperatorFactoryBase* bitwise_xor_operators[] = {
	&bitwise_xor_operator,
};
static CommandListOperatorFactoryBase* bitwise_or_operators[] = {
	&bitwise_or_operator,
};
static CommandListOperatorFactoryBase* and_operators[] = {
	&and_operator,
};
static CommandListOperatorFactoryBase* or_operators[] = {
	&or_operator,
};

static CommandListSyntaxTree::Tokens::iterator transform_operators_token(
	CommandListSyntaxTree* tree,
	CommandListSyntaxTree::Tokens::iterator i,
	CommandListOperatorFactoryBase* factories[], int num_factories,
	bool unary)
{
	std::shared_ptr<CommandListOperatorToken> token;
	std::shared_ptr<CommandListOperator> op;
	std::shared_ptr<CommandListOperandBase> lhs;
	std::shared_ptr<CommandListOperandBase> rhs;
	int f;

	token = std::dynamic_pointer_cast<CommandListOperatorToken>(*i);
	if (!token)
		return i;

	for (f = 0; f < num_factories; f++) {
		if (token->token.compare(factories[f]->pattern()))
			continue;

		lhs = nullptr;
		rhs = nullptr;
		if (i > tree->tokens.begin())
			lhs = std::dynamic_pointer_cast<CommandListOperandBase>(*(i - 1));
		if (i < tree->tokens.end() - 1)
			rhs = std::dynamic_pointer_cast<CommandListOperandBase>(*(i + 1));

		if (unary) {
			if (rhs && !lhs) {
				op = factories[f]->create(nullptr, *token, *(i + 1));
				i = tree->tokens.erase(i, i + 2);
				i = tree->tokens.insert(i, std::move(op));
				break;
			}
		}
		else {
			if (lhs && rhs) {
				op = factories[f]->create(*(i - 1), *token, *(i + 1));
				i = tree->tokens.erase(i - 1, i + 2);
				i = tree->tokens.insert(i, std::move(op));
				break;
			}
		}
	}

	return i;
}

static void transform_operators_visit(CommandListSyntaxTree* tree,
	CommandListOperatorFactoryBase* factories[], int num_factories,
	bool right_associative, bool unary)
{
	CommandListSyntaxTree::Tokens::iterator i;
	CommandListSyntaxTree::Tokens::reverse_iterator rit;

	if (!tree)
		return;

	if (right_associative) {
		if (unary) {
			for (rit = tree->tokens.rbegin() + 1; rit != tree->tokens.rend(); rit++) {
				i = transform_operators_token(tree, rit.base() - 1, factories, num_factories, unary);
				rit = std::reverse_iterator<CommandListSyntaxTree::Tokens::iterator>(i + 1);
			}
		}
		else {
			for (rit = tree->tokens.rbegin() + 1; rit < tree->tokens.rend() - 1; rit++) {
				i = transform_operators_token(tree, rit.base() - 1, factories, num_factories, unary);
				rit = std::reverse_iterator<CommandListSyntaxTree::Tokens::iterator>(i + 1);
			}
		}
	}
	else {
		if (unary) {
			throw CommandListSyntaxError(L"FIXME: Implement left-associative unary operators", 0);
		}
		else {
			for (i = tree->tokens.begin() + 1; i < tree->tokens.end() - 1; i++)
				i = transform_operators_token(tree, i, factories, num_factories, unary);
		}
	}
}

static void transform_operators_recursive(CommandListWalkable* tree,
	CommandListOperatorFactoryBase* factories[], int num_factories,
	bool right_associative, bool unary)
{
	for (auto& inner : tree->walk()) {
		transform_operators_recursive(dynamic_cast<CommandListWalkable*>(inner.get()),
			factories, num_factories, right_associative, unary);
	}

	transform_operators_visit(dynamic_cast<CommandListSyntaxTree*>(tree),
		factories, num_factories, right_associative, unary);
}

bool CommandListExpression::parse(Globals& G, const std::wstring* expression, const std::wstring* ini_namespace, CommandListScope* scope)
{
	CommandListSyntaxTree tree(0);

	try {
		tokenise(G, expression, &tree, ini_namespace, scope);

		group_parenthesis(&tree);

		transform_operators_recursive(&tree, unary_operators, ARRAYSIZE(unary_operators), true, true);
		transform_operators_recursive(&tree, exponent_operators, ARRAYSIZE(exponent_operators), true, false);
		transform_operators_recursive(&tree, multi_division_operators, ARRAYSIZE(multi_division_operators), false, false);
		transform_operators_recursive(&tree, add_subtract_operators, ARRAYSIZE(add_subtract_operators), false, false);
		transform_operators_recursive(&tree, shift_operators, ARRAYSIZE(shift_operators), false, false);
		transform_operators_recursive(&tree, relational_operators, ARRAYSIZE(relational_operators), false, false);
		transform_operators_recursive(&tree, equality_operators, ARRAYSIZE(equality_operators), false, false);
		transform_operators_recursive(&tree, bitwise_and_operators, ARRAYSIZE(bitwise_and_operators), false, false);
		transform_operators_recursive(&tree, bitwise_xor_operators, ARRAYSIZE(bitwise_xor_operators), false, false);
		transform_operators_recursive(&tree, bitwise_or_operators, ARRAYSIZE(bitwise_or_operators), false, false);
		transform_operators_recursive(&tree, and_operators, ARRAYSIZE(and_operators), false, false);
		transform_operators_recursive(&tree, or_operators, ARRAYSIZE(or_operators), false, false);

		evaluatable = tree.finalise();

		////log_syntax_tree(evaluatable, "Final syntax tree:\n");
		return true;
	}
	catch (const CommandListSyntaxError&) {
		/*printf(
			"Syntax Error: %S\n"
			"              %*s: %S\n",
			expression->c_str(), (int)e.pos + 1, "^", e.msg.c_str());*/
		return false;
	}

}

float CommandListExpression::evaluate()
{
	return evaluatable->evaluate();
}

bool CommandListExpression::static_evaluate(float* ret, bool evaluate_variables)
{
	return evaluatable->static_evaluate(ret, evaluate_variables);
}

bool CommandListExpression::optimise()
{
	std::shared_ptr<CommandListEvaluatable> replacement;
	bool ret;

	if (!evaluatable) {
		//printf("BUG: Non-evaluatable expression, please report this and provide your d3dx.ini\n");
		evaluatable = std::make_shared<CommandListOperand>(0, L"<BUG>");
		return false;
	}

	ret = evaluatable->optimise(&replacement);

	if (replacement)
		evaluatable = replacement;

	return ret;
}

std::shared_ptr<CommandListEvaluatable> CommandListOperator::finalise()
{
	auto lhs_finalisable = std::dynamic_pointer_cast<CommandListFinalisable>(lhs_tree);
	auto rhs_finalisable = std::dynamic_pointer_cast<CommandListFinalisable>(rhs_tree);
	auto lhs_evaluatable = std::dynamic_pointer_cast<CommandListEvaluatable>(lhs_tree);
	auto rhs_evaluatable = std::dynamic_pointer_cast<CommandListEvaluatable>(rhs_tree);

	if (lhs || rhs) {
		//printf("BUG: Attempted to finalise already final operator\n");
		throw CommandListSyntaxError(L"BUG", token_pos);
	}

	if (lhs_tree) {
		if (!lhs && lhs_finalisable)
			lhs = lhs_finalisable->finalise();
		if (!lhs && lhs_evaluatable)
			lhs = lhs_evaluatable;
		if (!lhs)
			throw CommandListSyntaxError(L"BUG: LHS operand invalid", token_pos);
		lhs_tree = nullptr;
	}

	if (!rhs && rhs_finalisable)
		rhs = rhs_finalisable->finalise();
	if (!rhs && rhs_evaluatable)
		rhs = rhs_evaluatable;
	if (!rhs)
		throw CommandListSyntaxError(L"BUG: RHS operand invalid", token_pos);
	rhs_tree = nullptr;

	return nullptr;
}

std::shared_ptr<CommandListEvaluatable> CommandListSyntaxTree::finalise()
{
	std::shared_ptr<CommandListFinalisable> finalisable;
	std::shared_ptr<CommandListEvaluatable> evaluatable;
	std::shared_ptr<CommandListToken> token;
	Tokens::iterator i;

	for (i = tokens.begin(); i != tokens.end(); i++) {
		finalisable = std::dynamic_pointer_cast<CommandListFinalisable>(*i);
		if (finalisable) {
			evaluatable = finalisable->finalise();
			if (evaluatable) {

				token = std::dynamic_pointer_cast<CommandListToken>(evaluatable);
				if (!token) {
					//printf("BUG: finalised token did not cast back\n");
					throw CommandListSyntaxError(L"BUG", token_pos);
				}
				i = tokens.erase(i);
				i = tokens.insert(i, std::move(token));
			}
		}
	}

	if (tokens.empty())
		throw CommandListSyntaxError(L"Empty expression", 0);

	if (tokens.size() > 1)
		throw CommandListSyntaxError(L"Unexpected", tokens[1]->token_pos);

	evaluatable = std::dynamic_pointer_cast<CommandListEvaluatable>(tokens[0]);
	if (!evaluatable)
		throw CommandListSyntaxError(L"Non-evaluatable", tokens[0]->token_pos);

	return evaluatable;
}

CommandListSyntaxTree::Walk CommandListSyntaxTree::walk()
{
	Walk ret;
	std::shared_ptr<CommandListWalkable> inner;
	Tokens::iterator i;

	for (i = tokens.begin(); i != tokens.end(); i++) {
		inner = std::dynamic_pointer_cast<CommandListWalkable>(*i);
		if (inner)
			ret.push_back(std::move(inner));
	}

	return ret;
}

float CommandListOperator::evaluate()
{
	if (lhs)
		return evaluate(lhs->evaluate(), rhs->evaluate());
	return evaluate(std::numeric_limits<float>::quiet_NaN(), rhs->evaluate());
}

bool CommandListOperator::static_evaluate(float* ret, bool evaluate_variables)
{
	float lhs_static = std::numeric_limits<float>::quiet_NaN(), rhs_static;
	bool is_static;

	is_static = rhs->static_evaluate(&rhs_static, evaluate_variables);
	if (lhs)
		is_static = lhs->static_evaluate(&lhs_static, evaluate_variables) && is_static;

	if (is_static) {
		if (ret)
			*ret = evaluate(lhs_static, rhs_static);
		return true;
	}

	return false;
}

bool CommandListOperator::optimise(std::shared_ptr<CommandListEvaluatable>* replacement)
{
	std::shared_ptr<CommandListEvaluatable> lhs_replacement;
	std::shared_ptr<CommandListEvaluatable> rhs_replacement;
	std::shared_ptr<CommandListOperand> operand;
	bool making_progress = false;
	float static_val;
	std::wstring static_val_str;

	if (lhs)
		making_progress = lhs->optimise(&lhs_replacement) || making_progress;
	if (rhs)
		making_progress = rhs->optimise(&rhs_replacement) || making_progress;

	if (lhs_replacement)
		lhs = lhs_replacement;
	if (rhs_replacement)
		rhs = rhs_replacement;

	if (!static_evaluate(&static_val))
		return making_progress;

	static_val_str = std::to_wstring(static_val);

	operand = std::make_shared<CommandListOperand>(token_pos, static_val_str.c_str());
	operand->type = ParamOverrideType::VALUE;
	operand->val = static_val;
	*replacement = std::dynamic_pointer_cast<CommandListEvaluatable>(operand);
	return true;
}

CommandListSyntaxTree::Walk CommandListOperator::walk()
{
	Walk ret;
	std::shared_ptr<CommandListWalkable> lhs;
	std::shared_ptr<CommandListWalkable> rhs;

	lhs = std::dynamic_pointer_cast<CommandListWalkable>(lhs_tree);
	rhs = std::dynamic_pointer_cast<CommandListWalkable>(rhs_tree);

	if (lhs)
		ret.push_back(std::move(lhs));
	if (rhs)
		ret.push_back(std::move(rhs));

	return ret;
}

void VariableAssignment::run()
{
	float orig = var->fval;


	var->fval = expression.evaluate();


	if (var->flags & VariableFlags::PERSIST){}
		//G->user_config_dirty |= (var->fval != orig);
}

bool AssignmentCommand::optimise()
{
	return expression.optimise();
}

static bool operand_allowed_in_context(ParamOverrideType type, CommandListScope* scope)
{
	if (scope)
		return true;

	switch (type) {
	case ParamOverrideType::VALUE:
	case ParamOverrideType::INI_PARAM:
	case ParamOverrideType::VARIABLE:
	case ParamOverrideType::RES_WIDTH:
	case ParamOverrideType::RES_HEIGHT:
	case ParamOverrideType::TIME:
	case ParamOverrideType::FRAME_NUMBER:
	case ParamOverrideType::HUNTING:
	case ParamOverrideType::EFFECTIVE_DPI:
	case ParamOverrideType::SLI:
	case ParamOverrideType::STEREO_ACTIVE:
	case ParamOverrideType::STEREO_AVAILABLE:
		return true;
	}
	return false;
}

bool valid_variable_name(const std::wstring& name)
{
	if (name.length() < 2)
		return false;

	if (name[0] != L'$')
		return false;

	if ((name[1] < L'a' || name[1] > L'z') && name[1] != L'_')
		return false;

	return (name.find_first_not_of(L"abcdefghijklmnopqrstuvwxyz_0123456789", 2) == std::wstring::npos);
}

bool parse_command_list_var_name(Globals& G, const std::wstring& name, const std::wstring* ini_namespace, CommandListVariable** target)
{
	CommandListVariables::iterator var = G.command_list_globals.end();

	if (name.length() < 2 || name[0] != L'$')
		return false;

	std::wstring low_name(name);
	std::transform(low_name.begin(), low_name.end(), low_name.begin(), ::towlower);

	var = G.command_list_globals.end();
	if (!ini_namespace->empty())
		var = G.command_list_globals.find(get_namespaced_var_name_lower(low_name, ini_namespace));
	if (var == G.command_list_globals.end())
		var = G.command_list_globals.find(low_name);
	if (var == G.command_list_globals.end())
		return false;

	*target = &var->second;
	return true;
}

bool CommandListOperand::parse_float(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope, size_t& out_length)
{
	if (ParseFloatToken(*operand, val, out_length))
	{
		type = ParamOverrideType::VALUE;
		return operand_allowed_in_context(type, scope);
	}
	return false;
}

bool CommandListOperand::parse_ini_param(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope)
{
	if (ParseIniParamName(operand->c_str(), &param_idx)) {
		type = ParamOverrideType::INI_PARAM;
		//G->iniParamsReserved = max(G->iniParamsReserved, param_idx + 1);
		return operand_allowed_in_context(type, scope);
	}
	return false;
}

bool CommandListOperand::parse_variable(Globals& G, const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope)
{
	CommandListVariable* var = nullptr;

	if (find_local_variable(*operand, scope, &var) ||
		parse_command_list_var_name(G, *operand, ini_namespace, &var)) {
		type = ParamOverrideType::VARIABLE;
		var_ftarget = &var->fval;
		return operand_allowed_in_context(type, scope);
	}
	return false;
}

bool CommandListOperand::parse_target(Globals& G, const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope)
{
	int ret;
	ret = texture_filter_target.ParseTarget(G, operand->c_str(), true, ini_namespace, scope);
	if (ret) {
		type = ParamOverrideType::TEXTURE;
		return operand_allowed_in_context(type, scope);
	}
	return false;
}

bool CommandListOperand::parse_shader(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope)
{
	int len1 = 0;
	int ret = swscanf_s(operand->c_str(), L"%lcs%n", &shader_filter_target, 1, &len1);
	if (ret == 1 && len1 == operand->length()) {
		switch (shader_filter_target) {
		case L'v': case L'h': case L'd': case L'g': case L'p': case L'c':
			type = ParamOverrideType::SHADER;
			return operand_allowed_in_context(type, scope);
		}
	}
	return false;
}

bool CommandListOperand::parse_scissor(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope)
{
	int len1 = 0;
	int ret = swscanf_s(operand->c_str(), L"scissor%u_%n", &scissor, &len1);
	//D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE = 16
	if (ret == 1 && scissor < 16) {
		if (!wcscmp(operand->c_str() + len1, L"left"))
			type = ParamOverrideType::SCISSOR_LEFT;
		else if (!wcscmp(operand->c_str() + len1, L"top"))
			type = ParamOverrideType::SCISSOR_TOP;
		else if (!wcscmp(operand->c_str() + len1, L"right"))
			type = ParamOverrideType::SCISSOR_RIGHT;
		else if (!wcscmp(operand->c_str() + len1, L"bottom"))
			type = ParamOverrideType::SCISSOR_BOTTOM;
		else
			return false;
		return operand_allowed_in_context(type, scope);
	}
	return false;
}

bool CommandListOperand::parse_ini_keywords(const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope)
{
	type = lookup_enum_val<const wchar_t*, ParamOverrideType>
		(ParamOverrideTypeNames, operand->c_str(), ParamOverrideType::INVALID);

	if (type != ParamOverrideType::INVALID)
		return operand_allowed_in_context(type, scope);
	return false;
}

bool ParseCommandListVariableAssignment(Globals& G, const wchar_t* section,
	const wchar_t* key, std::wstring* val, const std::wstring* raw_line,
	CommandList* command_list, CommandList* pre_command_list, CommandList* post_command_list,
	const std::wstring* ini_namespace)
{
	std::wstring line = key;

	if (line.empty() && raw_line)
		line = *raw_line;

	bool declare_local = !line.compare(0, 5, L"local");

	if (!declare_local && line[0] != L'$')
		return false;

	CommandArgumentReader args(L"variable_assignment", line, section, ini_namespace, pre_command_list->scope);

	std::wstring name;

	if (!args.PeekToken(&name))
		return args.Fail();

	if (declare_local)
	{
		if (!args.ConsumeToken())
			return args.Fail();

		if (!args.ConsumeSeparator(SeparatorMode::Space))
			return args.Fail();

		if (!args.PeekToken(&name))
			return args.Fail();

		if (!declare_local_variable(G, section, name, pre_command_list, ini_namespace))
			return false;

		if (val->empty())
			return true;
	}

	if (name.back() == L']')
		return false;

	CommandListVariable* var = nullptr;

	if (!args.GetVariable(G, var, false))
		return args.Fail();

	VariableAssignment* command = new VariableAssignment();

	command->var = var;

	if (!command->expression.parse(G, val, ini_namespace, command_list->scope))
		goto bail;

	command->ini_line = L"[" + std::wstring(section) + L"] " + line + L" = " + *val;
	command_list->commands.push_back(std::shared_ptr<CommandListCommand>(command));
	return true;

bail:
	delete command;
	return false;
}

IniParserResult ResourceCopyTarget::ParseTargetPrefix(const wchar_t*& target, size_t& length)
{
	switch (target[0]) {
	case L'$':
		if ((target[length - 1] == L']') && !wcsncmp(target, L"$pool", 5)) {
			evaluation_mode = ResourceCopyTargetEvaluationMode::VARIABLE;
			target++;
			length--;
			return IniParserResult::TOKEN_FOUND;
		}
	case L'@':
		evaluation_mode = ResourceCopyTargetEvaluationMode::RESOURCE_IDENTITY;
		target++;
		length--;
		return IniParserResult::TOKEN_FOUND;
	case L'#':
		evaluation_mode = ResourceCopyTargetEvaluationMode::POOL_INDEX;
		target++;
		length--;
		return IniParserResult::TOKEN_FOUND;
	}
	return IniParserResult::TOKEN_NOT_FOUND;
}

//float MemberArg::GetValue(CommandListState* state)
//{
//	if (expression)
//		return expression->evaluate(state);
//
//	return 0.0f;
//}

const std::wstring& MemberArg::GetString() const
{
	return constant_string;
}

bool ResourceCopyTarget::ParseMemberArguments(
	Globals& G, const MemberInfo& member, const wchar_t* args_start, const wchar_t* args_end, const std::wstring* ini_namespace, CommandListScope* scope
)
{
	size_t num_args = member.num_args();

	// No "(...)" present.
	if (!args_start)
		return num_args == 0;

	std::wstring argument_text(args_start, args_end - args_start);

	CommandArgumentReader args(member.keyword, argument_text, L"", ini_namespace, scope);

	for (size_t i = 0; i < num_args; i++)
	{
		switch (member.args[i])
		{
		case MemberArg::Type::String:
		{
			std::wstring value;

			if (!args.GetToken(&value, CommandArgumentReader::PeekMode::Argument))
				return args.Fail();

			member_args[i].constant_string = value;
			member_args[i].type = MemberArg::Type::String;
			break;
		}

		case MemberArg::Type::Unsigned:
		case MemberArg::Type::Signed:
		case MemberArg::Type::Float:
		{
			std::unique_ptr<CommandListExpression> expression;

			if (!args.GetExpression(G, &expression))
				return false;

			member_args[i].expression = std::move(expression);
			member_args[i].type = member.args[i];
			break;
		}

		default:
			return false;
		}

		if (i + 1 < num_args)
		{
			if (!args.ConsumeSeparator(SeparatorMode::Comma))
				return args.Fail();
		}
	}

	return args.Finished();
}

IniParserResult extract_arguments(const wchar_t* target, size_t& length, const wchar_t*& args_start, const wchar_t*& args_end)
{
	args_start = nullptr;
	args_end = nullptr;

	if (length == 0 || target[length - 1] != L')')
		return IniParserResult::TOKEN_NOT_FOUND;

	const wchar_t* open = wcsrchr(target, L'(');

	if (!open || open <= target)
		return IniParserResult::SYNTAX_ERROR;

	// Remove "(...)" from target.
	args_start = open + 1;
	args_end = target + length - 1;

	length = open - target;

	return IniParserResult::TOKEN_FOUND;
}

bool suffix_equals(const wchar_t* str, size_t len, const wchar_t* suffix, size_t suffix_len)
{
	return len >= suffix_len && !wmemcmp(str + len - suffix_len, suffix, suffix_len);
}

IniParserResult ResourceCopyTarget::ParseTargetMember(
	Globals& G, const wchar_t*& target, size_t& length, std::wstring& temp_target, const std::wstring* ini_namespace, CommandListScope* scope
)
{
	//LogInfo("ParseTargetMember: target=%ls, length=%d\n", target, length);

	if (length < 8 // Smallest possible match is "ib->size", so this check rejects almost everything except custom resources.
		|| !(evaluation_mode & ResourceCopyTargetEvaluationMode::RESOURCE_MASK)) // Members are supported only for Resources.
	{
		return IniParserResult::TOKEN_NOT_FOUND;
	}

	static constexpr MemberInfo members[] = {
		{ L"->size",           6, ResourceCopyTargetEvaluationMode::RESOURCE_SIZE },
		{ L"->index",          7, ResourceCopyTargetEvaluationMode::POOL_INDEX },
		{ L"->offset",         8, ResourceCopyTargetEvaluationMode::RESOURCE_OFFSET },
		{ L"->stride",         8, ResourceCopyTargetEvaluationMode::RESOURCE_STRIDE },
		{ L"->region",         8, ResourceCopyTargetEvaluationMode::RESOURCE_REGION, {{
			MemberArg::Type::Unsigned, // Byte Offset 
			MemberArg::Type::Unsigned  // Byte Size 
		}} },
		{ L"->hashregion",    12, ResourceCopyTargetEvaluationMode::RESOURCE_REGION_HASH, {{
			MemberArg::Type::Unsigned, // Byte Offset 
			MemberArg::Type::Unsigned  // Byte Size 
		}} },
		{ L"->lastframe",   13, ResourceCopyTargetEvaluationMode::POOL_LAST_FRAME },
		{ L"->spatialhash",   13, ResourceCopyTargetEvaluationMode::RESOURCE_SPATIAL_HASH, {{
			MemberArg::Type::Unsigned, // X Byte Offset 
			MemberArg::Type::Unsigned, // Y Byte Offset 
			MemberArg::Type::Unsigned, // Z Byte Offset 
			MemberArg::Type::Float     // Cell Size
		}} },
		{ L"->sourcestride",  14, ResourceCopyTargetEvaluationMode::RESOURCE_SOURCE_STRIDE },
		{ L"->elementformat", 15, ResourceCopyTargetEvaluationMode::LAYOUT_ELEMENT_FORMAT, {{
			MemberArg::Type::String,  // Semantic Name
			MemberArg::Type::Unsigned // Semantic Index
		}} },
		{ L"->elementoffset", 15, ResourceCopyTargetEvaluationMode::LAYOUT_ELEMENT_OFFSET, {{
			MemberArg::Type::String,  // Semantic Name
			MemberArg::Type::Unsigned // Semantic Index
		}} },
	};

	// Consume (...) arguments contents (adjust `length` accordingly). Ensure syntax error passthrough.
	const wchar_t* args_start = nullptr;
	const wchar_t* args_end = nullptr;
	IniParserResult args_result = extract_arguments(target, length, args_start, args_end);
	if (args_result == IniParserResult::SYNTAX_ERROR)
		return IniParserResult::SYNTAX_ERROR;

	// Consume member keyword (adjust `target` and `length` accordingly).
	for (const auto& member : members)
	{
		// Members are listed by ASC length. Exit loop if target is shorter than current member length plus "ib" length of 2.
		if (length < member.len + 2)
			break;

		// Skip to next member if ">" pointer is not found at expected pos (avoids unneeded "wmemcmp" calls).
		const wchar_t* member_pos = target + length - member.len;
		if (member_pos[1] != L'>')
			continue;

		// Check if the trailing end matches the member substr, "->" included.
		if (!suffix_equals(target, length, member.keyword, member.len))
			continue;

		if (!ParseMemberArguments(G, member, args_start, args_end, ini_namespace, scope))
			return IniParserResult::SYNTAX_ERROR;

		// Member found.
		evaluation_mode = member.mode;

		length -= member.len;

		temp_target.assign(target, length);
		target = temp_target.c_str();

		//LogInfo("ParseTargetMember: TOKEN_FOUND keyword=%ls, target=%ls\n", member.keyword, target);
		return IniParserResult::TOKEN_FOUND;
	}

	return IniParserResult::TOKEN_NOT_FOUND;
}

IniParserResult ResourceCopyTarget::ParseTargetCustomResource(Globals& G, const wchar_t*& target, size_t length, const std::wstring* ini_namespace, CommandListScope* scope)
{
	//LogInfo("ParseTargetCustomResource: target=%ls, length=%d\n", target, length);
	if (length < 9 || wcsncmp(target, L"resource", 8))
		return IniParserResult::TOKEN_NOT_FOUND;

	// Exit early for non-resource type evaluation modes (essentially on invalid syntax)
	if (!(evaluation_mode & ResourceCopyTargetEvaluationMode::RESOURCE_MASK))
		return IniParserResult::SYNTAX_ERROR;

	// section name should already have been transformed to lower
	// case from ParseCommandList, so our keys will be consistent
	// in the unordered_map:
	std::wstring resource_id(target);
	std::wstring namespaced_section;

	CustomResources::iterator res = G.customResources.end();
	if (get_namespaced_section_name_lower(&resource_id, ini_namespace, &namespaced_section))
		res = G.customResources.find(namespaced_section);
	if (res == G.customResources.end())
		res = G.customResources.find(resource_id);
	if (res == G.customResources.end())
		return IniParserResult::SYNTAX_ERROR;

	//static_custom_resource = &res->second;
	type = ResourceCopyTargetType::CUSTOM_RESOURCE;

	return IniParserResult::TOKEN_FOUND;
}

IniParserResult ResourceCopyTarget::ParseTargetPool(Globals& G, const wchar_t*& target, size_t length, const std::wstring* ini_namespace, CommandListScope* scope, bool is_source)
{
	if (length < 5 || wcsncmp(target, L"pool", 4))
		return IniParserResult::TOKEN_NOT_FOUND;

	std::wstring pool_id;
	std::wstring pool_index_text;

	if (target[length - 1] == L']')
	{
		// Parse PoolName[$id] or PoolName[0]
		const wchar_t* pool_index_open_pos = wcschr(target, L'[');
		if (pool_index_open_pos && pool_index_open_pos > target) {
			pool_index_text = std::wstring(pool_index_open_pos + 1, target + length - 1);
			length = pool_index_open_pos - target;
			pool_id = std::wstring(target, target + length);
		}
		else {
			// Invalid syntax (opening `[` not found or located after closing `]`)
			return IniParserResult::SYNTAX_ERROR;
		}
	}
	else if (evaluation_mode == ResourceCopyTargetEvaluationMode::RESOURCE_IDENTITY)
	{
		// Treat @PoolName as POOL_IDENTITY
		evaluation_mode = ResourceCopyTargetEvaluationMode::POOL_IDENTITY;
		pool_id = std::wstring(target);
	}
	else if (evaluation_mode == ResourceCopyTargetEvaluationMode::POOL_INDEX
		|| evaluation_mode == ResourceCopyTargetEvaluationMode::RESOURCE_SIZE)
	{
		// Treat #PoolName and PoolName->Size as POOL_SIZE
		evaluation_mode = ResourceCopyTargetEvaluationMode::POOL_SIZE;
		pool_id = std::wstring(target);
	}
	else if (evaluation_mode == ResourceCopyTargetEvaluationMode::RESOURCE
		|| evaluation_mode == ResourceCopyTargetEvaluationMode::VARIABLE)
	{
		pool_id = std::wstring(target);
	}

	if (!pool_id.empty())
	{
		std::wstring namespaced_section;
		CustomResourcePools::iterator con = G.customResourcePools.end();
		if (get_namespaced_section_name_lower(&pool_id, ini_namespace, &namespaced_section))
			con = G.customResourcePools.find(namespaced_section);
		if (con == G.customResourcePools.end())
			con = G.customResourcePools.find(pool_id);
		if (con != G.customResourcePools.end())
			custom_resource_pool = &con->second;
	}

	if (custom_resource_pool == nullptr)
		return IniParserResult::SYNTAX_ERROR;

	// No pool index specified, treat target as non-evaluatable pool.
	if (pool_index_text.empty()) {
		type = ResourceCopyTargetType::POOL;
		return IniParserResult::TOKEN_FOUND;
	}

	// Pool range operation. Only DST is supported for now.
	if (pool_index_text == L"*") {
		if (is_source)
			return IniParserResult::SYNTAX_ERROR;
		type = ResourceCopyTargetType::POOL;
		evaluation_mode = ResourceCopyTargetEvaluationMode::POOL_FULL_RANGE;
		return IniParserResult::TOKEN_FOUND;
	}

	// Handle resource pool index
	if (custom_resource_pool->index_type == PoolIndexType::STATIC)
	{
		// Parse value for STATIC index type.
		wchar_t* end;
		float static_pool_index = wcstof(pool_index_text.c_str(), &end);
		if (*end != L'\0')
			return IniParserResult::SYNTAX_ERROR;

		// Statically resolve custom resource or variable from pool.
		switch (evaluation_mode)
		{
		case ResourceCopyTargetEvaluationMode::VARIABLE:
			//LogInfo("ParseTargetPool: STATIC VARIABLE pool_index=%f\n", static_pool_index);
			//static_pool_variable = custom_resource_pool->GetVariable(static_pool_index, false, false, !is_source);
			type = ResourceCopyTargetType::VARIABLE;
			return IniParserResult::TOKEN_FOUND;

		default:
			//LogInfo("ParseTargetPool: STATIC RESOURCE pool_index=%f\n", static_pool_index);
			//static_custom_resource = custom_resource_pool->GetResource(static_pool_index, false, false, !is_source);
			type = ResourceCopyTargetType::CUSTOM_RESOURCE;
			return IniParserResult::TOKEN_FOUND;
		}
	}
	else
	{
		// Parse expression for any dynamic index type.
		pool_dynamic_index_expression = std::make_unique<CommandListExpression>();
		if (!pool_dynamic_index_expression->parse(G, &pool_index_text, ini_namespace, scope)) {
			pool_dynamic_index_expression.reset();
			return IniParserResult::SYNTAX_ERROR;
		}

		// Custom resource or variable will be resolved dynamically by operation parser.
		switch (evaluation_mode)
		{
		case ResourceCopyTargetEvaluationMode::VARIABLE:
			//LogInfo("ParseTargetPool: DYNAMIC VARIABLE pool_index_text=%ls\n", pool_index_text.c_str());
			type = ResourceCopyTargetType::VARIABLE;
			return IniParserResult::TOKEN_FOUND;

		default:
			//LogInfo("ParseTargetPool: DYNAMIC RESOURCE pool_index_text=%ls\n", pool_index_text.c_str());
			type = ResourceCopyTargetType::CUSTOM_RESOURCE;
			return IniParserResult::TOKEN_FOUND;
		}
	}

	return IniParserResult::SYNTAX_ERROR;
}

static constexpr bool is_shader_resource(wchar_t shader_type) {
	switch (shader_type) {
	case L'v': case L'h': case L'd': case L'g': case L'p': case L'c':
		return true;
	default:
		return false;
	}
}

//Taken from d3d11.h
#define	D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT	( 8 )
#define	D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT	( 32 )
#define	D3D11_SO_STREAM_COUNT	( 4 )
#define	D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT	( 128 )
#define	D3D11_1_UAV_SLOT_COUNT	( 64 )
#define	D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT	( 14 )

constexpr bool token_equals(const wchar_t* str, size_t len, const wchar_t* token, size_t token_len)
{
	return len == token_len && wmemcmp(str, token, token_len) == 0;
}

IniParserResult ResourceCopyTarget::ParseTargetPipelineSlot(const wchar_t*& target, size_t length, bool is_source)
{
	//LogInfo("ParseTargetPipelineSlot: target=%ls, length=%d, is_source=%d\n", target, length, is_source);

	int ret, len;

	struct TargetInfo {
		const wchar_t* keyword;
		size_t len;
		ResourceCopyTargetType type;
		bool source_only;
		bool parse_shader = false;
		int max_slot_count = 0;
	};

	static constexpr TargetInfo targets[] = {
		{ L"ib",            2, ResourceCopyTargetType::INDEX_BUFFER,          false                                                           },
		// o7 (length: min = 2, max = 2)
		{ L"o%u%n",         2, ResourceCopyTargetType::RENDER_TARGET,         false, false, D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT            },
		// XXX: Any reason to allow access to sequential swap chains? Given
		// they either won't exist or are read only I can't think of one.
		{ L"bb",            2, ResourceCopyTargetType::SWAP_CHAIN,            true,                                                           },
		{ L"od",            2, ResourceCopyTargetType::DEPTH_STENCIL_TARGET,  false,                                                          },
		// vb31 (length: min = 3, max = 4)
		{ L"vb%u%n",        3, ResourceCopyTargetType::VERTEX_BUFFER,         false, false, D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT         },
		// so3 (length: min = 3, max = 3)
		{ L"so%u%n",        3, ResourceCopyTargetType::STREAM_OUTPUT,         false, false, D3D11_SO_STREAM_COUNT                             },
		{ L"this",          4, ResourceCopyTargetType::THIS_RESOURCE,         false,                                                          },
		{ L"null",          4, ResourceCopyTargetType::EMPTY,                 true,                                                           },
		{ L"r_bb",          4, ResourceCopyTargetType::REAL_SWAP_CHAIN,       true,                                                           },
		{ L"f_bb",          4, ResourceCopyTargetType::FAKE_SWAP_CHAIN,       true,                                                           },
		// vs-t127 (length: min = 5, max = 7)
		{ L"%lcs-t%u%n",    5, ResourceCopyTargetType::SHADER_RESOURCE,       false,  true, D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT      },
		// cs-u7 (length: min = 5, max = 5)
		{ L"%lcs-u%u%n",    5, ResourceCopyTargetType::UNORDERED_ACCESS_VIEW, false,  true, D3D11_1_UAV_SLOT_COUNT                            },
		// vs-cb13 (length: min = 6, max = 7)
		{ L"%lcs-cb%u%n",   6, ResourceCopyTargetType::CONSTANT_BUFFER,       false,  true, D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT },
		// Alternate means to assign IniParams
		{ L"iniparams",     9, ResourceCopyTargetType::INI_PARAMS,            true,                                                           },
		{ L"cursor_mask",  11, ResourceCopyTargetType::CURSOR_MASK,           true,                                                           },
		{ L"cursor_color", 12, ResourceCopyTargetType::CURSOR_COLOR,          true,                                                           },

		// TODO
		// vs-s15 (length: min = 5, max = 6)
		//{ L"%lcs-s%u%n",    5, ResourceCopyTargetType::SHADER_RESOURCE,      true,   true, D3D11_COMMONSHADER_SAMPLER_SLOT_COUNT           },
	};

	// Consume member keyword (adjust `target` and `length` accordingly).
	bool found = false;
	for (const auto& t : targets) {
		// Targets are listed by ASC length. Exit loop if token length is shorter than minimal length of current target.
		if (length < t.len)
			break;
		// Skip to next target if this one has to be a source (rhd), but destination (lhd) is being parsed (avoids unneeded "wmemcmp" calls).
		if (t.source_only && !is_source)
			continue;
		// Match token against pattern with shader type and slot id.
		if (t.parse_shader) {
			ret = swscanf_s(target, t.keyword, &shader_type, 1, &slot, &len);
			if (ret == 2 && len == length && slot < t.max_slot_count) {
				type = t.type;
				if (type == ResourceCopyTargetType::UNORDERED_ACCESS_VIEW) {
					// These views are only valid for pixel and compute shaders:
					if (shader_type != L'p' && shader_type != L'c') {
						return IniParserResult::SYNTAX_ERROR;
					}
				}
				//LogInfo("ParseTargetPipelineSlot: TOKEN_FOUND target=%ls, shader_type=%lc, slot=%d\n", t.keyword, shader_type, slot);
				return is_shader_resource(shader_type) ? IniParserResult::TOKEN_FOUND : IniParserResult::SYNTAX_ERROR;
			}
		}
		// Match token against pattern with slot id only.
		else if (t.max_slot_count)
		{
			ret = swscanf_s(target, t.keyword, &slot, &len);
			if (ret == 1 && len == length && slot < t.max_slot_count) {
				type = t.type;
				//LogInfo("ParseTargetPipelineSlot: TOKEN_FOUND target=%ls, slot=%d\n", t.keyword, slot);
				return IniParserResult::TOKEN_FOUND;
			}
		}
		// Match token against exact string.
		else if (token_equals(target, length, t.keyword, t.len)) {
			type = t.type;

			if (type & ResourceCopyTargetType::SWAP_CHAIN_MASK) {
				// Holding a reference on the back buffer will prevent
				// ResizeBuffers() from working, so forbid caching any views of
				// the back buffer. Leaving it bound could also be a problem,
				// but since this is usually only used from custom shader
				// sections they will take care of unbinding it automatically:
				//forbid_view_cache = true;
			}

			//LogInfo("ParseTargetPipelineSlot: TOKEN_FOUND target=%ls\n", t.keyword);
			return IniParserResult::TOKEN_FOUND;
		}
	}

	return IniParserResult::TOKEN_NOT_FOUND;
}

bool contains_whitespace(const wchar_t* str, size_t len)
{
	while (len--)
		if (iswspace(*str++))
			return true;
	return false;
}

bool ResourceCopyTarget::ParseTarget(Globals& G, const wchar_t* target, bool is_source, const std::wstring* ini_namespace, CommandListScope* scope)
{
	IniParserResult ret;
	size_t length = wcslen(target);
	std::wstring temp_target;

	if (!target || length < 2)
		return false;

	// Consume an optional target prefix (`@` or `#` or `$`).
	ret = ParseTargetPrefix(target, length);
	//LogInfo("ParseTarget: %d at ParseTargetPrefix\n", ret);
	if (ret == IniParserResult::SYNTAX_ERROR)
		return false;

	// Parse pool variable early.
	if (evaluation_mode == ResourceCopyTargetEvaluationMode::VARIABLE)
	{
		// Parse pool variable (e.g. `$PoolFoo[0]`).
		ret = ParseTargetPool(G, target, length, ini_namespace, scope, is_source);
		//LogInfo("ParseTarget: %d at ParseTargetPool\n", ret);
		return ret == IniParserResult::TOKEN_FOUND;
	}

	// Consume an optional resource member suffix (e.g. `->HashRegion(0, 16)` or `->Length`).
	ret = ParseTargetMember(G, target, length, temp_target, ini_namespace, scope);
	//LogInfo("ParseTarget: %d at ParseTargetMember\n", ret);
	if (ret == IniParserResult::SYNTAX_ERROR)
		return false;

	// Parse the remainder as a custom resource (e.g. `ResourceFoo`).
	ret = ParseTargetCustomResource(G, target, length, ini_namespace, scope);
	//LogInfo("ParseTarget: %d at ParseTargetCustomResource\n", ret);
	if (ret != IniParserResult::TOKEN_NOT_FOUND)
		return ret == IniParserResult::TOKEN_FOUND;

	// Parse the remainder as a resource pool (e.g. `PoolFoo`).
	ret = ParseTargetPool(G, target, length, ini_namespace, scope, is_source);
	//LogInfo("ParseTarget: %d at ParseTargetPool\n", ret);
	if (ret != IniParserResult::TOKEN_NOT_FOUND)
		return ret == IniParserResult::TOKEN_FOUND;

	// Parse the remainder as a pipeline slot (e.g. `vb0`, `this`, `null`).
	ret = ParseTargetPipelineSlot(target, length, is_source);
	//LogInfo("ParseTarget: %d at ParseTargetPipelineSlot\n", ret);
	if (ret != IniParserResult::TOKEN_NOT_FOUND)
		return ret == IniParserResult::TOKEN_FOUND;

	//LogInfo("ParseTarget: 0 at END\n");
	return false;
}

static bool ParseIfCommand(Globals& G, const wchar_t* section, const std::wstring* line,
	CommandList* pre_command_list, CommandList* post_command_list,
	const std::wstring* ini_namespace, const std::wstring& full_path, int line_index)
{
	IfCommand* operation = new IfCommand(G, section, full_path, line->c_str(), line_index);
	std::wstring expression = line->substr(line->find_first_not_of(L" \t", 3));

	if (!operation->expression.parse(G, &expression, ini_namespace, pre_command_list->scope))
		goto bail;

	pre_command_list->scope->emplace_front();

	return AddCommandToList(operation, NULL, NULL, pre_command_list, post_command_list, section, line->c_str(), NULL);
bail:
	G.errored_lines.insert(ErroredLine{ full_path, line_index, line->c_str(), L"Invalid expression"});
	delete operation;
	return false;
}

static bool ParseElseIfCommand(Globals& G, const wchar_t* section, const std::wstring* line, int prefix,
	CommandList* pre_command_list, CommandList* post_command_list,
	const std::wstring* ini_namespace, const std::wstring& full_path, int line_index)
{
	ElseIfCommand* operation = new ElseIfCommand(G, section, full_path, line->c_str(), line_index);
	std::wstring expression = line->substr(line->find_first_not_of(L" \t", prefix));

	if (!operation->expression.parse(G, &expression, ini_namespace, pre_command_list->scope))
		goto bail;

	pre_command_list->scope->front().clear();

	AddCommandToList(new ElsePlaceholder(full_path, line->c_str(), line_index), NULL, NULL, pre_command_list, post_command_list, section, line->c_str(), NULL);
	return AddCommandToList(operation, NULL, NULL, pre_command_list, post_command_list, section, line->c_str(), NULL);
bail:
	G.errored_lines.insert(ErroredLine{ full_path, line_index, line->c_str(), L"Invalid expression"});
	delete operation;
	return false;
}

static bool ParseElseCommand(const wchar_t* section,
	CommandList* pre_command_list, CommandList* post_command_list, const std::wstring* ini_namespace,
	const std::wstring& full_path, int line_index, const std::wstring& line)
{
	pre_command_list->scope->front().clear();

	return AddCommandToList(new ElsePlaceholder(full_path, line, line_index), NULL, NULL, pre_command_list, post_command_list, section, L"else", NULL);
	return true;
}

static bool _ParseEndIfCommand(Globals& G, const wchar_t* section,
	CommandList* command_list, const std::wstring* ini_namespace, bool post, const std::wstring& full_path,
	int line_index, const std::wstring& line, bool has_nested_else_if = false)
{
	CommandList::Commands::reverse_iterator rit;
	IfCommand* if_command;
	ElseIfCommand* else_if_command;
	ElsePlaceholder* else_command = NULL;
	CommandList::Commands::iterator else_pos = command_list->commands.end();

	for (rit = command_list->commands.rbegin(); rit != command_list->commands.rend(); rit++) {
		else_command = dynamic_cast<ElsePlaceholder*>(rit->get());
		if (else_command) {
			else_pos = rit.base() - 1;
		}

		if_command = dynamic_cast<IfCommand*>(rit->get());
		if (if_command) {
			else_if_command = dynamic_cast<ElseIfCommand*>(rit->get());

			if (post && !if_command->post_finalised) {
				if_command->true_commands_post->commands.assign(rit.base(), else_pos);
				if_command->true_commands_post->ini_section = if_command->ini_line;
				if (else_pos != command_list->commands.end()) {
					if_command->false_commands_post->commands.assign(else_pos + 1, command_list->commands.end());
					if_command->false_commands_post->ini_section = if_command->ini_line + L" <else>";
				}
				command_list->commands.erase(rit.base(), command_list->commands.end());
				if_command->post_finalised = true;
				if_command->has_nested_else_if = has_nested_else_if;
				if (else_if_command)
					return _ParseEndIfCommand(G, section, command_list, ini_namespace, post, full_path, line_index, line, true);
				return true;
			}
			else if (!post && !if_command->pre_finalised) {
				if_command->true_commands_pre->commands.assign(rit.base(), else_pos);
				if_command->true_commands_pre->ini_section = if_command->ini_line;
				if (else_pos != command_list->commands.end()) {
					if_command->false_commands_pre->commands.assign(else_pos + 1, command_list->commands.end());
					if_command->false_commands_pre->ini_section = if_command->ini_line + L" <else>";
				}
				command_list->commands.erase(rit.base(), command_list->commands.end());
				if_command->pre_finalised = true;
				if_command->has_nested_else_if = has_nested_else_if;
				if (else_if_command)
					return _ParseEndIfCommand(G, section, command_list, ini_namespace, post, full_path, line_index, line, true);
				return true;
			}
		}
	}
	//wprintf(L"[WARNING] Statement \"endif\" missing \"if\"\ - [%ls] @ [%ls]\n", section, ini_namespace);
	G.errored_lines.insert(ErroredLine{ full_path, line_index, line, L"Missing \"if\" or invalid expression in \"if\""});
	return false;
}

static bool ParseEndIfCommand(Globals& G, const wchar_t* section,
	CommandList* pre_command_list, CommandList* post_command_list, const std::wstring* ini_namespace,
	const std::wstring& full_path, int line_index, const std::wstring& line)
{
	bool ret;

	ret = _ParseEndIfCommand(G, section, pre_command_list, ini_namespace, false, full_path, line_index, line);
	if (post_command_list)
		ret = ret && _ParseEndIfCommand(G, section, post_command_list, ini_namespace, true, full_path, line_index, line);

	if (ret)
		pre_command_list->scope->pop_front();

	return ret;
}

bool ParseCommandListFlowControl(Globals& G, const wchar_t* section, const std::wstring* line,
	CommandList* pre_command_list, CommandList* post_command_list,
	const std::wstring* ini_namespace, const std::wstring& full_path, int line_index)
{
	if (!wcsncmp(line->c_str(), L"if ", 3))
		return ParseIfCommand(G, section, line, pre_command_list, post_command_list, ini_namespace, full_path, line_index);

	if (!wcsncmp(line->c_str(), L"elif ", 5))
		return ParseElseIfCommand(G, section, line, 5, pre_command_list, post_command_list, ini_namespace, full_path, line_index);

	if (!wcsncmp(line->c_str(), L"else if ", 8))
		return ParseElseIfCommand(G, section, line, 8, pre_command_list, post_command_list, ini_namespace, full_path, line_index);

	if (!wcscmp(line->c_str(), L"else"))
		return ParseElseCommand(section, pre_command_list, post_command_list, ini_namespace, full_path, line_index, line->c_str());

	if (!wcscmp(line->c_str(), L"endif"))
		return ParseEndIfCommand(G, section, pre_command_list, post_command_list, ini_namespace, full_path, line_index, line->c_str());

	return false;
}

IfCommand::IfCommand(Globals& G, const wchar_t* section, const std::wstring& full_path, const std::wstring& line, int line_index) :
	pre_finalised(false),
	post_finalised(false),
	has_nested_else_if(false),
	section(section),
	full_path(full_path),
	line(line),
	line_index(line_index)
{
	true_commands_pre = std::make_shared<CommandList>();
	true_commands_post = std::make_shared<CommandList>();
	false_commands_pre = std::make_shared<CommandList>();
	false_commands_post = std::make_shared<CommandList>();
	true_commands_post->post = true;
	false_commands_post->post = true;

	true_commands_pre->ini_section = L"if placeholder";
	true_commands_post->ini_section = L"if placeholder";
	false_commands_pre->ini_section = L"else placeholder";
	false_commands_post->ini_section = L"else placeholder";

	G.dynamically_allocated_command_lists.push_back(true_commands_pre);
	G.dynamically_allocated_command_lists.push_back(true_commands_post);
	G.dynamically_allocated_command_lists.push_back(false_commands_pre);
	G.dynamically_allocated_command_lists.push_back(false_commands_post);

	G.registered_command_lists.push_back(true_commands_pre.get());
	G.registered_command_lists.push_back(true_commands_post.get());
	G.registered_command_lists.push_back(false_commands_pre.get());
	G.registered_command_lists.push_back(false_commands_post.get());
}

void IfCommand::run()
{
	
}

bool IfCommand::optimise()
{
	return expression.optimise();
}

bool IfCommand::noop(Globals& G, bool post, bool ignore_cto_pre, bool ignore_cto_post)
{
	float static_val;
	bool is_static;

	if ((post && !post_finalised) || (!post && !pre_finalised)) {
		//wprintf(L"[WARNING] Statement \"if\" missing \"endif\": - \"%ls\"\n", ini_line.c_str());
		G.errored_lines.insert(ErroredLine{ full_path, line_index, line, L"Missing \"endif\""});
		return true;
	}

	is_static = expression.static_evaluate(&static_val);
	if (is_static) {
		if (static_val) {
			false_commands_pre->clear();
			false_commands_post->clear();
		}
		else {
			true_commands_pre->clear();
			true_commands_post->clear();
		}
	}

	if (post)
		return true_commands_post->noop() && false_commands_post->noop();
	return true_commands_pre->noop() && false_commands_pre->noop();
}

void CommandPlaceholder::run()
{
	//printf("BUG: Placeholder command executed: %S\n", ini_line.c_str());
}

bool CommandPlaceholder::noop(Globals& G, bool post, bool ignore_cto_pre, bool ignore_cto_post)
{
	//wprintf(L"[WARNING] Command not terminated - [%ls]\n", ini_line.c_str());
	G.errored_lines.insert(ErroredLine{ full_path, line_index, line, L"Missing \"if\" or invalid expression in \"if\"" });
	return true;
}