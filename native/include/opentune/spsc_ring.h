#pragma once
#include <atomic>
#include <array>
#include <cstddef>
#include <cstdint>

namespace opentune {
// Single producer, single consumer. Producer never modifies the consumer index.
// 32-bit indices are lock-free on every declared Android ABI. Monotonic modulo
// arithmetic is safe because capacity < 2^31 and the live distance is bounded.
template <size_t Capacity> class SpscRing {
    static_assert(Capacity > 0 && Capacity < (1u << 30));
    static_assert((Capacity & (Capacity - 1)) == 0, "power-of-two capacity preserves index wrap");
    static_assert(std::atomic<uint32_t>::is_always_lock_free);
public:
    size_t push(const float* data, size_t count) noexcept {
        const uint32_t w = write_.load(std::memory_order_relaxed);
        const uint32_t r = read_.load(std::memory_order_acquire);
        const size_t available = Capacity - static_cast<uint32_t>(w - r);
        const size_t copy = count < available ? count : available;
        for (size_t i = 0; i < copy; ++i) samples_[(w + i) % Capacity] = data[i];
        write_.store(w + static_cast<uint32_t>(copy), std::memory_order_release);
        return copy;
    }
    size_t pop(float* data, size_t capacity) noexcept {
        const uint32_t r = read_.load(std::memory_order_relaxed);
        const uint32_t w = write_.load(std::memory_order_acquire);
        const size_t available = static_cast<uint32_t>(w - r);
        const size_t copy = capacity < available ? capacity : available;
        for (size_t i = 0; i < copy; ++i) data[i] = samples_[(r + i) % Capacity];
        read_.store(r + static_cast<uint32_t>(copy), std::memory_order_release);
        return copy;
    }
    // Consumer only; safely drops backlog without touching producer-owned slots.
    size_t discard() noexcept {
        const uint32_t r = read_.load(std::memory_order_relaxed);
        const uint32_t w = write_.load(std::memory_order_acquire);
        read_.store(w, std::memory_order_release);
        return static_cast<uint32_t>(w - r);
    }
    size_t size() const noexcept {
        return static_cast<uint32_t>(write_.load(std::memory_order_acquire) - read_.load(std::memory_order_acquire));
    }
private:
    std::array<float, Capacity> samples_{};
    alignas(64) std::atomic<uint32_t> write_{0};
    alignas(64) std::atomic<uint32_t> read_{0};
};
}
