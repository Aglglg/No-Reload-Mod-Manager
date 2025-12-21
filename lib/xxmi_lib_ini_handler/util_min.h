#pragma once

#define SENSIBLE_ENUM(ENUMTYPE) \
inline int operator | (ENUMTYPE a, ENUMTYPE b) { return (((int)a) | ((int)b)); } \
inline int operator & (ENUMTYPE a, ENUMTYPE b) { return (((int)a) & ((int)b)); } \
inline int operator ^ (ENUMTYPE a, ENUMTYPE b) { return (((int)a) ^ ((int)b)); } \
inline int operator ~ (ENUMTYPE a) { return (~((int)a)); } \
inline ENUMTYPE &operator |= (ENUMTYPE &a, ENUMTYPE b) { return (ENUMTYPE &)(((int &)a) |= ((int)b)); } \
inline ENUMTYPE &operator &= (ENUMTYPE &a, ENUMTYPE b) { return (ENUMTYPE &)(((int &)a) &= ((int)b)); } \
inline ENUMTYPE &operator ^= (ENUMTYPE &a, ENUMTYPE b) { return (ENUMTYPE &)(((int &)a) ^= ((int)b)); } \
inline bool operator || (ENUMTYPE a,  ENUMTYPE b) { return (((int)a) || ((int)b)); } \
inline bool operator || (    bool a,  ENUMTYPE b) { return (((int)a) || ((int)b)); } \
inline bool operator || (ENUMTYPE a,      bool b) { return (((int)a) || ((int)b)); } \
inline bool operator && (ENUMTYPE a,  ENUMTYPE b) { return (((int)a) && ((int)b)); } \
inline bool operator && (    bool a,  ENUMTYPE b) { return (((int)a) && ((int)b)); } \
inline bool operator && (ENUMTYPE a,      bool b) { return (((int)a) && ((int)b)); } \
inline bool operator ! (ENUMTYPE a) { return (!((int)a)); }

template <class T1, class T2>
struct EnumName_t {
	T1 name;
	T2 val;
};