#!/bin/bash

export CXX_ABI=${CXX_ABI:-0}
export ABI_FLAG=$([[ "${CXX_ABI}" == "1" ]] && echo "-abiv1" || echo "")
export ABI_CXXFLAGS=$([[ "${CXX_ABI}" == "1" ]] && echo "-D_GLIBCXX_USE_CXX11_ABI=1" || echo "-D_GLIBCXX_USE_CXX11_ABI=0")
