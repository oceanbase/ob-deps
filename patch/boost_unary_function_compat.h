// Compatibility header for std::unary_function removed in C++17
// This file provides a compatibility alias for boost 1.67.0

#ifndef BOOST_UNARY_FUNCTION_COMPAT_H
#define BOOST_UNARY_FUNCTION_COMPAT_H

#include <functional>

#if __cplusplus >= 201703L
// C++17 and later: std::unary_function may be removed by some libstdc++ variants.
// Avoid redefining it on libc++/libstdc++ where it already exists (even if deprecated).
#if !defined(_LIBCPP_VERSION) && !defined(__GLIBCXX__)
namespace std {
    template<class _Arg, class _Result>
    struct unary_function {
        typedef _Arg argument_type;
        typedef _Result result_type;
    };
}
#endif
#endif

#endif // BOOST_UNARY_FUNCTION_COMPAT_H

