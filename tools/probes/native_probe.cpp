// Toolchain smoke probe only. This is NOT a pitch detector or production DSP.
#include <atomic>
#include <cmath>
#include <iostream>
#include <thread>

int main() {
    int failures = 0;
    const auto check = [&failures](const char* label, bool passed) {
        std::cout << (passed ? "PASS " : "FAIL ") << label << '\n';
        failures += passed ? 0 : 1;
    };
    check("double precision", sizeof(double) == 8);
    check("A0 mapping", std::abs(440.0 * std::exp2((21.0 - 69.0) / 12.0) - 27.5) < 1e-10);
    check("C8 mapping", std::abs(440.0 * std::exp2((108.0 - 69.0) / 12.0) - 4186.009044809578) < 1e-8);
    check("octave cents", std::abs(1200.0 * std::log2(880.0 / 440.0) - 1200.0) < 1e-10);
    check("negative cents", std::abs(1200.0 * std::log2(220.0 / 440.0) + 1200.0) < 1e-10);
    check("nonstandard target", std::abs(1200.0 * std::log2(442.0 / 442.0)) < 1e-10);
    std::atomic<int> state{0};
    std::thread worker([&state] { state.store(42, std::memory_order_release); });
    worker.join();
    check("thread and atomic", state.load(std::memory_order_acquire) == 42);
    std::cout << "Toolchain checks only; no audio or device validation.\n";
    return failures == 0 ? 0 : 1;
}
