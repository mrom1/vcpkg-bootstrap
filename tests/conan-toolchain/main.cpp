#include <fmt/core.h>
#include <nlohmann/json.hpp>

#include <string>

int main()
{
    const auto json = nlohmann::json::parse(R"({"greeting": "Hello", "name": "World"})");
    fmt::print("{} {}!\n", json["greeting"].get<std::string>(), json["name"].get<std::string>());
    return 0;
}
