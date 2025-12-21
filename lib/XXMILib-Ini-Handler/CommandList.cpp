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

void CommandList::clear()
{
	commands.clear();
	static_vars.clear();
}

float CommandListOperand::evaluate()
{
	//This project is to specifically parse & static evaluate included files, and parse if/elif statement.
	//But not to evaluate if/elif statement

	//DUMMY
	return 1;
}

bool CommandListOperand::static_evaluate(float* ret)
{
	switch (type) {
	case ParamOverrideType::VALUE:
		*ret = val;
		return true;
	case ParamOverrideType::HUNTING:
	case ParamOverrideType::FRAME_ANALYSIS:

		//It's also used to determine included file, in preamble "condition = "
		//But while parsing included file, hunting mode is not parsed yet.

		//And this project is to specifically parse & static evaluate included files, and parse if/elif statement.
		//But not to evaluate if/elif statement

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

static const wchar_t* operator_tokens[] = {
	L"===", L"!==",

	L"==", L"!=", L"//", L"<=", L">=", L"&&", L"||", L"**",

	L"(", L")", L"!", L"*", L"/", L"%", L"+", L"-", L"<", L">",
};

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

static void tokenise(Globals& G, const std::wstring* expression, CommandListSyntaxTree* tree, const std::wstring* ini_namespace, CommandListScope* scope)
{
	std::wstring remain = *expression;
	ResourceCopyTarget texture_filter_target;
	std::shared_ptr<CommandListOperand> operand;
	std::wstring token;
	size_t pos = 0;
	size_t start_pos = 0;
	size_t end_pos = 0;
	int ipos = 0;
	size_t friendly_pos = 0;
	float fval;
	int ret;
	int i;
	bool last_was_operand = false;

	//printf("    Tokenising \"%S\"\n", expression->c_str());

	while (true) {
	next_token:
		pos = remain.find_first_not_of(L" \t", pos);
		if (pos == std::wstring::npos)
			return;
		remain = remain.substr(pos);
		friendly_pos += pos;

		for (i = 0; i < ARRAYSIZE(operator_tokens); i++) {
			if (!remain.compare(0, wcslen(operator_tokens[i]), operator_tokens[i])) {
				pos = wcslen(operator_tokens[i]);
				tree->tokens.emplace_back(std::make_shared<CommandListOperatorToken>(friendly_pos, remain.substr(0, pos)));
				//printf("      Operator: \"%S\"\n", tree->tokens.back()->token.c_str());
				last_was_operand = false;
				goto next_token;
			}
		}

		pos = remain.find_first_not_of(L"abcdefghijklmnopqrstuvwxyz_-0123456789");
		if (pos) {
			token = remain.substr(0, pos);
			ret = texture_filter_target.ParseTarget(G, token.c_str(), true, ini_namespace);
			if (ret) {
				operand = std::make_shared<CommandListOperand>(friendly_pos, token);
				if (operand->parse(G, &token, ini_namespace, scope)) {
					tree->tokens.emplace_back(std::move(operand));
					//printf("      Resource Slot: \"%S\"\n", tree->tokens.back()->token.c_str());
					if (last_was_operand)
						throw CommandListSyntaxError(L"Unexpected identifier", friendly_pos);
					last_was_operand = true;
					continue;
				}
				else {
					//printf("BUG: Token parsed as resource slot, but not as operand: \"%S\"\n", token.c_str());
					throw CommandListSyntaxError(L"BUG", friendly_pos);
				}
			}
		}

		if (remain[0] < '0' || remain[0] > '9') {
			pos = remain.find_first_not_of(L"abcdefghijklmnopqrstuvwxyz_0123456789$.");
			if (remain[pos] == L'\\') {
				end_pos = remain.find_first_of(L"=&|+-/*><%!", pos + 1);
				start_pos = remain.rfind(L'\\', end_pos) + 1;
				pos = remain.find_first_not_of(L"abcdefghijklmnopqrstuvwxyz_0123456789.", start_pos);
			}

			if (pos) {
				token = remain.substr(0, pos);
				operand = std::make_shared<CommandListOperand>(friendly_pos, token);
				if (operand->parse(G, &token, ini_namespace, scope)) {
					tree->tokens.emplace_back(std::move(operand));
					//printf("      Identifier: \"%S\"\n", tree->tokens.back()->token.c_str());
					if (last_was_operand)
						throw CommandListSyntaxError(L"Unexpected identifier", friendly_pos);
					last_was_operand = true;
					continue;
				}
				throw CommandListSyntaxError(L"Unrecognised identifier: " + token, friendly_pos);
			}
		}

		ret = swscanf_s(remain.c_str(), L"%f%n", &fval, &ipos);
		if (ret != 0 && ret != EOF) {
			pos = ipos;

			token = remain.substr(0, ipos);
			operand = std::make_shared<CommandListOperand>(friendly_pos, token);
			if (operand->parse(G, &token, ini_namespace, scope)) {
				tree->tokens.emplace_back(std::move(operand));
				//printf("      Float: \"%S\"\n", tree->tokens.back()->token.c_str());
				if (last_was_operand)
					throw CommandListSyntaxError(L"Unexpected identifier", friendly_pos);
				last_was_operand = true;
				continue;
			}
			else {
				//printf("BUG: Token parsed as float, but not as operand: \"%S\"\n", token.c_str());
				throw CommandListSyntaxError(L"BUG", friendly_pos);
			}
		}

		throw CommandListSyntaxError(L"Parse error", friendly_pos);
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
DEFINE_OPERATOR(unary_plus_operator, "+", (+rhs));
DEFINE_OPERATOR(unary_negate_operator, "-", (-rhs));

DEFINE_OPERATOR(exponent_operator, "**", (pow(lhs, rhs)));

DEFINE_OPERATOR(multiplication_operator, "*", (lhs* rhs));
DEFINE_OPERATOR(division_operator, "/", (lhs / rhs));
DEFINE_OPERATOR(floor_division_operator, "//", (floor(lhs / rhs)));
DEFINE_OPERATOR(modulus_operator, "%", (fmod(lhs, rhs)));

DEFINE_OPERATOR(addition_operator, "+", (lhs + rhs));
DEFINE_OPERATOR(subtraction_operator, "-", (lhs - rhs));

DEFINE_OPERATOR(less_operator, "<", (lhs < rhs));
DEFINE_OPERATOR(less_equal_operator, "<=", (lhs <= rhs));
DEFINE_OPERATOR(greater_operator, ">", (lhs > rhs));
DEFINE_OPERATOR(greater_equal_operator, ">=", (lhs >= rhs));

DEFINE_OPERATOR(equality_operator, "==", (lhs == rhs));
DEFINE_OPERATOR(inequality_operator, "!=", (lhs != rhs));
DEFINE_OPERATOR(identical_operator, "===", (*(uint32_t*)&lhs == *(uint32_t*)&rhs));
DEFINE_OPERATOR(not_identical_operator, "!==", (*(uint32_t*)&lhs != *(uint32_t*)&rhs));

DEFINE_OPERATOR(and_operator, "&&", (lhs&& rhs));

DEFINE_OPERATOR(or_operator, "||", (lhs || rhs));

static CommandListOperatorFactoryBase* unary_operators[] = {
	&unary_not_operator,
	&unary_negate_operator,
	&unary_plus_operator,
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
		transform_operators_recursive(&tree, relational_operators, ARRAYSIZE(relational_operators), false, false);
		transform_operators_recursive(&tree, equality_operators, ARRAYSIZE(equality_operators), false, false);
		transform_operators_recursive(&tree, and_operators, ARRAYSIZE(and_operators), false, false);
		transform_operators_recursive(&tree, or_operators, ARRAYSIZE(or_operators), false, false);

		evaluatable = tree.finalise();

		////log_syntax_tree(evaluatable, "Final syntax tree:\n");
		return true;
	}
	catch (const CommandListSyntaxError& e) {
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

bool CommandListExpression::static_evaluate(float* ret)
{
	return evaluatable->static_evaluate(ret);
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

bool CommandListOperator::static_evaluate(float* ret)
{
	float lhs_static = std::numeric_limits<float>::quiet_NaN(), rhs_static;
	bool is_static;

	is_static = rhs->static_evaluate(&rhs_static);
	if (lhs)
		is_static = lhs->static_evaluate(&lhs_static) && is_static;

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

bool CommandListOperand::parse(Globals& G, const std::wstring* operand, const std::wstring* ini_namespace, CommandListScope* scope)
{
	CommandListVariable* var = NULL;
	int ret, len1;

	ret = swscanf_s(operand->c_str(), L"%f%n", &val, &len1);
	if (ret != 0 && ret != EOF && len1 == operand->length()) {
		type = ParamOverrideType::VALUE;
		return operand_allowed_in_context(type, scope);
	}

	if (ParseIniParamName(operand->c_str(), &param_idx)) {
		type = ParamOverrideType::INI_PARAM;
		//G->iniParamsReserved = max(G->iniParamsReserved, param_idx + 1);
		return operand_allowed_in_context(type, scope);
	}

	if (find_local_variable(*operand, scope, &var) ||
		parse_command_list_var_name(G, *operand, ini_namespace, &var)) {
		type = ParamOverrideType::VARIABLE;
		var_ftarget = &var->fval;
		return operand_allowed_in_context(type, scope);
	}

	ret = texture_filter_target.ParseTarget(G, operand->c_str(), true, ini_namespace);
	if (ret) {
		type = ParamOverrideType::TEXTURE;
		return operand_allowed_in_context(type, scope);
	}

	len1 = 0;
	ret = swscanf_s(operand->c_str(), L"%lcs%n", &shader_filter_target, 1, &len1);
	if (ret == 1 && len1 == operand->length()) {
		switch (shader_filter_target) {
		case L'v': case L'h': case L'd': case L'g': case L'p': case L'c':
			type = ParamOverrideType::SHADER;
			return operand_allowed_in_context(type, scope);
		}
	}

	len1 = 0;
	ret = swscanf_s(operand->c_str(), L"scissor%u_%n", &scissor, &len1);
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
	VariableAssignment* command = NULL;
	CommandListVariable* var = NULL;
	std::wstring name = key;

	if (name.empty() && raw_line)
		name = *raw_line;

	if (!name.compare(0, 6, L"local ")) {
		name = name.substr(name.find_first_not_of(L" \t", 6));
		if (!declare_local_variable(G, section, name, pre_command_list, ini_namespace))
			return false;

		if (val->empty())
			return true;
	}

	if (!find_local_variable(name, pre_command_list->scope, &var) &&
		!parse_command_list_var_name(G, name, ini_namespace, &var))
		return false;

	command = new VariableAssignment();
	command->var = var;

	if (!command->expression.parse(G, val, ini_namespace, command_list->scope))
		goto bail;

	command->ini_line = L"[" + std::wstring(section) + L"] " + std::wstring(key) + L" = " + *val;
	command_list->commands.push_back(std::shared_ptr<CommandListCommand>(command));
	return true;
bail:
	delete command;
	return false;
}

CustomResource::CustomResource()
{
}

CustomResource::~CustomResource()
{
}

bool ResourceCopyTarget::ParseTarget(Globals& G, const wchar_t* target,
	bool is_source, const std::wstring* ini_namespace)
{
	int ret, len;
	size_t length = wcslen(target);
	CustomResources::iterator res;

	ret = swscanf_s(target, L"%lcs-cb%u%n", &shader_type, 1, &slot, &len);
	//D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT = 14
	if (ret == 2 && len == length && slot < 14) {
		type = ResourceCopyTargetType::CONSTANT_BUFFER;
		goto check_shader_type;
	}

	ret = swscanf_s(target, L"%lcs-t%u%n", &shader_type, 1, &slot, &len);
	//D3D11_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT = 128
	if (ret == 2 && len == length && slot < 128) {
		type = ResourceCopyTargetType::SHADER_RESOURCE;
		goto check_shader_type;
	}

	ret = swscanf_s(target, L"o%u%n", &slot, &len);
	//D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT = 8
	if (ret == 1 && len == length && slot < 8) {
		type = ResourceCopyTargetType::RENDER_TARGET;
		return true;
	}

	if (!wcscmp(target, L"od")) {
		type = ResourceCopyTargetType::DEPTH_STENCIL_TARGET;
		return true;
	}

	ret = swscanf_s(target, L"%lcs-u%u%n", &shader_type, 1, &slot, &len);
	//D3D11_PS_CS_UAV_REGISTER_COUNT = 8
	if (ret == 2 && len == length && slot < 8) {

		if (shader_type == L'p' || shader_type == L'c') {
			type = ResourceCopyTargetType::UNORDERED_ACCESS_VIEW;
			return true;
		}
		return false;
	}

	ret = swscanf_s(target, L"vb%u%n", &slot, &len);
	//D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT	= 32
	if (ret == 1 && len == length && slot < 32) {
		type = ResourceCopyTargetType::VERTEX_BUFFER;
		return true;
	}

	if (!wcscmp(target, L"ib")) {
		type = ResourceCopyTargetType::INDEX_BUFFER;
		return true;
	}

	ret = swscanf_s(target, L"so%u%n", &slot, &len);
	//D3D11_SO_STREAM_COUNT	= 4
	if (ret == 1 && len == length && slot < 4) {
		type = ResourceCopyTargetType::STREAM_OUTPUT;
		return true;
	}

	if (is_source && !wcscmp(target, L"null")) {
		type = ResourceCopyTargetType::EMPTY;
		return true;
	}

	if (length >= 9 && !wcsncmp(target, L"resource", 8)) {

		std::wstring resource_id(target);
		std::wstring namespaced_section;

		res = G.customResources.end();
		if (get_namespaced_section_name_lower(&resource_id, ini_namespace, &namespaced_section))
			res = G.customResources.find(namespaced_section);
		if (res == G.customResources.end())
			res = G.customResources.find(resource_id);
		if (res == G.customResources.end())
			return false;

		custom_resource = &res->second;
		type = ResourceCopyTargetType::CUSTOM_RESOURCE;
		return true;
	}

	if (is_source && !wcscmp(target, L"iniparams")) {
		type = ResourceCopyTargetType::INI_PARAMS;
		return true;
	}

	if (is_source && !wcscmp(target, L"cursor_mask")) {
		type = ResourceCopyTargetType::CURSOR_MASK;
		return true;
	}

	if (is_source && !wcscmp(target, L"cursor_color")) {
		type = ResourceCopyTargetType::CURSOR_COLOR;
		return true;
	}

	if (!wcscmp(target, L"this")) {
		type = ResourceCopyTargetType::THIS_RESOURCE;
		return true;
	}

	if (is_source && !wcscmp(target, L"bb")) {
		type = ResourceCopyTargetType::SWAP_CHAIN;

		return true;
	}

	if (is_source && !wcscmp(target, L"r_bb")) {
		type = ResourceCopyTargetType::REAL_SWAP_CHAIN;

		return true;
	}

	if (is_source && !wcscmp(target, L"f_bb")) {
		type = ResourceCopyTargetType::FAKE_SWAP_CHAIN;

		return true;
	}

	return false;

check_shader_type:
	switch (shader_type) {
	case L'v': case L'h': case L'd': case L'g': case L'p': case L'c':
		return true;
	}
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
		return true_commands_post->commands.empty() && false_commands_post->commands.empty();
	return true_commands_pre->commands.empty() && false_commands_pre->commands.empty();
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