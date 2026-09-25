#ifdef USE_VCPKG
#include <fmt/core.h>
#else
#include <iostream>
#endif

int main()
{
#ifdef USE_VCPKG
    fmt::print("Hello {}!\n", "World");
#else
    std::cout << "Hello World!\n";
#endif
    return 0;
}
