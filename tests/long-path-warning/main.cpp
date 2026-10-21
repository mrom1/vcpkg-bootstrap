#include <Eigen/Core>
#include <iostream>

int main()
{
    const Eigen::Vector2i v(1, 1);
    if (v.sum() == 2)
        std::cout << "Hello World!" << std::endl;
    return 0;
}