#include <string>
#include "ResourceHash.h"
#include "Globals.h"

FuzzyMatchResourceDesc::FuzzyMatchResourceDesc(std::wstring section)
{
	texture_override = new TextureOverride();
	texture_override->ini_section = section;
}

FuzzyMatchResourceDesc::~FuzzyMatchResourceDesc()
{
	delete texture_override;
}

bool TextureOverrideLess(const struct TextureOverride& lhs, const struct TextureOverride& rhs)
{
	if (lhs.priority != rhs.priority)
		return lhs.priority < rhs.priority;
	return lhs.ini_section < rhs.ini_section;
}
bool FuzzyMatchResourceDescLess::operator() (const std::shared_ptr<FuzzyMatchResourceDesc>& lhs, const std::shared_ptr<FuzzyMatchResourceDesc>& rhs) const
{
	return TextureOverrideLess(*lhs->texture_override, *rhs->texture_override);
}