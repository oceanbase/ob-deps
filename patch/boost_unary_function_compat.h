// Compatibility header for std::unary_function removed in C++17
// This file provides a compatibility alias for boost 1.67.0

#ifndef BOOST_UNARY_FUNCTION_COMPAT_H
#define BOOST_UNARY_FUNCTION_COMPAT_H

#include <functional>

#if __cplusplus >= 201703L
// C++17 and later: std::unary_function was removed
// Provide compatibility by redefining it in std namespace
// Note: This is a workaround for boost 1.67.0 compatibility
namespace std {
    template<class _Arg, class _Result>
    struct unary_function {
        typedef _Arg argument_type;
        typedef _Result result_type;
    };
}
#endif

#endif // BOOST_UNARY_FUNCTION_COMPAT_H

