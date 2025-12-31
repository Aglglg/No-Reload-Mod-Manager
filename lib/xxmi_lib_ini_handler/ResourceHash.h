#pragma once
#include <set>
#include <memory>
#include <string>

class FuzzyMatchResourceDesc {
public:
	struct TextureOverride* texture_override;

	FuzzyMatchResourceDesc(std::wstring section);
	~FuzzyMatchResourceDesc();
};
bool TextureOverrideLess(const struct TextureOverride& lhs, const struct TextureOverride& rhs);
struct FuzzyMatchResourceDescLess {
	bool operator() (const std::shared_ptr<FuzzyMatchResourceDesc>& lhs, const std::shared_ptr<FuzzyMatchResourceDesc>& rhs) const;
};
typedef std::set<std::shared_ptr<FuzzyMatchResourceDesc>, FuzzyMatchResourceDescLess> FuzzyTextureOverrides;