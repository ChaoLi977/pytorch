#pragma once
#include <ATen/ATen.h>

namespace at {
namespace native {

template <
    typename scalar_t,
    typename std::enable_if<std::is_same<c10::Half, scalar_t>::value>::type* =
        nullptr>
__device__ __forceinline__ void fastSpecializedAtomicAdd(
    scalar_t* tensor,
    size_t index,
    const size_t numel,
    scalar_t value) {
#if (                         \
    (CUDA_VERSION < 10000) || \
    (defined(__CUDA_ARCH__) && (__CUDA_ARCH__ < 700)))
  atomicAdd(
      reinterpret_cast<at::Half*>(tensor) + index,
      static_cast<at::Half>(value));
#else
  bool low_bit = (index % 2 == 0) &&
      (reinterpret_cast<std::uintptr_t>(tensor) % sizeof(__half2) == 0);

  if (low_bit && index < (numel - 1)) {
    __half2 value2;
    value2.x = value;
    value2.y = __int2half_rz(0);
    atomicAdd(reinterpret_cast<__half2*>(tensor) + index / 2, value2);

  } else if (!low_bit && index > 0) {
    __half2 value2;
    value2.x = __int2half_rz(0);
    value2.y = value;
    atomicAdd(reinterpret_cast<__half2*>(tensor) + index / 2, value2);

  } else {
    atomicAdd(
        reinterpret_cast<__half*>(tensor) + index, static_cast<__half>(value));
  }
#endif
}

template <
    typename scalar_t,
    typename std::enable_if<!std::is_same<c10::Half, scalar_t>::value>::type* =
        nullptr>
__device__ __forceinline__ void fastSpecializedAtomicAdd(
    scalar_t* tensor,
    size_t index,
    const size_t numel,
    scalar_t value) {
  atomicAdd(tensor + index, value);
}

template <class scalar_t>
__device__ __forceinline__ void fastAtomicAdd(
    scalar_t* tensor,
    size_t index,
    const size_t numel,
    scalar_t value,
    bool fast_atomics) {
  if (fast_atomics) {
    fastSpecializedAtomicAdd(tensor, index, numel, value);
  } else {
    atomicAdd(tensor + index, value);
  }
}

} // namespace native
} // namespace at
