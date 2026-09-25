#include <fmt/core.h>
#include <fmt/format.h>
#include <fmt/printf.h>
#include <fmt/color.h>


int main()
{
    fmt::print(fmt::fg(fmt::color::green), "Hello World!\n");
    return 0;
}
